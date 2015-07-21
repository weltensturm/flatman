module flatman.split;

import flatman;


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
	int paddingElem = 0;
	int paddingOuter = 0;
	int border = 2;
	int titleHeight;

	class DragInfo {
		size_t sizeIdx;
		long sizeLeft;
		long sizeRight;
		int dragStart;
	}

	DragInfo dragInfo;

	Window window;

	long[] sizes;

	this(int[2] pos, int[2] size, int mode=horizontal){
		move(pos);
		resize(size);
		this.mode = mode;
		titleHeight = bh;
		paddingElem = bh/2;
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
		sizes[clientActive] += 25;
		rebuild;
	}

	void sizeDec(){
		sizes[clientActive] -= 25;
		rebuild;
	}

	void toggleTitles(){
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
		rebuild;
		focus(active);
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
				}
			}
		}
	}

	void onButtonRelease(XButtonReleasedEvent* ev){
		if(ev.button == Mouse.buttonLeft){
			dragInfo = null;
		}
	}

	void onMotion(XMotionEvent* ev){
		if(dragInfo){
			sizes[dragInfo.sizeIdx] = dragInfo.sizeLeft + ev.x - dragInfo.dragStart;
			sizes[dragInfo.sizeIdx+1] = dragInfo.sizeRight - ev.x + dragInfo.dragStart;
			rebuild;
		}
	}

	override void onHide(){
		foreach(c; children)
			XMoveWindow(dpy, (cast(Client)c).win, size.w+pos.x, 0);
		XUnmapWindow(dpy, window);
	}

	override Base add(Base client){
		super.add(client);
		sizes ~= client.size.w;
		rebuild;
		return client;
	}

	override void remove(Base client){
		auto i = children.countUntil(client);
		if(i < 0)
			return;
		sizes = sizes[0..i] ~ sizes[i+1..$];
		foreach(ref s; sizes)
			s = cast(int)(s*(sizes.length+1.0)/sizes.length);
		super.remove(client);
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
		double max = size.w-paddingOuter*2-paddingElem*(children.length-1);
		double cur = sizes.sum;
		foreach(ref s; sizes){
			s = (s*max/cur).lround;
		}
	}

	void rebuild(){
		if(children.length){
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
				],[
					mode==horizontal ? cast(int)sizes[i] : size.w-paddingOuter*2,
					(mode==vertical ? cast(int)sizes[i] : size.h-paddingOuter*2) - titleHeight
			]);
			offset += cast(int)sizes[i]+paddingElem;
		}
		onDraw;
	}

	override void onDraw(){
		draw.setColor(normbgcolor);
		draw.rect(0, 0, size.w, size.h);
		auto client = active;
		if(client && client == monitorActive.active){
			draw.setColor(selbgcolor);
			draw.rect(
					client.pos.x-pos.x-border,
					client.pos.y-pos.y-border,
					client.size.w+border+1,
					client.size.h+border+1
			);
			draw.rect(
					client.pos.x-pos.x-border,
					client.pos.y-pos.y-border-titleHeight,
					cast(int)draw.width(client.name)+border+1,
					client.size.h+border+1
			);
		}
		if(titleHeight){
			draw.setColor(selfgcolor);
			foreach(c; children){
				draw.text((cast(Client)c).name, [c.pos.x-pos.x-1, c.pos.y-pos.y-titleHeight]);
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
