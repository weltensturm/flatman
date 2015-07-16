module flatman.config;

import flatman;


enum fonts = [
    "Sans:size=10.5",
    "VL Gothic:size=10.5",
    "WenQuanYi Micro Hei:size=10.5",
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

enum launcher = "dinu -fn Consolas-11";
enum terminal  = "terminator";

static Key[] keys;
static Button[] buttons;

shared static this(){
	keys = [
		Key(0, XK_Alt_L, {}),
		Key(MODKEY,                       XK_d,      {pipeShell(launcher ~ " -c ~/.dinu/" ~ monitorActive.workspaceActive.to!string);}),
		Key(MODKEY,			              XK_Return, {pipeShell(terminal);}),
		Key(MODKEY,                       XK_j,      {focusstack(-1);}),
		Key(MODKEY,                       XK_semicolon,      {focusstack(1);}),
		Key(MODKEY|ControlMask,           XK_j, {sizeDec;}),
		Key(MODKEY|ControlMask,           XK_semicolon, {sizeInc;}),
		Key(MODKEY,                       XK_k, {monitorActive.nextWs;}),
		Key(MODKEY,                       XK_l, {monitorActive.prevWs;}),
		Key(MODKEY,                       XK_Tab, {monitorActive.nextWs;}),
		Key(MODKEY|ShiftMask,             XK_Tab, {monitorActive.prevWs;}),
		Key(MODKEY|ShiftMask,             XK_k, {monitorActive.moveDown;}),
		Key(MODKEY|ShiftMask,             XK_l, {monitorActive.moveUp;}),
		//Key(MODKEY,                       XK_Tab,    {view;}),
		Key(MODKEY|ShiftMask,             XK_q,      {killclient;}),
		Key(MODKEY|ShiftMask,             XK_space,  {togglefloating;}),
		Key(MODKEY,                       XK_comma,  {focusmon(-1);}),
		Key(MODKEY,                       XK_period, {focusmon(1);}),
		Key(MODKEY|ShiftMask,             XK_e,      {quit;} ),
		Key(MODKEY,             		  XK_t,      {monitorActive.workspace.split.toggleTitles;} ),
		Key(MODKEY|ShiftMask,			  XK_r,		 {restart=true;running=false;}),
	];

	[XK_1, XK_2, XK_3, XK_4, XK_5, XK_6, XK_7, XK_8, XK_9, XK_0].each((size_t i, size_t k){
		keys ~= Key(MODKEY,                       k,      {monitorActive.switchWorkspace(cast(int)i);});
	});

	buttons = [];

}
