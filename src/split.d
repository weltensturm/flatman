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
	int paddingElem;
	int paddingOuter;
	int border;
	int titleHeight;

	class DragInfo {
		size_t sizeIdx;
		long sizeLeft;
		long sizeRight;
		int dragStart;
	}

	DragInfo dragInfo;
	long dragWindow = -1;

	Window window;

	long[] sizes;

	this(int[2] pos, int[2] size, int mode=horizontal){
		move(pos);
		resize(size);
		this.mode = mode;
		titleHeight = cast(int)(config["split title height"].to!double*bh).lround;
		border = config["split border"].to!int;
		paddingElem = config["split paddingElem"].to!int;
		paddingOuter = config["split paddingOuter"].to!int;
		XSetWindowAttributes wa;
		wa.override_redirect = true;
		wa.background_pixmap = ParentRelative;
		wa.event_mask = PointerMotionMask|ButtonPressMask|ButtonReleaseMask|ExposureMask;
		window = XCreateWindow(
				dpy, root, pos.x, pos.y, size.w, size.h,
				0, DefaultDepth(dpy, screen), CopyFromParent,
				DefaultVisual(dpy, screen),
				CWOverrideRedirect|CWBackPixmap|CWEventMask, &wa
		);
		XDefineCursor(dpy, window, flatman.cursor[CurMove].cursor);
		//XMapRaised(dpy, window);
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

	void toggleTitles(){
		if(clientActive >= sizes.length || clientActive < 0)
			return;
		if(!titleHeight)
			titleHeight = bh;
		else
			titleHeight = 0;
		rebuild;
	}

	void focusDir(int dir){
		if(!children.length)
			return;
		auto i = clientActive+dir;
		if(i < 0)
			i = cast(int)children.length-1;
		if(i >= children.length)
			i = 0;
		focus(children[i]);
	}

	void moveDir(int dir){
		if(children.length < 2 || clientActive+dir >= children.length || clientActive+dir < 0)
			return;
		auto active = active;
		children[clientActive] = children[clientActive+dir];
		children[clientActive+dir] = active;
		auto size = sizes[clientActive];
		sizes[clientActive] = sizes[clientActive+dir];
		sizes[clientActive+dir] = size;
		clientActive += dir;
		rebuild;
	}

	override void onShow(){
		foreach(c; children)
			c.show;
		rebuild;
	}

	void onButton(XButtonPressedEvent* ev){
		if(ev.button == Mouse.buttonLeft){
			foreach(i, c; children){
				if(i+1 < children.length && ev.x > c.pos.x+c.size.w && ev.x < children[i+1].pos.x){
					dragInfo = new DragInfo;
					dragInfo.sizeIdx = i;
					dragInfo.sizeLeft = sizes[i];
					dragInfo.sizeRight = sizes[i+1];
					dragInfo.dragStart = ev.x;
					return;
				}else{
					if(ev.x > c.pos.x && ev.x < c.pos.x+c.size.w){
						dragWindow = i;
					}
				}
			}
		}else if(ev.button == Mouse.buttonMiddle){
			foreach(i, c; children){
				if(ev.x > c.pos.x && ev.x < c.pos.x+c.size.w){
					focus(cast(Client)c);
					killclient;
				}
			}
		}
	}

	void onButtonRelease(XButtonReleasedEvent* ev){
		if(ev.button == Mouse.buttonLeft){
			dragInfo = null;
			dragWindow = -1;
		}
	}

	Time lasttime;
	void onMotion(XMotionEvent* ev){
		if(dragInfo){
			if((ev.time - lasttime) <= (1000 / 60))
				return;
			lasttime = ev.time;
			sizes[dragInfo.sizeIdx] = dragInfo.sizeLeft + ev.x - dragInfo.dragStart;
			sizes[dragInfo.sizeIdx+1] = dragInfo.sizeRight - ev.x + dragInfo.dragStart;
			rebuild;
		}
		if(dragWindow >= 0){
			auto c = children[dragWindow];
			if(ev.x > c.pos.x+c.size.w && dragWindow+1 < children.length){
				auto cn = children[dragWindow+1];
				if(ev.x > c.pos.x+paddingElem+cn.size.w){
					clientActive = dragWindow;
					moveDir(1);
					dragWindow++;
				}
			}else if(ev.x < children[dragWindow].pos.x && dragWindow > 0){
				auto cp = children[dragWindow-1];
				if(ev.x < cp.pos.x+c.size.w){
					clientActive = dragWindow;
					moveDir(-1);
					dragWindow--;
				}
			}
		}
	}

	override void onHide(){
		foreach(c; children)
			c.hide;
		XUnmapWindow(dpy, window);
	}

	override Base add(Base client){
		assert(!client.parent);
		assert(!flatman.clients.canFind(client));
		"split adding %s".format((cast(Client)client).name).log;
		client.parent = this;
		client.hidden = false;
		if(clientActive < children.length){
			children = children[0..clientActive+1] ~ client ~ children[clientActive+1..$];
			sizes = sizes[0..clientActive+1] ~ client.size.w ~ sizes[clientActive+1..$];
		}else{
			children ~= client;
			sizes ~= client.size.w;
		}
		sizes.to!string.log;
		rebuild;
		if(hidden)
			client.hide;
		return client;
	}

	override void remove(Base client){
		"split removing %s".format((cast(Client)client).name).log;
		auto i = children.countUntil(client);
		if(i < 0)
			return;
		super.remove(client);
		sizes = sizes[0..i] ~ sizes[i+1..$];
		sizes.to!string.log;
		rebuild;
	}

	override void move(int[2] pos){
		super.move(pos);
		rebuild;
	}

	override void resize(int[2] size){
		super.resize(size);
		rebuild;
	}

	void normalize(){
		assert(sizes.length == children.length);
		double max = size.w-paddingOuter*2-paddingElem*(children.length-1);
		double cur = sizes.sum;
		foreach(ref s; sizes)
			s = (s*max/cur).lround;
		foreach(i, ref s; sizes)
			s = s.max(10, (cast(Client)children[i]).minw);
		cur = sizes.sum;
		foreach(ref s; sizes)
			s = (s*max/cur).lround;
	}

	void rebuild(){
		if(children.length && !hidden){
			XMapWindow(dpy, window);
		}else{
			XUnmapWindow(dpy, window);
			return;
		}
		normalize;
		XMoveWindow(dpy, window, pos.x, pos.y);
		XResizeWindow(dpy, window, size.w, size.h);
		int offset = paddingOuter;
		foreach(i, client; children){
			(cast(Client)client).moveResize([
					(mode==horizontal ? offset : paddingOuter) + pos.x,
					(mode==vertical ? offset : paddingOuter) + pos.y + titleHeight
			],
			[
					mode==horizontal ? cast(int)sizes[i] : size.w-paddingOuter*2,
					(mode==vertical ? cast(int)sizes[i] : size.h-paddingOuter*2) - titleHeight
			]);
			offset += cast(int)sizes[i]+paddingElem;
		}
		onDraw;
	}

	override void onDraw(){
		draw.setColor("#"~config["split background"]);
		draw.rect(0, 0, size.w, size.h);
		foreach(c; children){
			auto client = cast(Client)c;
			auto act = (client == monitor.active ? "active" : "normal");
			draw.setColor("#"~config["split border " ~ act]);
			draw.rect(
					client.pos.x-pos.x-border,
					client.pos.y-pos.y-border,
					client.size.w+border+1,
					client.size.h+border+1
			);
			if(titleHeight){
				auto w = cast(int)draw.width(client.name)+border+1;
				draw.clip(client.pos.a-pos-[border,border+titleHeight], [w, bh]);
				draw.rect(
						client.pos.x-pos.x-border,
						client.pos.y-pos.y-border-titleHeight,
						w,
						bh
				);
				draw.setColor("#"~config["split title " ~ act]);
				draw.text(client.name, [c.pos.x-pos.x+border+1, c.pos.y-pos.y-titleHeight]);
				draw.noclip;
			}
		}
		draw.map(window, 0, 0, size.w, size.h);
	}

	void destroy(){
		foreach(c; children)
			unmanage(cast(Client)c, false);
		XUnmapWindow(dpy, window);
		XDestroyWindow(dpy, window);
	}

}
