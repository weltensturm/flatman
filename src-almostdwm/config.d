module dwm.config;

import dwm;

/* See LICENSE file for copyright and license details. */

/* appearance */
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
enum borderpx  = 2;        /* border pixel of windows */
enum snap      = 32;       /* snap pixel */
enum showbar           = true;     /* False means no bar */
enum topbar            = false;     /* False means bottom bar */

/* tagging */
enum tags = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"];

static const Rule[] rules = [
	/* xprop(1):
	 *	WM_CLASS(STRING) = instance, class
	 *	WM_NAME(STRING) = title
	 */
	/* class      instance    title       tags mask     isfloating   monitor */
	{ "Gimp",     "",       "",       0,            true,        -1 },
	{ "Firefox",  "",       "",       1 << 8,       false,       -1 },
];

enum mfact = 0.55;
enum nmaster = 1;
enum resizehints = true;

static const Layout[] layouts = [
	{ "tile",      &tile },
	{ "float",      null },
	{ "monocle",      &monocle },
];

enum MODKEY = Mod1Mask;

enum launcher = "/home/void/Projects/d/dinu/bin/dinu -fn Consolas-11";
enum terminal  = "terminator";

static Key[] keys;
static Button[] buttons;

void each(T)(T[] array, void delegate(size_t, T) dg){
	foreach(i, data; array)
		dg(i, data);
}

shared static this(){
	keys = [
		Key(MODKEY,                       XK_d,      {pipeShell(launcher);}),
		Key(MODKEY|ShiftMask,             XK_Return, {pipeShell(terminal);}),
		Key(MODKEY,                       XK_b,      {togglebar;}),
		Key(MODKEY,                       XK_j,      {focusstack(1);}),
		Key(MODKEY,                       XK_k,      {focusstack(-1);}),
		Key(MODKEY,                       XK_i,      {incnmaster(1);}),
		Key(MODKEY,                       XK_o,      {incnmaster(-1);}),
		Key(MODKEY,                       XK_h,      {setmfact(-0.05);}),
		Key(MODKEY,                       XK_l,      {setmfact(0.05);}),
		Key(MODKEY,                       XK_Return, {zoom;}),
		Key(MODKEY,                       XK_Tab,    {view;}),
		Key(MODKEY|ShiftMask,             XK_q,      {killclient;}),
		Key(MODKEY,                       XK_e,      {setlayout(&layouts[0]);}),
		Key(MODKEY,                       XK_f,      {setlayout(&layouts[1]);}),
		Key(MODKEY,                       XK_w,      {setlayout(&layouts[2]);}),
		Key(MODKEY,                       XK_space,  {setlayout(null);}),
		Key(MODKEY|ShiftMask,             XK_space,  {togglefloating;}),
		Key(MODKEY,                       XK_minus,      {view(~0);}),
		Key(MODKEY|ShiftMask,             XK_minus,      {tag(~0);}),
		Key(MODKEY,                       XK_comma,  {focusmon(-1);}),
		Key(MODKEY,                       XK_period, {focusmon(1);}),
		Key(MODKEY|ShiftMask,             XK_comma,  {tagmon(-1);}),
		Key(MODKEY|ShiftMask,             XK_period, {tagmon(1);}),
		Key(MODKEY|ShiftMask,             XK_e,      {quit;} ),
	];
	
	[XK_1, XK_2, XK_3, XK_4, XK_5, XK_6, XK_7, XK_8, XK_9, XK_0].each((size_t i, int k){
		keys ~= Key(MODKEY,                       k,      {view(1<<i);});
		keys ~= Key(MODKEY|ControlMask,           k,      {toggleview(1<<i);});
		keys ~= Key(MODKEY|ShiftMask,             k,      {tag(1<<i);});
		keys ~= Key(MODKEY|ControlMask|ShiftMask, k,      {toggletag(1<<i);});
	});
	
	/* click can be ClkLtSymbol, ClkStatusText, ClkWinTitle, ClkClientWin, or ClkRootWin */
	
	buttons = [
		Button(ClkLtSymbol,          0,              Button1,        (b){setlayout(null);} ),
		Button(ClkLtSymbol,          0,              Button3,        (b){setlayout(&layouts[2]);} ),
		Button(ClkWinTitle,          0,              Button2,        (b){zoom;} ),
		Button(ClkStatusText,        0,              Button2,        (b){pipeShell(terminal);} ),
		Button(ClkClientWin,         MODKEY,         Button1,        (b){movemouse;} ),
		Button(ClkClientWin,         MODKEY,         Button2,        (b){togglefloating;} ),
		Button(ClkClientWin,         MODKEY,         Button3,        (b){resizemouse;} ),
		Button(ClkTagBar,            0,              Button1,        (b){view(b);} ),
		Button(ClkTagBar,            0,              Button3,        (b){toggleview(b);} ),
		Button(ClkTagBar,            MODKEY,         Button1,        (b){tag(b);} ),
		Button(ClkTagBar,            MODKEY,         Button3,        (b){toggletag(b);} ),
	];

}
