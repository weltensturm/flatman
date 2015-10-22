module flatman.tabs;

import flatman;

__gshared:


class Tabs: Container {

	Window window;

	bool insertTab;

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
		XMapWindow(dpy, window);
		XLowerWindow(dpy, window);
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
	}

	void mouse(bool focus){
		//showTitles = focus;
		//if(active)
		//	this.focus(active);
		monitor.peekTitles = focus;
		foreach(tabs; monitor.workspace.split.children.to!(Tabs[]))
			tabs.resize(tabs.size);
		if(focus && active && active != flatman.active)
			flatman.focus(active);
		monitor.peekTitles = focus;
	}

	void mouse(int[2] pos){
		cursorPos = pos;
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
			flatman.focus(client);
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
			active.show;
		resize(size);
		onDraw;
		hidden = false;
	}

	override void hide(){
		if(hidden)
			return;
		XUnmapWindow(dpy, window);
		foreach(c; clients)
			c.hide;
		hidden = true;
	}

	alias add = Base.add;

	override void add(Client client){
		add(client.to!Base);
		active = client;
		resize(size);
	}

	alias remove = Base.remove;

	override void remove(Client client){
		"tabs removing %s".format(client.name).log;
		super.remove(client);
		XSync(dpy, false);
		auto n = any;
		if(n)
			active = n;
		writeln(n);
		onDraw;
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
		onDraw;
	}

	void moveRight(){
		if(clientActive >= children.length-1)
			return;
		swap(children[clientActive], children[clientActive+1]);
		clientActive++;
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
		client.show;
		"tabs focus %s".format(client.name).log;
		super.active = client;
		resize(size);
	}

	override void resize(int[2] size){
		super.resize(size);
		auto padding = config["split paddingOuter"].split.to!(int[4]);
		if(active)
			active.moveResize(
				pos.a + [padding[0], insertTab ? bh : padding[2]],
				size.a - [padding[0]+padding[1], (insertTab ? bh : padding[2])+padding[3]]
			);
		//XRaiseWindow(dpy, window);
		XMoveResizeWindow(dpy, window, pos.x, pos.y, size.w, (monitor.peekTitles || insertTab) ? bh : padding[2]);
		draw.resize(size);
		onDraw;
	}

	override void onDraw(){
		if(hidden)
			return;
		int offset = 0;
		bool containerFocused = clients.canFind(flatman.active);
		foreach(i, c; children.to!(Client[])){
			auto gap = config["split paddingElem"].to!int;
			auto leaf = (
					c.isUrgent ? "urgent"
					: flatman.active == c ? "active"
					: c.isfullscreen ? "fullscreen"
					: "normal");
			auto color = config.color("split border "
					~ (insertTab ? "insert " : "")
					~ leaf);
			draw.clip([offset,0], [size.w/cast(int)children.length,size.h]);
			draw.setColor(color);
			draw.rect([offset,0], [size.w/cast(int)children.length,size.h]);
			if(monitor.peekTitles || insertTab){
				if(!containerFocused && i == clientActive){
					draw.setColor(config.color("split border active"));
					draw.rect([offset,size.h-2], [size.w/cast(int)clients.length,2]);
				}
				color = config.color("split title "
						~ (insertTab ? "insert " : "")
						~ leaf);
				draw.setColor(color);
				draw.setFont("Consolas:size=10", 0);
				draw.text([offset + size.w/cast(int)(clients.length)/2 - draw.width(c.name)/2, size.h-bh], bh+2, c.name);
			}
			draw.setColor(config.color("split background"));
			if(i != 0)
				draw.rect([offset,0], [gap,size.h]);
			if(i != children.length-1)
				draw.rect([offset+size.w-gap,0], [2,size.h]);
			draw.noclip;
			offset += size.w/children.length;
		}
		if((monitor.peekTitles || insertTab) && containerFocused){
			draw.setColor(config.color("split border active"));
			draw.rect([0,size.h-bh], [size.w, 2]);
		}
		draw.finishFrame;
	}

}



class TabsWindow {

	this(){

	}

}


