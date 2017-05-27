module composite;


public import
	core.thread,
	core.sys.posix.signal,
	core.memory,
	std.process,
	std.algorithm,
	std.array,
	std.datetime,
	std.string,
	std.math,
	std.stdio,
	std.file,
	std.path,
	std.conv,
	derelict.opengl3.gl,
	derelict.opengl3.glx,
	x11.X,
	x11.Xlib,
	x11.Xutil,
	x11.Xproto,
	x11.Xatom,
	x11.extensions.Xcomposite,
	x11.extensions.Xdamage,
	x11.extensions.Xfixes,
	x11.extensions.XInput,
	x11.extensions.render,
	x11.extensions.Xrender,
	x11.keysymdef,
	ws.wm,
	ws.math,
	ws.time,
	ws.frameTimer,
	ws.x.property,
	ws.x.draw,
	common.window,
	common.screens,
	common.atoms,
	composite.main,
	composite.overview,
	composite.client,
	composite.animation;


x11.Xlib.Screen screen;
ulong root;

enum CompositeRedirectManual = 1;
