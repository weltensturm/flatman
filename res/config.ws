
logging true

mod super

keys {
    Super_L             overview
    Super_R             overview
    alt+d               exec dinu -f -fn Ubuntu-10 -as 0 -l 0 -r 0.3333 -y 24 -c "$(flatman-context -p)"
    mod+Return          exec flatman-terminal
    mod+n               exec firefox
    mod+shift+w         exec i3lock -c 000000 && systemctl suspend

    mod+Tab             focus tab next
    alt+Tab             focus tab next
    mod+shift+Tab       focus tab previous
    alt+shift+Tab       focus tab previous
    mod+j               focus dir left
    mod+Left            focus dir left
    mod+semicolon       focus dir right
    mod+Right           focus dir right
    mod+a               focus dir left
    mod+d               focus dir right

    mod+shift+j         move left
    mod+shift+semicolon move right
    mod+shift+k         move down
    mod+shift+l         move up
    mod+shift+Left      move left
    mod+shift+Right     move right
    mod+shift+Down      move down
    mod+shift+Up        move up
    mod+shift+a         move left
    mod+shift+d         move right
    mod+shift+w         move down
    mod+shift+s         move up

    mod+ctrl+j          resize -
    mod+ctrl+semicolon  resize +
    
    mod+r               resize mouse
    mod+m               move mouse

    mod+k               workspace-history next
    mod+Down            workspace-history next
    mod+grave           workspace-history next
    mod+l               workspace-history prev
    mod+Up              workspace-history prev
    mod+shift+grave     workspace-history prev

    mod+ctrl+l          workspace - create
    mod+ctrl+k          workspace + create
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


split {
    padding-elem 6
    background 111111
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
