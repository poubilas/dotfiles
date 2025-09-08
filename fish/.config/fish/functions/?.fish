function ? --description 'DuckDuckGo-Suche in lynx'
    if test (count $argv) -eq 0
        echo "Benutzung: ? <Suchbegriff>"
        return 1
    end
    set -l query (string join ' ' -- $argv)
    set -l enc (string escape --style=url -- $query)
    # /html ist die JS-freie DDG-Seite – perfekt für lynx
    lynx "https://duckduckgo.com/lite/?q=$enc"
end
