module flatman.config;

import flatman;

__gshared:


class Config {

	string[string] values;

	string opIndex(string name){
		return values.get(name, "ff9999");
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
		Decode.text(block, (name, value, isBlock){
			if(isBlock)
				loadBlock(value, namespace ~ " " ~ name);
			else
				values[(namespace ~ " " ~ name).strip] = value.strip;
		});
	}

	void load(){
		auto prioritizedPaths = [
			"%s/config.ws".format(thisExePath.dirName),
			"/etc/flatman",
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


enum fonts = [
    "Consolas:size=10"
];

enum normbordercolor = "#444444";
enum normbgcolor     = "#222222";
enum normfgcolor     = "#bbbbbb";
enum selbordercolor  = "#005577";
enum selbgcolor      = "#005577";
enum selfgcolor      = "#eeeeee";
enum borderpx  = 0;        /* border pixel of windows */
enum snap      = 32;       /* snap pixel */
enum showbar           = false;     /* False means no bar */
enum topbar            = false;     /* False means bottom bar */

/* tagging */
enum tags = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"];

void each(T)(T[] data, void delegate(size_t i, T data) dg){
	foreach(i, d; data)
		dg(i, d);
}

static const Rule[] rules = [
	{ "Gimp",     "",       "",       0,            true,        -1 },
	{ "Firefox",  "",       "",       1 << 8,       false,       -1 },
];

enum mfact = 0.55;
enum nmaster = 1;
enum resizehints = true;

enum MODKEY = Mod1Mask;

enum launcher = "dinu -fn Consolas-10";
enum terminal  = "terminator";

static Key[] keys;
static Button[] buttons;

string currentContext(){
	try
		return "~/.dinu/%s".format(monitor.workspaceActive).expandTilde.readText;
	catch
		return "~".expandTilde;
}
