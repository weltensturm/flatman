

$mod Mod1Mask

keys {
	$mod+d exec dinu -fn Consolas-10 -c ~/.dinu/$wsNum
	$mod+return exec cd $(cat ~/.dinu/$wsNum) && terminator
	$mod+j focus left
	$mod+left focus left
	$mod+; focus right
	$mod+right focus right
	$mod+k workspace down
	$mod+down workspace down
	$mod+l workspace up
	$mod+up workspace up
}


split {
	background 222222
	border 2
	paddingElem 10
	paddingOuter 0
	border {
		normal 444444
		active dd8300
	}
	title {
		height 1
		normal cccccc
		active ffffff
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