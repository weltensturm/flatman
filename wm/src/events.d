module flatman.events;


import flatman;


alias WmEvent = int;


Event!(int[2]) mouseMoved;
Event!(Mouse.button) mousePressed;
Event!(Mouse.button) mouseReleased;
Event!() tick;


void eventsInit(){
	mouseMoved = new Event!(int[2]);
	mousePressed = new Event!(Mouse.button);
	mouseReleased = new Event!(Mouse.button);
	tick = new Event!();
}


struct EventMaskMapping {
	int mask;
	int type;
}

enum eventMaskMap = [
	EventMaskMapping(ExposureMask, Expose),
	EventMaskMapping(EnterWindowMask, EnterNotify),
	EventMaskMapping(LeaveWindowMask, LeaveNotify),
	EventMaskMapping(ButtonPressMask, ButtonPress),
	EventMaskMapping(ButtonReleaseMask, ButtonRelease),
	EventMaskMapping(PointerMotionMask, MotionNotify)
];


void register(Window window, void delegate(XEvent*)[int] handler){
	int mask;
	foreach(ev, dg; handler){
		foreach(mapping; eventMaskMap){
			if(mapping.type == ev)
				mask |= mapping.mask;
		}
		customHandler[window][ev] = dg;
	}
	XSelectInput(dpy, window, mask);
}

void unregister(Window window){
	customHandler.remove(window);
}


enum handler = [
	ButtonPress: (XEvent* e) => onButton(&e.xbutton),
	ButtonRelease: (XEvent* e) => onButtonRelease(&e.xbutton),
	MotionNotify: &onMotion,
	ClientMessage: (XEvent* e) => onClientMessage(&e.xclient),
	ConfigureRequest: &onConfigureRequest,
	ConfigureNotify: (XEvent* e) => onConfigure(e.xconfigure.window, e.xconfigure.x, e.xconfigure.y, e.xconfigure.width, e.xconfigure.height),
	CreateNotify: &onCreate,
	DestroyNotify: &onDestroy,
	EnterNotify: (XEvent* e) => onEnter(&e.xcrossing),
	Expose: &onExpose,
	FocusIn: &onFocus,
	KeyPress: &onKey,
    KeyRelease: &onKeyRelease,
	MappingNotify: (XEvent* e) => onMapping(e),
	MapRequest: &onMapRequest,
	PropertyNotify: (XEvent* e) => onProperty(&e.xproperty),
	UnmapNotify: (XEvent* e) => onUnmap(&e.xunmap, wintoclient(e.xunmap.window))
];

enum handlerNames = [
	ButtonPress: "ButtonPress",
	ButtonRelease: "ButtonRelease",
	ClientMessage: "ClientMessage",
	ConfigureRequest: "ConfigureRequest",
	ConfigureNotify: "ConfigureNotify",
	DestroyNotify: "DestroyNotify",
	EnterNotify: "EnterNotify",
	Expose: "Expose",
	FocusIn: "FocusIn",
	KeyPress: "KeyPress",
	KeyRelease: "KeyRelease",
	MappingNotify: "MappingNotify",
	MapRequest: "MapRequest",
	MotionNotify: "MotionNotify",
	PropertyNotify: "PropertyNotify",
	UnmapNotify: "UnmapNotify",
];


void onButton(XButtonPressedEvent* ev){
	Client c = wintoclient(ev.window);
	Monitor m = findMonitor(ev.window);
	if(m && m != monitor){
		if(monitor && monitor.active)
			monitor.active.unfocus(true);
		monitor = m;
	}
	if(c){
		if(c.isFloating && !c.global)
			c.parent.to!Floating.raise(c);
		c.focus;
		foreach(bind; buttons)
			if(bind.button == ev.button && cleanMask(bind.mask) == cleanMask(ev.state))
				bind.func();
	}
	mousePressed(ev.button);
}

void onButtonRelease(XButtonReleasedEvent* ev){
	mouseReleased(ev.button);
}

void onClientMessage(XClientMessageEvent* cme){
	auto c = wintoclient(cme.window);
	auto handler = [
		Atoms._NET_CURRENT_DESKTOP: {
			if(cme.data.l[2] > 0)
				newWorkspace(cme.data.l[0]);
			switchWorkspace(cast(int)cme.data.l[0]);
		},
		Atoms._NET_WM_STATE: {
			if(!c)
				return;
			auto sh = [
				Atoms._NET_WM_STATE_FULLSCREEN: {
					bool s = (cme.data.l[0] == _NET_WM_STATE_ADD
		              || (cme.data.l[0] == _NET_WM_STATE_TOGGLE && !c.isfullscreen));
					c.setFullscreen(s);
				},
				Atoms._NET_WM_STATE_DEMANDS_ATTENTION: {
					c.requestAttention;
				}
			];
			if(cme.data.l[1] in sh)
				sh[cme.data.l[1]]();
			if(cme.data.l[2] in sh)
				sh[cme.data.l[2]]();
		},
		Atoms._NET_ACTIVE_WINDOW: {
			if(!c)
				return;
			if(cme.data.l[0] < 2){
				c.requestAttention;
			}else
				c.focus;
		},
		Atoms._NET_WM_DESKTOP: {
			if(!c)
				return;
			if(cme.data.l[2] == 1)
				newWorkspace(cme.data.l[0]);
			c.setWorkspace(cme.data.l[0]);
		},
		Atoms._NET_MOVERESIZE_WINDOW: {
			if(!c || !c.isFloating)
				return;
			c.moveResize(cme.data.l[0..2].to!(int[2]), cme.data.l[2..4].to!(int[2]));
		},
		Atoms._NET_RESTACK_WINDOW: {
			if(!c || c == monitor.active)
				return;
			c.requestAttention;
		},
		Atoms._NET_WM_MOVERESIZE: {
			if(!c)
				return;
			if(cme.data.l[2] == 8)
				dragClient(c, c.pos.a - cme.data.l[0..2].to!(int[2]));
		},
		wm.state: {
			if(cme.data.l[0] == IconicState){
				"iconify %s".format(c).log;
			}
		},
		Atoms._FLATMAN_OVERVIEW: {
			if(cme.data.l[0] != 2)
				return;
			overview(cme.data.l[1] > 0);
		},
		Atoms._FLATMAN_TELEPORT: {
			if(cme.data.l[0] != 2 || !c)
				return;
			auto target = wintoclient(cme.data.l[0]);
			if(target)
				teleport(c, target, cme.data.l[1]);
		}
	];
	if(cme.message_type in handler)
		handler[cme.message_type]();
	else
		"unknown message type %s %s".format(cme.message_type, cme.message_type.name).log;
}

void onProperty(XPropertyEvent* ev){
	Client c = wintoclient(ev.window);
	if(c){
		//"%s ev %s %s".format(c, "onProperty", ev.atom.name).log;
		c.onProperty(ev);
	}
}

void onConfigure(Window window, int x, int y, int width, int height){
	"%s onConfigure %s %s".format(wintoclient(window), [x,y], [width,height]);
	if(window == root){
		bool dirty = (sw != width || sh != height);
		sw = width;
		sh = height;
		if(updateMonitors() || dirty){
			updateWorkarea;
			restack;
		}
	}
}

void onConfigureRequest(XEvent* e){
	XConfigureRequestEvent* ev = &e.xconfigurerequest;
	Client c = wintoclient(ev.window);
	if(c){
		c.onConfigureRequest(ev);
	}else{
		XWindowChanges wc;
		wc.x = ev.x;
		wc.y = ev.y;
		wc.width = ev.width;
		wc.height = ev.height;
		wc.border_width = ev.border_width;
		wc.sibling = ev.above;
		wc.stack_mode = ev.detail;
		XConfigureWindow(dpy, ev.window, ev.value_mask, &wc);
	}
}

void onCreate(XEvent* e){
	auto ev = &e.xcreatewindow;
	if(ev.override_redirect){
		x11.X.Window[] wmWindows;
		foreach(ws; monitor.workspaces){
			foreach(separator; ws.split.separators)
				wmWindows ~= separator.window;
		}
		"unmanaged window".log;
		if(!(unmanaged ~ wmWindows).canFind(ev.window))
			unmanaged ~= ev.window;
	}
}

void onDestroy(XEvent* e){
	XDestroyWindowEvent* ev = &e.xdestroywindow;
	if(unmanaged.canFind(ev.window))
		unmanaged = unmanaged.without(ev.window);
	Client c = wintoclient(ev.window);
	if(c)
		c.destroy;
}

void onEnter(XCrossingEvent* ev){
	if(dragging || (ev.mode != NotifyNormal || ev.detail == NotifyInferior) && ev.window != root)
		return;
	Client c = wintoclient(ev.window);
	if(c)
		c.onEnter(ev);
}

void onExpose(XEvent *e){
	XExposeEvent *ev = &e.xexpose;
	Monitor m = findMonitor(ev.window);
	if(ev.count == 0 && m)
		redraw = true;
}

void onFocus(XEvent* e){ /* there are some broken focus acquiring clients */
	XFocusChangeEvent *ev = &e.xfocus;
	if(monitor.active && ev.window == monitor.active.win)
		monitor.active.focus;
	//auto c = wintoclient(ev.window);
	//if(c && c != active)
	//	c.requestAttention;
}

void onKey(XEvent* e){
	XKeyEvent *ev = &e.xkey;
	KeySym keysym = XKeycodeToKeysym(dpy, cast(KeyCode)ev.keycode, 0);
	"key %s".format(keysym).log;
	foreach(key; flatman.keys){
		if(keysym == key.keysym && cleanMask(key.mod) == cleanMask(ev.state) && key.func)
			key.func(true);
	}
}

void onKeyRelease(XEvent* e){
	XKeyEvent *ev = &e.xkey;
	KeySym keysym = XKeycodeToKeysym(dpy, cast(KeyCode)ev.keycode, 0);
	"key release %s".format(keysym).log;
	foreach(key; flatman.keys){
		if(keysym == key.keysym && key.func)
			key.func(false);
	}
}

void onMapping(XEvent *e){
	XMappingEvent *ev = &e.xmapping;
	XRefreshKeyboardMapping(ev);
	if(ev.request == MappingKeyboard)
		grabkeys();
}

void onMapRequest(XEvent *e){
	__gshared XWindowAttributes wa;
	XMapRequestEvent *ev = &e.xmaprequest;
	if(!XGetWindowAttributes(dpy, ev.window, &wa)){
		return;
	}
	if(wa.override_redirect){
		XMapWindow(dpy, ev.window);
		return;
	}
	if(!wintoclient(ev.window) && ev.parent == root){
		try{
			manage(ev.window, &wa);
			//XMapWindow(dpy, ev.window);
		}catch(Throwable t){
			t.toString.log;
		}
	}
}

void onUnmap(XUnmapEvent* ev, Client client){
	if(client)
		client.onUnmap(ev);
}

void onMotion(XEvent* e){
	auto ev = &e.xmotion;
	/+
	if(ev.window != root && (!active || ev.window != active.win && ev.subwindow != active.win)){
		auto c = wintoclient(ev.window);
		if(c)
			c.focus;
	}
	+/
	mouseMoved([ev.x_root, ev.y_root]);
	focus(findMonitor([ev.x_root, ev.y_root]));
}

enum XRequestCode {
    X_CreateWindow                   = 1,
    X_ChangeWindowAttributes         = 2,
    X_GetWindowAttributes            = 3,
    X_DestroyWindow                  = 4,
    X_DestroySubwindows              = 5,
    X_ChangeSaveSet                  = 6,
    X_ReparentWindow                 = 7,
    X_MapWindow                      = 8,
    X_MapSubwindows                  = 9,
    X_UnmapWindow                   = 10,
    X_UnmapSubwindows               = 11,
    X_ConfigureWindow               = 12,
    X_CirculateWindow               = 13,
    X_GetGeometry                   = 14,
    X_QueryTree                     = 15,
    X_InternAtom                    = 16,
    X_GetAtomName                   = 17,
    X_ChangeProperty                = 18,
    X_DeleteProperty                = 19,
    X_GetProperty                   = 20,
    X_ListProperties                = 21,
    X_SetSelectionOwner             = 22,
    X_GetSelectionOwner             = 23,
    X_ConvertSelection              = 24,
    X_SendEvent                     = 25,
    X_GrabPointer                   = 26,
    X_UngrabPointer                 = 27,
    X_GrabButton                    = 28,
    X_UngrabButton                  = 29,
    X_ChangeActivePointerGrab       = 30,
    X_GrabKeyboard                  = 31,
    X_UngrabKeyboard                = 32,
    X_GrabKey                       = 33,
    X_UngrabKey                     = 34,
    X_AllowEvents                   = 35,
    X_GrabServer                    = 36,
    X_UngrabServer                  = 37,
    X_QueryPointer                  = 38,
    X_GetMotionEvents               = 39,
    X_TranslateCoords               = 40,
    X_WarpPointer                   = 41,
    X_SetInputFocus                 = 42,
    X_GetInputFocus                 = 43,
    X_QueryKeymap                   = 44,
    X_OpenFont                      = 45,
    X_CloseFont                     = 46,
    X_QueryFont                     = 47,
    X_QueryTextExtents              = 48,
    X_ListFonts                     = 49,
    X_ListFontsWithInfo             = 50,
    X_SetFontPath                   = 51,
    X_GetFontPath                   = 52,
    X_CreatePixmap                  = 53,
    X_FreePixmap                    = 54,
    X_CreateGC                      = 55,
    X_ChangeGC                      = 56,
    X_CopyGC                        = 57,
    X_SetDashes                     = 58,
    X_SetClipRectangles             = 59,
    X_FreeGC                        = 60,
    X_ClearArea                     = 61,
    X_CopyArea                      = 62,
    X_CopyPlane                     = 63,
    X_PolyPoint                     = 64,
    X_PolyLine                      = 65,
    X_PolySegment                   = 66,
    X_PolyRectangle                 = 67,
    X_PolyArc                       = 68,
    X_FillPoly                      = 69,
    X_PolyFillRectangle             = 70,
    X_PolyFillArc                   = 71,
    X_PutImage                      = 72,
    X_GetImage                      = 73,
    X_PolyText8                     = 74,
    X_PolyText16                    = 75,
    X_ImageText8                    = 76,
    X_ImageText16                   = 77,
    X_CreateColormap                = 78,
    X_FreeColormap                  = 79,
    X_CopyColormapAndFree           = 80,
    X_InstallColormap               = 81,
    X_UninstallColormap             = 82,
    X_ListInstalledColormaps        = 83,
    X_AllocColor                    = 84,
    X_AllocNamedColor               = 85,
    X_AllocColorCells               = 86,
    X_AllocColorPlanes              = 87,
    X_FreeColors                    = 88,
    X_StoreColors                   = 89,
    X_StoreNamedColor               = 90,
    X_QueryColors                   = 91,
    X_LookupColor                   = 92,
    X_CreateCursor                  = 93,
    X_CreateGlyphCursor             = 94,
    X_FreeCursor                    = 95,
    X_RecolorCursor                 = 96,
    X_QueryBestSize                 = 97,
    X_QueryExtension                = 98,
    X_ListExtensions                = 99,
    X_ChangeKeyboardMapping         = 100,
    X_GetKeyboardMapping            = 101,
    X_ChangeKeyboardControl         = 102,
    X_GetKeyboardControl            = 103,
    X_Bell                          = 104,
    X_ChangePointerControl          = 105,
    X_GetPointerControl             = 106,
    X_SetScreenSaver                = 107,
    X_GetScreenSaver                = 108,
    X_ChangeHosts                   = 109,
    X_ListHosts                     = 110,
    X_SetAccessControl              = 111,
    X_SetCloseDownMode              = 112,
    X_KillClient                    = 113,
    X_RotateProperties              = 114,
    X_ForceScreenSaver              = 115,
    X_SetPointerMapping             = 116,
    X_GetPointerMapping             = 117,
    X_SetModifierMapping            = 118,
    X_GetModifierMapping            = 119,
    X_NoOperation                   = 127
}
