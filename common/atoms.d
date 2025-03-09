module common.atoms;

import
	std.traits,
	std.stdio,
	std.string,
	ws.bindings.xlib,
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
		alias AtomType = WindowHandle;
	static if(Format == XA_STRING)
		alias AtomType = string;

}


auto getprop(int T)(WindowHandle window, Atom atom){
	auto raw = _rawget(window, atom, T);
	auto data = *(cast(AtomType!T*)raw);
	XFree(raw);
	return data;
}


long getprop(T: long)(WindowHandle window, Atom atom){
	auto p = _rawget(window, atom, cast(int)XA_CARDINAL);
	auto d = *(cast(long*)p);
	XFree(p);
	return d;
}


ubyte* _rawget(WindowHandle window, Atom atom, int type, ulong count=1){
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
