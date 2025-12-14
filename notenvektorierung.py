#!/usr/bin/env python3
"""
Notenvektorisierungs-App für die Uni Mainz
=========================================
Vektorisiert Notenbücher (PDF) über die Uni Mainz API mit BGE-M3 Embeddings.
"""

import os
import sys
import json
import requests
import pdfplumber
import tiktoken
import re  # <--- Das muss ganz oben zu den Imports
from typing import List, Dict, Any
from chromadb import Client, Settings
from chromadb.utils import embedding_functions
import chromadb

# Konfiguration
API_BASE_URL = "https://ki-chat.uni-mainz.de/api"
API_KEY = os.environ.get("API_KEY", "")

# ChromaDB-Client (neue Konfiguration gemäß aktueller Dokumentation)
chroma_client = chromadb.PersistentClient(path="./chroma_db")

# Wir brauchen keine lokale Funktion, da wir die API nutzen.
# Das spart GB an Speicherplatz und Startzeit.
collection = chroma_client.get_or_create_collection(
    name="notenbuch_embeddings"
)

def extract_text_from_pdf(pdf_path: str) -> str:
    """Extrahiert Text und bereinigt typische PDF-Fehler."""
    try:
        full_text = []
        with pdfplumber.open(pdf_path) as pdf:
            for page in pdf.pages:
                # Extrahiere Text
                text = page.extract_text()
                if text:
                    full_text.append(text)
        
        raw_text = "\n".join(full_text)
        
        # --- REINIGUNGSPROZESS ---
        
        # 1. Silbentrennung reparieren (Wort- \nrest -> Wortrest)
        # Findet Bindestrich am Zeilenende und klebt das Wort zusammen
        cleaned_text = re.sub(r'(\w+)-\s*\n\s*(\w+)', r'\1\2', raw_text)
        
        # 2. Zeilenumbrüche innerhalb von Sätzen entfernen
        # (Macht aus "Dies ist ein\nSatz." -> "Dies ist ein Satz.")
        cleaned_text = re.sub(r'(?<!\n)\n(?!\n)', ' ', cleaned_text)
        
        # 3. Komische Sonderzeichen und Artefakte entfernen
        # Entfernt alles, was kein Buchstabe, Zahl oder normales Satzzeichen ist
        # (Entfernt ■, •, usw.)
        cleaned_text = re.sub(r'[^\w\s.,;:!?()"\'-äöüÄÖÜß]', '', cleaned_text)
        
        # 4. Mehrfach-Leerzeichen auf eines reduzieren
        cleaned_text = re.sub(r'\s+', ' ', cleaned_text)
        
        return cleaned_text
        
    except Exception as e:
        print(f"Fehler beim Lesen von {pdf_path}: {e}")
        return ""

def chunk_text(text: str, max_tokens: int = 256, overlap: int = 64) -> List[str]:
    """
    Teilt Text in Chunks mit Überlappung (Sliding Window).
    Verbesserung: Verhindert Informationsverlust an den Schnittstellen.
    """
    encoder = tiktoken.get_encoding("cl100k_base")
    tokens = encoder.encode(text)
    
    chunks = []
    total_tokens = len(tokens)
    
    # Wenn der Text kürzer ist als ein Chunk, gib ihn einfach zurück
    if total_tokens <= max_tokens:
        return [encoder.decode(tokens)]
    
    # Sliding Window Logik
    start = 0
    while start < total_tokens:
        end = min(start + max_tokens, total_tokens)
        chunk_tokens = tokens[start:end]
        chunks.append(encoder.decode(chunk_tokens))
        
        # Wir rücken vor, aber gehen ein Stück zurück (Overlap)
        # Schrittweite = Chunkgröße - Überlappung
        step = max_tokens - overlap
        
        # Abbruchbedingung, wenn wir am Ende sind
        if end == total_tokens:
            break
            
        start += step
    
    return chunks

def get_embeddings(chunks: List[str]) -> List[List[float]]:
    """Ruft Embeddings über die Uni Mainz API ab."""
    try:
        response = requests.post(
            f"{API_BASE_URL}/embeddings",
            headers={"Authorization": f"Bearer {API_KEY}"},
            json={"model": "bge-m3", "input": chunks}
        )
        response.raise_for_status()
        data = response.json()
        return [item["embedding"] for item in data["data"]]
    except Exception as e:
        print(f"Fehler bei der Embedding-Anfrage: {e}")
        return []

def process_pdf(pdf_path: str):
    """Verarbeitet eine PDF-Datei und speichert die Embeddings."""
    print(f"Verarbeite {pdf_path}...")
    
    # Text extrahieren
    text = extract_text_from_pdf(pdf_path)
    if not text:
        print(f"Kein Text in {pdf_path} gefunden.")
        return
    
    # In Chunks aufteilen
    chunks = chunk_text(text)
    print(f"Text in {len(chunks)} Chunks aufgeteilt.")
    
    # Embeddings abrufen
    embeddings = get_embeddings(chunks)
    if not embeddings:
        print("Keine Embeddings erhalten.")
        return
    
    # In ChromaDB speichern
    ids = [f"{pdf_path}_{i}" for i in range(len(chunks))]
    metadatas = [{"source": pdf_path, "chunk_id": i} for i in range(len(chunks))]
    
    collection.add(
        ids=ids,
        embeddings=embeddings,
        documents=chunks,
        metadatas=metadatas
    )
    
    print(f"✅ {len(chunks)} Embeddings für {pdf_path} gespeichert.")

def search_similar(query: str, n_results: int = 5) -> List[Dict[str, Any]]:
    """Sucht nach ähnlichen Textabschnitten."""
    try:
        # Embedding für Query abrufen
        query_embedding = get_embeddings([query])[0]
        
        # Suche in ChromaDB
        results = collection.query(
            query_embeddings=[query_embedding],
            n_results=n_results
        )
        
        # Formatierung der Ergebnisse
        formatted_results = []
        for i, doc in enumerate(results["documents"][0]):
            formatted_results.append({
                "text": doc,
                "source": results["metadatas"][0][i]["source"],
                "chunk_id": results["metadatas"][0][i]["chunk_id"],
                "distance": results["distances"][0][i]
            })
        
        return formatted_results
        
    except Exception as e:
        print(f"Fehler bei der Suche: {e}")
        return []

def show_usage():
    """Zeigt die korrekte Syntax für die Verwendung der App."""
    print("Verwendung:")
    print("  python notenvektorierung.py process <pdf_datei>")
    print("  python notenvektorierung.py search \"Suchbegriff\"")
    print("\nBeispiele:")
    print("  python notenvektorierung.py process EditionPetersUnterrichtslieder.pdf")
    print("  python notenvektorierung.py search \"Cricoarytenoid-Gelenk\"")

def main():
    """Hauptfunktion der App."""
    if not API_KEY:
        print("Fehler: API_KEY nicht gesetzt. Bitte setzen Sie die Umgebungsvariable API_KEY.")
        return
    
    if len(sys.argv) < 2:
        print("Fehler: Kein Befehl angegeben.")
        show_usage()
        return
    
    command = sys.argv[1]
    
    if command == "process":
        if len(sys.argv) < 3:
            print("Fehler: Keine PDF-Datei angegeben.")
            show_usage()
            return
        
        # Verarbeite alle angegebenen Dateien
        pdf_files = []
        for arg in sys.argv[2:]:
            if arg.endswith('.pdf'):
                pdf_files.append(arg)
            else:
                # Versuche, Wildcards zu expandieren
                import glob
                matched_files = glob.glob(arg)
                for matched_file in matched_files:
                    if matched_file.endswith('.pdf'):
                        pdf_files.append(matched_file)
        
        if not pdf_files:
            print("Fehler: Keine PDF-Dateien gefunden.")
            show_usage()
            return
        
        # Verarbeite jede PDF-Datei
        for pdf_path in pdf_files:
            process_pdf(pdf_path)
        
    elif command == "search":
        if len(sys.argv) < 3:
            print("Fehler: Kein Suchbegriff angegeben.")
            show_usage()
            return
        query = " ".join(sys.argv[2:])
        results = search_similar(query)
        
        print(f"\n🔍 Suchergebnisse für: {query}\n")
        for i, result in enumerate(results, 1):
            print(f"━━━ Ergebnis {i} ━━━")
            print(f"Quelle: {result['source']}")
            print(f"Chunk: {result['chunk_id']}")
            print(f"Ähnlichkeit: {1 - result['distance']:.4f}")
            print(f"Text: {result['text'][:300]}...")
            print()
    
    else:
        print(f"Fehler: Unbekannter Befehl: {command}")
        show_usage()

if __name__ == "__main__":
    main()
