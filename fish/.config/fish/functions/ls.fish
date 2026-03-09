function ls --wraps='eza -al --color=always --group-directories-first --icons' \
            --description 'alias ls=eza -al --color=always --group-directories-first --icons | less -RX'
    eza -al --color=always --group-directories-first --icons $argv | less -RX
end
