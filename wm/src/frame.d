module flatman.frame;

import flatman;

__gshared:


class Frame: Base {

	Client client;

	x11.X.Window window;

	int[2] dragStart;
	double clickTime;

	bool hasMouseFocus;

	enum DragMode {
		none,
		moving,
		resizing
	}

	DragMode dragMode = DragMode.none;

	this(Client client, int[2] pos, int[2] size){
		this.client = client;
		this.pos = pos;
		this.size = size;
		XSetWindowAttributes wa;
		wa.override_redirect = true;
		wa.background_pixmap = ParentRelative;
		window = XCreateWindow(
				dpy, flatman.root, pos.x, pos.y, size.w, size.h,
				0, DefaultDepth(dpy, screen), CopyFromParent,
				DefaultVisual(dpy, screen),
				CWOverrideRedirect|CWBackPixmap|CWEventMask, &wa
		);
		_draw = new XDraw(dpy, window);
		window.register([
			Expose: (XEvent* e)=>onDraw(),
			EnterNotify: (XEvent* e)=>mouse(true),
			LeaveNotify: (XEvent* e)=>mouse(false),
			ButtonPress: (XEvent* e)=>mouse(e.xbutton.button, true),
			ButtonRelease: (XEvent* e)=>mouse(e.xbutton.button, false),
			MotionNotify: (XEvent* e)=>mouse([e.xmotion.x, e.xmotion.y])
		]);
		XMapWindow(dpy, window);
		show;
	}

	void mouse(bool focus){
		hasMouseFocus = focus;
		client.focus;
	}

	void mouse(int button, bool pressed){
		if(pressed && button == Mouse.buttonLeft && dragMode != DragMode.resizing){
			.drag(client, client.pos.a - cursorPos - pos);
		}else if(pressed && button == Mouse.buttonRight && dragMode != DragMode.moving){
			dragMode = DragMode.resizing;
			dragStart = cursorPos;
		}else if(!pressed)
			dragMode = DragMode.none;
	}

	void mouse(int[2] pos){
		cursorPos = pos;
		if(dragMode == DragMode.moving){
			this.pos = this.pos.a + pos - dragStart;
			XMoveWindow(dpy, window, this.pos.x, this.pos.y);
			client.moveResize(this.pos.a + [0,cfg.tabsTitleHeight], client.sizeFloating);
			XEvent ev;
			while(XCheckMaskEvent(dpy, PointerMotionMask|SubstructureRedirectMask, &ev)){}
		}else if(dragMode == DragMode.resizing){
			this.pos.h = this.pos.h + pos.h - dragStart.h;
			size.w = size.w + pos.w - dragStart.w;
			client.size.h = client.size.h + dragStart.h - pos.h;
			size = [size.w.max(1), size.h.max(1)];
			client.size = [client.size.w.max(1), client.size.h.max(1)];
			dragStart.w = pos.w;
			XMoveResizeWindow(dpy, window, this.pos.x, this.pos.y, size.w, size.h);
			draw.resize(this.size);
			client.moveResize(this.pos.a + [0,cfg.tabsTitleHeight], [size.w, client.size.h]);
			XEvent ev;
			while(XCheckMaskEvent(dpy, PointerMotionMask|SubstructureRedirectMask, &ev)){}
		}
	}

	override void show(){
		replace!long(window, net.windowDesktop, monitor.workspaceActive);
		"frame.show".log;
		hidden = false;
		XMoveWindow(dpy, window, pos.x, pos.y);
	}

	override void hide(){
		"frame.hide".log;
		hidden = true;
		XMoveWindow(dpy, window, pos.x, pos.y-monitor.size.h);
		//XUnmapWindow(dpy, window);
	}

	void destroy(){
		draw.destroy;
		window.unregister;
		XDestroyWindow(dpy, window);
	}

	void moveResize(int[2] pos, int[2] size){
		"frame.moveResize %s %s".format(pos, size).log;
		draw.resize([size.w.max(1), size.h.max(1)]);
		this.pos = pos;
		this.size = size;
		if(hidden)
			XMoveWindow(dpy, window, pos.x, pos.y-monitor.size.h);
		else
			XMoveResizeWindow(dpy, window, pos.x, pos.y, size.w.max(1), size.h.max(1));
	}

	override void onDraw(){
		/+
		draw.setColor(config.color("split background"));
		draw.rect([0,0], size);
		draw.setFont("Consolas", 10);
		draw.setColor(config.color("tabs title normal"));
		draw.text([size.w/2, size.h-cfg.tabsTitleHeight], cfg.tabsTitleHeight, client.name, 0.5);
		draw.finishFrame;
		+/
		draw.setFont(config["tabs title font"], config["tabs title font-size"].to!int);
		bool hover = hasMouseFocus;
		auto state = (
				client.isUrgent ? "urgent"
				: client.isfullscreen ? "fullscreen"
				: flatman.active == client ? "active"
				: hover ? "hover"
				//: !containerFocused && client == active ? "activeBg"
				: "normal");
		draw.setColor(config.color("tabs background " ~ state));
		draw.rect([0,0], size);

		draw.setColor(config.color("tabs border %s color".format(state == "active" ? "active" : "normal")));
		auto height = config["tabs border %s height".format(state == "active" ? "active" : "normal")].to!int;
		draw.rect([0, size.h-height], [size.x, height]);

		auto textOffset = (size.w/2 - draw.width(client.name)/2).max(size.h);
		draw.setColor([0.1,0.1,0.1]);
		/+
		foreach(x; [-1,0,1])
			foreach(y; [-1,0,1])
				draw.text([x+textOffset, y], size.h+2, client.name);
		+/
		draw.setColor(config.color("tabs title " ~ state));
		draw.text([textOffset, 0], size.h, client.name);
		if(client.icon.length){
			if(!client.xicon){
				client.xicon = draw.to!XDraw.icon(client.icon, client.iconSize.to!(int[2]));
			}
			auto scale = (size.h-4.0)/client.iconSize.h;
			draw.to!XDraw.icon(client.xicon, (textOffset-client.iconSize.w*scale).lround.to!int, 2, scale);
		}
		draw.finishFrame;
	}

}
