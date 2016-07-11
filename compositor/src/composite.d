module composite.main;

import composite;

__gshared:


CompositeManager manager;


bool running = true;


extern(C) nothrow @nogc @system void stop(int){
	running = false;
}

void main(){
	try {
		signal(SIGINT, &stop);
		XSetErrorHandler(&xerror);
		root = XDefaultRootWindow(wm.displayHandle);
		new CompositeManager;
		double lastFrame = now;
		while(running){
			//XSync(wm.displayHandle, false);
			wm.processEvents;
			if(manager.restack){
				manager.updateStack;
				manager.restack = false;
			}
			manager.draw;
			auto frame = now;
			if(lastFrame-frame > 0)
				Thread.sleep((((lastFrame-frame))*1000).lround.msecs);
			lastFrame += 1.0/61;
		}
	}catch(Throwable t){
		writeln(t);
	}
	manager.cleanup;
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


Atom[string] atoms;

Atom atom(string n){
	if(n !in atoms)
		atoms[n] = XInternAtom(wm.displayHandle, n.toStringz, false);
	return atoms[n];
}



class CompositeManager {

	Picture backBuffer;
	Pixmap backBufferPixmap;
	GLXPixmap glxPixmap;
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

	bool restack;

	this(){

		manager = this;

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
		backBufferPixmap = XCreatePixmap(wm.displayHandle, root, DisplayWidth(wm.displayHandle, 0), DisplayHeight(wm.displayHandle, 0), depth);
		backBuffer = XRenderCreatePicture(wm.displayHandle, backBufferPixmap, format, 0, null);
		//XFreePixmap(wm.displayHandle, backBufferPixmap); // The picture owns the pixmap now

		XSync(wm.displayHandle, false);
		"created backbuffer".writeln;
		
		workspaceProperty = new Property!(XA_CARDINAL, false)(root, "_NET_CURRENT_DESKTOP");
		workspace = workspaceProperty.get;
		
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

		updateWallpaper;

		initAlpha;
		//setupVerticalSync;
		shadowT = shadow(0, -1, 30);
		shadowB = shadow(0, 1, 30);
		shadowL = shadow(-1, 0, 30);
		shadowR = shadow(1, 0, 30);
		shadowTl = shadow(-1, -1, 30);
		shadowTr = shadow(1, -1, 30);
		shadowBl = shadow(-1, 1, 30);
		shadowBr = shadow(1, 1, 30);
	}

	void cleanup(){
		foreach(client; clients)
			client.cleanup;
		XRenderFreePicture(wm.displayHandle, frontBuffer);
		XRenderFreePicture(wm.displayHandle, backBuffer);
	}
		
	Picture shadowT;
	Picture shadowB;
	Picture shadowL;
	Picture shadowR;
	Picture shadowTl;
	Picture shadowTr;
	Picture shadowBl;
	Picture shadowBr;


	Picture shadow(int x, int y, int width){
		auto id = width*100 + x*10 + y;
		auto pixmap = XCreatePixmap(wm.displayHandle, root, x ? width : 1, y ? width : 1, 32);
		XRenderPictureAttributes pa;
		pa.repeat = true;
		auto picture = XRenderCreatePicture(wm.displayHandle, pixmap, XRenderFindStandardFormat(wm.displayHandle, PictStandardARGB32), CPRepeat, &pa);
		XRenderColor c;
		c.red =   0;
		c.green = 0;
		c.blue =  0;
		if(x && y){
			foreach(x1; 0..width){
				foreach(y1; 0..width){
					double[2] dir = [(-x).max(0)*width-x1, (-y).max(0)*width-y1];
					auto len = asqrt(dir[0]*dir[0] + dir[1]*dir[1]).min(width);
					c.alpha = ((1-len/width).pow(3)/6*0xffff).to!ushort;
					XRenderFillRectangle(wm.displayHandle, PictOpSrc, picture, &c, x1, y1, 1, 1);
				}
			}
		}else{
			foreach(i; 0..width){
				c.alpha = ((i.to!double/width).pow(3)/6 * 0xffff).to!ushort;
				XRenderFillRectangle(wm.displayHandle, PictOpSrc, picture, &c, x ? (x > 0 ? width-i: i) : 0, y ? (y > 0 ? width-i : i) : 0, 1, 1);
			}
		}
		XFreePixmap(wm.displayHandle, pixmap);
		return picture;
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
		client.workspace = client.workspaceProperty.get;
		client.workspaceAnimation(client.workspace, client.workspace);
		"found window %s".format(window).writeln;
		clients ~= client;
	}

	void evDestroy(x11.X.Window window){
		foreach(i, c; clients){
			if(c.windowHandle == window && !c.destroyed){
				c.destroyed = true;
				c.onHide;
				restack = true;
				return;
			}
		}
	}

	void evConfigure(XEvent* e){
		if(e.xconfigure.window == .root){
			width = e.xconfigure.width;
			height = e.xconfigure.height;
			return;
		}
		foreach(i, c; clients){
			if(c.windowHandle == e.xconfigure.window){
				c.processEvent(e);
				restack = true;
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
			}else{
				foreach(bg; background_props_str){
					if(e.atom == bg.atom){
						updateWallpaper;
					}
				}
			}
		}else{
			if(!clients.length)
				return;
			if(![clients[0].workspaceProperty.property, clients[0].tabDirectionProperty.property].canFind(e.atom))
				return;
			CompositeClient client;
			foreach(c; clients){
				if(e.window == c.windowHandle){
					client = c;
					break;
				}
			}
			if(!client)
				return;
			if(e.atom == client.workspaceProperty.property){
				client.workspace = client.workspaceProperty.get;
				client.workspaceAnimation(workspace, workspace);
			}else if(e.atom == client.tabDirectionProperty.property){
				client.tabDirection = client.tabDirectionProperty.get.to!int;
			}
		}
	}

	void updateWallpaper(){
		if(root_pixmap)
			XFreePixmap(wm.displayHandle, root_pixmap);
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
			clients = new CompositeClient[nchildren];
			foreach(i, window; children[0..nchildren]){
				foreach(c; clientsOld){
					if(c.windowHandle == window && !c.destroyed){
						clients[i] = c;
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

	void setupVerticalSyncPixmap(){

		import derelict.opengl3.glx;
		import derelict.opengl3.glxext;

	    int[] pixmap_attribs = [
	        GLX_TEXTURE_TARGET_EXT, GLX_TEXTURE_2D_EXT,
	        GLX_TEXTURE_FORMAT_EXT, GLX_TEXTURE_FORMAT_RGB_EXT,
	        None
	    ];
	    glxPixmap = glXCreatePixmap(wm.displayHandle, null, cast(uint)backBuffer, pixmap_attribs.ptr);

		GLint[] att = [GLX_RGBA, GLX_DEPTH_SIZE, 24, GLX_DOUBLEBUFFER, 0];
		auto graphicsInfo = glXChooseVisual(wm.displayHandle, 0, att.ptr);
		auto graphicsContext = glXCreateContext(wm.displayHandle, graphicsInfo, null, True);
		glXMakeCurrent(wm.displayHandle, cast(uint)glxPixmap, cast(__GLXcontextRec*)graphicsContext);

	}

	void verticalSync(){
		glXSwapBuffers(wm.displayHandle, cast(uint)vsyncWindow);
		glFinish();
	}

	void verticalSyncDraw(){
		glViewport(0,0,width,height);
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glOrtho(0,1,0,1,0,1);
		glMatrixMode(GL_MODELVIEW);
		
		glBegin(GL_QUADS);
		glVertex2f(0,0);
		glVertex2f(1,0);
		glVertex2f(1,1);
		glVertex2f(0,1);
		glEnd();
		glXSwapBuffers(wm.displayHandle, cast(uint)vsyncWindow);
	}

	void drawClient(CompositeClient c){

		auto alpha = c.animation.fade.calculate;
		auto animPos = [c.animation.pos.x.calculate, c.animation.pos.y.calculate];
		auto animOffset = [c.animation.renderOffset.x.calculate, c.animation.renderOffset.y.calculate];
		auto animSize = [c.animation.size.x.calculate, c.animation.size.y.calculate];

		auto scale = alpha/4+0.75;

		int[2] pos = [
			(animPos.x + (1-scale)*c.size.x/2).lround.to!int,
			(animPos.y + (1-scale)*c.size.y/2).lround.to!int
		];

		int[2] size = [
			(animSize.w.min(c.size.w)*scale).lround.to!int,
			(animSize.h.min(c.size.h)*scale).lround.to!int 
		];

		c.updateScale(scale);

		if(c.resizeGhost && (!c.animation.size[0].done || !c.animation.size[1].done)){
			c.updateResizeGhostScale(scale);

			auto ghostAlpha = alpha; // * (1-c.animation.size.x.completion).max(0).min(1);
			if(c.animation.size.x.completion != 1){
				XRenderComposite(
					wm.displayHandle,
					ghostAlpha < 1 || c.hasAlpha ? PictOpOver : PictOpSrc,
					c.resizeGhost,
					ghostAlpha < 1 ? this.alpha[(ghostAlpha*ALPHA_STEPS).to!int] : None,
					backBuffer,
					animOffset.x.lround.to!int,
					animOffset.y.lround.to!int,
					0,
					0,
					pos.x,
					pos.y,
					(animSize.w*scale).lround.to!int,
					(animSize.h*scale).lround.to!int
				);
			}
		}

		alpha = alpha*(c.resizeGhost ? c.animation.size.x.completion : 1).max(0);
		XRenderComposite(
			wm.displayHandle,
			alpha < 1 || c.hasAlpha ? PictOpOver : PictOpSrc,
			c.picture,
			alpha < 1 ? this.alpha[(alpha*ALPHA_STEPS).to!int] : None,
			backBuffer,
			animOffset.x.lround.to!int,
			animOffset.y.lround.to!int,
			0,0,
			pos.x,
			pos.y,
			size.w,
			size.h
		);
		if(false)
			drawShadow(pos, size);
	}

	void drawShadow(int[2] pos, int[2] size){
		foreach(x; [-1, 0, 1]){
			if(x < 0 && pos.x<=0 || x > 0 && pos.x+size.w>=width)
				continue;
			foreach(y; [-1, 0, 1]){
				if(y < 0 && pos.y<=0 || y > 0 && pos.y+size.h>=height)
					continue;
				if(x == 0 && y == 0)
					continue;
				Picture s;
				final switch(10*x+y){
					case 10*0 + -1:
						s = shadowT;
						break;
					case 10*0 + 1:
						s = shadowB;
						break;
					case 10*-1 + 0:
						s = shadowL;
						break;
					case 10*1 + 0:
						s = shadowR;
						break;
					case 10*-1 + -1:
						s = shadowTl;
						break;
					case 10*1 + -1:
						s = shadowTr;
						break;
					case 10*-1 + 1:
						s = shadowBl;
						break;
					case 10*1 + 1:
						s = shadowBr;
						break;
				}
				XRenderComposite(
					wm.displayHandle,
					PictOpOver,
					s,
					None,
					backBuffer,
					0,
					0,
					0,0,
					pos.x + (x > 0 ? size.w-1 : 30*x),
					pos.y + (y > 0 ? size.h-1 : 30*y),
					x == 0 ? size.w-1 : 30,
					y == 0 ? size.h-1 : 30
				);
			}
		}
	}

	void draw(){
		CompositeClient[] windowsDraw;

		foreach(c; clients ~ destroyed){
			auto animPos = [c.animation.pos.x.calculate, c.animation.pos.y.calculate];
			auto animSize = [c.animation.size.x.calculate, c.animation.size.y.calculate];
			if(
				!c.picture
				|| c.animation.fade.calculate == 0
				|| animPos.x+animSize.w <= 0
				|| animPos.y+animSize.h <= 0
				|| animPos.x >= width
				|| animPos.y >= height)
				continue;
			/+
			if(!c.hasAlpha && c.animation.fade.calculate == 1)
				foreach(cq; windowsDraw.dup){
					auto cqAnimPos = [cq.animation.pos.x.calculate, cq.animation.pos.y.calculate];
					auto cqAnimSize = [cq.animation.size.x.calculate, cq.animation.size.y.calculate];
					if(
							cqAnimPos.x.max(0) - animPos.x >= 0
							&& cqAnimPos.y - animPos.y >= 0
							&& cqAnimPos.x+cqAnimSize.w <= animPos.x+animSize.w
							&& cqAnimPos.y+cqAnimSize.h <= animPos.y+animSize.h
							)
						windowsDraw = windowsDraw.filter!(a => a != cq).array;
				}
			+/
			windowsDraw ~= c;
		}		

		Animation.update;
		XRenderComposite(wm.displayHandle, PictOpSrc, root_picture, None, backBuffer, 0,0,0,0,0,0,width,height);

		foreach(c; windowsDraw){
			drawClient(c);
		}
		//verticalSync;
		//verticalSyncDraw;

		XRenderComposite(wm.displayHandle, PictOpSrc, backBuffer, None, frontBuffer, 0, 0, 0, 0, 0, 0, width, height);

	}

}

