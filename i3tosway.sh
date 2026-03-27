#!/usr/bin/env bash
set -euo pipefail

# i3 → Sway Migrations-Script
# Voraussetzung: i3 ist bereits installiert und läuft.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$(whoami)}"

info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
warn()    { echo "[WARN]  $*"; }
die()     { echo "[FEHLER] $*" >&2; exit 1; }

# --- Schritt 1: Sway und Wayland-Pakete installieren ---
info "Schritt 1: Pacman-Pakete installieren..."
sudo pacman -S --needed \
    sway swaybg swaylock swayidle \
    xorg-xwayland \
    waybar \
    kanshi \
    grim slurp wl-clipboard \
    wob \
    gammastep \
    ly
success "Pacman-Pakete installiert."

# AUR-Pakete
info "AUR-Pakete installieren (yay)..."
if ! command -v yay &>/dev/null; then
    die "yay ist nicht installiert. Bitte zuerst yay installieren."
fi
yay -S --needed rofi-wayland ydotool
success "AUR-Pakete installiert."

# --- Schritt 3: ly aktivieren ---
info "Schritt 3: ly aktivieren und starten..."
if systemctl is-enabled ly@tty2.service &>/dev/null; then
    warn "ly@tty2.service ist bereits aktiviert — überspringe enable."
else
    sudo systemctl enable ly@tty2.service
    success "ly@tty2.service aktiviert."
fi

if systemctl is-active ly@tty2.service &>/dev/null; then
    warn "ly@tty2.service läuft bereits — überspringe start."
else
    sudo systemctl start ly@tty2.service
    success "ly@tty2.service gestartet."
fi

# --- Schritt 4: Benutzer zur input-Gruppe hinzufügen ---
info "Schritt 4: Benutzer '$USER_NAME' zur input-Gruppe hinzufügen..."
if id -nG "$USER_NAME" | grep -qw input; then
    warn "Benutzer '$USER_NAME' ist bereits in der input-Gruppe."
else
    sudo usermod -aG input "$USER_NAME"
    success "Benutzer '$USER_NAME' zur input-Gruppe hinzugefügt."
    warn "Bitte ausloggen und neu einloggen, damit die Gruppenänderung wirksam wird."
fi

# --- Schritt 5: Vorhandene Configs entfernen und stow ---
info "Schritt 5: Vorhandene Konfigurationsdateien entfernen..."
rm -f "$HOME/.config/alacritty/alacritty.toml"
rm -rf "$HOME/.config/sway" "$HOME/.config/waybar" "$HOME/.config/kanshi"
success "Alte Konfigurationen entfernt."

info "Dotfiles verlinken (stow)..."
cd "$DOTFILES_DIR"
stow alacritty sway waybar kanshi
success "Dotfiles verlinkt."

# Symlinks prüfen
info "Symlinks prüfen..."
ERRORS=0
for link in \
    "$HOME/.config/alacritty/alacritty.toml" \
    "$HOME/.config/sway/config"; do
    if [ -L "$link" ]; then
        success "$link -> $(readlink "$link")"
    else
        warn "Kein Symlink: $link"
        ERRORS=$((ERRORS + 1))
    fi
done

if [ "$ERRORS" -gt 0 ]; then
    die "Einige Symlinks wurden nicht korrekt gesetzt."
fi

echo ""
echo "========================================"
echo " Migration abgeschlossen!"
echo " Sway in ly auswählen und starten."
echo "========================================"
