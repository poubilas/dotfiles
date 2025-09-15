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
?() {
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
alias ls='ls -la'

# ~/.bashrc
sus() {
  systemctl suspend "$@"
}

