function sun
    set query "Wetter Mainz-Oberstadt"
    firefox --new-window "https://www.google.com/search?q="(string escape --style=url -- $query)
end
