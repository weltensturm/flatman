module common.screens;

import
	std.algorithm,
	x11.Xlib,
	x11.extensions.Xinerama,
	ws.math;

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


auto intersectArea(int[2] pos1, int[2] size1, int[2] pos2, int[2] size2){
	return (max(0, min(pos1.x+size1.w, pos2.x+size2.w) - max(pos1.x, pos2.x))
    	  * max(0, min(pos1.y+size1.h, pos2.y+size2.h) - max(pos1.y, pos2.y)));	
}


int findScreen(Screen[int] screens, int[2] pos, int[2] size=[1,1]){
	int result = 0;
	int a, area = -1;
	foreach(i, screen; screens)
		if((a = intersectArea(pos, size, [screen.x, screen.y], [screen.w, screen.h])) > area){
			area = a;
			result = i;
		}
	return result;
}
