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


uint numlockmask;


class KeybindSystem {

	int mod;
	Key[] binds;
	Button[] buttons;

	this(){
		Events ~= this;
	}

	void destroy(){
		Events.forget(this);
	}

	void grab(){
		updatenumlockmask();
		uint i, j;
		KeyCode code;
		XUngrabKey(dpy, AnyKey, AnyModifier, root);
		foreach(key; binds){
			grabKey(key);
		}
		//grabKey(Key(XK_Alt_L));
		//XGrabKeyboard(dpy, root, true, GrabModeAsync, GrabModeAsync, CurrentTime);
	}

	private int getMask(string name){
		switch(name){
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
			default:
				throw new Exception("Unknown mask \"%s\"".format(name));
		}
	}

	@ConfigUpdate
	void onConfig(NestedConfig config){
		Key[] binds;
		if(!config.mod.length)
			throw new ConfigException("Modifier key is not set");
		mod = getMask(config.mod);
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
			binds ~= bind;
		}
		this.binds = binds;
		grab;

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

	@WindowKey
	void onKey(Window, bool pressed, int mask, Keyboard.key key){
		foreach(bind; binds){
			if(key == bind.keysym && (!pressed || cleanMask(bind.mod) == cleanMask(mask)) && bind.func){
				bind.func(pressed);
			}
		}
	}

	@KeyboardMapping
	void onMapping(XMappingEvent *ev){
		XRefreshKeyboardMapping(ev);
		if(ev.request == MappingKeyboard)
			grab();
	}


	@WindowMouseButton
	void onButton(Window window, bool _, int mask, Mouse.button button){
		if(auto c = find(window)){
			if(c.isFloating && !c.global)
				c.parent.to!Floating.raise(c);
			focus(c);
			foreach(bind; buttons)
				if(bind.button == button && cleanMask(bind.mask) == cleanMask(mask))
					bind.func();
		}
	}

}

T cleanMask(T)(T mask){
	return mask & ~(numlockmask|LockMask) & (ShiftMask|ControlMask|Mod1Mask|Mod2Mask|Mod3Mask|Mod4Mask|Mod5Mask);
}

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


KeySym getKey(string name){
	auto ks = XStringToKeysym(cast(char*)name.toStringz);
	if(ks == NoSymbol)
		throw new Exception(`Could not find key "%s"`.format(name));
	return ks;
}

