source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

# Benutzerdefinierte Konfiguration für den Webbrowser Lynx
set -x LYNX_CFG "$HOME/.config/lynx/lynx.cfg"
set -x LYNX_LSS "$HOME/.config/lynx/lynx.lss"

alias bl='bluetoothctl'

# Re-apply local overrides after the CachyOS config defines its aliases.
source ~/.config/fish/functions/ls.fish
