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

struct ConfigInt4 {

	int[4] value;
	alias value this;

	this(string text){
		value = text.split.to!(int[4]);
	}

}


struct WmConfig {

	string[] keys;
	string[] autostart;

	bool workspaceWrap;

	int tabsTitleHeight;
	int tabsWidth;
	ConfigInt4 tabsPadding;
	ConfigColor tabsBorderNormalColor;
	ConfigColor tabsBorderActiveColor;
	ConfigColor tabsBorderFullscreenColor;
	ConfigColor tabsBackgroundNormal;
	ConfigColor tabsBackgroundFullscreen;
	ConfigColor tabsBackgroundHover;
	ConfigColor tabsBackgroundActive;
	ConfigColor tabsBackgroundUrgent;
	string tabsTitleFont;
	int tabsTitleFont_size;
	int tabsTitleShow;
	ConfigColor tabsTitleNormal;
	ConfigColor tabsTitleActive;
	ConfigColor tabsTitleUrgent;
	ConfigColor tabsTitleHover;
	ConfigColor tabsTitleFullscreen;

}

WmConfig cfg;


class ConfigNode {

	this(string context){
		this.context = context;
	}

	string context;

	string value(){
		return config[context];
	}

	alias value this;

	T opCast(T)() if(is(T == int[4])) {
		return value.split.to!(int[4]);
	}

	T opCast(T)() if(is(T == float[3])) {
		if(context !in config.colors){
			auto color = value;
			config.colors[context] = [
					color[0..2].to!int(16)/255.0,
					color[2..4].to!int(16)/255.0,
					color[4..6].to!int(16)/255.0
			]; 
		}
		return config.colors[context];
	}

	T opCast(T)() if(is(T == int)) {
		return value.to!int;
	}

	T opCast(T)() if(is(T == string)) {
		return value;
	}

	ConfigNode opIndex(string s){
		return new ConfigNode(context ~ " " ~ s);
	}

	ConfigNode opDispatch(string s)() if(s != "to") {
		return new ConfigNode(context ~ " " ~ s.replace("_", "-"));
	}

	/+
	float[3] color(){
		return opCast!(float[3]);
	}
	+/

}


class Config {

	string[string] values;
	string[] autostart;

	float[3][string] colors;

	string opIndex(string name){
		if(name in values)
			return values[name];
		"WARNING: config entry not found: %s".format(name).log;
		return "ff9999";
	}

	float[3] color(string name){
		if(name !in colors){
			auto color = this[name];
			colors[name] = [
					color[0..2].to!int(16)/255.0,
					color[2..4].to!int(16)/255.0,
					color[4..6].to!int(16)/255.0
			];
		}
		return colors[name];
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

	ConfigNode opDispatch(string s)(){
		return new ConfigNode(s);
	}

}

Config config;


shared static this(){
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

