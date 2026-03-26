# Arch Linux + Sway Installation

Stand: 2026-03
Grundlage: https://www.youtube.com/watch?v=fFxWuYui2LI

---

## 1. Boot auf neuem Computer

```bash
loadkeys de-latin1
setfont ter-132b
```

### WLAN verbinden

```bash
iwctl
device list                                        # normalerweise wlan0
station wlan0 get-networks
station wlan0 connect 'FRITZ!Box 6660 Cable QK'   # auf beide ' achten!
exit

ping www.google.com -c 5
```

### Routing prüfen / korrigieren

```bash
ip route
ip route del 192.168.178.186 dev wlan0             # überflüssige Route entfernen
ip route add default via 192.168.178.1 dev wlan0   # richtiges Gateway
```

### SSH aktivieren (für Remote-Installation)

```bash
ip -br a
passwd
systemctl status sshd    # sollte aktiv sein
```

---

## 2. Zugriff via SSH auf newinstall

```bash
ssh root@192.168.178.xx
```

```bash
timedatectl set-timezone Europe/Berlin
timedatectl set-ntp true
```

---

## 3. Partitionierung

```bash
lsblk    # Festplatte ermitteln, meist nvme0n1
gdisk /dev/nvme0n1
```

```
o                            # neue Partitionstabelle
n - ok - ok - +1G - ef00    # Boot-Partition 1 GB, Typ EFI
n - ok - ok - ok - ok       # Rest als zweite Partition
w
```

```bash
lsblk    # Überprüfung
```

---

## 4. Festplattenverschlüsselung (LUKS)

```bash
cryptsetup luksFormat /dev/nvme0n1p2
cryptsetup luksOpen /dev/nvme0n1p2 main
```

---

## 5. BTRFS formatieren und mounten

```bash
mkfs.btrfs /dev/mapper/main
mount /dev/mapper/main /mnt
cd /mnt

btrfs subvolume create @
btrfs subvolume create @home
ls

cd -
umount /mnt

mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@ \
    /dev/mapper/main /mnt

mkdir /mnt/home
mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@home \
    /dev/mapper/main /mnt/home

mkfs.fat -F32 /dev/nvme0n1p1
mkdir /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot
```

---

## 6. Grundsystem installieren

```bash
pacstrap /mnt base
genfstab -U -p /mnt >> /mnt/etc/fstab
arch-chroot /mnt
```

```bash
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc
```

---

## 7. Lokalisierung

```bash
pacman -Syu vim

vim /etc/locale.gen
# de_DE.UTF-8 UTF-8   → auskommentieren

locale-gen
echo "LANG=de_DE.UTF-8" >> /etc/locale.conf
echo "KEYMAP=de" >> /etc/vconsole.conf
```

---

## 8. Netzwerk & Benutzer

```bash
echo "DellXXXX" >> /etc/hostname    # Computername anpassen

passwd    # Root-Passwort

useradd -m -g users -G wheel patrick
passwd patrick

mkdir -m 755 /etc/sudoers.d
echo "patrick ALL=(ALL) ALL" > /etc/sudoers.d/patrick
chmod 0440 /etc/sudoers.d/patrick

pacman -S sudo rsync
```

---

## 9. Essentielle Pakete

```bash
pacman -Syu base-devel linux linux-headers linux-firmware btrfs-progs \
    grub efibootmgr mtools networkmanager network-manager-applet \
    openssh git acpid grub-btrfs ufw
```

---

## 10. Zusätzliche Pakete

```bash
pacman -S man-db man-pages-de man-pages texinfo \
    bluez bluez-utils \
    pipewire pipewire-pulse pipewire-jack wireplumber alsa-utils sof-firmware \
    ttf-firacode-nerd ttf-hack \
    intel-ucode \
    firefox firefox-i18n-de
```

> Intel-GPU: `libva-intel-driver` (8.–11. Gen) oder `intel-media-driver` (ab 12. Gen)

---

## 11. Boot-Loader

### Initramfs

```bash
vim /etc/mkinitcpio.conf
```

```
MODULES=(btrfs atkbd)
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)
```

```bash
mkinitcpio -p linux
```

### GRUB installieren

```bash
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

lsblk -f >> /etc/default/grub    # UUID von nvme0n1p2 (crypto_LUKS) kopieren
vim /etc/default/grub
```

```
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet cryptdevice=UUID=XXXX:main root=/dev/mapper/main"
```

```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

---

## 12. Services aktivieren & Neustart

```bash
systemctl enable NetworkManager bluetooth sshd acpid
exit
shutdown now    # USB-Stick entfernen!
```

---

## 13. Nach Neustart: WLAN & Schrift

```bash
nmcli device wifi list
nmcli device wifi connect 'FRITZ!Box 6660 Cable QK' --ask

sudo pacman -S terminus-font
setfont ter-132b
```

---

## 14. yay installieren

```bash
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd ..
```

---

## 15. Timeshift (Snapshots)

```bash
yay -S timeshift timeshift-autosnap

sudo timeshift --list-devices
sudo timeshift --create --comment "Neuinstallation $(date +%Y-%m-%d)" --tags D
```

### GRUB für Timeshift-Snapshots konfigurieren

```bash
sudo su
echo "export EDITOR=vim" > ~/.bashrc
source ~/.bashrc
systemctl edit --full grub-btrfsd
# ExecStart: Ende muss sein: --syslog -t   (/.snapshots entfernen, -t einfügen)

grub-mkconfig -o /boot/grub/grub.cfg
```

---

## 16. Zram

```bash
sudo pacman -S zram-generator
sudo mkdir -p /etc/systemd/zram-generator.conf.d/
sudo vim /etc/systemd/zram-generator.conf.d/zram.conf
```

```ini
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
```

```bash
sudo systemctl daemon-reexec
sudo systemctl start /dev/zram0
reboot
lsblk
```

---

## 17. Display-Manager ly

```bash
sudo pacman -S ly
sudo systemctl enable ly@tty2.service
sudo systemctl start ly@tty2.service
```

Sway erscheint automatisch in ly sobald es installiert ist (`/usr/share/wayland-sessions/sway.desktop`).

---

## 18. Dotfiles klonen

```bash
git clone https://github.com/poubilas/dotfiles.git
cd dotfiles
```

---

## 19. Sway und alle Wayland-Pakete installieren

### pacman

```bash
sudo pacman -S \
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
    wpctl
```

### AUR (yay)

```bash
yay -S rofi-wayland ydotool rate-mirrors-bin
```

> `rofi-wayland` ersetzt `rofi` — yay fragt nach Bestätigung, mit `y` bestätigen.

> `xorg-xwayland` ermöglicht X11-Apps (z.B. Newshosting AppImage) unter Sway. Sway lädt XWayland automatisch beim ersten Start einer X11-App.

---

## 20. Benutzer zur input-Gruppe hinzufügen (ydotool)

```bash
sudo usermod -aG input patrick
```

> **Wichtig:** Danach ausloggen und neu einloggen, damit die Gruppenänderung aktiv wird.

---

## 21. Dotfiles verlinken (stow)

```bash
cd ~/dotfiles
stow sway waybar kanshi alacritty bash fish vim qutebrowser aerc rofi lynx
source ~/.bashrc
```

---

## 22. aerc: E-Mail-Konto einrichten

```bash
cp /path/to/accounts.conf ~/dotfiles/aerc/.config/aerc/accounts.conf
sudo chmod 600 ~/dotfiles/aerc/.config/aerc/accounts.conf
```

> `accounts.conf` ist in `.gitignore` ausgeschlossen — enthält Zugangsdaten im Klartext.

---

## 23. pacman optimieren

```bash
sudo vim /etc/pacman.conf
# ParallelDownloads = 10

sudo vim /etc/pacman.d/mirrorlist
# Als erste Zeile für lokalen Pacoloco-Cache:
# Server = http://192.168.178.93:9129/repo/archlinux/$repo/os/$arch
```

### Mirror-Geschwindigkeit optimieren (nach yay-Installation)

```bash
rate-mirrors --entry-country=Germany \
  --country-neighbors-per-country=0 \
  --protocol https \
  --country-test-mirrors-per-country 10 \
  --top-mirrors-number-to-retest 20 \
  --max-mirrors-to-output 20 \
  --min-bytes-per-mirror 300000 \
  arch | sudo tee /etc/pacman.d/mirrorlist
```

---

## 24. Sway starten

In ly `sway` auswählen. Beim ersten Start öffnen sich automatisch:

| Workspace | App |
|---|---|
| 1 | Alacritty (Terminal) |
| 2 | Firefox |
| 3 | Obsidian |
| 4 | Qutebrowser |
| 5 | Aerc (E-Mail) |

---

## 25. Sway-Konfiguration: Übersicht

Alle Konfigurationsdateien liegen in `~/dotfiles/` und werden per `stow` nach `~/.config/` verlinkt.

### Tastatur & Touchpad (`~/.config/sway/config`)

Deutsches Layout und rechte Menütaste als Super_R sind direkt in der Sway-Config:

```
input type:keyboard {
    xkb_layout de
    xkb_options altwin:menu_win
}

input type:touchpad {
    tap enabled
    tap_button_map lrm
    drag enabled
    dwt enabled
    natural_scroll disabled
    scroll_method two_finger
}
```

> Keine separate `xorg.conf.d`-Datei nötig — Sway verwaltet Eingabegeräte direkt.

### Monitor-Verwaltung (`~/.config/kanshi/config`)

kanshi erkennt automatisch angeschlossene Monitore:

- **Nur internes Display**: `eDP-1` wird aktiviert
- **Laptop + externer Monitor**: `eDP-1` links, externer Monitor rechts
- **Nur externer Monitor**: `eDP-1` deaktiviert

Output-Namen ermitteln: `swaymsg -t get_outputs | jq '.[].name'`

### Screenshots (`~/.config/sway/screenshot.sh`)

| Tastenkombination | Aktion |
|---|---|
| `Fn+Druck` | Ausschnitt → Zwischenablage |
| `Fn+Shift+Druck` | Vollbild → Zwischenablage |
| `Super+Fn+Druck` | Ausschnitt → ~/Downloads |
| `Super+Fn+Shift+Druck` | Vollbild → ~/Downloads |

> **Dell Latitude 7330**: `Fn+Druck` nötig, nicht nur `Druck`.

### Idle / Auto-Suspend (`~/.config/sway/idle.sh`)

```bash
idle 10      # Suspend nach 10 Minuten (Standard beim Start)
idle never   # Suspend deaktivieren
idle status  # Status anzeigen
```

30 Sekunden vor dem Suspend erscheint eine Warnmeldung via dunst. Bei Aktivität wird die Meldung automatisch geschlossen.

### Lautstärke-OSD (wob)

Beim Drücken der Lautstärketasten (`XF86AudioRaiseVolume` / `XF86AudioLowerVolume`) erscheint ein Balken-OSD. Technisch: Werte werden in `/tmp/wobpipe` geschrieben, `wob` liest daraus.

### Farbtemperatur (`gammastep`)

Wird automatisch beim Start ausgeführt mit Standort Mainz (49.98°N, 8.27°E). Abends wärmere Bildschirmfarben, tagsüber neutral.

### Maus-Klick-Skripte

| Tastenkombination | Aktion |
|---|---|
| `AltGr+Space` | Cursor zum rechten Rand → Klick |
| `AltGr+Return` | Cursor zur Mitte → Klick |
| `AltGr+Escape` | Cursor zum linken Rand → Klick |

Cursor-Bewegung und Klick erfolgen komplett über `swaymsg` (keine X11-Tools nötig). Nützlich um per Tastatur in Browserfenster zu fokussieren und dann mit vim-Bindings zu scrollen.

### Alacritty (`~/.config/alacritty/alacritty.toml`)

Schriftgröße 20pt. Ctrl-Tastenkombinationen explizit gebunden um Konflikte mit dem kitty-Protokoll über SSH zu vermeiden (Ctrl+R, Ctrl+L, Ctrl+A, Ctrl+E, Ctrl+K, Ctrl+U, Ctrl+W).

---

## 26. Firewall (optional)

```bash
sudo ufw enable
sudo systemctl enable --now ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw status verbose
```

---

## 27. Abschluss-Snapshot

```bash
sudo timeshift --create --comments "Mit Sway-Einstellungen $(date +%Y-%m-%d)"
```

---

## Wichtige Tastenkombinationen (Sway)

| Kürzel | Funktion |
|---|---|
| `Super+Return` | Terminal (Alacritty) |
| `Super+q` | Fenster schließen |
| `Ctrl+Space` | Rofi Launcher |
| `Super+l` | Bildschirm sperren (swaylock) |
| `Super+Shift+e` | Sway beenden |
| `Super+Shift+c` | Config neu laden |
| `Super+f` | Vollbild |
| `Super+Shift+Space` | Floating toggle |
| `Super+1…0` | Workspace wechseln |
| `Ctrl+Super+←/→` | Workspace vor/zurück |
| `Super+p` | Perplexity |
| `Super+c` | ChatGPT |
| `Super+g` | Gemini |
| `Super+y` | YouTube |
| `Super+m` | Aerc (E-Mail) |
| `Super+k` | Google Keep |
