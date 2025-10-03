function sl --description "Bildschirm aus; nach X Minuten herunterfahren"
    set -l mins $argv[1]

    if test -z "$mins"
        echo "Nutzung: sl <Minuten>"
        return 1
    end

    if not string match -rq '^[0-9]+$' -- $mins
        echo "Fehler: <Minuten> muss eine ganze Zahl sein."
        return 1
    end

    set -l secs (math "$mins * 60")
    echo "Fahre in $mins Minute(n) herunter… (Ctrl+C zum Abbrechen)"

    sleep 4

    # Bildschirm ausschalten
    if type -q kscreen-doctor
        kscreen-doctor --dpms off
    else if type -q xset
        xset dpms force off
    end

    sleep $secs
    systemctl poweroff
end
