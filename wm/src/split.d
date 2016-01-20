module flatman.split;

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


class Split: Container {

	enum {
		horizontal,
		vertical
	}

	int mode;
	Window window;

	long[] sizes;
	
	bool lock;

	this(int[2] pos, int[2] size, int mode=horizontal){
		hidden = true;
		this.mode = mode;

		XSetWindowAttributes wa;
		wa.override_redirect = true;
		wa.background_pixmap = ParentRelative;
		window = XCreateWindow(
				dpy, flatman.root, pos.x, pos.y, size.w, size.h,
				0, DefaultDepth(dpy, screen), CopyFromParent,
				DefaultVisual(dpy, screen),
				CWOverrideRedirect|CWBackPixmap|CWEventMask, &wa
		);
		XDefineCursor(dpy, window, flatman.cursor[CurMove].cursor);
		_draw = new XDraw(dpy, DefaultScreen(dpy), window, size.w, size.h);
		window.register([
			Expose: (XEvent* e)=>onDraw()
		]);

		move(pos);
		resize(size);
	}

	void destroy(){
		customHandler[window] = customHandler[window].init;
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
		//if(clients.length)
		//	XMapWindow(dpy, window);
		"split show".log;
		hidden = false;
		foreach(c; children)
			c.show;
		rebuild;
	}

	override void hide(){
		if(hidden)
			return;
		XUnmapWindow(dpy, window);
		hidden = true;
		foreach(c; children)
			c.hide;
		"hide split".log;
	}

	alias add = Base.add;

	override void add(Client client){
		add(client, long.max);
	}

	void add(Client client, long position=long.max){
		XSync(dpy, false);
		if(position == long.max)
			position = clientActive;
		"split adding %s at %s".format(client.to!Client.name, position).log;
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
			if(!hidden)
				tab.show;
		}
		tab.add(client);
		rebuild;
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
				flatman.focus(client);
			}
		}
		lock = false;
		rebuild;
	}

	override void onDraw(){
		draw.setColor(config.color("split background"));
		draw.rect(pos, size);
		draw.finishFrame;
		super.onDraw;
	}

	override void remove(Base base){
		Base.remove(base);
		rebuild;
	}

	override void remove(Client client){
		"split removing %s".format(client.name).log;
		foreach(i, container; children.to!(Tabs[])){
			if(container.children.canFind(client)){
				container.remove(client);
				if(!container.children.length){
					container.destroy;
					remove(container);
					sizes = sizes[0..i] ~ sizes[i+1..$];
					if(clientActive >= children.length)
						clientActive = cast(int)children.length-1;
					rebuild;
					return;
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
		"split resize %s".format(size).log;
		if(size.w < 0 || size.h < 0)
			throw new Exception("workspace size invalid");
		super.resize(size);
		if(draw)
			draw.resize(size);
		XResizeWindow(dpy, window, size.w, size.h);
		rebuild;
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
		"split normalized %s".format(sizes).log;
	}

	void rebuild(){
		if(lock)
			return;
		if(children.length && !hidden){
			//XMapWindow(dpy, window);
			//XLowerWindow(dpy, window);
		}else
			XUnmapWindow(dpy, window);
		normalize;
		int offset = 0;
		foreach(i, c; children){
			c.move(pos.a + (mode==horizontal ? [offset, 0].a : [0, offset].a));
			XSync(dpy, false);
			c.resize(mode==horizontal ? [cast(int)sizes[i], size.h] : [size.w, cast(int)sizes[i]]);
			offset += cast(int)sizes[i]+config["split paddingElem"].to!long;
		}
		onDraw;
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
			"focus dir %s client %s".format(dir, client.name).log;
			flatman.focus(client);
		}
	}

	void focusTabs(int dir){
		if(clientActive+dir >= 0 && clientActive+dir < children.length){
			focus(children[clientActive+dir].to!Tabs.active);
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
