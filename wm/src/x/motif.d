module flatman.x.motif;


import flatman;


struct MotifAtoms {
	@("_MOTIF_WM_HINTS") Atom hints;
}

MotifAtoms motif;


bool getIsDecorated(Window window){
	int di;
	ulong dl;
	ubyte* p;
	Atom da;
	long[] data;
	ulong count;
	if(XGetWindowProperty(
			dpy,
			window,
			motif.hints,
			0L,
			long.max,
			false,
			motif.hints,
			&da,
			&di,
			&count,
			&dl,
			&p) == Success && p){
		data = (cast(CARDINAL*)p)[0..count].dup;
		XFree(p);
	}
	return !data.length || !((data[0] & 2) && data[2] == 0);
}
