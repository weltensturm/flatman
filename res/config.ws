
logging true

mod super

keys {
    Super_L             overview
    Super_R             overview
    alt+d               exec dinu -f -fn Ubuntu-10 -as 0 -l 0 -r 0.3333 -y 12 -c "$(flatman-context -p)"
    mod+Return          exec flatman-terminal
    mod+n               exec firefox
    mod+shift+w         exec i3lock -c 000000 && systemctl suspend

    mod+Tab             focus tab next
    alt+Tab             focus tab next
    mod+shift+Tab       focus tab previous
    alt+shift+Tab       focus tab previous
    mod+h               focus dir left
    mod+l               focus dir right
    mod+j               focus dir down
    mod+k               focus dir up
    mod+Left            focus dir left
    mod+Right           focus dir right
    mod+Up              focus dir up
    mod+Down            focus dir down
    mod+w               focus dir up
    mod+a               focus dir left
    mod+s               focus dir down
    mod+d               focus dir right

    mod+shift+h         move left
    mod+shift+l         move right
    mod+shift+j         move down
    mod+shift+k         move up
    mod+shift+Left      move left
    mod+shift+Right     move right
    mod+shift+Down      move down
    mod+shift+Up        move up
    mod+shift+a         move left
    mod+shift+d         move right
    mod+shift+w         move up
    mod+shift+s         move down

    mod+ctrl+h          resize -
    mod+ctrl+l          resize +
    
    mod+r               resize mouse
    mod+m               move mouse

    mod+grave           workspace-history next
    mod+shift+grave     workspace-history prev
    mod+i               workspace-history next
    mod+u               workspace-history prev

    mod+0               workspace last s
    mod+9               workspace last create
    mod+1               workspace first s
    mod+2               workspace first create
    mod+w               insert
    mod+shift+q         killclient
    mod+shift+space     toggle floating
    mod+f               toggle fullscreen
    mod+shift+e         quit
    mod+t               toggle titles
    mod+shift+r         reload
    #mod+p              exec "if setxkbmap -query | grep us; then setxkbmap de; else setxkbmap us; fi; notify-send `setxkbmap -query | grep layout`"
    
    XF86AudioRaiseVolume exec pactl set-sink-volume @DEFAULT_SINK@ +3%
    XF86AudioLowerVolume exec pactl set-sink-volume @DEFAULT_SINK@ -3%
    XF86AudioMute exec pactl set-sink-mute @DEFAULT_SINK@ toggle

    XF86MonBrightnessUp exec xbacklight -inc 3
    XF86MonBrightnessDown exec xbacklight -dec 3
}


workspace-wrap false


workspace-padding 0


split {
    padding 0
    spacing 0
    background 111111
    separator-size 0
}


tabs {
    sort-by history
    width 120
    border {
        height 12
        active 111111
        normal 111111
        fullscreen 005577
    }
    padding 0 0 1 0
    background {
        normal 111111
        fullscreen aaaaff
        hover 111111
        activeBg 111111
        active 111111
        urgent 111111
    }
    title {
        font sans
        font-size 10
        height 24
        show 0
        normal bbbbbb
        active ffffff
        urgent dd8600
        hover ffffff
        fullscreen 888888
    }
}


dock {
    background 333333
    window {
        text ffffff
        background {
            normal 333333
            active 333333
            urgent ffff00
        }
    }
    workspace {
        title eeeeee
        background 262626
    }
}
