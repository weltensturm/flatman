

mod super

keys {
    Super_L				overview
    Super_R				overview
    alt+d				exec dinu -f -fn Ubuntu-10 -as 0 -l 0 -r 0.3333 -y 24 -c "$(flatman-context -p)"
    mod+Return			exec cd "$(flatman-context)" && terminator || terminator
    mod+n				exec firefox
    mod+shift+w			exec i3lock -c 000000 && systemctl suspend
    mod+j				focus dir -
    mod+Left			focus dir -
    mod+i				focus stack -
    mod+semicolon		focus dir +
    mod+Right			focus dir +
    alt+Tab				focus dir +
    alt+shift+Tab		focus dir -
    mod+o				focus stack +
    mod+ctrl+j			resize -
    mod+ctrl+semicolon	resize +
    mod+r				resize mouse
    mod+m				move mouse
    mod+k				workspace + filled
    mod+Down			workspace + filled
    mod+asciitilde		workspace + filled
    mod+l				workspace - filled
    mod+Up				workspace - filled
    mod+shift+asciitilde		workspace - filled
    mod+ctrl+l			workspace - create
    mod+ctrl+k			workspace + create
    mod+0				workspace last s
    mod+9				workspace last create
    mod+1				workspace first s
    mod+2				workspace first create
    mod+shift+j			move -
    mod+shift+semicolon	move +
    mod+shift+k			move down
    mod+shift+l			move up
    mod+shift+Left		move -
    mod+shift+Right     move +
    mod+shift+Down		move down
    mod+shift+Up		move up
    mod+w				insert
    mod+shift+q			killclient
    mod+shift+space		toggle floating
    mod+f				toggle fullscreen
    mod+shift+e			quit
    mod+t				toggle titles
    mod+shift+r			reload
    #mod+p				exec "if setxkbmap -query | grep us; then setxkbmap de; else setxkbmap us; fi; notify-send `setxkbmap -query | grep layout`"
    
    XF86AudioRaiseVolume exec pactl set-sink-volume @DEFAULT_SINK@ +3%
    XF86AudioLowerVolume exec pactl set-sink-volume @DEFAULT_SINK@ -3%
    XF86AudioMute exec pactl set-sink-mute @DEFAULT_SINK@ toggle

    XF86MonBrightnessUp exec xbacklight -inc 3
    XF86MonBrightnessDown exec xbacklight -dec 3
}


workspace-wrap false


split {
    padding-elem 6
    background 222222
}


tabs {
    width 120
    border {
        height 12
        active 222222
        normal 222222
        fullscreen 005577
    }
    padding 0 0 1 0
    background {
        normal 222222
        fullscreen aaaaff
        hover 222222
        activeBg 222222
        active 222222
        urgent 222222
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
