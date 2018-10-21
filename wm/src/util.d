module flatman.util;


import flatman;


void notify(string message){
	Log.info(message);
	["notify-send", "-a", "flatman", message].spawnProcess;
}


Client find(Window w){
	foreach(c; clients)
		if(c.win == w || c.orig == w)
			return c;
	return null;
}

Client active(){
	return monitor.active;
}

Client[] globals(){
	return monitors.fold!((a, b) => a ~ b.globals)(cast(Client[])[]).array;
}

Client[] clients(){
	return monitors.map!(a => a.clients).fold!((a, b) => a ~ b);
}

Client[] clientsVisible(){
	return monitors.map!(a => a.clientsVisible).fold!((a, b) => a ~ b);
}

Monitor findMonitor(int[2] pos, int[2] size=[1,1]){
	Monitor result = monitor;
	int a, area = 0;
	foreach(monitor; monitors)
		if((a = intersectArea(pos.x, pos.y, size.w, size.h, monitor)) > area){
			area = a;
			result = monitor;
		}
	return result;
}

Monitor findMonitor(Window w){
	int x, y;
	if(w == root && getrootptr(&x, &y))
		return findMonitor([x, y]);
	return findMonitor(find(w));
}

Monitor findMonitor(Client w){
	foreach(m; monitors){
		if(m.clients.canFind(w))
			return m;
	}
	return null;
}


auto intersectArea(T, M)(T x, T y, T w, T h, M m){
	return (max(0, min(x+w,m.pos.x+m.size.w) - max(x,m.pos.x))
    	* max(0, min(y+h,m.pos.y+m.size.h) - max(y,m.pos.y)));
}

T cleanMask(T)(T mask){
	return mask & ~(numlockmask|LockMask) & (ShiftMask|ControlMask|Mod1Mask|Mod2Mask|Mod3Mask|Mod4Mask|Mod5Mask);
}

auto width(T)(T x){
	return x.size.w + 2 * x.bw;
}

auto height(T)(T x){
	return x.size.h + 2 * x.bw;
}


bool getrootptr(int *x, int *y){
	int di;
	uint dui;
	Window dummy;
	return 1 == XQueryPointer(dpy, root, &dummy, &dummy, x, y, &di, &di, &dui);
}
