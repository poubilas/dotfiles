# i3 → Sway: Zusätzliche Installation

Voraussetzung: i3 ist bereits installiert und läuft. Diese Anleitung ergänzt das bestehende System um Sway, sodass beide Session über `ly` auswählbar sind.

---

## 1. Sway und Wayland-Pakete installieren

### pacman

```bash
sudo pacman -S \
    sway swaybg swaylock swayidle \
    xorg-xwayland \
    waybar \
    kanshi \
    grim slurp wl-clipboard \
    wob \
    gammastep \
    ly
```

### AUR (yay)

```bash
yay -S rofi-wayland ydotool
```

> `rofi-wayland` ersetzt das bereits installierte `rofi` — yay fragt nach Bestätigung (`y`).

---

## 2. Bereits vorhandene Pakete (kein erneutes Installieren nötig)

Diese Pakete aus der i3-Installation funktionieren auch unter Sway direkt:

| Paket | Rolle |
|---|---|
| `alacritty` | Terminal |
| `dunst` | Benachrichtigungen |
| `brightnessctl` | Helligkeit |
| `dex` + `polkit-gnome` | XDG-Autostart / Polkit |
| `pipewire` + `wireplumber` | Audio |
| `firefox`, `qutebrowser`, `obsidian`, `aerc` | Anwendungen |
| `gnome-calculator` | Taschenrechner |
| `stow` | Dotfile-Verwaltung |

---

## 3. ly aktivieren

```bash
sudo systemctl enable ly@tty2.service
sudo systemctl start ly@tty2.service
```

Sway erscheint automatisch in ly sobald es installiert ist (`/usr/share/wayland-sessions/sway.desktop`).
i3 erscheint unter `/usr/share/xsessions/i3.desktop`.

> Falls ly bereits läuft (für i3), ist kein weiterer Schritt nötig — Sway taucht nach der Installation automatisch auf.

---

## 4. Benutzer zur input-Gruppe hinzufügen (ydotool)

```bash
sudo usermod -aG input patrick
```

> Danach ausloggen und neu einloggen. Nötig für die Maus-Klick-Skripte (`AltGr+Space` usw.).

---

## 5. Dotfiles verlinken (stow)

stow kann keine Symlinks anlegen, wenn die Zieldatei bereits existiert. Zuerst vorhandene Dateien entfernen:

```bash
rm -f ~/.config/alacritty/alacritty.toml
rm -rf ~/.config/sway ~/.config/waybar ~/.config/kanshi
```

Dann verlinken:

```bash
cd ~/dotfiles
stow alacritty sway waybar kanshi
```

Prüfen ob Symlinks korrekt gesetzt sind:

```bash
ls -la ~/.config/alacritty/alacritty.toml
ls -la ~/.config/sway/config
```

Die Ausgabe muss `->` zeigen (Symlink), z.B.:
```
~/.config/sway/config -> ~/dotfiles/sway/.config/sway/config
```

> Die i3/polybar-Verlinkungen bleiben bestehen — sie stören nicht, da Sway sie ignoriert.

---

## 6. Unterschiede i3 → Sway

| Funktion | i3 (X11) | Sway (Wayland) |
|---|---|---|
| WM | `i3` | `sway` |
| Statusleiste | `polybar` | `waybar` |
| Hintergrundbild | `feh` | `output * bg ...` (in sway config) |
| Screenshots | `flameshot` | `grim` + `slurp` |
| Bildschirmsperre | `i3lock` | `swaylock` |
| Idle / Suspend | `xautolock` / `idle.sh` | `swayidle` / `idle.sh` |
| Monitor-Verwaltung | `xrandr` / `smart-monitor.sh` | `kanshi` |
| Lautstärke-OSD | `xob` | `wob` |
| Blaulichtfilter | `redshift` | `gammastep -m wayland` |
| App-Launcher | `rofi` | `rofi-wayland` |
| Maus-Klick-Skripte | `xdotool` | `ydotool` |
| Compositor | `picom` | (eingebaut in sway) |
| Tastaturlayout | `xmodmap` | `input type:keyboard { xkb_layout de }` |

---

## 7. Sway starten

In `ly` auswählen: **sway**

Beim ersten Start öffnen sich automatisch:

| Workspace | App |
|---|---|
| 1 | Alacritty |
| 2 | Firefox |
| 3 | Obsidian |
| 4 | Qutebrowser |
| 5 | Aerc |
