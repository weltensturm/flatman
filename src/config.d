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

	void loadBlock(string block, string namespace){
		Decode.text(block, (name, value, isBlock){
			if(isBlock)
				loadBlock(value, namespace ~ " " ~ name);
			else
				values[(namespace ~ " " ~ name).strip] = value;
		});
	}

	void load(){
		auto paths = [
			"~/.config/flatman/config.ws".expandTilde,
			"%s/config.ws".format(thisExePath.dirName),
		];
		foreach(path; paths){
			try{
				loadBlock(path.readText, "");
				"loaded config %s".format(values).log;
				return;
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

shared static this(){
	keys = [
		Key(MODKEY,             XK_d,      {pipeShell(launcher ~ " -c ~/.dinu/" ~ monitor.workspaceActive.to!string);}),
		Key(MODKEY,			    XK_Return, {pipeShell("cd \"%s\" && %s".format(currentContext, terminal));}),
		Key(MODKEY,             XK_j,      {focusstack(-1);}),
		Key(MODKEY,             XK_semicolon,      {focusstack(1);}),
		
		Key(MODKEY|ControlMask, XK_j, {sizeDec;}),
		Key(MODKEY|ControlMask, XK_semicolon, {sizeInc;}),
		Key(MODKEY,				XK_r, {mouseresize;}),
		Key(MODKEY,				XK_m, {mousemove;}),

		Key(MODKEY,             XK_k, {monitor.nextWsFilled;}),
		Key(MODKEY,             XK_l, {monitor.prevWsFilled;}),
		Key(MODKEY,             XK_Tab, {monitor.nextWsFilled;}),
		Key(MODKEY|ShiftMask,   XK_Tab, {monitor.prevWsFilled;}),
		Key(MODKEY|ShiftMask,	XK_j, {monitor.workspace.split.moveDir(-1);}),
		Key(MODKEY|ShiftMask,	XK_semicolon, {monitor.workspace.split.moveDir(1);}),
		Key(MODKEY|ShiftMask,   XK_k, {monitor.moveDown;}),
		Key(MODKEY|ShiftMask,   XK_l, {monitor.moveUp;}),
		//Key(MODKEY,             XK_Tab,    {view;}),
		Key(MODKEY|ShiftMask,   XK_q,      {killclient;}),
		Key(MODKEY|ShiftMask,   XK_space,  {togglefloating;}),
		Key(MODKEY,				XK_f,	   {togglefullscreen;}),
		Key(MODKEY,             XK_comma,  {focusmon(-1);}),
		Key(MODKEY,             XK_period, {focusmon(1);}),
		Key(MODKEY|ShiftMask,   XK_e,      {quit;}),
		Key(MODKEY,             XK_t,      {monitor.workspace.split.toggleTitles;} ),
		Key(MODKEY|ShiftMask,	XK_r,		 {restart=true; running=false;}),
	];

	[XK_1, XK_2, XK_3, XK_4, XK_5, XK_6, XK_7, XK_8, XK_9, XK_0].each((size_t i, size_t k){
		keys ~= Key(MODKEY, k, {monitor.switchWorkspace(cast(int)i);});
		keys ~= Key(MODKEY|ShiftMask, k, {monitor.moveWorkspace(cast(int)i);});
	});

	buttons = [
		Button(MODKEY, Button1, {mousemove;} ),
		Button(MODKEY, Button2, {togglefloating;} ),
		Button(MODKEY, Button3, {mouseresize;} ),
	];

}
