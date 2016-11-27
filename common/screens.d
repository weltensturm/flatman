module common.screens;

import
	x11.Xlib,
	x11.extensions.Xinerama;

struct Screen {
	int x, y, w, h;
}

Screen[int] screens(Display* dpy){
	int count;
	auto screenInfo = XineramaQueryScreens(dpy, &count);
	Screen[int] res;
	foreach(screen; screenInfo[0..count])
		res[screen.screen_number] = Screen(screen.x_org, screen.y_org, screen.width, screen.height);
	XFree(screenInfo);
	return res;
}
