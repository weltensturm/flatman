module dock.compositeClient;

import dock;


class CompositeClient: ws.wm.Window {
	
	bool hasAlpha;
	Picture picture;
	Pixmap pixmap;
	Damage damage;
	Property!(XA_CARDINAL, false) workspaceProperty;
	long workspace;
	XWindowAttributes a;

	this(x11.X.Window window, int[2] pos, int[2] size, XWindowAttributes a){
		this.pos = pos;
		this.size = size;
		this.a = a;
		super(window);
		isActive = true;
		if(a.map_state & IsViewable){
			hidden = false;
			createPicture;
		}
		XSelectInput(wm.displayHandle, windowHandle, PropertyChangeMask);
		workspaceProperty = new Property!(XA_CARDINAL, false)(windowHandle, "_NET_WM_DESKTOP");
		workspace = workspaceProperty.get;
		damage = XDamageCreate(wm.displayHandle, window, XDamageReportNonEmpty);
	}
	
    override void gcInit(){}

	void createPicture(){
		if(hidden)
			return;
		if(pixmap)
			XFreePixmap(dpy, pixmap);
		if(picture)
			XRenderFreePicture(dpy, picture);

		XWindowAttributes attr;
		XGetWindowAttributes(dpy, windowHandle, &attr);
    	XRenderPictFormat* format = XRenderFindVisualFormat(dpy, attr.visual);
    	if(!format)
    		return;
		hasAlpha = (format.type == PictTypeDirect && format.direct.alphaMask);
		XRenderPictureAttributes pa;
		pa.subwindow_mode = IncludeInferiors;
		pixmap = XCompositeNameWindowPixmap(dpy, windowHandle);

		x11.X.Window root_return;
		int int_return;
		uint short_return;
		auto s = XGetGeometry(wm.displayHandle, pixmap, &root_return, &int_return, &int_return, &short_return, &short_return, &short_return, &short_return);
		if(!s){
			"XCompositeNameWindowPixmap failed".writeln;
			pixmap = None;
			picture = None;
			return;
		}

		picture = XRenderCreatePicture(dpy, pixmap, format, CPSubwindowMode, &pa);
		XRenderSetPictureFilter(dpy, picture, "best", null, 0);
	}
	
	void destroy(){
		if(pixmap)
			XFreePixmap(wm.displayHandle, pixmap);
		if(picture)
			XRenderFreePicture(wm.displayHandle, picture);
		XDamageDestroy(dpy, damage);
	}

	override void resize(int[2] size){
		this.size = size;
		createPicture;
	}

	override void move(int[2] pos){
		this.pos = pos;
	}

	override void onHide(){
		hidden = true;
	}

	override void onShow(){
		hidden = false;
		createPicture;
	}

}
