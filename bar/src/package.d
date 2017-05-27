module bar;

public import
	core.thread,
	core.sys.posix.signal,
	
	std.algorithm,
	std.datetime,
	std.string,
	std.stdio,
	std.traits,
	std.conv,
	std.math,

	x11.X,
	x11.Xlib,
	x11.Xutil,
	x11.Xproto,
	x11.extensions.Xinerama,
	x11.extensions.render,
	x11.extensions.Xrender,
	x11.Xatom,

	ws.gui.base,
	ws.x.property,
	ws.x.draw,
	ws.math.vector,
    ws.wm,

	common.configLoader,
	common.screens,
	common.atoms,

    bar.bar,
	bar.config,
    bar.main,
    bar.plugin,
    bar.plugins,
	bar.powerButton,
	bar.widget.taskList,
	bar.widget.taskListEntry,
	bar.alpha,
    bar.client,
	bar.widget.tray,
	bar.xembed;


enum CompilePlugins = false;


static if(CompilePlugins){
	public import commando;
}