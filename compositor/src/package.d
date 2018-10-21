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
	std.traits,
	std.random,

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
	x11.extensions.Xdamage,
	x11.keysymdef,

	ws.wm,
	ws.event,
	ws.gui.input,
	ws.math,
	ws.time,
	ws.frameTimer,
	ws.x.property,
	ws.x.draw,
	ws.x.backbuffer,
	ws.gl.context,
	ws.gl.draw,
	ws.draw,

	common.window,
	common.screens,
	common.atoms,
	common.configLoader,
	common.queryTree,

	composite.util,
	composite.main,
	composite.config,
	composite.backend.backend,
	composite.backend.xrender,
	composite.backend.xrenderWindow,
	composite.overview,
	composite.overviewWindow,
	composite.damage,
	composite.client,
	composite.animation;


x11.Xlib.Screen screen;
ulong root;

enum CompositeRedirectAutomatic = 0;
enum CompositeRedirectManual = 1;
