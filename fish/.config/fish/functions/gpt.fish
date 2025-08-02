function gpt
    set query (string join " " $argv)
    firefox --new-window "https://chatgpt.com/?q="(string escape --style=url -- $query)
end
