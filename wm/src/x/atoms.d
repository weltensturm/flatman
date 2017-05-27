module flatman.x.atoms;


import flatman;


static Atom[string] atoms;

static string[Atom] names;

Atom atom(string n){
	if(n !in atoms)
		atoms[n] = XInternAtom(dpy, n.toStringz, false);
	return atoms[n];
}

string name(Atom atom){
	if(atom in names)
		return names[atom];
	auto data = XGetAtomName(dpy, atom);
	auto text = data.to!string;
	names[atom] = text;
	XFree(data);
	return text;
}

void fillAtoms(T)(ref T data){
	foreach(n; FieldNameTuple!T){
		mixin("data." ~ n ~ " = atom(__traits(getAttributes, data."~n~")[0]);");
	}
}

template AtomType(int Format){

	static if(Format == XA_CARDINAL || Format == XA_PIXMAP)
		alias AtomType = long;
	static if(Format == XA_ATOM)
		alias AtomType = Atom;
	static if(Format == XA_WINDOW)
		alias AtomType = x11.X.Window;
	static if(Format == XA_STRING)
		alias AtomType = string;

}


auto getprop(int T)(Window window, Atom atom){
	auto raw = _rawget(window, atom, T);
	auto data = *(cast(AtomType!T*)raw);
	XFree(raw);
	return data;
}

CARDINAL getprop(T: CARDINAL)(Window window, Atom atom){
	auto p = _rawget(window, atom, XA_CARDINAL);
	auto d = *(cast(CARDINAL*)p);
	XFree(p);
	return d;
}


ubyte* _rawget(Window window, Atom atom, int type, ulong count=1){
	int di;
	ulong dl;
	ubyte* p;
	Atom da;
	if(XGetWindowProperty(dpy, window, atom, 0L, count, false, type,
	                      &da, &di, &count, &dl, &p) == Success && p){
		return p;
	}
	throw new Exception("no data");
}
