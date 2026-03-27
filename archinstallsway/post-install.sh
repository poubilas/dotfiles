#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# post-install.sh — Schritt 13–27
# Läuft nach dem ersten Neustart als normaler Benutzer (z.B. patrick)
# =============================================================================

info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
warn()    { echo "[WARN]  $*"; }
die()     { echo "[FEHLER] $*" >&2; exit 1; }
pause()   { read -rp "[MANUELL] $* — Enter wenn fertig..."; }

[[ "$EUID" -eq 0 ]] && die "Nicht als root ausführen! Als normaler Benutzer starten."

# --- WLAN verbinden ---
info "WLAN verbinden..."
nmcli device wifi list
read -rp "WLAN-SSID: " SSID
nmcli device wifi connect "$SSID" --ask
success "WLAN verbunden."

# --- Schrift & Terminus-Font ---
info "Terminus-Font installieren..."
sudo pacman -S --noconfirm terminus-font
setfont ter-132b
success "Schrift gesetzt."

# --- yay installieren ---
info "yay (AUR-Helper) installieren..."
if command -v yay &>/dev/null; then
    warn "yay ist bereits installiert — überspringe."
else
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~
    rm -rf /tmp/yay
    success "yay installiert."
fi

# --- pacman optimieren ---
info "pacman: ParallelDownloads aktivieren..."
sudo sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
grep -q "^ParallelDownloads" /etc/pacman.conf || \
    sudo sed -i '/^\[options\]/a ParallelDownloads = 10' /etc/pacman.conf
success "ParallelDownloads aktiviert."

# --- Mirror-Liste optimieren ---
info "Schnellste Mirror ermitteln (rate-mirrors)..."
yay -S --needed --noconfirm rate-mirrors-bin
rate-mirrors --entry-country=Germany \
    --country-neighbors-per-country=0 \
    --protocol https \
    --country-test-mirrors-per-country 10 \
    --top-mirrors-number-to-retest 20 \
    --max-mirrors-to-output 20 \
    --min-bytes-per-mirror 300000 \
    arch | sudo tee /etc/pacman.d/mirrorlist
success "Mirrorlist aktualisiert."

# --- Timeshift ---
info "Timeshift installieren..."
yay -S --needed --noconfirm timeshift timeshift-autosnap
sudo timeshift --create --comment "Neuinstallation $(date +%Y-%m-%d)" --tags D
success "Erster Snapshot erstellt."

# --- grub-btrfsd konfigurieren (manueller Schritt) ---
info "grub-btrfsd konfigurieren..."
warn "Manueller Schritt: Im Editor die ExecStart-Zeile anpassen."
warn "  Ende muss lauten: --syslog -t"
warn "  (/.snapshots entfernen, -t einfügen)"
pause "Beliebige Taste zum Öffnen des Editors"
sudo systemctl edit --full grub-btrfsd
sudo grub-mkconfig -o /boot/grub/grub.cfg
success "grub-btrfsd konfiguriert."

# --- Zram ---
info "Zram einrichten..."
sudo pacman -S --needed --noconfirm zram-generator
sudo mkdir -p /etc/systemd/zram-generator.conf.d/
sudo tee /etc/systemd/zram-generator.conf.d/zram.conf > /dev/null <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF
sudo systemctl daemon-reexec
sudo systemctl start /dev/zram0
success "Zram konfiguriert."

# --- ly Display-Manager ---
info "ly Display-Manager installieren und aktivieren..."
sudo pacman -S --needed --noconfirm ly
sudo systemctl enable ly@tty2.service
sudo systemctl start ly@tty2.service || true
success "ly aktiviert."

# --- Dotfiles klonen ---
info "Dotfiles klonen..."
if [[ -d "$HOME/dotfiles" ]]; then
    warn "~/dotfiles existiert bereits — überspringe git clone."
else
    git clone https://github.com/poubilas/dotfiles.git "$HOME/dotfiles"
fi
success "Dotfiles vorhanden."

# --- Sway und Wayland-Pakete installieren ---
info "Sway und alle Wayland-Pakete installieren (pacman)..."
sudo pacman -S --needed --noconfirm \
    sway swaybg swaylock swayidle xorg-xwayland \
    waybar \
    kanshi \
    grim slurp wl-clipboard \
    wob \
    gammastep \
    rofi \
    alacritty \
    dunst libnotify \
    vim ranger \
    pavucontrol \
    bluez bluez-utils \
    obsidian qutebrowser \
    aerc \
    zathura zathura-pdf-poppler \
    lynx tmux btop powertop tlp \
    foliate w3m \
    stow jq \
    gnome-calculator \
    dex polkit-gnome \
    brightnessctl \
    wireplumber \
    firefox firefox-i18n-de
success "Pacman-Pakete installiert."

info "AUR-Pakete installieren (yay)..."
yay -S --needed --noconfirm rofi-wayland ydotool
success "AUR-Pakete installiert."

# --- Benutzer zur input-Gruppe hinzufügen ---
info "Benutzer zur input-Gruppe hinzufügen..."
USERNAME=$(whoami)
if id -nG "$USERNAME" | grep -qw input; then
    warn "Bereits in der input-Gruppe."
else
    sudo usermod -aG input "$USERNAME"
    success "Zur input-Gruppe hinzugefügt (nach Re-Login aktiv)."
fi

# --- Dotfiles verlinken ---
info "Alte Konfigurationen entfernen und stow ausführen..."
rm -f "$HOME/.bashrc"
rm -f "$HOME/.config/alacritty/alacritty.toml"
rm -rf "$HOME/.config/sway" "$HOME/.config/waybar" "$HOME/.config/kanshi"

cd "$HOME/dotfiles"
stow sway waybar kanshi alacritty bash fish vim qutebrowser aerc rofi lynx
source "$HOME/.bashrc" || true
success "Dotfiles verlinkt."

# --- Firewall ---
info "Firewall (ufw) einrichten..."
sudo pacman -S --needed --noconfirm ufw
sudo ufw enable
sudo systemctl enable --now ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
success "Firewall aktiv."

# --- Abschluss-Snapshot ---
info "Abschluss-Snapshot erstellen..."
sudo timeshift --create --comment "Mit Sway-Einstellungen $(date +%Y-%m-%d)" --tags D
success "Snapshot erstellt."

# --- aerc-Hinweis ---
echo ""
warn "Manueller Schritt: aerc E-Mail-Konto einrichten"
warn "  cp /path/to/accounts.conf ~/dotfiles/aerc/.config/aerc/accounts.conf"
warn "  sudo chmod 600 ~/dotfiles/aerc/.config/aerc/accounts.conf"

echo ""
echo "========================================"
echo " Installation abgeschlossen!"
echo " System neu starten und in ly 'sway'"
echo " auswählen."
echo "   sudo reboot"
echo "========================================"
