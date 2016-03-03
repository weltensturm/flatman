module flatman.config;

import flatman;

__gshared:


struct ConfigColor {

	float[3] color;
	alias color this;

	this(string text){
		color = [
			text[0..2].to!int(16)/255.0,
			text[2..4].to!int(16)/255.0,
			text[4..6].to!int(16)/255.0
		];
	}

}


struct WmConfig {

	void value(string name, string value){
		foreach(field; FieldNameTuple!WmConfig){
			string splitName;
			foreach(c; field){
				if(c.toUpper == c.to!dchar && c != '_')
					splitName ~= " " ~ c.toLower.to!string;
				else if(c == '_')
					splitName ~= "-";
				else
					splitName ~= c;
			}
			if(splitName == name){
				mixin("
					static if(is(typeof(" ~ field ~ ") == string[])){
						foreach(line; value.splitLines){
							if(line.strip.length)
								" ~ field ~ " ~= line;
						}
					}else{
						" ~ field ~ " = value.to!(typeof(" ~ field ~ "));
					}
				");
				return;
			}
		}
	}

	void loadBlock(string block, string namespace){
		Decode.text(block, (name, value, isBlock){
			if(isBlock && !isList(name))
				loadBlock(value, namespace ~ " " ~ name);
			else
				this.value((namespace ~ " " ~ name).strip, value.strip);
		});
	}

	bool isList(string name){
		foreach(field; FieldNameTuple!WmConfig){
			string splitName;
			foreach(c; field){
				if(c.toUpper == c.to!dchar && c != '_')
					splitName ~= " " ~ c.toLower.to!string;
				else if(c == '_')
					splitName ~= "-";
				else
					splitName ~= c;
			}
			if(splitName == name){
				mixin("return is(typeof(" ~ field ~ ") == string[]);");
			}
		}
		return false;
	}

	void load(){
		auto prioritizedPaths = [
			"/etc/flatman/config.ws",
			"~/.config/flatman/config.ws".expandTilde,
		];
		foreach(path; prioritizedPaths){
			try{
				loadBlock(path.readText, "");
				"loaded config %s".format(path).log;
			}catch(Exception e)
				e.toString.log;
		}
	}

	string[] keys;
	string[] autostart;

	int splitPaddingElem;
	ConfigColor splitBackground;

	ConfigColor tabsBorder;
	ConfigColor tabsBorderActive;
	ConfigColor tabsBackgroundNormal;
	ConfigColor tabsBackgroundFullscreen;
	ConfigColor tabsBackgroundHover;
	ConfigColor tabsBackgroundActiveBg;
	ConfigColor tabsBackgroundActive;
	ConfigColor tabsBackgroundUrgent;
	string tabsTitleFont;
	int tabsTitleFont_size;
	int tabsTitleShow;
	ConfigColor tabsTitleNormal;
	ConfigColor tabsTitleActive;
	ConfigColor tabsTitleActiveBg;
	ConfigColor tabsTitleUrgent;
	ConfigColor tabsTitleHover;
	ConfigColor tabsTitleFullscreen;

}


class Config {

	string[string] values;
	string[] autostart;

	string opIndex(string name){
		if(name in values)
			return values[name];
		"WARNING: config entry not found: %s".format(name).log;
		return "ff9999";
	}

	float[3] color(string name){
		auto clr = this[name];
		return [
				clr[0..2].to!int(16)/255.0,
				clr[2..4].to!int(16)/255.0,
				clr[4..6].to!int(16)/255.0
		]; 
	}

	string key(string name){
		return this[name];
	}

	void loadBlock(string block, string namespace){
		if(namespace.strip == "autostart")
			loadAutostart(block);
		else {
			Decode.text(block, (name, value, isBlock){
				if(isBlock)
					loadBlock(value, namespace ~ " " ~ name);
				else
					values[(namespace ~ " " ~ name).strip] = value.strip;
			});
		}
	}

	void loadAutostart(string block){
		foreach(line; block.splitLines){
			line = line.strip;
			if(line == "ignore previous")
				autostart = [];
			else
				autostart ~= line;
		}
	}

	void load(){
		auto prioritizedPaths = [
			"/etc/flatman/config.ws",
			"~/.config/flatman/config.ws".expandTilde,
		];
		foreach(path; prioritizedPaths){
			try{
				loadBlock(path.readText, "");
				"loaded config %s".format(path).log;
			}catch(Exception e)
				e.toString.log;
		}
	}

}

Config config;


shared static this(){
	WmConfig cfg;
	cfg.load;
	config = new Config;
	config.load;
}

void each(T)(T[] data, void delegate(size_t i, T data) dg){
	foreach(i, d; data)
		dg(i, d);
}

static const Rule[] rules = [
	{ "Gimp",     "",       "",       0,            true,        -1 },
	{ "Firefox",  "",       "",       1 << 8,       false,       -1 },
];

enum MODKEY = Mod1Mask;

static Key[] keys;
static Button[] buttons;

