module flatman.config;

import flatman;

__gshared:


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

