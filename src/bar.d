module flatman.bar;

import flatman;


class Bar {

	Window window;
	flatman.Monitor monitor;

	int[2] pos;
	int[2] size;
	
	this(int[2] pos, int[2] size, flatman.Monitor monitor){
		this.pos = pos;
		this.size = size;
		this.monitor = monitor;
		XSetWindowAttributes wa;
		wa.override_redirect = true;
		wa.background_pixmap = ParentRelative;
		wa.event_mask = ButtonPressMask|ExposureMask;
		window = XCreateWindow(
			dpy, root, pos.x, pos.y, size.w, size.h,
			0, DefaultDepth(dpy, screen), CopyFromParent,
			DefaultVisual(dpy, screen),
			CWOverrideRedirect|CWBackPixmap|CWEventMask, &wa
		);
		XDefineCursor(dpy, window, cursor[CurNormal].cursor);
		XMapRaised(dpy, window);
	}

	void update(int[2] pos, int[2] size){
		this.pos = pos;
		this.size = size;
		XMoveResizeWindow(dpy, window, pos.x, pos.y, size.w, size.h);
	}

	void destroy(){
		XUnmapWindow(dpy, window);
		XDestroyWindow(dpy, window);
	}

	void onButton(XEvent* e){
		XButtonPressedEvent* ev = &e.xbutton;
		if(ev.button == Mouse.wheelDown)
			monitorActive.nextWs;
		else if(ev.button == Mouse.wheelUp)
			monitorActive.prevWs;
		else
			quit;
	}

	void onDraw(){
		draw.setColor(normbgcolor);
		draw.rect(0,0,size.w,size.h);
		draw.setColor(normfgcolor);
		try{
			auto name = ("~/.dinu/".expandTilde ~ monitorActive.workspaceActive.to!string).readText;
			name = name.replace("~".expandTilde, "~");
			draw.text(tags[monitorActive.workspaceActive] ~ ": " ~ name, [0, 0]);
		}catch{
			draw.text(tags[monitorActive.workspaceActive], [0,0]);
		}
		auto ct = Clock.currTime();
		auto text = "%s.%s. %s:%02d".format(ct.day, cast(int)ct.month, ct.hour, ct.minute);
		draw.text(text, [size.w/2, 0], 0.5);
		draw.map(window, 0, 0, size.w, size.h);
	}

}
