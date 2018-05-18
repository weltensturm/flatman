module flatman.x.atoms;


import flatman;


__gshared:


Atom[string] atoms;

string[Atom] names;


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
