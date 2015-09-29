

keys {
	alt+d				exec "dinu -fn UbuntuMono-9 -c ~/.dinu/$(cws)"
	alt+Return			exec "cd $(cat ~/.dinu/$(cws)) && terminator"
	alt+shift+w			exec i3lock && systemctl suspend
	alt+j				focus -
	alt+Left			focus -
	alt+semicolon		focus +
	alt+Right			focus +
	alt+ctrl+j			resize -
	alt+ctrl+semicolon	resize +
	alt+r				resize mouse
	alt+m				move mouse
	alt+k				workspace + filled
	alt+Down			workspace + filled
	alt+l				workspace - filled
	alt+Up				workspace - filled
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
	
	XF86AudioRaiseVolume exec pactl set-sink-volume @DEFAULT_SINK@ +3%
	XF86AudioLowerVolume exec pactl set-sink-volume @DEFAULT_SINK@ -3%
	XF86AudioMute exec pactl set-sink-mute @DEFAULT_SINK@ toggle
}


split {
	background 222222
	border 0 0 2 0
	paddingElem 4
	paddingOuter 0 0 2 0
	border {
		normal 444444
		active dd8300
		insert {
			normal 444444
			active dd8300
		}
	}
	title {
		show 0
		normal cccccc
		active ffffff
		insert {
			normal ffffff
			active ffffff
		}
	}
}

bar {
	background 222222
	foreground 000000
}

dock {
	background 222222
	window {
		text ffffff
		background {
			normal 444444
			active dd8300
			urgent ffff00
		}
	}
	workspace {
		title eeeeee
		background 262626
	}
}
