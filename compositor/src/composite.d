module composite.main;

import composite;

__gshared:


CompositeManager manager;


void main(){
	try {
		XSetErrorHandler(&xerror);
		root = XDefaultRootWindow(wm.displayHandle);
		manager = new CompositeManager;
		while(true){
			wm.processEvents;
			manager.draw;
			Thread.sleep(10.msecs);
		}
	}catch(Throwable t){
		writeln(t);
	}
}

extern(C) nothrow int xerror(Display* dpy, XErrorEvent* e){
	try {
		char[128] buffer;
		XGetErrorText(wm.displayHandle, e.error_code, buffer.ptr, buffer.length);
		//"XError: %s (major=%s, minor=%s, serial=%s)".format(buffer.to!string, e.request_code, e.minor_code, e.serial).writeln;
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

		XSynchronize(wm.displayHandle, true);

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
		auto format = XRenderFindVisualFormat(wm.displayHandle, visual);
		XSelectInput(wm.displayHandle, root,
		    SubstructureNotifyMask
		    | ExposureMask
		    | PropertyChangeMask);

 		//overlay = XCompositeGetOverlayWindow(wm.displayHandle, root);
	    //XSelectInput(wm.displayHandle, overlay, ExposureMask);

		XRenderPictureAttributes pa;
		pa.subwindow_mode = IncludeInferiors;
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
			foreach(c; clients){
				if(c.windowHandle == e.window){
					if(e.atom == c.workspaceProperty.property){
						c.workspace = c.workspaceProperty.get;
						c.workspaceAnimation(workspace, workspace);
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
		// Get the values of background attributes
		foreach(bgprop; [rootmapId, setrootId]){
			auto res = bgprop.get;
			if(res){
				pixmap = res;
				break;
			}
		}
		// Make sure the pixmap we got is valid
		//if(pixmap && !validate_pixmap(ps, pixmap))
		//	pixmap = None;
		// Create a pixmap if there isn't any
		if(!pixmap){
			pixmap = XCreatePixmap(wm.displayHandle, root, 1, 1, depth);
			fill = true;
		}
		// Create Picture
		XRenderPictureAttributes pa;
		pa.repeat = True,
		root_picture = XRenderCreatePicture(wm.displayHandle, pixmap, XRenderFindVisualFormat(wm.displayHandle, visual), CPRepeat, &pa);
		// Fill pixmap if needed
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
					if(c.windowHandle == window){
						clients ~= c;
					}
				}
			}
			XFree(children);
		}
		XUngrabServer(wm.displayHandle);
		if(clients.length){
			/+
			if(clients[0] != currentClient){
				lastClient = currentClient;
				currentClient = clients[0];
				writeln(currentClient, ' ', lastClient);
				if(lastClient)
					writeln(currentClient.getTitle, ' ', lastClient.getTitle);
				if(lastClient && currentClient.currentTabs.get == lastClient.currentTabs.get){
					auto dir = currentClient.currentTab.get > lastClient.currentTab.get ? -1 : 1;
					lastClient.switchTab(dir, false);
					currentClient.switchTab(dir*-1, true);
				}
			}
			+/
		}
	}

	void draw(){
		XRenderComposite(wm.displayHandle, PictOpSrc, root_picture, None, backBuffer, 0,0,0,0,0,0,width,height);
		foreach(c; clients){
			//if(!XGetWindowAttributes(wm.displayHandle, c.windowHandle, &c.a))
			//	continue;
			auto alpha = c.animation.fade.calculate;
			if(c.picture && alpha > 0){

				/+
				XTransform xform = {[
				    [XDoubleToFixed( c.size[0]/c.animation.size[0].calculate ), XDoubleToFixed( 0 ), XDoubleToFixed(     0 )],
				    [XDoubleToFixed( 0 ), XDoubleToFixed( c.size[1]/c.animation.size[1].calculate ), XDoubleToFixed(     0 )],
				    [XDoubleToFixed( 0 ), XDoubleToFixed( 0 ), XDoubleToFixed( 1 )]
				]};
				XRenderSetPictureTransform(wm.displayHandle, c.picture, &xform);
				+/

				auto scale = alpha/4+0.75;

				XTransform xform = {[
				    [XDoubleToFixed( 1 ), XDoubleToFixed( 0 ), XDoubleToFixed( 0 )],
				    [XDoubleToFixed( 0 ), XDoubleToFixed( 1 ), XDoubleToFixed( 0 )],
				    [XDoubleToFixed( 0 ), XDoubleToFixed( 0 ), XDoubleToFixed( scale )]
				]};
				XRenderSetPictureTransform(wm.displayHandle, c.picture, &xform);

				XRenderComposite(
					wm.displayHandle,
					alpha < 1 || c.hasAlpha ? PictOpOver : PictOpSrc,
					c.picture,
					alpha < 1 ? this.alpha[(alpha*ALPHA_STEPS).to!int] : None,
					backBuffer,
					0,0,0,0,
					(c.animation.pos.x.calculate + (1-scale)*c.size.x/2).lround.to!int,
					(c.animation.pos.y.calculate + (1-scale)*c.size.y/2).lround.to!int,
					(c.animation.size[0].calculate*scale).lround.to!int,
					(c.animation.size[1].calculate*scale).lround.to!int
				);

			}
		}
		XRenderComposite(wm.displayHandle, PictOpSrc, backBuffer, None, frontBuffer, 0, 0, 0, 0, 0, 0, width, height);
		foreach(i, c; clients){
			if(c.destroyed && c.animation.fade.done){
				if(i < clients.length-1)
					clients = clients[0..i] ~ clients[i+1..$];
				else
					clients = clients[0..i];
				c.destroy;
				return;
			}
		}
		//XRectangle r = {0, 0, cast(ushort)width, cast(ushort)height};
		//XserverRegion region = XFixesCreateRegion( wm.displayHandle, &r, 1 );
		//if(damage)
		//	XFixesDestroyRegion(wm.displayHandle, damage);
		//auto damage = region;

		//XFixesSetPictureClipRegion(wm.displayHandle, frontBuffer, 0, 0, damage);

		/+
		foreach(mon; monitors){
			for(auto client = mon.clients; client; client = client.next){
				//if(!client.isVisible || !client.isPainted)
				//	continue;
				// Update the region containing the area the window was last rendered at.
				//client.updateOnScreenRegion;
				// Only draw the window if it's opaque
				//if(client.isOpaque){
					// Set the clip region for the backbuffer to the damage region, and
					// subtract the clients shape from the damage region
					//XFixesSetPictureClipRegion(wm.displayHandle, backBuffer, 0, 0, damage);
					//XFixesSubtractRegion(wm.displayHandle, damage, damage, client.shape);
					XRenderComposite(wm.displayHandle, PictOpSrc, client.picture,
							None, backBuffer, 0, 0, 0, 0,
							client.pos.x,
							client.pos.y,
							client.size.w,
							client.size.h);
				//}
				// Save the clip region before the next client shape is subtracted from it.
				// We need to restore it later when we're drawing the shadow.
				//client.setShapeClip(damage);
				//translucents = client ~ translucents;
			}
		}
		+/

		// Draw any areas of the root window not covered by windows
		//XFixesSetPictureClipRegion(wm.displayHandle, backBuffer, 0, 0, damage);
		//XRenderComposite(wm.displayHandle, PictOpSrc, wallpaper, None, backBuffer, 0, 0, 0, 0, 0, 0, width, height);
		// Destroy the damage region
		//XFixesDestroyRegion(wm.displayHandle, damage);
		//damage = None;
		// Copy the back buffer contents to the root window
		//XFixesSetPictureClipRegion(wm.displayHandle, backBuffer, 0, 0, None);
		/+
		// If there's no damage, update the whole display
		if(damage == None || initialRepaint){
			XRectangle r = {0, 0, width, height};
			XserverRegion region = XFixesCreateRegion( wm.displayHandle, &r, 1 );
			if(damage)
				XFixesDestroyRegion(wm.displayHandle, damage);
			damage = region;
			initialRepaint = false;
		}
		// Use the damage region as the clip region for the root window
		XFixesSetPictureClipRegion(wm.displayHandle, frontBuffer, 0, 0, damage);
		// Draw each opaque window top to bottom, subtracting the bounding rect of
		// each drawn window from the clip region.
		ClientList::ConstIterator end = mList.constEnd();
		Client[] translucents;
		for(ClientList::ConstIterator it = mList.constBegin(); it != end; ++it){
			if(!client.isVisible || !client.isPainted)
				continue;
			// Update the region containing the area the window was last rendered at.
			client.updateOnScreenRegion;
			// Only draw the window if it's opaque
			if(client.isOpaque{
				// Set the clip region for the backbuffer to the damage region, and
				// subtract the clients shape from the damage region
				XFixesSetPictureClipRegion(wm.displayHandle, backBuffer, 0, 0, damage);
				XFixesSubtractRegion(wm.displayHandle, damage, damage, client.shape;
				XRenderComposite(wm.displayHandle, PictOpSrc, client.picture,
						None, backBuffer, 0, 0, 0, 0,
						client.pos.x, client.pos.y,
						client.size.w + client.borderWidth * 2,
						client.size.h + client.borderWidth * 2);
			}
			// Save the clip region before the next client shape is subtracted from it.
			// We need to restore it later when we're drawing the shadow.
			client.setShapeClip(damage);
			translucents = client ~ translucents;
		}
		// Draw any areas of the root window not covered by windows
		XFixesSetPictureClipRegion(wm.displayHandle, backBuffer, 0, 0, damage);
		XRenderComposite(wm.displayHandle, PictOpSrc, rootTile, None, backBuffer, 0, 0, 0, 0, 0, 0, width(), height());
		// Now walk the list backwards, drawing translucent windows and shadows.
		// That we draw bottom to top is important now since we're drawing translucent windows.
		end = translucents.constEnd();
		foreach(client; translucents){
			// Restore the previously saved clip region
			XFixesSetPictureClipRegion(wm.displayHandle, backBuffer, 0, 0, client.shapeClip;
			// Only draw the window if it's translucent
			// (we drew the opaque ones in the previous loop)
			if(!client.isOpaque
				XRenderComposite(wm.displayHandle, PictOpOver, client.picture,
					    client.alphaMask, backBuffer, 0, 0, 0, 0,
						client.pos.x + client.borderWidth,
						client.pos.y + client.borderWidth,
						client.width, client.height;
			// We don't need the clip region anymore
			client.destroyShapeClip;
		}
		translucents.clear;
		// Destroy the damage region
		XFixesDestroyRegion(wm.displayHandle, damage);
		damage = None;
		// Copy the back buffer contents to the root window
		XFixesSetPictureClipRegion(wm.displayHandle, backBuffer, 0, 0, None);
		XRenderComposite(wm.displayHandle, PictOpSrc, backBuffer, None, frontBuffer, 0, 0, 0, 0, 0, 0, width, height;
			+/
	}

}

