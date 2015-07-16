module dwm.monitor;

import dwm;

struct Monitor {
	string ltsymbol;
	float mfact;
	int nmaster;
	int num;
	int by;               /* bar geometry */
	int mx, my, mw, mh;   /* screen size */
	int wx, wy, ww, wh;   /* window area  */
	uint seltags;
	uint sellt;
	uint[2] tagset;
	bool showbar;
	bool topbar;
	Client clients;
	Client clientActive;
	Client stack;
	Monitor* next;
	Window barwin;
	const(Layout)*[2] lt;
};


Monitor* createmon(){
	auto m = new Monitor;
	m.tagset[0] = m.tagset[1] = 1;
	m.mfact = mfact;
	m.nmaster = nmaster;
	m.showbar = showbar;
	m.topbar = topbar;
	m.lt[0] = &layouts[0];
	m.lt[1] = &layouts[1 % layouts.length];
	m.ltsymbol = layouts[0].symbol;
	return m;
}


void arrange(Monitor *m){
	if(m)
		showhide(m.stack);
	else for(m = monitors; m; m = m.next)
		showhide(m.stack);
	if(m){
		arrangemon(m);
		restack(m);
	} else for(m = monitors; m; m = m.next)
		arrangemon(m);
}

void arrangemon(Monitor* m){
	m.ltsymbol = m.lt[m.sellt].symbol;
	if(m.lt[m.sellt].arrange)
		m.lt[m.sellt].arrange(m);
}

void cleanup(Monitor* mon){
	Monitor *m;

	if(mon == monitors)
		monitors = monitors.next;
	else {
		for(m = monitors; m && m.next != mon; m = m.next){}
		m.next = mon.next;
	}
	XUnmapWindow(dpy, mon.barwin);
	XDestroyWindow(dpy, mon.barwin);
}

void drawbar(Monitor* m){
	int x, xx, w;
	uint i, occ = 0, urg = 0;
	Client c;

	for(c = m.clients; c; c = c.next){
		occ |= c.tags;
		if(c.isurgent)
			urg |= c.tags;
	}
	x = 0;
	for(i = 0; i < tags.length; i++){
		w = TEXTW(tags[i]);
		drw_setscheme(draw, m.tagset[m.seltags] & 1 << i ? &scheme[SchemeSel] : &scheme[SchemeNorm]);
		drw_text(draw, x, 0, w, bh, tags[i].toStringz, urg & 1 << i);
		drw_rect(draw, x, 0, w, bh, m == monitorActive && monitorActive.clientActive && monitorActive.clientActive.tags & 1 << i,
		           occ & 1 << i, urg & 1 << i);
		x += w;
	}
	w = blw = TEXTW(m.ltsymbol);
	drw_setscheme(draw, &scheme[SchemeNorm]);
	drw_text(draw, x, 0, w, bh, m.ltsymbol.toStringz, 0);
	x += w;
	xx = x;
	if(m == monitorActive){ /* status is only drawn on selected monitor */
		w = TEXTW(statusText);
		x = m.ww - w;
		if(x < xx){
			x = xx;
			w = m.ww - xx;
		}
		drw_text(draw, x, 0, w, bh, statusText.toStringz, 0);
	}else
		x = m.ww;
	if((w = x - xx) > bh){
		x = xx;
		if(m.clientActive){
			drw_setscheme(draw, m == monitorActive ? &scheme[SchemeSel] : &scheme[SchemeNorm]);
			drw_text(draw, x, 0, w, bh, m.clientActive.name.toStringz, 0);
			drw_rect(draw, x, 0, w, bh, m.clientActive.isfixed, m.clientActive.isfloating, 0);
		}
		else {
			drw_setscheme(draw, &scheme[SchemeNorm]);
			drw_text(draw, x, 0, w, bh, null, 0);
		}
	}
	drw_map(draw, m.barwin, 0, 0, m.ww, bh);
}

void monocle(Monitor* m){
	uint n = 0;
	Client c;
	for(c = m.clients; c; c = c.next)
		if(isVisible(c))
			n++;
	if(n > 0) /* override layout symbol */
		m.ltsymbol = "[%s]".format(n);
	for(c = nexttiled(m.clients); c; c = nexttiled(c.next))
		c.resize(m.wx, m.wy, m.ww - 2 * c.bw, m.wh - 2 * c.bw, false);
}

void restack(Monitor* m){
	Client c;
	XEvent ev;
	XWindowChanges wc;

	drawbar(m);
	if(!m.clientActive)
		return;
	if(m.clientActive.isfloating || !m.lt[m.sellt].arrange)
		XRaiseWindow(dpy, m.clientActive.win);
	if(m.lt[m.sellt].arrange){
		wc.stack_mode = Below;
		wc.sibling = m.barwin;
		for(c = m.stack; c; c = c.snext)
			if(!c.isfloating && isVisible(c)){
				XConfigureWindow(dpy, c.win, CWSibling|CWStackMode, &wc);
				wc.sibling = c.win;
			}
	}
	XSync(dpy, false);
	while(XCheckMaskEvent(dpy, EnterWindowMask, &ev)){}
}

void tile(Monitor* m){
	uint i, n, h, mw, my, ty;
	Client c;

	for(n = 0, c = nexttiled(m.clients); c; c = nexttiled(c.next), n++){}
	if(n == 0)
		return;

	if(n > m.nmaster)
		mw = cast(uint)(m.nmaster ? m.ww * m.mfact : 0);
	else
		mw = m.ww;
	for(i = my = ty = 0, c = nexttiled(m.clients); c; c = nexttiled(c.next), i++)
		if(i < m.nmaster){
			h = (m.wh - my) / (min(n, m.nmaster) - i);
			c.resize(m.wx, m.wy + my, mw - (2*c.bw), h - (2*c.bw), false);
			my += height(c);
		}
		else {
			h = (m.wh - ty) / (n - i);
			c.resize(m.wx + mw, m.wy + ty, m.ww - mw - (2*c.bw), h - (2*c.bw), false);
			ty += height(c);
		}
}

void updatebarpos(Monitor *m){
	m.wy = m.my;
	m.wh = m.mh;
	if(m.showbar){
		m.wh -= bh;
		m.by = m.topbar ? m.wy : m.wy + m.wh;
		m.wy = m.topbar ? m.wy + bh : m.wy;
	}
	else
		m.by = -bh;
}
