function up-mirr
    # Erstellt ein Backup der aktuellen Mirrorlist mit Zeitstempel
    sudo cp /etc/pacman.d/mirrorlist{,.bak.(date +%F-%H%M)}

    # Sucht die schnellsten deutschen Spiegelserver und schreibt sie in die Mirrorlist
    rate-mirrors --entry-country=Germany \
        --country-neighbors-per-country=0 \
        --protocol https \
        --country-test-mirrors-per-country 10 \
        --top-mirrors-number-to-retest 20 \
        --max-mirrors-to-output 20 \
        --min-bytes-per-mirror 300000 \
        arch | sudo tee /etc/pacman.d/mirrorlist
    
    # Erzwingt das Neuladen der Paketdatenbanken und führt ein Systemupdate durch
    sudo pacman -Syyu
end
