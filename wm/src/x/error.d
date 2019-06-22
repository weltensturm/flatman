module flatman.x.error;


import flatman;


extern(C) nothrow int function(Display *, XErrorEvent *) xerrorxlib;
extern(C) nothrow int function(Display*) xerrorfatalxlib;


/+
/* There's no way to check accesses to destroyed windows, thus those cases are
 * ignored (especially on UnmapNotify's).  Other types of errors call Xlibs
 * default error handler, which may call exit.  */
extern(C) nothrow int xerror(Display* dpy, XErrorEvent* ee){
	if(ee.error_code == XErrorCode.BadWindow
	|| (ee.request_code == X_SetInputFocus && ee.error_code == XErrorCode.BadMatch)
	|| (ee.request_code == X_PolyText8 && ee.error_code == XErrorCode.BadDrawable)
	|| (ee.request_code == X_PolyFillRectangle && ee.error_code == XErrorCode.BadDrawable)
	|| (ee.request_code == X_PolySegment && ee.error_code == XErrorCode.BadDrawable)
	|| (ee.request_code == X_ConfigureWindow && ee.error_code == XErrorCode.BadMatch)
	|| (ee.request_code == X_GrabButton && ee.error_code == XErrorCode.BadAccess)
	|| (ee.request_code == X_GrabKey && ee.error_code == XErrorCode.BadAccess)
	|| (ee.request_code == X_CopyArea && ee.error_code == XErrorCode.BadDrawable))
		return 0;
	try{
		(Log.RED ~ "flatman: X11 error: request code=%d %s, error code=%d %s").format(ee.request_code,
			cast(XRequestCode)ee.request_code, ee.error_code, cast(XErrorCode)ee.error_code).log;
	}catch(Throwable) {}
	return 0;
	//return xerrorxlib(dpy, ee); /* may call exit */
}
+/


extern(C) nothrow int xerrorfatal(Display* dpy){
	try{
		defaultTraceHandler.toString.log;
		"flatman: X11 fatal i/o error".log;
	}catch(Throwable) {}
	return xerrorfatalxlib(dpy);
}

extern(C) nothrow int xerrordummy(Display* dpy, XErrorEvent* ee){
	return 0;
}

nothrow extern(C) int xerrorstart(Display *dpy, XErrorEvent* ee){
	try
		"flatman: another window manager is already running".log;
	catch(Throwable) {}
	_exit(-1);
	return -1;
}
