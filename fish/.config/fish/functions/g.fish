function g
    set query (string join " " $argv)
    firefox --new-window "https://www.google.com/search?q="(string escape --style=url -- $query)
end
