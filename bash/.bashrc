#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'

# PS1 farbig gestalten und zweizeilig mit aktuellem Ordner
# PS1='[\u@\h \W]\$ '     # das ist der alte Prompt
# Farbdefinitionen für PS1 Prompt
YELLOW="\[\033[1;33m\]"
BLUE="\[\033[1;34m\]"
WHITE="\[\033[1;37m\]"
RESET="\[\033[0m\]"
# Prompt-Aufbau
export PS1="${BLUE}[\u@\h$] ${YELLOW}\w${RESET} > "

export LYNX_CFG="$HOME/.config/lynx/lynx.cfg"
export LYNX_LSS="$HOME/.config/lynx/lynx.lss"


# von Gemini vorgeschlagene aliase

# -----------------------------------------------------------------------------
# Bash-Funktionen (Übersetzung von Fish-Funktionen)
# -----------------------------------------------------------------------------

# Verbindet sich per SSH mit der angegebenen IP-Adresse.
nas() {
  ssh 192.168.178.186 "$@"
}

# Startet das System sofort neu.
reb() {
  sudo reboot now "$@"
}

# Fährt das System sofort herunter.
sd() {
  sudo shutdown now "$@"
}

# Führt ein vollständiges Systemupdate mit pacman durch.
up() {
  sudo pacman -Syu "$@"
}

# Startet den Vim-Editor.
v() {
  vim "$@"
}

# Führt eine DuckDuckGo-Suche im Text-Browser lynx aus.
lynx_search() {
    # Prüfen, ob Suchbegriffe übergeben wurden.
    if [ $# -eq 0 ]; then
        echo "Benutzung: ? <Suchbegriff>"
        return 1
    fi

    local query_string="$*"
    local encoded_string=""
    local char

    # Manuelle URL-Kodierung der Suchanfrage.
    for (( i=0; i<${#query_string}; i++ )); do
        char=${query_string:$i:1}
        case "$char" in
            [a-zA-Z0-9.~_-]) encoded_string+="$char" ;;
            ' ') encoded_string+='+' ;;
            *) encoded_string+=$(printf '%%%02X' "'$char") ;;
        esac
    done

    # Aufruf von lynx mit der kodierten URL.
    lynx "https://duckduckgo.com/lite/?q=$encoded_string"
}



# Öffnet die i3-Konfigurationsdatei in Vim
i3config() {
    vim ~/dotfiles/i3/.config/i3/config "$@"
}

alias dot='cd "$HOME/dotfiles"'
alias dl='cd "$HOME/Downloads"'
alias dev='cd "$HOME/dev"'
alias ls='ls -la'
alias v='vim'
alias \?='lynx_search'

# ~/.bashrc
sus() {
  systemctl suspend "$@"
}

up-mirr() {
  sudo cp /etc/pacman.d/mirrorlist{,.bak.$(date +%F-%H%M)}
  rate-mirrors --entry-country=Germany \
    --country-neighbors-per-country=0 \
    --protocol https \
    --country-test-mirrors-per-country 10 \
    --top-mirrors-number-to-retest 20 \
    --max-mirrors-to-output 20 \
    --min-bytes-per-mirror 300000 \
    arch | sudo tee /etc/pacman.d/mirrorlist 
    sudo pacman -Syyu
}

jf() {
    # Überprüfe, ob genau ein Argument (Dateiname) übergeben wurde
    if [ "$#" -ne 1 ]; then
        echo "Verwendung: jf <Dateiname>"
        return 1
    fi

    local filename="$1"
    local destination="root@192.168.178.90:/mnt/gemeinsam"

    echo "Kopiere Datei: '$filename'"
    echo "Zum Ziel: '$destination'"

    # Führe den scp-Befehl aus: scp <Dateiname> <Ziel>
    scp "$filename" "$destination"
    local status=$?  # Speichere den Exit-Status von scp

    # Überprüfe den Exit-Status des scp-Befehls
    if [ "$status" -eq 0 ]; then
        echo "✅ Datei erfolgreich kopiert."
    else
        echo "❌ FEHLER: Kopieren fehlgeschlagen. (scp Exit-Code: $status)"
    fi
}

nh() {
  QT_SCALE_FACTOR=1.7 nohup "/home/patrick/.local/share/Newshosting/3.8.9/Newshosting-x86_64.AppImage" \
    >/dev/null 2>&1 </dev/null &
  disown
}

new () {
    # 1. Variable definieren und Tilde (~) auf den Home-Pfad erweitern
    local target_dir="$HOME/Downloads/Newshosting"

    # 2. Prüfen, ob das Verzeichnis existiert
    if [ -d "$target_dir" ]; then
        # 3. Zum Verzeichnis wechseln
        cd "$target_dir" || return 1 # '|| return 1' stellt sicher, dass die Funktion bei Fehler abbricht
        echo "Gewechselt zu: $target_dir"

        # 4. Die 10 neuesten Einträge anzeigen (sortiert nach Zeit, neueste zuerst)
        # ls -lth: l=lang, t=Zeit, h=human readable (menschenlesbar)
        # head -n 11: 1 Zeile Header + 10 Einträge
        command ls -lth --color=always | head -n 11
    else
        # 5. Fehlermeldung ausgeben und Funktion beenden
        echo "Fehler: Das Verzeichnis '$target_dir' existiert nicht." >&2
        return 1
    fi
}

