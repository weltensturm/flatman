module common.atoms;

import
		std.traits,
		std.stdio,
		std.string,
		x11.Xlib,
		x11.Xutil,
		x11.Xproto,
		x11.Xatom,
		x11.X,
		ws.wm;

static Display* delegate() getDisplay;

void fillAtoms(T)(ref T data){
	foreach(n; FieldNameTuple!T){
		mixin("data." ~ n ~ " = XInternAtom(getDisplay ? getDisplay() : wm.displayHandle, \"" ~ n ~ "\", false);");
	}
}


class Atoms {

	static Atom opDispatch(string name)(){
		struct Tmp {
			__gshared Atom atom;
			static Atom get(){
				if(!atom)
					atom = XInternAtom(getDisplay ? getDisplay() : wm.displayHandle, name.toStringz, false);
				return atom;
			}
		}
		return Tmp.get;
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


auto getprop(int T)(x11.X.Window window, Atom atom){
	auto raw = _rawget(window, atom, T);
	auto data = *(cast(AtomType!T*)raw);
	XFree(raw);
	return data;
}


long getprop(T: long)(x11.X.Window window, Atom atom){
	auto p = _rawget(window, atom, XA_CARDINAL);
	auto d = *(cast(long*)p);
	XFree(p);
	return d;
}


ubyte* _rawget(x11.X.Window window, Atom atom, int type, ulong count=1){
	int di;
	ulong dl;
	ubyte* p;
	Atom da;
	if(XGetWindowProperty(getDisplay ? getDisplay() : wm.displayHandle, window, atom, 0L, count, false, type,
	                      &da, &di, &count, &dl, &p) == 0 && p){
		return p;
	}
	throw new Exception("no data");
}
