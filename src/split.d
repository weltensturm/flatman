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


class Split: Container {

	enum {
		horizontal,
		vertical
	}

	int mode;
	int padding;
	Window window;

	long[] sizes;
	
	this(int[2] pos, int[2] size, int mode=horizontal){
		hidden = true;
		this.mode = mode;
		padding = config["split paddingElem"].to!int;

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
		if(clients.length)
			XMapWindow(dpy, window);
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
		"split adding %s".format((cast(Client)client).name).log;
		Tabs tab;
		if(children.length && (cast(Tabs)children[clientActive]).insertTab){
			tab = cast(Tabs)children[clientActive];
		}else{
			tab = new Tabs;
			tab.parent = this;
			if(clientActive < children.length){
				children = children[0..clientActive+1] ~ tab ~ children[clientActive+1..$];
				sizes = sizes[0..clientActive+1] ~ client.size.w ~ sizes[clientActive+1..$];
			}else{
				children ~= tab;
				sizes ~= client.size.w;
			}
			tab.show;
		}
		tab.add(client);
		rebuild;
	}

	alias remove = Base.remove;

	override void onDraw(){
		draw.setColor(config.color("split background"));
		draw.rect(pos, size);
		draw.finishFrame;
		super.onDraw;
	}

	override void remove(Client client){
		"split removing %s".format((cast(Client)client).name).log;
		foreach(i, c; children){
			if(c.children.canFind(client)){
				c.remove(client);
				if(!c.children.length){
					c.hide;
					remove(c);
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
		if(children.length){
			XMapWindow(dpy, window);
			XLowerWindow(dpy, window);
		}else
			XUnmapWindow(dpy, window);
		normalize;
		int offset = 0;
		foreach(i, c; children){
			c.move(pos.a + (mode==horizontal ? [offset, 0].a : [0, offset].a));
			c.resize(mode==horizontal ? [cast(int)sizes[i], size.h] : [size.w, cast(int)sizes[i]]);
			offset += cast(int)sizes[i]+padding;
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
