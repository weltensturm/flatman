module flatman.x.motif;


import flatman;


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
			Atoms._MOTIF_WM_HINTS,
			0L,
			long.max,
			false,
			Atoms._MOTIF_WM_HINTS,
			&da,
			&di,
			&count,
			&dl,
			&p) == Success && p){
		data = (cast(CARDINAL*)p)[0..count].dup;
		XFree(p);
	}
	writeln("ASDF ", data);
	return !data.length || !((data[0] & 2) && data[2] == 0);
}
