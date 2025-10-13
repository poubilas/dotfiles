function new --description 'Wechselt in ~/Downloads/Newshosting und zeigt die 10 neuesten Einträge'
    set -l target_dir "$HOME/Downloads/Newshosting"

    if test -d "$target_dir"
        cd -- "$target_dir"

        if type -q eza
            # eza: farbig auch bei Pipe, Icons, Verzeichnisse zuerst, neueste zuerst
            eza -l -h --group-directories-first --icons \
                --sort=modified --reverse --color=always | head -n 10
        else
            # echtes ls (nicht dein Alias) als Fallback
            command ls -lht --color=always | head -n 11  # 1 Kopfzeile + 10 Einträge
        end
    else
        echo "Fehler: Das Verzeichnis '$target_dir' existiert nicht." >&2
        return 1
    end
end

