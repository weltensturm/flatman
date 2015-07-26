module flatman.frame;

import flatman;

__gshared:


class Frame {

	Window window;
	Client client;
	int titleHeight;
	int[2] pos;
	int[2] size;

	this(Client client){
		this.client = client;
		size = [client.size.w+2, client.size.h+titleHeight+2];
		pos = [client.pos.x-1, client.pos.y-1];
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
		XReparentWindow(dpy, client.win, window, client.pos.x-pos.x, client.pos.y-pos.y);
		XMapRaised(dpy, window);
	}

	void onDraw(){
		draw.setColor(normbgcolor);
		draw.rect(client.pos.x-1, client.pos.y-1, client.size.w+2, client.size.h+2);
		draw.map(window, pos.x, pos.y, size.w, size.h);
	}

}
