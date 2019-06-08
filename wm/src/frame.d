module flatman.frame;

import flatman;

import common.xevents;


__gshared:


class Frame: Base {

	Client client;

	x11.X.Window window;

	int[2] dragStart;
	double clickTime;

	bool hasMouseFocus;

    //GlContext context;
	//GlDraw _draw;
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
		hidden = true;

		auto visual = new XVisualInfo;
		if(!XMatchVisualInfo(dpy, DefaultScreen(dpy), 24, TrueColor, visual))
			writeln("XMatchVisualInfo failed");

		XSetWindowAttributes wa;
		wa.override_redirect = true;
    	wa.colormap = XCreateColormap(dpy, DefaultRootWindow(dpy), visual.visual, AllocNone);
		wa.background_pixmap = None;
		wa.border_pixmap = None;
		wa.border_pixel = 0;
		wa.bit_gravity = NorthWestGravity;

		window = XCreateWindow(
				dpy,
				flatman.root,
				pos.x, pos.y, size.w, size.h, 0,
				visual.depth,
				InputOutput,
				visual.visual,
                CWBorderPixel | CWOverrideRedirect | CWColormap | CWBackPixmap | CWEventMask,
				&wa
		);
		XSelectInput(dpy, window, ExposureMask | EnterWindowMask | LeaveWindowMask | ButtonPressMask |
								  ButtonReleaseMask | PointerMotionMask);
		show;
        _draw = new XDraw(dpy, window);
		draw.setFont(config.tabs.title.font, config.tabs.title.fontSize.to!int);
		window.replace(Atoms._FLATMAN_OVERVIEW_HIDE, 1L);
		Events[window] ~= this;
	}

	@WindowEnter
	void focus(){
		hasMouseFocus = true;
		client.focus;
	}

	@WindowLeave
	void unfocus(){
		hasMouseFocus = false;
	}

	@WindowMouseButton
	void mouse(bool pressed, int button){
		if(!pressed || .drag.dragging)
			return;
		if(button == Mouse.buttonLeft){
			.drag.window(button, client, client.pos.a - cursorPos - pos);
		}else if(button == Mouse.buttonRight){
			auto cursorRoot = [pos.x + cursorPos.x, pos.y + cursorPos.y];
			dragStart = cursorRoot;
			auto startPos = client.pos;
			auto startSize = client.size;
			.drag.drag(button, (int[2] pos){
				int[2] targetSize = [
					startSize.w - (dragStart.x - pos.x),
					startSize.h + (dragStart.y - pos.y)
				];
				int[2] targetPos = [
					startPos.x,
					startPos.y - (dragStart.y - pos.y)
				];
				client.moveResize(targetPos, targetSize);
			});
		}
	}

	@WindowMouseMove
	void mouse(int[2] pos){
		_cursorPos = pos.a;
		writeln("MOUSE ", cursorPos);
	}

	override void show(){
		window.replace(Atoms._NET_WM_DESKTOP, monitor.workspaceActive.to!long);
		"frame.show".log;
		hidden = false;
		XMapWindow(dpy, window);
	}

    @WindowMap
    override void onShow(){
        hidden = false;
    }

    @WindowUnmap
    override void onHide(){
        hidden = true;
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
		XDestroyWindow(dpy, window);
		Events.forget(this);
	}

	void moveResize(int[2] pos, int[2] size){
		if(hidden)
			XMoveWindow(dpy, window, pos.x, pos.y-monitor.size.h);
		else
			XMoveResizeWindow(dpy, window, pos.x, pos.y, size.w.max(1), size.h.max(1));
	}

	@WindowResize
	void onResize(int[2] size){
        "%s resize %s".format(draw, size).log;
		draw.resize([size.w.max(1), size.h.max(1)]);
		this.size = size;
	}

	@WindowMove
	void onMove(int[2] pos){
		this.pos = pos;
	}

	@WindowExpose
	override void onDraw(){
		if(hidden)
			return;
		"frame.draw".log;
		/+
		draw.setColor(config.color("split background"));
		draw.rect([0,0], size);
		draw.setFont("Consolas", 10);
		draw.setColor(config.color("tabs title normal"));
		draw.text([size.w/2, size.h- config.tabs.title.height],  config.tabs.title.height, client.name, 0.5);
		draw.finishFrame;
		+/

		auto background = (
				client.isUrgent ? config.tabs.background.urgent
				: client.isfullscreen ? config.tabs.background.fullscreen
				: flatman.active == client ? config.tabs.background.active
				: hasMouseFocus ? config.tabs.background.hover
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

		foreach(x; [-1,0,1])
			foreach(y; [-1,0,1])
				draw.text([x+textOffset, y], size.h+2, client.name);

		auto title = (
				client.isUrgent ? config.tabs.title.urgent
				: client.isfullscreen ? config.tabs.title.fullscreen
				: flatman.active == client ? config.tabs.title.active
				: hasMouseFocus ? config.tabs.title.hover
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
