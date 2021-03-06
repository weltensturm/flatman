module flatman;

public import
	core.runtime,
	core.thread,
	core.stdc.locale,
	core.stdc.signal,
	core.stdc.stdlib,
	core.sync.mutex,
	core.sys.posix.unistd,
	core.sys.posix.signal,
	core.sys.posix.sys.wait,

	std.parallelism,
	std.concurrency,
	std.regex,
	std.traits,
	std.meta,
	std.typecons,
	std.process,
	std.path,
	std.stdio,
	std.algorithm,
	std.array,
	std.range,
	std.math,
	std.string,
	std.conv,
	std.datetime,
	std.file,
	std.functional,

	x11.X,
	x11.Xlib,
	x11.Xutil,
	x11.Xproto,
	x11.Xatom,
	x11.extensions.Xcomposite,
	x11.extensions.Xfixes,
	x11.extensions.XInput,
	x11.extensions.render,
	x11.extensions.Xrender,
	x11.extensions.Xinerama,
	x11.keysymdef,

	ws.math,
	ws.inotify,
	ws.time,
	ws.gui.base,
	ws.gui.input,
	ws.draw,
    ws.gl.context,
	ws.gl.draw,
	ws.x.draw,
	ws.x.property,
	ws.decode,
	ws.bindings.fontconfig,
	ws.bindings.xft,

	common.event,
	common.configLoader,
	common.screens,
	common.atoms,
	common.xerror,
	common.queryTree,

	flatman.log,
	flatman.x.atoms,
	flatman.x.ewmh,
	flatman.x.icccm,
	flatman.x.motif,
	flatman.x.properties,
	flatman.x.error,
	flatman.layout.stacking,
	flatman.layout.monitor,
	flatman.layout.workspace,
	flatman.layout.container,
	flatman.layout.split,
	flatman.layout.floating,
	flatman.layout.tabs,
	flatman.workspaceHistory,
	flatman.dragging,
	flatman.util,
	flatman.flatman,
	flatman.events,
	flatman.manage,
	flatman.frame,
	flatman.client,
	flatman.commands,
	flatman.config,
	flatman.keybinds;


public import
	ws.wm: WindowHandle;
