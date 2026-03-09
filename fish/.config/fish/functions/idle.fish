function idle
    set -l notifier "/home/patrick/dotfiles/i3/.config/i3/xautolog-notifier.sh"
    set -l locker "systemctl suspend"

    set -l arg status
    if test (count $argv) -ge 1
        set arg "$argv[1]"
    end

    switch "$arg"
        case never off
            pkill -x xautolock >/dev/null 2>&1
            echo "Idle-Suspend deaktiviert"
        case status
            set -l cmd (pgrep -a -x xautolock | head -n1)
            if test -n "$cmd"
                set -l minutes (printf '%s\n' "$cmd" | sed -n 's/.*-time \([0-9][0-9]*\).*/\1/p')
                if test -n "$minutes"
                    echo "Idle-Suspend aktiv: $minutes Minuten"
                else
                    echo "Idle-Suspend aktiv"
                end
            else
                echo "Idle-Suspend deaktiviert"
            end
        case '' help -h --help
            echo "Verwendung: idle.sh never | idle.sh <minuten> | idle.sh status"
            return 0
        case '*'
            if string match -rq '^[0-9]+$' -- "$arg"; and test "$arg" -gt 0
                pkill -x xautolock >/dev/null 2>&1
                nohup xautolock \
                    -detectsleep \
                    -time "$arg" \
                    -notify 30 \
                    -notifier "$notifier" \
                    -locker "$locker" \
                    >/dev/null 2>&1 &
                echo "Idle-Suspend nach $arg Minuten"
            else
                echo "Ungueltig. Verwende: idle.sh never | idle.sh <minuten> | idle.sh status" >&2
                return 1
            end
    end
end
