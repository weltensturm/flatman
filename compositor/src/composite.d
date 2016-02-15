module composite.main;

import composite;

__gshared:


CompositeManager manager;


bool running = true;


void main(){
	try {
		XSetErrorHandler(&xerror);
		root = XDefaultRootWindow(wm.displayHandle);
		manager = new CompositeManager;
		while(true){
			wm.processEvents;
			auto frameStart = now;
			manager.draw;
			auto frameEnd = now;
			if(frameEnd - frameStart > 1.0/58)
				writeln(frameEnd - frameStart);
			Thread.sleep(((frameStart + 1.0/60.0 - frameEnd).max(0)*1000).lround.msecs);
		}
	}catch(Throwable t){
		writeln(t);
	}
}

extern(C) nothrow int xerror(Display* dpy, XErrorEvent* e){
	try {
		char[128] buffer;
		XGetErrorText(wm.displayHandle, e.error_code, buffer.ptr, buffer.length);
		"XError: %s (major=%s, minor=%s, serial=%s)".format(buffer.to!string, e.request_code, e.minor_code, e.serial).writeln;
	}
	catch {}
	return 0;
}

enum background_props_str = [
	"_XROOTPMAP_ID",
	"_XSETROOT_ID",
];


double eerp(double current, double target, double speed){
	auto dir = current > target ? -1 : 1;
	auto spd = abs(target-current)*speed+speed;
	spd = spd.min(abs(target-current)).max(0);
	return current + spd*dir;
}


void approach(ref double[2] current, double[2] target, double frt){
	current[0] = eerp(current[0], target[0], frt);
	current[1] = eerp(current[1], target[1], frt);
}


class CompositeManager {

	Picture backBuffer;
	Picture frontBuffer;

	int width;
	int height;

	//Damage damage;
	bool initialRepaint;

	CompositeClient[] clients;
	CompositeClient[] destroyed;
	x11.X.Window[] windows;

	x11.X.Window overlay;
	x11.X.Window reg_win;

	Property!(XA_CARDINAL, false) workspaceProperty;
	long workspace;

	Property!(XA_PIXMAP, false) rootmapId;
	Property!(XA_PIXMAP, false) setrootId;
	Pixmap root_pixmap;
	Picture root_picture;
	bool root_tile_fill;

	Visual* visual;
	int depth;

	enum ALPHA_STEPS = 256;

	Picture[ALPHA_STEPS] alpha;

	CompositeClient currentClient;
	CompositeClient lastClient;

	this(){

		//XSynchronize(wm.displayHandle, true);
		XInitThreads;
		width = DisplayWidth(wm.displayHandle, DefaultScreen(wm.displayHandle));
		height = DisplayHeight(wm.displayHandle, DefaultScreen(wm.displayHandle));

	    reg_win = XCreateSimpleWindow(wm.displayHandle, RootWindow(wm.displayHandle, 0), 0, 0, 1, 1, 0, None, None);
	    if(!reg_win)
	    	throw new Exception("Failed to create simple window");
	    "created simple window".writeln;
		//XCompositeUnredirectWindow(wm.displayHandle, reg_win, CompositeRedirectManual);
	    Xutf8SetWMProperties(wm.displayHandle, reg_win, cast(char*)"xcompmgr".toStringz, cast(char*)"xcompmgr".toStringz, null, 0, null, null, null);
	    Atom a = XInternAtom(wm.displayHandle, "_NET_WM_CM_S0", False);
	    XSetSelectionOwner(wm.displayHandle, a, reg_win, 0);
	    "selected CM_S0 owner".writeln;

		XCompositeRedirectSubwindows(wm.displayHandle, root, CompositeRedirectManual);
		"redirected subwindows".writeln;
		visual = DefaultVisual(wm.displayHandle, 0);
		depth = DefaultDepth(wm.displayHandle, 0);
		XSelectInput(wm.displayHandle, root,
		    SubstructureNotifyMask
		    | ExposureMask
		    | PropertyChangeMask);

 		//overlay = XCompositeGetOverlayWindow(wm.displayHandle, root);
	    //XSelectInput(wm.displayHandle, overlay, ExposureMask);

		XRenderPictureAttributes pa;
		pa.subwindow_mode = IncludeInferiors;
		auto format = XRenderFindVisualFormat(wm.displayHandle, visual);
		frontBuffer = XRenderCreatePicture(wm.displayHandle, root, format, CPSubwindowMode, &pa);
		Pixmap pixmap = XCreatePixmap(wm.displayHandle, root, DisplayWidth(wm.displayHandle, 0), DisplayHeight(wm.displayHandle, 0), DefaultDepth(wm.displayHandle, 0));
		backBuffer = XRenderCreatePicture(wm.displayHandle, pixmap, format, 0, null);
		XFreePixmap(wm.displayHandle, pixmap); // The picture owns the pixmap now
		XSync(wm.displayHandle, false);
		"created backbuffer".writeln;
		
		workspaceProperty = new Property!(XA_CARDINAL, false)(root, "_NET_CURRENT_DESKTOP");
		
		rootmapId = new Property!(XA_PIXMAP, false)(root, "_XROOTPMAP_ID");
		setrootId = new Property!(XA_PIXMAP, false)(root, "_XSETROOT_ID");

		wm.handlerAll[CreateNotify] ~= e => evCreate(e.xcreatewindow.window);
		wm.handlerAll[DestroyNotify] ~= e => evDestroy(e.xdestroywindow.window);
		wm.handlerAll[ConfigureNotify] ~= e => evConfigure(e);
		wm.handlerAll[MapNotify] ~= e => evMap(&e.xmap);
		wm.handlerAll[UnmapNotify] ~= e => evUnmap(&e.xunmap);
		wm.handlerAll[PropertyNotify] ~= e => evProperty(&e.xproperty);

		auto clientsProperty = new Property!(XA_WINDOW, true)(root, "_NET_CLIENT_LIST");

		"looking for windows".writeln;
		XFlush(wm.displayHandle);
		XGrabServer(wm.displayHandle);
		x11.X.Window root_return, parent_return;
		x11.X.Window* children;
		uint nchildren;
		XQueryTree(wm.displayHandle, root, &root_return, &parent_return, &children, &nchildren);
		if(children){
			foreach(window; children[0..nchildren]){
				if(root == root_return)
					evCreate(window);
			}
			XFree(children);
		}
		XUngrabServer(wm.displayHandle);
		XFlush(wm.displayHandle);

		get_root_tile;

		initAlpha;
		setupVerticalSync;
	}
	
	Picture colorPicture(bool argb, double a, double r, double g, double b){
		auto pixmap = XCreatePixmap(wm.displayHandle, root, 1, 1, argb ? 32 : 8);
		if(!pixmap)
			return None;
		XRenderPictureAttributes pa;
		pa.repeat = True;
		auto picture = XRenderCreatePicture(wm.displayHandle, pixmap, XRenderFindStandardFormat(wm.displayHandle, argb 	? PictStandardARGB32 : PictStandardA8), CPRepeat, &pa);
		if(!picture){
			XFreePixmap(wm.displayHandle, pixmap);
			return None;
		}
		XRenderColor c;
		c.alpha = (a * 0xffff).to!ushort;
		c.red =   (r * 0xffff).to!ushort;
		c.green = (g * 0xffff).to!ushort;
		c.blue =  (b * 0xffff).to!ushort;
		XRenderFillRectangle(wm.displayHandle, PictOpSrc, picture, &c, 0, 0, 1, 1);
		XFreePixmap(wm.displayHandle, pixmap);
		return picture;
	}

	void initAlpha(){
		foreach(i; 0..ALPHA_STEPS){
			if(i < ALPHA_STEPS-1)
				alpha[i] = colorPicture(false, i/cast(float)(ALPHA_STEPS-1), 0, 0, 0);
			else
				alpha[i] = None;				
		}
	}

	void evCreate(x11.X.Window window){
		XWindowAttributes wa;
		if(!XGetWindowAttributes(wm.displayHandle, window, &wa))
			return;
		auto client = new CompositeClient(window, [wa.x,wa.y], [wa.width,wa.height], wa);
		"found window %s".format(window).writeln;
		clients ~= client;
	}

	void evDestroy(x11.X.Window window){
		foreach(i, c; clients){
			if(c.windowHandle == window && !c.destroyed){
				c.destroyed = true;
				c.onHide;
				updateStack;
				return;
			}
		}
	}

	void evConfigure(XEvent* e){
		foreach(i, c; clients){
			if(c.windowHandle == e.xconfigure.window){
				c.processEvent(*e);
				updateStack;
				return;
			}
		}
		"could not configure window %s".format(e.xconfigure.window).writeln;
	}

	void evMap(XMapEvent* e){
		foreach(i, c; clients){
			if(c.windowHandle == e.window){
				c.onShow;
				return;
			}
		}
		evCreate(e.window);
	}

	void evUnmap(XUnmapEvent* e){
		foreach(c; clients){
			if(c.windowHandle == e.window){
				c.onHide;
				return;
			}
		}
	}

	void evProperty(XPropertyEvent* e){
		if(e.window == root){
			if(e.atom == workspaceProperty.property){
				auto oldWorkspace = workspace;
				workspace = workspaceProperty.get;
				foreach(c; clients){
					c.workspaceAnimation(workspace, oldWorkspace);
				}
			}
		}else{
			if(clients.length && e.atom == clients[0].workspaceProperty.property){
				foreach(c; clients){
					if(c.windowHandle == e.window){
						c.workspace = c.workspaceProperty.get;
						c.workspaceAnimation(workspace, workspace);
						running = false;
					}
				}
			}
		}
	}

	void get_root_tile(){
		assert(!root_pixmap);
		root_tile_fill = false;
		bool fill = false;
		Pixmap pixmap = None;
		foreach(bgprop; [rootmapId, setrootId]){
			auto res = bgprop.get;
			if(res){
				pixmap = res;
				break;
			}
		}
		if(!pixmap){
			pixmap = XCreatePixmap(wm.displayHandle, root, 1, 1, depth);
			fill = true;
		}
		XRenderPictureAttributes pa;
		pa.repeat = True,
		root_picture = XRenderCreatePicture(wm.displayHandle, pixmap, XRenderFindVisualFormat(wm.displayHandle, visual), CPRepeat, &pa);
		if(fill){
			XRenderColor c;
			c.red = c.green = c.blue = 0x8080;
			c.alpha = 0xffff;
			XRenderFillRectangle(wm.displayHandle, PictOpSrc, root_picture, &c, 0, 0, 1, 1);
		}
		root_tile_fill = fill;
		root_pixmap = pixmap;
		version(CONFIG_VSYNC_OPENGL){
			if (BKEND_GLX == ps.o.backend)
				return glx_bind_pixmap(ps, &root_tile_paint.ptex, root_pixmap, 0, 0, 0);
		}
	}

	void updateStack(){
		XGrabServer(wm.displayHandle);
		x11.X.Window root_return, parent_return;
		x11.X.Window* children;
		uint nchildren;
		XQueryTree(wm.displayHandle, root, &root_return, &parent_return, &children, &nchildren);
		if(children){
			auto clientsOld = clients;
			clients = [];
			foreach(window; children[0..nchildren]){
				foreach(c; clientsOld){
					if(c.windowHandle == window && !c.destroyed){
						clients ~= c;
					}
				}
			}
			auto destroyedOld = destroyed;
			destroyed = [];
			foreach(c; clientsOld ~ destroyedOld){
				if(c.destroyed){
					if(c.animation.fade.calculate > 0)
						destroyed ~= c;
					else
						c.destroy;
				}
			}
			XFree(children);
		}
		XUngrabServer(wm.displayHandle);
	}

	x11.X.Window vsyncWindow;

	void setupVerticalSync(){
		GLint[] att = [GLX_RGBA, GLX_DEPTH_SIZE, 24, GLX_DOUBLEBUFFER, 0];
		auto graphicsInfo = glXChooseVisual(wm.displayHandle, 0, att.ptr);
		auto graphicsContext = glXCreateContext(wm.displayHandle, graphicsInfo, null, True);
		writeln(graphicsContext);
		vsyncWindow = XCreateSimpleWindow(wm.displayHandle, root, 0, 0, 1, 1, 0, 0, 0);
		//XMapWindow(wm.displayHandle, vsyncWindow);
		glXMakeCurrent(wm.displayHandle, cast(uint)vsyncWindow, cast(__GLXcontextRec*)graphicsContext);
	}

	void verticalSync(){
		glXSwapBuffers(wm.displayHandle, cast(uint)vsyncWindow);
		glFinish();
	}

	void draw(){
		Animation.update;
		XRenderComposite(wm.displayHandle, PictOpSrc, root_picture, None, backBuffer, 0,0,0,0,0,0,width,height);
		foreach(c; clients ~ destroyed){
			auto alpha = c.animation.fade.calculate;
			if(c.picture && alpha > 0 && c.animation.pos.y.calculate > -height && c.animation.pos.y.calculate < height){

				auto scale = alpha/4+0.75;

				XTransform xform = {[
				    [XDoubleToFixed( 1 ), XDoubleToFixed( 0 ), XDoubleToFixed( 0 )],
				    [XDoubleToFixed( 0 ), XDoubleToFixed( 1 ), XDoubleToFixed( 0 )],
				    [XDoubleToFixed( 0 ), XDoubleToFixed( 0 ), XDoubleToFixed( scale )]
				]};
				XRenderSetPictureTransform(wm.displayHandle, c.picture, &xform);

				if(c.resizeGhost && (!c.animation.size[0].done || !c.animation.size[1].done)){
					XTransform xf = {[
						[XDoubleToFixed( 1 ), XDoubleToFixed( 0 ), XDoubleToFixed( 0 )],
						[XDoubleToFixed( 0 ), XDoubleToFixed( 1 ), XDoubleToFixed( 0 )],
						[XDoubleToFixed( 0 ), XDoubleToFixed( 0 ), XDoubleToFixed( scale )]
					]};
					XRenderSetPictureTransform(wm.displayHandle, c.resizeGhost, &xf);

					if(c.animation.size.x.completion != 1){
						XRenderComposite(
							wm.displayHandle,
							alpha < 1 || c.hasAlpha ? PictOpOver : PictOpSrc,
							c.resizeGhost,
							alpha < 1 ? this.alpha[((1-alpha)*ALPHA_STEPS).to!int] : None,
							backBuffer,
							0,0,0,0,
							(c.animation.pos.x.calculate + (1-scale)*c.size.x/2).lround.to!int,
							(c.animation.pos.y.calculate + (1-scale)*c.size.y/2).lround.to!int,
							(c.animation.size[0].calculate*scale).lround.to!int,
							(c.animation.size[1].calculate*scale).lround.to!int
						);
					}
				}

				alpha = alpha*(c.animation.size.x.completion).max(0);
				XRenderComposite(
					wm.displayHandle,
					alpha < 1 || c.hasAlpha ? PictOpOver : PictOpSrc,
					c.picture,
					alpha < 1 ? this.alpha[(alpha*ALPHA_STEPS).to!int] : None,
					backBuffer,
					0,0,0,0,
					(c.animation.pos.x.calculate + (1-scale)*c.size.x/2).lround.to!int,
					(c.animation.pos.y.calculate + (1-scale)*c.size.y/2).lround.to!int,
					(c.animation.size[0].calculate.min(c.size.x)*scale).lround.to!int,
					(c.animation.size[1].calculate.min(c.size.y)*scale).lround.to!int
				);

			}
		}
		//XSync(wm.displayHandle, false);
		//verticalSync;
		XRenderComposite(wm.displayHandle, PictOpSrc, backBuffer, None, frontBuffer, 0, 0, 0, 0, 0, 0, width, height);
	}

}

