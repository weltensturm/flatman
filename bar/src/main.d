module bar.main;


import bar;


extern(C) nothrow int xerror(Display* dpy, XErrorEvent* e){
	try {
		char[128] buffer;
		XGetErrorText(wm.displayHandle, e.error_code, buffer.ptr, buffer.length);
		"XError: %s (major=%s, minor=%s, serial=%s)".format(buffer.to!string, e.request_code, e.minor_code, e.serial).writeln;
	}
	catch {}
	return 0;
}


bool running = true;


extern(C) nothrow @nogc @system void stop(int){
	running = false;
}


void main(){
	XSetErrorHandler(&xerror);
	signal(SIGINT, &stop);
	auto bar = new Bar;
	wm.add(bar);
	while(wm.hasActiveWindows && running){
		wm.processEvents;
		bar.onDraw;
		Thread.sleep(10.msecs);
	}
	bar.onDestroy;
	writeln("quit");
}
