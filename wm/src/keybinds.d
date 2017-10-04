module flatman.keybinds;

import flatman;

__gshared:


enum MODKEY = Mod1Mask;

struct Button {
	uint mask;
	uint button;
	void function() func;
}

struct Key {
	uint mod;
	KeySym keysym;
	void delegate(bool) func;
}

Key[] keys;
Button[] buttons;
int mod;

void updatenumlockmask(){
	uint i, j;
	XModifierKeymap *modmap;
	numlockmask = 0;
	modmap = XGetModifierMapping(dpy);
	for(i = 0; i < 8; i++)
		for(j = 0; j < modmap.max_keypermod; j++)
			if(modmap.modifiermap[i * modmap.max_keypermod + j]
			   == XKeysymToKeycode(dpy, XK_Num_Lock))
				numlockmask = (1 << i);
	XFreeModifiermap(modmap);
}

void grabKey(Key key){
	auto modifiers = [ 0, LockMask, numlockmask, numlockmask|LockMask ];
	auto code = XKeysymToKeycode(dpy, key.keysym);
	foreach(mod; modifiers)
		XGrabKey(dpy, code, key.mod | mod, root, true, GrabModeAsync, GrabModeAsync);
}


void grabkeys(){
	updatenumlockmask();
	uint i, j;
	KeyCode code;
	XUngrabKey(dpy, AnyKey, AnyModifier, root);
	foreach(key; flatman.keys){
		grabKey(key);
	}
	//grabKey(Key(XK_Alt_L));
    //XGrabKeyboard(dpy, root, true, GrabModeAsync, GrabModeAsync, CurrentTime);
}


KeySym getKey(string name){
	auto ks = XStringToKeysym(cast(char*)name.toStringz);
	if(ks == NoSymbol)
		throw new Exception(`Could not find key "%s"`.format(name));
	return ks;
}

int getMask(string name){
	final switch(name){
		case "mod":
			return mod;
		case "alt":
			return Mod1Mask;
		case "super":
			return Mod4Mask;
		case "shift":
			return ShiftMask;
		case "ctrl":
			return ControlMask;
	}
}


void registerConfigKeys(){
	Log.info("Registering keys");
	assert(config.mod.length);
	mod = getMask(config.mod);
	Log.info("mod " ~ config.mod);
	assert(mod == Mod4Mask);
	foreach(key, action; config.keys){
		Key bind;
		auto split = action.split;
		bind.func = (pressed){
			call(pressed, split[0], split[1..$].array);
		};
		foreach(i, k; key.split("+")){
			if(i == key.count("+"))
				bind.keysym = getKey(k);
			else
				bind.mod |= getMask(k);
		}
		flatman.keys ~= bind;
	}

	//[XK_1, XK_2, XK_3, XK_4, XK_5, XK_6, XK_7, XK_8, XK_9, XK_0].each((size_t i, size_t k){
	//	flatman.keys ~= Key(MODKEY, k, {monitor.switchWorkspace(cast(int)i);});
	//	flatman.keys ~= Key(MODKEY|ShiftMask, k, {monitor.moveWorkspace(cast(int)i);});
	//});

	buttons = [
		Button(MODKEY, Button1, {mouseMove;} ),
		Button(MODKEY, Button2, {if(active) active.togglefloating;} ),
		Button(MODKEY, Button3, {mouseResize;} ),
	];

}

