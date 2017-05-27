module common.atoms;

import
		std.traits,
		std.stdio,
		std.string,
		x11.Xlib,
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
			static Atom atom;
			static Atom get(){
				if(!atom)
					atom = XInternAtom(getDisplay ? getDisplay() : wm.displayHandle, name.toStringz, false);
				return atom;
			}
		}
		return Tmp.get;
	}

}
