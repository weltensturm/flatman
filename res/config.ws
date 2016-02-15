

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
	paddingElem 0
	paddingOuter 0 0 2 0
	background 222222
	background {
		normal 222222
		hover 444444
		active dd8300
		urgent 222222
	}
	border 0 0 2 0
	border {
		normal 444444
		active dd8300
		urgent ffff00
		hover 444444
		fullscreen 005588
	}
	title {
		font Tahoma
		font-size 9
		show 0
		normal cccccc
		active ffffff
		urgent 000000
		hover ffffff
		fullscreen ffffff
		insert {
			normal ffffff
			active ffffff
			urgent 000000
			hover ffffff
			fullscreen ffffff
		}
	}
}

tabs {
	border dd8300
	background {
		normal 222222
		hover 444444
		activeBg 333333
		active dd8300
		urgent 222222
	}
	title {
		font Tahoma
		font-size 9
		show 0
		normal cccccc
		active ffffff
		activeBg ffffff
		urgent 000000
		hover ffffff
		fullscreen ffffff
	}
}

dock {
	background 222222
	window {
		text ffffff
		background {
			normal 222222
			active dd8300
			urgent ffff00
		}
	}
	workspace {
		title eeeeee
		background 262626
	}
}
