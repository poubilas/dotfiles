# Arch Linux + Sway — Automatisierte Installation

Drei Scripts ersetzen die manuelle Anleitung aus `INSTALL.md`.

---

## Übersicht

| Script | Wann | Was |
|---|---|---|
| `pre-install.sh` | Live-ISO (als root) | WLAN, Partitionierung, LUKS, BTRFS, pacstrap, chroot |
| `chroot.sh` | automatisch (via pre-install.sh) | Locale, Benutzer, Pakete, GRUB, Services |
| `post-install.sh` | Nach erstem Neustart (als Benutzer) | yay, Dotfiles, Sway, Timeshift, Firewall |

---

## Schritt 1 — Live-ISO booten

Arch Linux ISO booten. Dann:

```bash
curl -O https://raw.githubusercontent.com/poubilas/dotfiles/main/archinstallsway/pre-install.sh
bash pre-install.sh
```

Das Script fragt interaktiv nach:
- WLAN-SSID und Passwort
- Festplattenname (z.B. `nvme0n1`)
- LUKS-Passwort (zweimal)
- Computername (Hostname)
- Root-Passwort
- Benutzername und Passwort
- Intel-GPU Generation (für Treiber)

`chroot.sh` wird automatisch aufgerufen — kein manueller `arch-chroot`-Wechsel nötig.

Am Ende:

```bash
shutdown now   # USB-Stick vorher entfernen!
```

---

## Schritt 2 — Nach erstem Neustart

Als Benutzer (nicht root) einloggen. Dann:

```bash
curl -O https://raw.githubusercontent.com/poubilas/dotfiles/main/archinstallsway/post-install.sh
bash post-install.sh
```

Das Script fragt nach:
- WLAN-SSID und Passwort (nmcli)

**Ein manueller Schritt** bleibt:

### grub-btrfsd Editor (Schritt 15)

Das Script öffnet automatisch den Editor. Dort die `ExecStart`-Zeile anpassen:

```
# Vorher (Ende der Zeile):
ExecStart=... /.snapshots

# Nachher:
ExecStart=/usr/bin/grub-btrfsd --syslog -t
```

Speichern: `:wq`

---

## Nach der Installation

### aerc E-Mail einrichten (manuell)

```bash
cp /pfad/zu/accounts.conf ~/dotfiles/aerc/.config/aerc/accounts.conf
sudo chmod 600 ~/dotfiles/aerc/.config/aerc/accounts.conf
```

### Sway starten

In `ly` beim Login **sway** auswählen.

---

## Hinweise

- Die Scripts sind idempotent wo möglich (bereits installierte Pakete werden übersprungen)
- Bei Fehler bricht das Script mit einer Fehlermeldung ab (`set -euo pipefail`)
- Nach `post-install.sh`: neu einloggen damit die `input`-Gruppe aktiv wird (für ydotool)
