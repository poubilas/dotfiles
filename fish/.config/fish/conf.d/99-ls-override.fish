functions -e ls 2>/dev/null

function ls --wraps='eza -al --color=always --group-directories-first --icons' \
            --description 'alias ls=eza -al --color=always --group-directories-first --icons | less -R'
    eza -al --color=always --group-directories-first --icons $argv | less -R
end
