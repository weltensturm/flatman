

keys {
	alt+d				exec dinu -fn Monospace-9 -c "$(flatman-context -p)"
	alt+Return			exec cd "$(flatman-context)" && terminator
	alt+n				exec firefox
	alt+shift+w			exec i3lock -c 000000 && systemctl suspend
	alt+j				focus dir -
	alt+Left			focus dir -
	alt+i				focus stack -
	alt+semicolon		focus dir +
	alt+Right			focus dir +
	alt+o				focus stack +
	alt+ctrl+j			resize -
	alt+ctrl+semicolon	resize +
	alt+r				resize mouse
	alt+m				move mouse
	alt+k				workspace + filled
	alt+Down			workspace + filled
	alt+l				workspace - filled
	alt+Up				workspace - filled
	alt+ctrl+l			workspace - create
	alt+ctrl+k			workspace + create
	alt+0				workspace last s
	alt+9				workspace last create
	alt+1				workspace first s
	alt+2				workspace first create
	alt+shift+j			move -
	alt+shift+semicolon	move +
	alt+shift+k			move down
	alt+shift+l			move up
	alt+w				insert
	alt+shift+q			killclient
	alt+shift+space		toggle floating
	alt+f				toggle fullscreen
	alt+shift+e			quit
	alt+t				toggle titles
	alt+shift+r			reload
	#alt+p				"if setxkbmap -query | grep us; then setxkbmap de; else setxkbmap us; fi; notify-send `setxkbmap -query | grep layout`"
	
	XF86AudioRaiseVolume exec pactl set-sink-volume @DEFAULT_SINK@ +3%
	XF86AudioLowerVolume exec pactl set-sink-volume @DEFAULT_SINK@ -3%
	XF86AudioMute exec pactl set-sink-mute @DEFAULT_SINK@ toggle
}


autostart {
	flatman-dock
	flatman-menu
	flatman-compositor
	flatman-volume-icon
}


split {
	paddingElem 6
	background 222222
}

tabs {
	border {
		active {
			height 1
			color dd8600
		}
		normal {
			height 1
			color 333333
		}
	}
	paddingOuter 0 0 2 0
	background {
		normal 222222
		fullscreen 005577
		hover 333333
		activeBg 222222
		active 222222
		urgent 994333
	}
	title {
		font Tahoma
		font-size 9
		height 20
		show 0
		normal bbbbbb
		active ffffff
		activeBg bbbbbb
		urgent ffffff
		hover ffffff
		fullscreen ffffff
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
