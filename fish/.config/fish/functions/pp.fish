function pp
    set query (string join " " $argv)
    firefox --new-window "https://www.perplexity.ai/?q="(string escape --style=url -- $query)
end
