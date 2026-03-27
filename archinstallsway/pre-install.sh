#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# pre-install.sh — Schritt 1–6
# Läuft auf dem Arch Linux Live-ISO (als root)
# =============================================================================

info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
die()     { echo "[FEHLER] $*" >&2; exit 1; }
pause()   { read -rp "[WEITER] $* — Enter drücken..."; }

# --- Tastatur & Schrift ---
info "Tastatur und Schrift setzen..."
loadkeys de-latin1
setfont ter-132b

# --- WLAN ---
info "WLAN-Verbindung aufbauen..."
read -rp "WLAN-SSID: " SSID
read -rsp "WLAN-Passwort: " WLAN_PASS
echo
iwctl station wlan0 connect "$SSID" --passphrase "$WLAN_PASS"
sleep 4
ping -c 3 archlinux.org || die "Keine Internetverbindung. Routing prüfen und Script neu starten."
success "Netzwerk OK."

# --- Zeit ---
timedatectl set-timezone Europe/Berlin
timedatectl set-ntp true

# --- Festplatte wählen ---
echo ""
lsblk
echo ""
read -rp "Festplatte für Installation (z.B. nvme0n1 oder sda): " DISK
DISK_PATH="/dev/${DISK}"

# Partition-Präfix je nach Disk-Typ (NVMe vs. SATA)
if [[ "$DISK" == nvme* ]]; then
    PART_PREFIX="${DISK_PATH}p"
else
    PART_PREFIX="${DISK_PATH}"
fi
BOOT_PART="${PART_PREFIX}1"
LUKS_PART="${PART_PREFIX}2"

echo ""
echo "Folgende Festplatte wird KOMPLETT GELÖSCHT: $DISK_PATH"
echo "  Boot-Partition: $BOOT_PART (1 GB, EFI)"
echo "  System-Partition: $LUKS_PART (Rest, LUKS)"
read -rp "Fortfahren? (ja/nein): " CONFIRM
[[ "$CONFIRM" == "ja" ]] || die "Abgebrochen."

# --- Partitionierung ---
info "Partitionstabelle erstellen (sgdisk)..."
sgdisk -Z "$DISK_PATH"
sgdisk -n 1:0:+1G -t 1:ef00 "$DISK_PATH"
sgdisk -n 2:0:0 "$DISK_PATH"
lsblk
success "Partitionierung abgeschlossen."

# --- LUKS ---
info "LUKS-Verschlüsselung einrichten (Passwort wird abgefragt)..."
cryptsetup luksFormat "$LUKS_PART"
cryptsetup luksOpen "$LUKS_PART" main
success "LUKS geöffnet als /dev/mapper/main."

# --- BTRFS ---
info "BTRFS formatieren und Subvolumes anlegen..."
mkfs.btrfs /dev/mapper/main
mount /dev/mapper/main /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@ \
    /dev/mapper/main /mnt
mkdir /mnt/home
mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@home \
    /dev/mapper/main /mnt/home

mkfs.fat -F32 "$BOOT_PART"
mkdir /mnt/boot
mount "$BOOT_PART" /mnt/boot
success "Dateisystem gemountet."

# --- Grundsystem installieren ---
info "Grundsystem mit pacstrap installieren..."
pacstrap /mnt base
genfstab -U -p /mnt >> /mnt/etc/fstab
success "pacstrap abgeschlossen."

# --- chroot.sh übergeben ---
info "chroot.sh ins neue System kopieren..."
cp "$(dirname "$0")/chroot.sh" /mnt/chroot.sh
chmod +x /mnt/chroot.sh
echo "$DISK" > /mnt/disk.txt

# --- In chroot wechseln und chroot.sh starten ---
info "Wechsle in arch-chroot und führe chroot.sh aus..."
arch-chroot /mnt bash /chroot.sh

# --- Aufräumen ---
rm -f /mnt/chroot.sh /mnt/disk.txt

echo ""
echo "========================================"
echo " Schritt 1–12 abgeschlossen!"
echo " USB-Stick entfernen und System ausschalten:"
echo "   shutdown now"
echo "========================================"
