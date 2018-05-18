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
	XDraw _draw;
	int[2] _cursorPos;

	override int[2] cursorPos(){
		return _cursorPos;
	}

	override DrawEmpty draw(){
		return _draw;
	}

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
		window.replace(Atoms._FLATMAN_OVERVIEW_HIDE, 1L);
		XMapWindow(dpy, window);
		show;
	}

	void mouse(bool focus){
		hasMouseFocus = focus;
		client.focus;
	}

	void mouse(int button, bool pressed){
		if(pressed && button == Mouse.buttonLeft && dragMode != DragMode.resizing){
			dragClient(client, client.pos.a - cursorPos - pos);
		}else if(pressed && button == Mouse.buttonRight && dragMode != DragMode.moving){
			dragMode = DragMode.resizing;
			dragStart = cursorPos;
		}else if(!pressed)
			dragMode = DragMode.none;
	}

	void mouse(int[2] pos){
		_cursorPos = pos;
		if(dragMode == DragMode.moving){
			this.pos = this.pos.a + pos - dragStart;
			XMoveWindow(dpy, window, this.pos.x, this.pos.y);
			client.moveResize(this.pos.a + [0, config.tabs.title.height], client.sizeFloating);
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
			client.moveResize(this.pos.a + [0, config.tabs.title.height], [size.w, client.size.h]);
			XEvent ev;
			while(XCheckMaskEvent(dpy, PointerMotionMask|SubstructureRedirectMask, &ev)){}
		}
	}

	override void show(){
		window.replace(Atoms._NET_WM_DESKTOP, monitor.workspaceActive.to!long);
		"frame.show".log;
		hidden = false;
		XMapWindow(dpy, window);
	}

	override void hide(){
		"frame.hide".log;
		hidden = true;
		XUnmapWindow(dpy, window);
	}

	void destroy(){
		"frame.destroy".log;
		hide;
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
		draw.text([size.w/2, size.h- config.tabs.title.height],  config.tabs.title.height, client.name, 0.5);
		draw.finishFrame;
		+/
		draw.setFont(config.tabs.title.font, config.tabs.title.fontSize.to!int);
		bool hover = hasMouseFocus;
		auto background = (
				client.isUrgent ? config.tabs.background.urgent
				: client.isfullscreen ? config.tabs.background.fullscreen
				: flatman.active == client ? config.tabs.background.active
				: hover ? config.tabs.background.hover
				//: !containerFocused && client == active ? activeBg
				: config.tabs.background.normal
		);
		draw.setColor(background);
		draw.rect([0,0], size);
		
		auto border = flatman.active == client ? config.tabs.border.active : config.tabs.border.normal;
		draw.setColor(border);
		auto height = config.tabs.border.height;
		draw.rect([0, size.h-height], [size.x, height]);

		auto textOffset = (size.w/2 - draw.width(client.name)/2).max(size.h);
		draw.setColor([0.1,0.1,0.1]);
		/+
		foreach(x; [-1,0,1])
			foreach(y; [-1,0,1])
				draw.text([x+textOffset, y], size.h+2, client.name);
		+/
		auto title = (
				client.isUrgent ? config.tabs.title.urgent
				: client.isfullscreen ? config.tabs.title.fullscreen
				: flatman.active == client ? config.tabs.title.active
				: hover ? config.tabs.title.hover
				//: !containerFocused && client == active ? activeBg
				: config.tabs.title.normal
		);
		draw.setColor(title);
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
