function yt
    set query (string join " " $argv)
    set encoded_query (string escape --style=url -- $query)
    
    # Der Parameter &sp=EgIIBQ%3D%3D filtert die Ergebnisse nach "Dieses Jahr"
    set full_url "https://www.youtube.com/results?search_query=$encoded_query&sp=EgIIBQ%3D%3D"
    
    firefox --new-window $full_url
end
