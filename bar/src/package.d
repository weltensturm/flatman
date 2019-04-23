module bar;

public import
	core.thread,
	core.sys.posix.signal,

	std.range,
	std.algorithm,
	std.datetime,
	std.string,
	std.stdio,
	std.traits,
	std.conv,
	std.math,
	std.process,
	std.regex,
	std.random,

	x11.X,
	x11.Xlib,
	x11.Xutil,
	x11.Xproto,
	x11.extensions.Xinerama,
	x11.extensions.render,
	x11.extensions.Xrender,
	x11.extensions.Xcomposite,
	x11.extensions.Xdamage,
	x11.Xatom,

	ws.time,
	ws.gui.base,
	ws.x.property,
	ws.x.draw,
	ws.math.vector,
    ws.wm,
    ws.inotify,

	common.configLoader,
	common.screens,
	common.atoms,
	common.xerror,
	common.xembed,
	common.window,

    bar.bar,
	bar.config,
    bar.main,
    bar.plugins,
	bar.widget.widget,
	bar.widget.battery,
	bar.widget.taskList,
	bar.widget.taskListEntry,
	bar.widget.workspaceIndicator,
	bar.widget.clock,
	bar.alpha,
    bar.client,
	bar.widget.tray;

enum CompositeRedirectAutomatic = 0;
enum CompositeRedirectManual = 1;
