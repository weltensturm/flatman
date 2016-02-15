module flatman.keybinds;

import flatman;

__gshared:


KeySym getKey(string name){
	auto ks = XStringToKeysym(cast(char*)name.toStringz);
	if(ks == NoSymbol)
		throw new Exception(`Could not find key "%s"`.format(name));
	return ks;
}

int getMask(string name){
	final switch(name){
		case "alt":
			return Mod1Mask;
		case "shift":
			return ShiftMask;
		case "ctrl":
			return ControlMask;
	}
}


void registerConfigKeys(){
	foreach(key, value; config.values){
		if(key.startsWith("keys ")){
			key = key.chompPrefix("keys ");
			Key bind;
			auto space = value.countUntil(" ");
			bind.func = {
				if(space >= 0)
					call(value[0..space], value[space+1..$].split(" ").array);
				else
					call(value);
			};
			foreach(i, k; key.split("+")){
				if(i == key.count("+"))
					bind.keysym = getKey(k);
				else
					bind.mod |= getMask(k);
			}
			flatman.keys ~= bind;
		}
	}

	//[XK_1, XK_2, XK_3, XK_4, XK_5, XK_6, XK_7, XK_8, XK_9, XK_0].each((size_t i, size_t k){
	//	flatman.keys ~= Key(MODKEY, k, {monitor.switchWorkspace(cast(int)i);});
	//	flatman.keys ~= Key(MODKEY|ShiftMask, k, {monitor.moveWorkspace(cast(int)i);});
	//});

	buttons = [
		Button(MODKEY, Button1, {mousemove;} ),
		Button(MODKEY, Button2, {if(active) active.togglefloating;} ),
		Button(MODKEY, Button3, {mouseresize;} ),
	];

}

