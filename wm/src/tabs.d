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
			writeln("error");

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
		replace!long(window, net.windowDesktop, monitor.workspaceActive);
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
        XMoveWindow(dpy, window, pos.x, -monitor.size.h+pos.y);
		foreach(c; clients){
            XMoveWindow(dpy, c.win, c.pos.x, -monitor.size.h+c.pos.y);
        }
		hidden = true;
	}

	void destroy(){
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
		"tabs removing %s".format(client.name).log;
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
		"tabs focus %s".format(client.name).log;
		super.active = client;
		if(!hidden)
			resize(size);
	}

	override void resize(int[2] size){
		super.resize(size);
		auto padding = config["split paddingOuter"].split.to!(int[4]);
		draw.setFont(config["tabs title font"], config["tabs title font-size"].to!int);
		auto bh = (draw.fontHeight*1.2).lround.to!int;
		writeln(active);
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
		XMoveResizeWindow(dpy, window, pos.x, pos.y-(hidden ? monitor.size.h : 0), size.w, (monitor.peekTitles || showTabs) ? bh : padding[2]);
		draw.resize(size);
		onDraw;
	}

	override void onDraw(){
		if(hidden)
			return;
		draw.setFont(config["tabs title font"], config["tabs title font-size"].to!int);
		auto bh = (draw.fontHeight*1.2).lround.to!int;
		int offset = 0;
		bool containerFocused = clients.canFind(flatman.active);
		foreach(i, c; children.to!(Client[])){
			bool hover = mouseFocus && cursorPos.x > offset && cursorPos.x < offset+size.w/cast(int)children.length;
			auto state = (
					c.isUrgent ? "urgent"
					: flatman.active == c ? "active"
					: hover ? "hover"
					: !containerFocused && i == clientActive ? "activeBg"
					: c.isfullscreen ? "fullscreen"
					: "normal");
			draw.clip([offset,0], [size.w/cast(int)children.length,size.h]);
			draw.setColor(config.color("tabs background " ~ state));
			draw.rect([offset,0], [size.w/cast(int)children.length,size.h]);
			if(monitor.peekTitles || showTabs){
				auto textOffset = offset + (size.w/cast(int)(clients.length)/2 - draw.width(c.name)/2).max(bh);
				draw.setColor([0.1,0.1,0.1]);
				foreach(x; [-1,0,1]){
					foreach(y; [-1,0,1]){
						draw.text([x+textOffset, y+size.h-bh], bh+2, c.name);
					}
				}
				draw.setColor(config.color("tabs title " ~ state));
				draw.text([textOffset, size.h-bh], bh+2, c.name);
				if(c.icon.length){
					if(!c.xicon){
						c.xicon = draw.to!XDraw.icon(c.icon, c.iconSize.to!(int[2]));
					}
					auto scale = (bh-4)/c.iconSize.h.to!double;
					draw.to!XDraw.icon(c.xicon, (textOffset-c.iconSize.w*scale).to!int, 2, scale);
				}
			}
			draw.noclip;
			offset += size.w/children.length;
		}
		draw.setColor(config.color("split border active"));
		draw.rect([0,size.h-bh], [size.w, 2]);
		draw.finishFrame;
	}

}


