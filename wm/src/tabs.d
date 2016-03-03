module flatman.tabs;

import flatman;

__gshared:

Atom currentTab;
Atom currentTabs;

class Tabs: Container {

	Window window;

	bool showTabs = true;
	bool mouseFocus;

	this(){
		size = [10,10];
		XSetWindowAttributes wa;
		wa.override_redirect = true;
		wa.background_pixmap = ParentRelative;
		window = XCreateWindow(
				dpy, flatman.root, pos.x, pos.y, size.w, size.h,
				0, DefaultDepth(dpy, screen), CopyFromParent,
				DefaultVisual(dpy, screen),
				CWOverrideRedirect|CWBackPixmap|CWEventMask, &wa
		);
		//XMapWindow(dpy, window);
		//XLowerWindow(dpy, window);
		//XDefineCursor(dpy, window, flatman.cursor[CurMove].cursor);
		_draw = new XDraw(dpy, DefaultScreen(dpy), window, size.w, size.h);
		window.register([
			Expose: (XEvent* e)=>onDraw(),
			EnterNotify: (XEvent* e)=>mouse(true),
			LeaveNotify: (XEvent* e)=>mouse(false),
			ButtonPress: (XEvent* e)=>mouse(e.xbutton.button, true),
			ButtonRelease: (XEvent* e)=>mouse(e.xbutton.button, false),
			MotionNotify: (XEvent* e)=>mouse([e.xmotion.x, e.xmotion.y])
		]);
		hidden = true;
		if(!currentTab)
			currentTab = XInternAtom(dpy, "_FLATMAN_TAB", false);
		if(!currentTabs)
			currentTabs = XInternAtom(dpy, "_FLATMAN_TABS", false);
		if(!currentTab)
			"error".log;

	}

	void restack(){
		"tabs.restack".log;
		XLowerWindow(dpy, window);
		foreach_reverse(client; clients)
			if(client.isfullscreen)
				client.raise;
			else
				client.lower;
	}

	void mouse(bool focus){
		mouseFocus = focus;
		monitor.peekTitles = focus;
		foreach(tabs; monitor.workspace.split.children.to!(Tabs[]))
			tabs.resize(tabs.size);
		if(focus && active && active != flatman.active)
			active.focus;
		monitor.peekTitles = focus;
	}

	void mouse(int[2] pos){
		cursorPos = pos;
		mouseFocus = true;
		onDraw;
	}

	void mouse(Mouse.button button, bool pressed){
		Client client;
		foreach(i; 0..children.length){
			auto w = size.w/children.length;
			auto x = i*w;
			if(cursorPos.x > x && cursorPos.x < x+w){
				client = children[i].to!Client;
			}
		}
		if(!client)
			return;
		if(button == Mouse.buttonLeft){
			client.focus;
		}else if(button == Mouse.buttonMiddle && pressed){
			killclient(client);
			onDraw;
		}else if(button == Mouse.wheelDown && pressed)
			sizeDec;
		else if(button == Mouse.wheelUp && pressed)
			sizeInc;
	}

	override void show(){
		if(!hidden)
			return;
		XMapWindow(dpy, window);
		XMoveResizeWindow(dpy, window, pos.x, pos.y, size.w, size.h);
		if(active)
			active.configure;
		resize(size);
		onDraw;
		hidden = false;
	}

	override void hide(){
		if(hidden)
			return;
		//XUnmapWindow(dpy, window);
        XMoveWindow(dpy, window, pos.x, pos.y-monitor.size.h);
		foreach(c; clients){
            XMoveWindow(dpy, c.win, c.pos.x, c.pos.y-monitor.size.h);
        }
		hidden = true;
	}

	void destroy(){
		window.unregister;
		XDestroyWindow(dpy, window);
	}

	alias add = Base.add;

	override void add(Client client){
		//add(client.to!Base);
		if(clientActive+1 < children.length)
			children = children[0..clientActive+1] ~ client ~ children[clientActive+1..$];
		else
			add(client.to!Base);
		active = client;
		updateHints;
		resize(size);
		XSync(dpy, false);
	}

	alias remove = Base.remove;

	override void remove(Client client){
		"tabs.remove %s".format(client).log;
		super.remove(client);
		XSync(dpy, false);
		auto n = any;
		if(n)
			active = n;
		updateHints;
		onDraw;
	}

	void updateHints(){
		foreach(i, c; children.to!(Client[])){
			c.win.replace(currentTab, cast(long)i);
			c.win.replace(currentTabs, cast(long)cast(void*)this);
		}
		XSync(dpy, false);
	}

	Client next(){
		if(!children.length || clientActive == children.length-1)
			return null;
		return children[clientActive+1].to!Client;
	}

	Client prev(){
		if(!children.length || clientActive == 0)
			return null;
		return children[clientActive-1].to!Client;
	}

	void moveLeft(){
		if(clientActive <= 0)
			return;
		swap(children[clientActive], children[clientActive-1]);
		clientActive--;
		updateHints;
		onDraw;
	}

	void moveRight(){
		if(clientActive >= children.length-1)
			return;
		swap(children[clientActive], children[clientActive+1]);
		clientActive++;
		updateHints;
		onDraw;
	}

	Client any(){
		if(active)
			return active;
		auto a = clientActive.min(children.length-1).max(0);
		if(a >= 0 && a < children.length)
			return children[a].to!Client;
		return null;
	}

	alias active = Container.active;

	@property
	override void active(Client client){
		if(active && active != client)
			active.hide;
		if(!hidden && client.hidden){
			client.show;
			client.configure;
		}
		"tabs.active %s".format(client).log;
		super.active = client;
		if(!hidden)
			resize(size);
	}

	override void resize(int[2] size){
		super.resize(size);
		auto padding = config["tabs paddingOuter"].split.to!(int[4]);
		draw.setFont(config["tabs title font"], config["tabs title font-size"].to!int);
		auto bh = config["tabs title height"].to!int;
		if(active){
			if(active.isfullscreen){
				active.moveResize(monitor.pos, monitor.size);
			}else{
				active.moveResize(
					pos.a + [padding[0], showTabs ? bh : padding[2] - (hidden ? monitor.size.h : 0)],
					size.a - [padding[0]+padding[1], (showTabs ? bh : padding[2])+padding[3]]
				);
			}
		}
		//XRaiseWindow(dpy, window);
		int[2] winSize = [size.w, (monitor.peekTitles || showTabs) ? bh : padding[2]];
		XMoveResizeWindow(dpy, window, pos.x, pos.y-(hidden ? monitor.size.h : 0), winSize.w, winSize.h);
		draw.resize(winSize);
		onDraw;
	}

	override void onDraw(){
		if(hidden || !children.length)
			return;
		draw.setFont(config["tabs title font"], config["tabs title font-size"].to!int);
		auto bh = config["tabs title height"].to!int;
		int offset = 0;
		auto childWidth = (size.w/clients.length.to!double).lround.to!int;
		bool containerFocused = clients.canFind(flatman.active);
		auto padding = config["tabs paddingOuter"].split.to!(int[4]);
		foreach(i, c; children.to!(Client[])){
			drawTab(c, [offset, 0], [childWidth, (monitor.peekTitles || showTabs) ? bh : padding[2]], containerFocused);
			offset += childWidth;
		}
		draw.finishFrame;
	}

	void drawTab(Client client, int[2] pos, int[2] size, bool containerFocused){
		bool hover = mouseFocus && cursorPos.x > pos.x && cursorPos.x < pos.x+size.w;
		auto state = (
				client.isUrgent ? "urgent"
				: client.isfullscreen ? "fullscreen"
				: flatman.active == client ? "active"
				: hover ? "hover"
				: !containerFocused && client == active ? "activeBg"
				: "normal");
		draw.clip(pos, size);

		draw.setColor(config.color("tabs background " ~ state));
		draw.rect(pos, size);
		
		auto height = config["tabs border %s height".format(state == "active" ? "active" : "normal")].to!int;

		//draw.setColor(config.color("tabs border normal color"));
		//draw.rect(pos, [size.w, height]);
		
		draw.setColor(config.color("tabs border %s color".format(state == "active" ? "active" : "normal")));

		if(state == "active" || state == "activeBg")
			draw.rect([pos.x, pos.y+size.h-height], [size.x, height]);

		if(monitor.peekTitles || showTabs){
			auto textOffset = pos.x + (size.w/2 - draw.width(client.name)/2).max(size.h);
			draw.setColor([0.1,0.1,0.1]);
			foreach(x; [-1,0,1])
				foreach(y; [-1,0,1])
					draw.text([x+textOffset, y], size.h+2, client.name);
			draw.setColor(config.color("tabs title " ~ state));
			draw.text([textOffset, 0], size.h, client.name);
			if(client.icon.length){
				if(!client.xicon){
					client.xicon = draw.to!XDraw.icon(client.icon, client.iconSize.to!(int[2]));
				}
				auto scale = (size.h-4.0)/client.iconSize.h;
				draw.to!XDraw.icon(client.xicon, (textOffset-client.iconSize.w*scale).lround.to!int, 2, scale);
			}
		}
		draw.noclip;
	}

}


