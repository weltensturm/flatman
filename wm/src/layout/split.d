module flatman.layout.split;

import flatman;

__gshared:


long find(T)(T[] array, T what){
	long i;
	foreach(e; array){
		if(e == what)
			return i;
		i++;
	}
	return -1;
}


void swap(T)(ref T[] array, size_t i1, size_t i2){
	T copy = array[i1];
	array[i1] = array[i2];
	array[i2] = copy;
}


class Separator: Base {

	x11.X.Window window;

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
		_draw = new XDraw(dpy, window);
		window.register([
			Expose: (XEvent* e)=>onDraw(),
			/+
			EnterNotify: (XEvent* e)=>mouse(true),
			LeaveNotify: (XEvent* e)=>mouse(false),
			ButtonPress: (XEvent* e)=>mouse(e.xbutton.button, true),
			ButtonRelease: (XEvent* e)=>mouse(e.xbutton.button, false),
			MotionNotify: (XEvent* e)=>mouse([e.xmotion.x, e.xmotion.y])
			+/
		]);
		XMapWindow(dpy, window);
		hide;
	}

	override void show(){
		//replace!long(window, net.windowDesktop, monitor.workspaceActive);
		if(size.w > 0 && size.h > 0){
			"separator.show".log;
			hidden = false;
			XMoveWindow(dpy, window, pos.x, pos.y);
		}else
			hide;
	}

	override void hide(){
		"separator.hide".log;
		hidden = true;
		XMoveWindow(dpy, window, pos.x, pos.y-monitor.size.h);
		//XUnmapWindow(dpy, window);
	}

	void destroy(){
		window.unregister;
		XDestroyWindow(dpy, window);
	}

	void moveResize(int[2] pos, int[2] size){
		"separator.moveResize %s %s".format(pos, size).log;
		draw.resize([size.w.max(1), size.h.max(1)]);
		this.pos = pos;
		this.size = size;
		if(hidden)
			XMoveWindow(dpy, window, pos.x, pos.y-monitor.size.h);
		else
			XMoveResizeWindow(dpy, window, pos.x, pos.y, size.w.max(1), size.h.max(1));
	}

	override void onDraw(){
		draw.setColor(config.color("split background"));
		draw.rect([0,0], size);
		draw.finishFrame;
	}

}


class Split: Container {

	enum {
		horizontal,
		vertical
	}

	int mode;

	long[] sizes;
	
	Separator[] separators;

	bool lock;

	this(int[2] pos, int[2] size, int mode=horizontal){
		hidden = true;
		this.mode = mode;

		move(pos);
		resize(size);
	}

	void restack(){
		if(!children.length)
			return;
		with(Log("split.restack")){
			foreach(separator; separators)
				XRaiseWindow(dpy, separator.window);
			foreach(i, tabs; children.to!(Tabs[]))
				tabs.restack;
			if(clientActive < children.length && clientActive >= 0)
				children[clientActive].to!Tabs.restack;
		}
	}

	void destroy(){
		foreach(c; children)
			c.to!Container.destroy;
	}

	void sizeInc(){
		sizes[clientActive] += 50;
		rebuild;
		XSync(dpy, false);
		active.focus;
	}

	void sizeDec(){
		sizes[clientActive] -= 50;
		rebuild;
		XSync(dpy, false);
		active.focus;
	}

	override void show(){
		if(!hidden)
			return;
		with(Log("split.show")){
			hidden = false;
			foreach(c; children ~ separators.to!(Base[]))
				c.show;
			rebuild;
		}
	}

	override void hide(){
		if(hidden)
			return;
		with(Log("split.hide")){
			hidden = true;
			foreach(c; children ~ separators.to!(Base[]))
				c.hide;
		}
	}

	alias add = Base.add;

	override void add(Client client){
		add(client, long.max);
	}

	void add(Client client, long position=long.max){
		XSync(dpy, false);
		if(position == long.max)
			position = clientActive;
		with(Log("split.add %s pos=%s".format(client, position))){
			Tabs tab;
			if(position >= 0 && position < children.length){
				tab = children[position].to!Tabs;
			}else{
				tab = new Tabs;
				tab.parent = this;
				if(position >= 0 && position < children.length.to!long){
					children = children[0..position+1] ~ tab ~ children[position+1..$];
					sizes = sizes[0..position+1] ~ client.size.w ~ sizes[position+1..$];
				}else{
					if(position < 0){
						children = tab ~ children;
						sizes = client.size.w ~ sizes;
					}else{
						children ~= tab;
						sizes ~= client.size.w;
					}
				}
				if(children.length > 1)
					separators ~= new Separator;
				if(!hidden){
					tab.show;
					if(separators.length)
						separators[$-1].show;
				}
			}
			foreach(child; children.to!(Tabs[]))
				child.updateHints;
			tab.add(client);
			rebuild;
		}
	}

	void moveClient(int dir){
		lock = true;
		if(clientActive >= 0 && clientActive < children.length){
			auto tabs = children[clientActive].to!Tabs;
			Tabs tabsNext;
			if(clientActive+dir >= 0 && clientActive+dir < children.length)
				tabsNext = children[clientActive+dir].to!Tabs;
			if(dir < 0 && tabs.prev || dir > 0 && tabs.next){
				if(dir < 0)
					tabs.moveLeft;
				else
					tabs.moveRight;
			}else if(tabsNext){
				Client client = tabs.active;
				remove(client);
				tabsNext.add(client);
			}else{
				Client client = tabs.active;
				remove(client);
				add(client, clientActive+dir);
				client.focus;
			}
		}
		lock = false;
		rebuild;
	}

	override void onDraw(){
		foreach(s; separators)
			s.onDraw;
		super.onDraw;
	}

	override void remove(Base base){
		Base.remove(base);
		rebuild;
	}

	override void remove(Client client){
		with(Log("split.remove %s".format(client))){
			foreach(i, container; children.to!(Tabs[])){
				if(container.children.canFind(client)){
					container.remove(client);
					if(!container.children.length){
						container.destroy;
						remove(container);
						sizes = sizes[0..i] ~ sizes[i+1..$];
						if(separators.length){
							separators[$-1].destroy;
							separators = separators[0..$-1];
						}
						if(clientActive >= children.length)
							clientActive = cast(int)children.length-1;
						foreach(child; children.to!(Tabs[]))
							child.updateHints;
						rebuild;
						return;
					}
				}
			}
		}
	}

	override Client[] clients(){
		Client[] res;
		foreach(c; children)
			res ~= (cast(Container)c).clients;
		return res;
	}

	override void move(int[2] pos){
		super.move(pos);
		rebuild;
	}

	override void resize(int[2] size){
		with(Log("split.resize %s".format(size))){
			super.resize(size);
			if(draw)
				draw.resize(size);
			rebuild;
		}
	}

	void normalize(){
		auto padding = config["split paddingElem"].to!long;
		long max = size.w-padding*(children.length-1);
		max = max.max(400);
		foreach(ref s; sizes)
			s = s.min(max).max(10);
		double cur = sizes.sum;
		foreach(ref s; sizes)
			s = (s*max/cur).lround;
		/+
		foreach(i, ref s; sizes){
			auto minw = cast(long)(cast(Client)children[i]).minw;
			if(minw > 10 && minw < max && s < minw)
				s = minw;
		}
		+/
		cur = sizes.sum;
		foreach(ref s; sizes){
			auto old = s;
			s = (s*max/cur).lround;
		}
		"split.normalize %s".format(sizes).log;
	}

	void rebuild(){
		if(lock)
			return;
		with(Log("split.rebuild")){
			normalize;
			int offset = 0;
			auto padding = config["split paddingElem"].to!int;
			foreach(i, c; children){
				c.move(pos.a + (mode==horizontal ? [offset, 0].a : [0, offset].a));
				c.resize(mode==horizontal ? [cast(int)sizes[i], size.h] : [size.w, cast(int)sizes[i]]);
				offset += cast(int)sizes[i]+padding;
				if(i != children.length-1)
					separators[i].moveResize(c.pos.a+[c.size.w,0], [padding, c.size.h]);
			}
			redraw = true;
		}
	}

	Client next(){
		if(!children.length)
			return null;
		if(clientActive < 0)
			clientActive = 0;
		if(clientActive >= children.length)
			clientActive = children.length-1;
		Client n = children[clientActive].to!Tabs.next;
		if(!n && clientActive < children.length-1)
			n = children[clientActive+1].to!Tabs.active;
		return n;
	}

	Client prev(){
		if(!children.length)
			return null;
		if(clientActive < 0)
			clientActive = 0;
		if(clientActive >= children.length)
			clientActive = children.length-1;
		Client n = children[clientActive].to!Tabs.prev;
		if(!n && clientActive > 0)
			n = children[clientActive-1].to!Tabs.active;
		return n;
	}

	void focusDir(int dir){
		auto client = dir == 0 ? active : (dir > 0 ? next : prev);
		if(client){
			with(Log("split.focusDir %s client=%s".format(dir, client))){
				client.focus;
			}
		}
	}

	void focusTabs(int dir){
		if(clientActive+dir >= 0 && clientActive+dir < children.length){
			children[clientActive+dir].to!Tabs.active.focus;
		}
	}

	@property
	override Client active(){
		if(clientActive >= 0 && clientActive < children.length)
			return children[clientActive].to!Container.active;
		return null;
	}

	@property
	override void active(Client client){
		foreach(i, c; children.map!(a=>a.to!Container).array){
			if(c.children.canFind(client)){
				clientActive = cast(int)i;
				c.active = client;
			}
		}
	}

}
