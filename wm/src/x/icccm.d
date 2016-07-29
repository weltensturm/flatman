module flatman.x.icccm;


import flatman;


struct WmAtoms {
	@("WM_PROTOCOLS") Atom protocols;
	@("WM_DELETE_WINDOW") Atom delete_;
	@("WM_STATE") Atom state;
	@("WM_HINTS") Atom hints;
	@("WM_TAKE_FOCUS") Atom takeFocus;
}

WmAtoms wm;
