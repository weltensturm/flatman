module flatman.draw;

import flatman;

__gshared:


enum DRW_FONT_CACHE_SIZE = 32;

auto BETWEEN(T)(T x, T min, T max){
	return x > min && x < max;
}

class Clr {

	ulong pix;
	XftColor rgb;

	this(string name){
		Colormap cmap = DefaultColormap(dpy, screen);
		Visual* vis = DefaultVisual(dpy, screen);
		if(!XftColorAllocName(dpy, vis, cmap, name.toStringz, &rgb))
			throw new Exception("Cannot allocate color " ~ name);
		pix = rgb.pixel;
	}

}

class Cur {
	Cursor cursor;
	this(int shape){
		cursor = XCreateFontCursor(dpy, shape);
	}
	void destroy(){
		XFreeCursor(dpy, cursor);
	}
}

struct ClrScheme {
	Clr* fg;
	Clr* bg;
	Clr* border;
}

struct Extnts {
	uint w;
	uint h;
}
