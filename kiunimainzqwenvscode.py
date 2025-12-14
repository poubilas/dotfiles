#!/usr/bin/env python3
"""
JGU KI-Chat Terminal Client
===========================
Ein optisch ansprechender Terminal-Client für die KI-Chat-API der JGU Mainz.
Unterstützt Websuche via DuckDuckGo und seitenweises Scrollen.

Steuerung:
- SPACE: Nächste Seite
- b: Vorherige Seite
- q: Paging beenden
- /search <query>: Websuche durchführen
- /help: Hilfe anzeigen
- /models: Modelle anzeigen
- /model <name>: Modell wechseln
- /clear: Chatverlauf löschen
- /exit oder /quit: Beenden
"""

import os
import sys
import json
import requests
import re
import warnings
from typing import Optional, Generator

# Readline für Command History (Pfeiltasten)
try:
    import readline
    READLINE_AVAILABLE = True
except ImportError:
    READLINE_AVAILABLE = False

# Unterdrücke Deprecation-Warnungen
warnings.filterwarnings("ignore", category=RuntimeWarning)

# Tavily-Suche (primär) optional laden
try:
    from tavily import TavilyClient
    TAVILY_AVAILABLE = True
except ImportError:
    TAVILY_AVAILABLE = False
    print("Hinweis: tavily-python nicht installiert.")
    print("Für bessere Websuche: pip install tavily-python --break-system-packages")
    print()

# DuckDuckGo-Suche (Fallback) optional laden
try:
    from duckduckgo_search import DDGS
    DDGS_AVAILABLE = True
except ImportError:
    try:
        from ddgs import DDGS
        DDGS_AVAILABLE = True
    except ImportError:
        DDGS_AVAILABLE = False
        print("Hinweis: duckduckgo-search nicht installiert.")
        print("Für Websuche-Fallback: pip install duckduckgo-search --break-system-packages")
        print()

# BeautifulSoup für Web-Scraping optional
try:
    from bs4 import BeautifulSoup
    BS4_AVAILABLE = True
except ImportError:
    BS4_AVAILABLE = False

from rich.console import Console
from rich.panel import Panel
from rich.markdown import Markdown
from rich.table import Table
from rich.prompt import Prompt
from rich.text import Text
from rich.style import Style
from rich.box import ROUNDED, DOUBLE, SIMPLE, SQUARE
from rich.live import Live
from rich.spinner import Spinner
from rich.syntax import Syntax
from rich.rule import Rule
from rich.tree import Tree
from rich import print as rprint


# Konfiguration
API_BASE_URL = "https://ki-chat.uni-mainz.de/api"
API_KEY = os.environ.get("API_KEY", "")

# Console mit voller Terminal-Breite
import shutil
terminal_width = shutil.get_terminal_size().columns
console = Console(width=terminal_width, force_terminal=True, legacy_windows=False)


class Pager:
    """Einfacher Pager für seitenweises Scrollen mit Markdown-Unterstützung."""
    
    def __init__(self, content: str, lines_per_page: int = None, is_markdown: bool = False):
        self.raw_content = content
        self.is_markdown = is_markdown
        # Nutze nur 1 Zeile für Statusleiste statt 3
        self.lines_per_page = lines_per_page or (console.height - 1)
        
        # Für Markdown: Rendere und teile in Zeilen
        if is_markdown:
            # Teile den Content in logische Abschnitte (Paragraphen)
            self.sections = self._split_markdown(content)
        else:
            self.lines = content.split('\n')
        
        self._calculate_pages()
    
    def _split_markdown(self, content: str) -> list:
        """Teilt Markdown in Abschnitte."""
        # Teile an doppelten Zeilenumbrüchen (Paragraphen)
        sections = []
        current = []
        for line in content.split('\n'):
            if line.strip() == '' and current:
                sections.append('\n'.join(current))
                current = []
            else:
                current.append(line)
        if current:
            sections.append('\n'.join(current))
        return sections
    
    def _calculate_pages(self):
        """Berechnet die Seiten."""
        if self.is_markdown:
            # Schätze Zeilen pro Abschnitt und gruppiere
            self.pages = []
            current_page = []
            current_lines = 0
            
            for section in self.sections:
                section_lines = section.count('\n') + 3  # +3 für Padding
                if current_lines + section_lines > self.lines_per_page and current_page:
                    self.pages.append('\n\n'.join(current_page))
                    current_page = [section]
                    current_lines = section_lines
                else:
                    current_page.append(section)
                    current_lines += section_lines
            
            if current_page:
                self.pages.append('\n\n'.join(current_page))
            
            self.total_pages = len(self.pages) if self.pages else 1
        else:
            self.total_pages = max(1, (len(self.lines) + self.lines_per_page - 1) // self.lines_per_page)
    
    def get_page(self, page_num: int) -> str:
        """Gibt den Inhalt einer bestimmten Seite zurück."""
        if self.is_markdown:
            if page_num < len(self.pages):
                return self.pages[page_num]
            return ""
        else:
            start = page_num * self.lines_per_page
            end = start + self.lines_per_page
            return '\n'.join(self.lines[start:end])
    
    def show(self):
        """Zeigt den Inhalt mit Paging an."""
        if self.total_pages <= 1:
            if self.is_markdown:
                console.print(Markdown(self.raw_content))
            else:
                console.print(self.raw_content)
            return
        
        import termios
        import tty
        
        def get_char():
            fd = sys.stdin.fileno()
            old_settings = termios.tcgetattr(fd)
            try:
                tty.setraw(fd)
                ch = sys.stdin.read(1)
            finally:
                termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
            return ch
        
        current_page = 0
        while True:
            console.clear()
            
            # Zeige aktuelle Seite
            page_content = self.get_page(current_page)
            if self.is_markdown:
                console.print(Markdown(page_content))
            else:
                console.print(page_content)
            
            # Status-Leiste
            status = Text()
            status.append(f"\n── Seite {current_page + 1}/{self.total_pages} ", style="dim")
            status.append("│ ", style="dim")
            status.append("SPACE", style="bold cyan")
            status.append("=vor ", style="dim")
            status.append("b", style="bold cyan")
            status.append("=zurück ", style="dim")
            status.append("q", style="bold cyan")
            status.append("=beenden ──", style="dim")
            console.print(status)
            
            char = get_char()
            
            if char == ' ':
                if current_page < self.total_pages - 1:
                    current_page += 1
            elif char == 'b':
                if current_page > 0:
                    current_page -= 1
            elif char == 'q':
                break


class JGUKIChat:
    """Hauptklasse für den KI-Chat-Client."""
    
    def __init__(self):
        self.api_key = API_KEY
        self.base_url = API_BASE_URL
        self.models: list = []
        self.current_model: str = ""
        self.conversation: list = []

        # Tavily (primär) und DDGS (Fallback) initialisieren
        self.tavily_api_key = os.environ.get("TAVILY_API_KEY", "")
        self.tavily = TavilyClient(api_key=self.tavily_api_key) if TAVILY_AVAILABLE and self.tavily_api_key else None
        self.ddgs = DDGS() if DDGS_AVAILABLE else None
        self.last_search_method = None  # Speichert welche Suchmethode zuletzt verwendet wurde
        self.last_search_info = None    # Speichert Details zur letzten Suche (Anzahl Quellen, etc.)

        self.history_file = os.path.expanduser("~/.jgu_ki_chat_history")
        self.reasoning_effort: str = "medium"  # Standard: medium

        # Konfiguriere readline für Command History
        if READLINE_AVAILABLE:
            self._setup_readline()
        
    def _setup_readline(self):
        """Konfiguriert readline für Command History mit Pfeiltasten."""
        try:
            # Lade existierende History
            if os.path.exists(self.history_file):
                readline.read_history_file(self.history_file)

            # Setze History-Länge
            readline.set_history_length(1000)

            # Emacs-Tastenbelegung (Standard für Pfeiltasten)
            readline.parse_and_bind('set editing-mode emacs')

        except Exception as e:
            # Fehler beim Setup ignorieren, History ist optional
            pass

    def _save_history(self):
        """Speichert Command History beim Beenden."""
        if READLINE_AVAILABLE:
            try:
                readline.write_history_file(self.history_file)
            except Exception:
                pass

    def check_api_key(self) -> bool:
        """Überprüft, ob ein API-Key vorhanden ist."""
        if not self.api_key:
            console.print(Panel(
                "[bold red]Fehler:[/bold red] Kein API_KEY gefunden!\n\n"
                "Bitte setzen Sie die Umgebungsvariable API_KEY:\n"
                "[cyan]export API_KEY='Ihr-API-Schlüssel'[/cyan]\n\n"
                "Den Schlüssel erhalten Sie unter:\n"
                "[link]https://ki-chat.uni-mainz.de[/link] → Einstellungen → Konto\n\n"
                "Warum startet die App nicht?\n"
                "Die App benötigt einen gültigen API-Key, um mit der KI-Chat-API der JGU Mainz zu kommunizieren. "
                "Ohne diesen Schlüssel kann die App nicht auf die API zugreifen und startet daher nicht.",
                title="🔑 API-Schlüssel fehlt",
                border_style="red",
                expand=True
            ))
            return False
        return True
    
    def get_headers(self) -> dict:
        """Gibt die HTTP-Headers für API-Anfragen zurück."""
        return {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
    
    def fetch_models(self) -> list:
        """Ruft die verfügbaren Modelle von der API ab."""
        try:
            response = requests.get(
                f"{self.base_url}/models",
                headers=self.get_headers(),
                timeout=30
            )
            response.raise_for_status()
            data = response.json()
            self.models = [m.get("id", m.get("name", "Unknown")) for m in data.get("data", [])]
            return self.models
        except requests.RequestException as e:
            console.print(f"[red]Fehler beim Abrufen der Modelle: {e}[/red]")
            return []
    
    def select_model(self) -> Optional[str]:
        """Zeigt Modellauswahl an und lässt den Benutzer wählen."""
        with console.status("[bold green]Lade verfügbare Modelle...", spinner="dots"):
            models = self.fetch_models()
        
        if not models:
            console.print("[red]Keine Modelle verfügbar.[/red]")
            return None
        
        # Komplett neues Layout: Einfache nummerierte Liste
        console.print()
        console.print("[bold cyan]🤖 Verfügbare Modelle:[/bold cyan]")
        console.print()

        for i, model in enumerate(models, 1):
            console.print(f"  [cyan][{i}][/cyan]  [green]{model}[/green]")
        console.print()
        
        while True:
            try:
                console.print("[bold cyan]Modell auswählen (Nummer oder Name) [1][/bold cyan]: ", end="")
                choice = input() or "1"
            except EOFError:
                # Ctrl+D wird ignoriert
                console.print()
                continue

            # Versuche als Nummer zu interpretieren
            try:
                idx = int(choice) - 1
                if 0 <= idx < len(models):
                    self.current_model = models[idx]
                    return self.current_model
            except ValueError:
                pass

            # Versuche als Name zu interpretieren
            for model in models:
                if choice.lower() in model.lower():
                    self.current_model = model
                    return self.current_model

            console.print("[yellow]Ungültige Auswahl. Bitte erneut versuchen.[/yellow]")
    
    def extract_search_keywords(self, question: str) -> list[str]:
        """Extrahiert sinnvolle Suchbegriffe aus einer Frage. Gibt Liste von Suchqueries zurück."""
        # Entferne typische Fragewörter und Füllwörter
        stopwords = {
            "wie", "was", "wer", "wo", "wann", "warum", "welche", "welcher", "welches",
            "ist", "sind", "war", "waren", "wird", "werden", "kann", "können",
            "der", "die", "das", "den", "dem", "des", "ein", "eine", "einer", "einem",
            "und", "oder", "aber", "denn", "weil", "dass", "ob", "wenn", "als",
            "zu", "zum", "zur", "von", "vom", "bei", "mit", "für", "über", "unter",
            "ich", "du", "er", "sie", "es", "wir", "ihr", "mich", "mir", "dich", "dir",
            "nicht", "kein", "keine", "keiner", "auch", "noch", "schon", "sehr",
            "bitte", "kannst", "könntest", "würdest", "sag", "sage", "erzähl", "erkläre",
            "gib", "zeig", "zeige", "finde", "such", "suche", "vergleiche", "vergleich",
            "the", "is", "are", "was", "were", "what", "who", "where", "when", "why", "how",
            "can", "could", "would", "please", "tell", "me", "about", "find", "compare",
            "in", "im", "an", "am", "auf"
        }
        
        # Erkenne Thema der Anfrage
        question_lower = question.lower()
        topic_prefix = ""
        topic_words = set()

        if any(w in question_lower for w in ["wetter", "temperatur", "regen", "weather", "klima"]):
            topic_prefix = "Wetter heute"
            topic_words = {"wetter", "temperatur", "regen", "weather", "klima", "wie", "ist", "das"}
        elif any(w in question_lower for w in ["news", "nachrichten", "aktuell", "neuigkeiten"]):
            topic_prefix = "News aktuell"
            topic_words = {"news", "nachrichten", "aktuell", "neuigkeiten"}
        elif any(w in question_lower for w in ["preis", "kosten", "price", "cost"]):
            topic_prefix = "Preis aktuell"
            topic_words = {"preis", "kosten", "price", "cost"}
        
        # Bereinige die Frage
        clean_question = question.replace(",", " , ").replace("?", "").replace("!", "").replace(".", "")
        original_words = clean_question.split()
        
        # Finde zusammenhängende Ortsnamen (Wörter mit Großbuchstaben die aufeinanderfolgen)
        locations = []
        current_location = []
        
        for word in original_words:
            if word == ",":
                if current_location:
                    locations.append(" ".join(current_location))
                    current_location = []
            elif word[0].isupper() and word.lower() not in stopwords and word.lower() not in topic_words:
                current_location.append(word)
            else:
                if current_location:
                    locations.append(" ".join(current_location))
                    current_location = []
        
        if current_location:
            locations.append(" ".join(current_location))
        
        # Entferne Duplikate und leere Einträge
        locations = list(dict.fromkeys([loc for loc in locations if loc.strip()]))
        
        # Wenn mehrere Orte gefunden und ein Thema erkannt, erstelle separate Suchen
        if len(locations) >= 2 and topic_prefix:
            return [f"{topic_prefix} {loc}" for loc in locations]
        
        # Wenn ein Ort und Thema (für Wetter: spezifischere Query)
        if len(locations) == 1 and topic_prefix:
            if "Wetter" in topic_prefix:
                # Bessere Wetter-Query für aktuelle Daten (nur eine Query)
                return [f"Wetter {locations[0]} aktuell heute"]
            return [f"{topic_prefix} {locations[0]}"]
        
        # Fallback: Alle relevanten Wörter
        keywords = [w for w in original_words if w.lower() not in stopwords and len(w) > 1 and w != ","]
        if keywords:
            return [" ".join(keywords)]
        
        return [question.replace("?", "").strip()]
    
    def fetch_page_content(self, url: str, max_chars: int = 3000) -> Optional[str]:
        """Ruft den Textinhalt einer Webseite ab."""
        # Überspringe bekannte irrelevante Domains
        skip_domains = ['microsoft.com', 'office.com', 'apple.com', 'google.com/search', 
                        'facebook.com', 'twitter.com', 'instagram.com', 'amazon.com',
                        'youtube.com', 'linkedin.com']
        if any(domain in url.lower() for domain in skip_domains):
            return None
        
        try:
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            response = requests.get(url, headers=headers, timeout=10)
            response.raise_for_status()
            
            if BS4_AVAILABLE:
                soup = BeautifulSoup(response.text, 'html.parser')
                
                # Entferne Script, Style, Nav, Footer etc.
                for element in soup(['script', 'style', 'nav', 'footer', 'header', 'aside', 'iframe', 'noscript']):
                    element.decompose()
                
                # Extrahiere Text
                text = soup.get_text(separator=' ', strip=True)
            else:
                # Fallback: Einfache Regex-basierte Extraktion
                text = re.sub(r'<script[^>]*>.*?</script>', '', response.text, flags=re.DOTALL | re.IGNORECASE)
                text = re.sub(r'<style[^>]*>.*?</style>', '', text, flags=re.DOTALL | re.IGNORECASE)
                text = re.sub(r'<[^>]+>', ' ', text)
                text = re.sub(r'\s+', ' ', text).strip()
            
            # Bereinige und kürze
            text = re.sub(r'\s+', ' ', text)
            
            if len(text) > max_chars:
                text = text[:max_chars] + "..."
            
            return text if len(text) > 100 else None
            
        except Exception as e:
            return None
    
    def web_search_tavily(self, query: str, max_results: int = 5):
        """Führt eine Websuche mit Tavily durch (bevorzugte Methode)."""
        try:
            # Erkenne komplexe Recherche-Fragen und erhöhe Quellenanzahl
            is_research_query = any(kw in query.lower() for kw in [
                "vergleich", "compare", "analyse", "analyse", "forschung",
                "research", "studie", "paper", "unterschied", "entwicklung"
            ])

            # Passe Tiefe und Anzahl an
            depth = "advanced" if is_research_query else "basic"
            results = max(max_results, 8) if is_research_query else max_results

            response = self.tavily.search(
                query=query,
                search_depth=depth,
                max_results=results,
                include_answer=True
            )

            output = []

            # Anzahl der gefundenen Quellen
            num_results = len(response.get('results', []))

            # Speichere Info für spätere Anzeige
            self.last_search_info = {
                'sources': num_results,
                'depth': depth,
                'method': 'Tavily'
            }

            output.append(f"🔍 Suchergebnisse für: {query}")
            output.append(f"📊 Quellen verwendet: {num_results} | Suchtiefe: {depth}\n")

            # Direkte Antwort von Tavily (wenn verfügbar)
            if response.get('answer'):
                output.append(f"📝 Zusammenfassung: {response['answer']}\n")

            # Detaillierte Quellen
            for i, result in enumerate(response.get('results', []), 1):
                title = result.get('title', 'Kein Titel')
                url = result.get('url', '')
                content = result.get('content', 'Keine Beschreibung')

                output.append(f"━━━ Quelle {i}: {title} ━━━")
                output.append(f"URL: {url}")
                output.append(f"Inhalt:\n{content}\n")

            return '\n'.join(output)

        except Exception as e:
            # Bei Fehler zurück zu None, damit Fallback greift
            return None

    def web_search_ddgs(self, query: str, max_results: int = 5):
        """Führt eine Websuche mit DuckDuckGo durch (Fallback)."""
        if not self.ddgs:
            return None

        try:
            # Einfache DDGS-Suche (Fallback)
            raw_results = list(self.ddgs.text(query, max_results=max_results, region='de-de'))

            if not raw_results:
                return None

            num_results = min(len(raw_results), max_results)

            # Speichere Info für spätere Anzeige
            self.last_search_info = {
                'sources': num_results,
                'depth': 'basic',
                'method': 'DuckDuckGo'
            }

            output = []
            output.append(f"🔍 Suchergebnisse für: {query}")
            output.append(f"📊 Quellen verwendet: {num_results} | Suchtiefe: basic\n")

            for i, result in enumerate(raw_results[:max_results], 1):
                title = result.get('title', 'Kein Titel')
                url = result.get('href', '')
                snippet = result.get('body', 'Keine Beschreibung')

                output.append(f"━━━ Quelle {i}: {title} ━━━")
                output.append(f"URL: {url}")

                # Versuche Seiteninhalt zu holen
                page_content = self.fetch_page_content(url)
                if page_content:
                    output.append(f"Inhalt:\n{page_content}\n")
                else:
                    output.append(f"Zusammenfassung: {snippet}\n")

            return '\n'.join(output)

        except Exception as e:
            return None

    def web_search(self, query: str, max_results: int = 5, return_structured: bool = False):
        """Führt eine Websuche durch - versucht zuerst Tavily, dann DDGS als Fallback.

        Args:
            query: Suchanfrage
            max_results: Maximale Anzahl Ergebnisse
            return_structured: Wird ignoriert (Legacy-Parameter)

        Returns:
            String mit Suchergebnissen oder Fehlermeldung
        """
        search_result = None
        used_method = None

        # 1. Versuche Tavily (bevorzugt)
        if self.tavily:
            search_result = self.web_search_tavily(query, max_results)
            if search_result:
                used_method = "Tavily"

        # 2. Fallback zu DDGS
        if not search_result and self.ddgs:
            search_result = self.web_search_ddgs(query, max_results)
            if search_result:
                used_method = "DuckDuckGo (Fallback)"

        # 3. Keine Suchmethode verfügbar
        if not search_result:
            error_msg = "Websuche nicht verfügbar. Bitte installiere:\n"
            error_msg += "  • pip install tavily-python --break-system-packages (empfohlen)\n"
            error_msg += "  • pip install duckduckgo-search --break-system-packages (Fallback)"
            self.last_search_method = None
            return (error_msg, []) if return_structured else error_msg

        # Speichere welche Methode verwendet wurde (für spätere Anzeige)
        self.last_search_method = used_method

        # Gebe nur die Suchergebnisse zurück (ohne "Verwendet:" Präfix)
        return (search_result, []) if return_structured else search_result
    
    def display_search_tree(self, structured_results: list):
        """Zeigt Suchergebnisse als hierarchischen Tree an."""
        tree = Tree("🔍 [bold cyan]Suchergebnisse[/bold cyan]", guide_style="dim")

        for query_data in structured_results:
            query_branch = tree.add(f"[yellow]Query:[/yellow] [bold]{query_data['query']}[/bold]")

            for result in query_data['results']:
                source_branch = query_branch.add(
                    f"[green]#{result['source_num']}[/green] [link={result['url']}]{result['title']}[/link]"
                )
                source_branch.add(f"[dim]🔗 {result['url']}[/dim]")
                source_branch.add(f"[dim italic]{result['content'][:150]}...[/dim italic]")

        console.print(tree)

    def chat_completion_direct(self, messages: list) -> Generator[str, None, None]:
        """Sendet eine Nachrichtenliste direkt an die API."""
        payload = {
            "model": self.current_model,
            "messages": messages,
            "stream": True
        }

        # Füge reasoning_effort hinzu für GPT OSS 120B
        # Laut Doku: https://www.zdv.uni-mainz.de/ki-chat-api-nutzung/
        # Werte: "low", "medium", "high"
        if "gpt oss 120b" in self.current_model.lower():
            payload["reasoning_effort"] = self.reasoning_effort
        
        try:
            response = requests.post(
                f"{self.base_url}/chat/completions",
                headers=self.get_headers(),
                json=payload,
                stream=True,
                timeout=120
            )

            # Besseres Error Handling
            if response.status_code != 200:
                error_detail = ""
                try:
                    error_data = response.json()
                    error_detail = f"\nDetails: {json.dumps(error_data, indent=2)}"
                except:
                    error_detail = f"\nResponse: {response.text[:500]}"

                yield f"\n[API Error {response.status_code}]{error_detail}\n"
                return

            response.raise_for_status()
            
            for line in response.iter_lines():
                if line:
                    line = line.decode('utf-8')
                    if line.startswith("data: "):
                        data = line[6:]
                        if data == "[DONE]":
                            break
                        try:
                            chunk = json.loads(data)
                            delta = chunk.get("choices", [{}])[0].get("delta", {})
                            content = delta.get("content", "")
                            if content:
                                yield content
                        except json.JSONDecodeError:
                            continue
            
        except requests.RequestException as e:
            yield f"\n[Fehler: {e}]"
    
    def chat_completion(self, user_message: str, use_search: bool = False) -> Generator[str, None, None]:
        """Sendet eine Nachricht an die API und streamt die Antwort."""

        # Zurücksetzen der letzten Such-Informationen (wird ggf. in web_search() neu gesetzt)
        self.last_search_method = None
        self.last_search_info = None

        # Websuche bei Bedarf - erweiterte Trigger-Wörter
        search_context = ""
        search_triggers = ["aktuell", "heute", "news", "neu", "2024", "2025",
                          "wetter", "weather", "temperatur", "preis", "kurs", "börse",
                          "letzte", "latest", "current", "jetzt", "gerade"]

        # Prüfe ob IRGENDEINE Suchmethode verfügbar ist (Tavily ODER DDGS)
        # Nur bei explizitem /w oder eindeutigen Aktualitäts-Anfragen
        strong_triggers = ["aktuell", "heute", "news", "2025", "wetter", "weather", "preis", "kurs"]
        should_search = use_search or any(kw in user_message.lower() for kw in strong_triggers)

        if (self.tavily or self.ddgs) and should_search:
            # Websuche durchführen
            search_results = self.web_search(user_message)
            if search_results and "Fehler" not in search_results and "nicht verfügbar" not in search_results:
                search_context = f"\n\n[Aktuelle Suchergebnisse zum Thema:\n{search_results}]\n\n"
        
        # Nachricht mit Suchkontext erweitern
        enhanced_message = user_message
        if search_context:
            enhanced_message = f"{user_message}\n\nBitte berücksichtige diese aktuellen Informationen aus dem Web:{search_context}"
        
        self.conversation.append({"role": "user", "content": enhanced_message})

        payload = {
            "model": self.current_model,
            "messages": self.conversation,
            "stream": True
        }

        # Füge reasoning_effort hinzu für GPT OSS 120B
        # Laut Doku: https://www.zdv.uni-mainz.de/ki-chat-api-nutzung/
        # Werte: "low", "medium", "high"
        if "gpt oss 120b" in self.current_model.lower():
            payload["reasoning_effort"] = self.reasoning_effort
        
        try:
            response = requests.post(
                f"{self.base_url}/chat/completions",
                headers=self.get_headers(),
                json=payload,
                stream=True,
                timeout=120
            )

            # Besseres Error Handling
            if response.status_code != 200:
                error_detail = ""
                try:
                    error_data = response.json()
                    error_detail = f"\nDetails: {json.dumps(error_data, indent=2)}"
                except:
                    error_detail = f"\nResponse: {response.text[:500]}"

                yield f"\n[API Error {response.status_code}]{error_detail}\n"
                return

            response.raise_for_status()
            
            full_response = ""
            for line in response.iter_lines():
                if line:
                    line = line.decode('utf-8')
                    if line.startswith("data: "):
                        data = line[6:]
                        if data == "[DONE]":
                            break
                        try:
                            chunk = json.loads(data)
                            delta = chunk.get("choices", [{}])[0].get("delta", {})
                            content = delta.get("content", "")
                            if content:
                                full_response += content
                                yield content
                        except json.JSONDecodeError:
                            continue
            
            self.conversation.append({"role": "assistant", "content": full_response})
            
        except requests.RequestException as e:
            yield f"\n[Fehler: {e}]"
    
    def enhance_code_blocks(self, text: str) -> str:
        """Verbessert Code-Blöcke mit explizitem Syntax Highlighting.

        Erkennt ```language Code-Blöcke und rendert sie mit rich.syntax.Syntax
        für besseres Highlighting statt Standard-Markdown.
        """
        import re

        # Pattern für Code-Blöcke mit Sprach-Angabe
        pattern = r'```(\w+)\n(.*?)```'

        # Sammle alle Code-Blöcke
        code_blocks = []
        for match in re.finditer(pattern, text, re.DOTALL):
            lang = match.group(1)
            code = match.group(2)
            code_blocks.append({
                'lang': lang,
                'code': code,
                'full_match': match.group(0),
                'start': match.start(),
                'end': match.end()
            })

        # Wenn Code-Blöcke gefunden wurden, zeige sie separat mit besserem Styling
        if code_blocks:
            parts = []
            last_end = 0

            for block in code_blocks:
                # Text vor dem Code-Block
                before = text[last_end:block['start']]
                if before.strip():
                    parts.append(('text', before))

                # Code-Block mit Syntax Highlighting
                parts.append(('code', block['lang'], block['code']))
                last_end = block['end']

            # Rest nach dem letzten Code-Block
            after = text[last_end:]
            if after.strip():
                parts.append(('text', after))

            return parts

        return None

    def display_response(self, response_text: str):
        """Zeigt eine Antwort mit Paging an."""

        # Versuche Code-Blöcke zu extrahieren für verbessertes Highlighting
        enhanced_parts = self.enhance_code_blocks(response_text)

        # Zähle geschätzte Zeilen (inkl. Markdown-Expansion)
        line_count = response_text.count('\n')
        has_tables = '|' in response_text and '---' in response_text

        # Tabellen brauchen mehr Platz
        if has_tables:
            line_count *= 2

        # Für kurze Antworten: direkt anzeigen (nutze mehr Platz)
        if line_count < console.height - 5:
            if enhanced_parts:
                # Zeige mit verbessertem Code-Highlighting
                for part in enhanced_parts:
                    if part[0] == 'text':
                        console.print(Markdown(part[1]))
                    elif part[0] == 'code':
                        lang, code = part[1], part[2]
                        syntax = Syntax(code, lang, theme="monokai", line_numbers=True, background_color="default")
                        console.print(Panel(syntax, title=f"💻 {lang.upper()}", border_style="cyan", expand=True))
            else:
                console.print(Panel(
                    Markdown(response_text),
                    title="🤖 Antwort",
                    border_style="green",
                    box=ROUNDED,
                    expand=True
                ))
        else:
            # Für lange Antworten: Paging mit Markdown
            console.print(Panel(
                "[dim]Lange Antwort - Paging aktiviert (SPACE/b/q)[/dim]",
                title="🤖 Antwort",
                border_style="green",
                box=ROUNDED,
                expand=True
            ))
            pager = Pager(response_text, is_markdown=True)
            pager.show()

        # Trennlinie nach jeder Antwort
        console.print(Rule(style="dim blue"))
    
    def show_help(self):
        """Zeigt Hilfe an."""
        help_text = '''
[bold cyan]Verfügbare Befehle:[/bold cyan]

[bold yellow]Websuche:[/bold yellow]
[green]/w <frage>[/green]       - Frage mit Websuche beantworten

[bold yellow]Chat:[/bold yellow]
[green]/model[/green]           - Modell wechseln
[green]/reasoning <level>[/green] - Reasoning Effort setzen (low/medium/high, nur für GPT OSS 120B)
[green]/paste[/green]           - Paste-Modus für lange, mehrzeilige Texte (beende mit END)
[green]/clear[/green]           - Chatverlauf löschen
[green]/history[/green]         - Chatverlauf anzeigen
[green]/help[/green]            - Diese Hilfe anzeigen
[green]/exit[/green] oder [green]/quit[/green] - Programm beenden

[bold cyan]Paging-Steuerung (bei langen Antworten):[/bold cyan]

[green]SPACE[/green]  - Nächste Seite
[green]b[/green]      - Vorherige Seite
[green]q[/green]      - Paging beenden

[bold cyan]Tipps:[/bold cyan]

• Verwende [bold]/w <frage>[/bold] für Websuche (z.B.: /w Wetter Mainz)
• [bold]Websuche:[/bold] Nutzt Tavily (bevorzugt) mit DuckDuckGo als Fallback
• [bold]Mehrzeilen-Eingabe:[/bold] Starte mit [cyan]"""[/cyan] und beende mit [cyan]"""[/cyan] auf neuer Zeile
• Die App führt automatisch Websuche durch bei Themen wie
  Wetter, Preise, News, Börse oder Schlüsselwörtern wie "aktuell", "heute"
• Der Chatverlauf wird zwischen Fragen beibehalten
• Mit /clear kann ein neues Gespräch begonnen werden
• Mit Ctrl+C beendest du das Programm jederzeit
• Mit ↑/↓ Pfeiltasten navigierst du durch die Command History
'''
        console.print(Panel(help_text, title="📖 Hilfe", border_style="blue", expand=True))
    
    def show_history(self):
        """Zeigt den Chatverlauf an."""
        if not self.conversation:
            console.print("[yellow]Noch kein Chatverlauf vorhanden.[/yellow]")
            return
        
        output = []
        for msg in self.conversation:
            role = msg["role"]
            content = msg["content"][:200] + "..." if len(msg["content"]) > 200 else msg["content"]
            if role == "user":
                output.append(f"[bold blue]👤 Du:[/bold blue]\n{content}\n")
            else:
                output.append(f"[bold green]🤖 KI:[/bold green]\n{content}\n")
        
        pager = Pager('\n'.join(output))
        pager.show()
    
    def print_header(self):
        """Zeigt den Header an."""
        console.print()
        console.print("[bold cyan]" + "=" * 70 + "[/bold cyan]")
        console.print()
        console.print("[bold white]            🎓  JGU Mainz KI-Chat Terminal Client[/bold white]")
        console.print("[dim]                  Powered by ki-chat.uni-mainz.de[/dim]")
        console.print()
        console.print("[bold cyan]" + "=" * 70 + "[/bold cyan]")
        console.print()
    
    def run(self):
        """Hauptschleife des Chat-Clients."""
        console.clear()
        self.print_header()
        
        if not self.check_api_key():
            return
        
        # Modellauswahl
        if not self.select_model():
            return
        
        # Status der Websuche ermitteln
        search_status = ""
        if self.tavily:
            search_status = "🔍 [bold green]Tavily[/bold green] (primär) + [green]DuckDuckGo[/green] (Fallback)"
        elif self.ddgs:
            search_status = "🔍 [yellow]DuckDuckGo[/yellow] (Tavily nicht konfiguriert)"
        else:
            search_status = "🔍 [red]Keine Websuche verfügbar[/red]"

        console.print(Panel(
            f"[green]Modell ausgewählt:[/green] [bold]{self.current_model}[/bold]\n\n"
            f"[green]Websuche:[/green] {search_status}\n\n"
            f"Geben Sie [cyan]/help[/cyan] ein für Hilfe.\n"
            f"Geben Sie Ihre Frage ein und drücken Sie Enter.\n\n"
            f"[bold yellow]Tipp:[/bold yellow] Verwende [cyan]/w <frage>[/cyan] für Websuche",
            title="✅ Bereit",
            border_style="green",
            expand=True
        ))

        while True:
            try:
                console.print()
                # Zeige reasoning_effort wenn GPT OSS 120B aktiv ist
                prompt_text = f"[bold blue]👤 Du[/bold blue] [dim cyan]({self.current_model}"
                if "OSS 120B" in self.current_model or "oss 120b" in self.current_model.lower():
                    # Entferne das ":" und füge die schließende Klammer hinzu
                    reasoning_part = f" | reasoning {self.reasoning_effort})"
                    prompt_text += reasoning_part
                else:
                    prompt_text += ")"  # Kein reasoning_effort für andere Modelle
                prompt_text += "[/dim cyan]"

                user_input = Prompt.ask(
                    prompt_text, 
                    default="", 
                    console=console,
                    show_default=False  # Verhindert automatischen Doppelpunkt
                )

                if not user_input.strip():
                    continue

                # Mehrzeilen-Modus: """ am Anfang
                if user_input.strip().startswith('"""'):
                    lines = [user_input.strip()[3:]]  # Entferne ersten """
                    console.print('[dim]Mehrzeilen-Modus (beende mit """ auf neuer Zeile)[/dim]')

                    while True:
                        next_line = Prompt.ask("[dim]...[/dim] ", default="", console=console)
                        if next_line.strip() == '"""':
                            break
                        lines.append(next_line)

                    user_input = '\n'.join(lines)
                    if not user_input.strip():
                        continue

                # Befehle verarbeiten
                if user_input.startswith("/"):
                    cmd_parts = user_input[1:].split(maxsplit=1)
                    cmd = cmd_parts[0].lower()
                    arg = cmd_parts[1] if len(cmd_parts) > 1 else ""

                    if cmd == "paste":
                        # Paste-Modus: Mehrzeilige Eingabe ohne """ Marker
                        console.print()
                        console.print(Panel(
                            "[cyan]📋 Paste-Modus aktiviert[/cyan]\n\n"
                            "Füge deinen Text ein (mehrere Zeilen möglich).\n"
                            "Beende die Eingabe mit einer Zeile die nur [bold]END[/bold] enthält.\n\n"
                            "[dim]Tipp: Du kannst auch Strg+V verwenden zum Einfügen.[/dim]",
                            border_style="cyan",
                            expand=True
                        ))
                        console.print()

                        lines = []
                        while True:
                            try:
                                line = Prompt.ask("[dim cyan]│[/dim cyan] ", default="", console=console)
                                if line.strip().upper() == "END":
                                    break
                                lines.append(line)
                            except EOFError:
                                break

                        if lines:
                            user_input = '\n'.join(lines)
                            console.print()
                            console.print(f"[green]✓ {len(lines)} Zeilen erfasst ({len(user_input)} Zeichen)[/green]")
                            console.print()

                            # Verarbeite die Eingabe als normale Chat-Anfrage
                            full_response = ""
                            with Live(Panel(Spinner("dots", text="Denke nach..."), border_style="green", expand=True),
                                      refresh_per_second=10, transient=True):
                                for chunk in self.chat_completion(user_input, use_search=False):
                                    full_response += chunk

                            if full_response:
                                self.display_response(full_response)
                        else:
                            console.print("[yellow]Keine Eingabe erfasst.[/yellow]")
                        continue
                    elif cmd in ["exit", "quit", "q"]:
                        self._save_history()
                        console.print("[yellow]Auf Wiedersehen! 👋[/yellow]")
                        break
                    elif cmd == "help":
                        self.show_help()
                        continue
                    elif cmd == "model":
                        self.select_model()
                        continue
                    elif cmd == "reasoning":
                        if arg and arg.lower() in ["low", "medium", "high"]:
                            self.reasoning_effort = arg.lower()
                            console.print(f"[green]Reasoning Effort auf '{self.reasoning_effort}' gesetzt.[/green]")
                        else:
                            console.print(f"[yellow]Aktueller Reasoning Effort:[/yellow] [bold]{self.reasoning_effort}[/bold]")
                            console.print("[dim]Optionen: low, medium, high[/dim]")
                            console.print("[dim]Verwendung: /reasoning <level>[/dim]")
                        continue
                    elif cmd == "clear":
                        self.conversation = []
                        console.print("[green]Chatverlauf gelöscht.[/green]")
                        continue
                    elif cmd == "history":
                        self.show_history()
                        continue
                    elif cmd == "w" and arg:
                        # Einfacher Websuche-Befehl: /w <frage>
                        console.print()
                        full_response = ""
                        with Live(Panel(Spinner("dots", text="Suche und denke nach..."), border_style="green", expand=True),
                                  refresh_per_second=10, transient=True):
                            for chunk in self.chat_completion(arg, use_search=True):
                                full_response += chunk

                        # Zeige welche Suchmethode verwendet wurde mit Details
                        if hasattr(self, 'last_search_info') and self.last_search_info:
                            info = self.last_search_info
                            console.print(
                                f"[dim]🔍 Websuche via: [bold]{info['method']}[/bold] | "
                                f"📊 Quellen: {info['sources']} | Suchtiefe: {info['depth']}[/dim]\n"
                            )

                        if full_response:
                            self.display_response(full_response)
                        continue
                    else:
                        console.print(f"[yellow]Unbekannter Befehl: {cmd}. Geben Sie /help ein für Hilfe.[/yellow]")
                        continue
                
                # Chat-Anfrage (automatische Websuche bei relevanten Schlüsselwörtern)
                console.print()
                full_response = ""

                with Live(Panel(Spinner("dots", text="Denke nach..."), border_style="green", expand=True),
                          refresh_per_second=10, transient=True):
                    for chunk in self.chat_completion(user_input, use_search=False):
                        full_response += chunk

                # Zeige welche Suchmethode verwendet wurde (falls Websuche getriggert wurde)
                if hasattr(self, 'last_search_info') and self.last_search_info:
                    info = self.last_search_info
                    console.print(
                        f"[dim]🔍 Websuche via: [bold]{info['method']}[/bold] | "
                        f"📊 Quellen: {info['sources']} | Suchtiefe: {info['depth']}[/dim]\n"
                    )

                if full_response:
                    self.display_response(full_response)
                
            except KeyboardInterrupt:
                # Ctrl+C beendet das Programm sofort (wie /exit)
                self._save_history()
                console.print("\n[yellow]Unterbrochen. Auf Wiedersehen! 👋[/yellow]")
                break
            except EOFError:
                # Ctrl+D wird ignoriert - nichts passiert
                console.print()
                continue


def main():
    """Einstiegspunkt."""
    chat = JGUKIChat()
    chat.run()


if __name__ == "__main__":
    main()
