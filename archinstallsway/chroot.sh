#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# chroot.sh — Schritt 6–12
# Läuft innerhalb von arch-chroot /mnt (aufgerufen von pre-install.sh)
# =============================================================================

info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
die()     { echo "[FEHLER] $*" >&2; exit 1; }

DISK=$(cat /disk.txt)
if [[ "$DISK" == nvme* ]]; then
    LUKS_PART="/dev/${DISK}p2"
else
    LUKS_PART="/dev/${DISK}2"
fi

# --- Zeitzone ---
info "Zeitzone und Hardware-Uhr setzen..."
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc
success "Zeitzone: Europe/Berlin"

# --- Lokalisierung ---
info "Lokalisierung einrichten..."
pacman -Syu --noconfirm vim
sed -i 's/^#de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=de_DE.UTF-8" > /etc/locale.conf
echo "KEYMAP=de" > /etc/vconsole.conf
success "Lokalisierung abgeschlossen."

# --- Hostname & Benutzer ---
read -rp "Computername (Hostname): " HOSTNAME
echo "$HOSTNAME" > /etc/hostname

info "Root-Passwort setzen:"
passwd

read -rp "Benutzername (z.B. patrick): " USERNAME
useradd -m -g users -G wheel "$USERNAME"
info "Passwort für $USERNAME setzen:"
passwd "$USERNAME"

mkdir -m 755 /etc/sudoers.d
echo "$USERNAME ALL=(ALL) ALL" > "/etc/sudoers.d/$USERNAME"
chmod 0440 "/etc/sudoers.d/$USERNAME"
success "Benutzer '$USERNAME' angelegt."

# Benutzername für post-install.sh speichern
echo "$USERNAME" > /username.txt

# --- Essentielle Pakete ---
info "Essentielle Pakete installieren..."
pacman -S --noconfirm base-devel linux linux-headers linux-firmware btrfs-progs \
    grub efibootmgr mtools networkmanager network-manager-applet \
    openssh git acpid grub-btrfs ufw
success "Essentielle Pakete installiert."

# --- Zusätzliche Pakete ---
info "Zusätzliche Pakete installieren..."

echo ""
echo "Intel-GPU Treiber:"
echo "  1) libva-intel-driver  (8.–11. Gen)"
echo "  2) intel-media-driver  (ab 12. Gen)"
echo "  3) keinen (kein Intel oder später)"
read -rp "Auswahl [1/2/3]: " GPU_CHOICE
case "$GPU_CHOICE" in
    1) GPU_PKG="libva-intel-driver" ;;
    2) GPU_PKG="intel-media-driver" ;;
    *) GPU_PKG="" ;;
esac

pacman -S --noconfirm man-db man-pages-de man-pages texinfo \
    bluez bluez-utils \
    pipewire pipewire-pulse pipewire-jack wireplumber alsa-utils sof-firmware \
    ttf-firacode-nerd ttf-hack \
    intel-ucode \
    firefox firefox-i18n-de \
    ${GPU_PKG:+$GPU_PKG}
success "Zusätzliche Pakete installiert."

# --- mkinitcpio ---
info "mkinitcpio.conf anpassen..."
sed -i 's/^MODULES=.*/MODULES=(btrfs atkbd)/' /etc/mkinitcpio.conf
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -p linux
success "Initramfs erstellt."

# --- GRUB ---
info "GRUB installieren..."
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

info "GRUB Kernel-Parameter mit LUKS-UUID konfigurieren..."
LUKS_UUID=$(blkid -s UUID -o value "$LUKS_PART")
sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet cryptdevice=UUID=${LUKS_UUID}:main root=/dev/mapper/main\"|" \
    /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
success "GRUB konfiguriert (UUID: $LUKS_UUID)."

# --- Services aktivieren ---
info "Services aktivieren..."
systemctl enable NetworkManager bluetooth sshd acpid
success "Services aktiviert."

echo ""
echo "========================================"
echo " chroot.sh abgeschlossen!"
echo " Zurück im pre-install.sh..."
echo "========================================"
