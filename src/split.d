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

	Window window;

	long[] separators;

	this(int[2] pos, int[2] size, int mode=horizontal){
		super(pos, size);
		this.mode = mode;
		titleHeight = bh;
		paddingElem = bh/2;
		XSetWindowAttributes wa;
		wa.override_redirect = true;
		wa.background_pixmap = ParentRelative;
		wa.event_mask = ButtonPressMask|ExposureMask;
		window = XCreateWindow(
				dpy, root, pos.x, pos.y, size.w, size.h,
				0, DefaultDepth(dpy, screen), CopyFromParent,
				DefaultVisual(dpy, screen),
				CWOverrideRedirect|CWBackPixmap|CWEventMask, &wa
		);
		XDefineCursor(dpy, window, cursor[CurMove].cursor);
		//XMapRaised(dpy, window);
	}

	void sizeInc(){
		foreach(i, ref s; separators[0..$-1]){
			if(i < clientActive)
				s -= 10;
			else
				s += 10;
		}
		rebuild;
	}

	void sizeDec(){
		foreach(i, ref s; separators[0..$-1]){
			if(i < clientActive)
				s += 10;
			else
				s -= 10;
		}
		rebuild;
	}

	void toggleTitles(){
		if(!titleHeight)
			titleHeight = bh;
		else
			titleHeight = 0;
		rebuild;
	}

	override void focus(Client c){
		super.focus(c);
	}

	void focus(int dir){
		if(!clients.length)
			return;
		auto i = clientActive+dir;
		if(i < 0)
			i = cast(int)clients.length-1;
		if(i >= clients.length)
			i = 0;
		focus(clients[i]);
	}

	override void activate(){
		rebuild;
		focus(0);
	}

	override void deactivate(){
		foreach(c; clients)
			XMoveWindow(dpy, c.win, size.w+pos.x, 0);
		XUnmapWindow(dpy, window);
	}

	override void add(Client client){
		super.add(client);
		foreach(ref s; separators)
			s = cast(int)(s*separators.length/(separators.length+1.0));
		separators ~= size.w-paddingOuter+paddingElem;
		rebuild;
	}

	override void remove(Client client){
		auto idx = clients.countUntil(client);
		if(idx < 0)
			return;
		separators = separators[0..idx] ~ separators[idx+1..$];
		foreach(ref s; separators)
			s = cast(int)(s*(separators.length+1.0)/separators.length);
		if(separators.length)
			separators[$-1] = size.w-paddingOuter+paddingElem;
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

	void rebuild(){
		if(clients.length){
			XMapWindow(dpy, window);
		}else{
			XUnmapWindow(dpy, window);
			return;
		}
		XMoveWindow(dpy, window, pos.x, pos.y);
		int offset = 0;
		foreach(i, client; clients){
			client.resize([
					(mode==horizontal ? offset : 0) + pos.x + paddingOuter,
					(mode==vertical ? offset : 0) + pos.y + titleHeight + paddingOuter
				],[
					mode==horizontal ? cast(int)separators[i]-offset-paddingElem : this.size.w-paddingOuter*2,
					(mode==vertical ? cast(int)separators[i]-offset-paddingElem : this.size.h-paddingOuter*2) - titleHeight
				], false);
			offset = cast(int)separators[i];
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
			foreach(c; clients){
				draw.text(c.name, [c.pos.x-pos.x-1, c.pos.y-pos.y-titleHeight]);
			}
		}
		draw.map(window, 0, 0, size.w, size.h);
	}

}
