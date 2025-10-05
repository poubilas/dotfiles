function jf
    # Überprüfe, ob genau ein Argument (Dateiname) übergeben wurde
    if test (count $argv) -ne 1
        echo "Verwendung: jf <Dateiname>"
        return 1
    end
    
    set filename $argv[1]
    
    set destination "root@192.168.178.75:/mnt/gemeinsam"
    
    echo "Kopiere Datei: '$filename'"
    echo "Zum Ziel: '$destination'"
    
    # Führe den scp-Befehl aus: scp <Dateiname> <Ziel>
    scp "$filename" "$destination"
    
    # Überprüfe den Exit-Status des scp-Befehls
    if test $status -eq 0
        echo "✅ Datei erfolgreich kopiert."
    else
        echo "❌ FEHLER: Kopieren fehlgeschlagen. (scp Exit-Code: $status)"
    end
end
