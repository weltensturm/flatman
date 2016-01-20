module composite.client;


import composite;


class CompositeClient: ws.wm.Window {
	
	bool hasAlpha;
	Picture picture;
	Picture resizeGhost;
	Pixmap resizeGhostPixmap;
	int[2] resizeGhostSize;
	Pixmap pixmap;
	Property!(XA_CARDINAL, false) workspaceProperty;
	long workspace;
	XWindowAttributes a;
	bool destroyed;

	ClientAnimation animation;

	Property!(XA_CARDINAL, false) currentTab;
	Property!(XA_CARDINAL, false) currentTabs;

	override void hide(){}

	this(x11.X.Window window, int[2] pos, int[2] size, XWindowAttributes a){
		super(window);
		this.pos = pos;
		this.size = size;
		this.a = a;
		animation = new ClientAnimation(pos, size);
		isActive = true;
		if(a.map_state & IsViewable){
			hidden = false;
			animation.fade.replace(0, 1);
			createPicture;
		}
		XSelectInput(wm.displayHandle, windowHandle, PropertyChangeMask);
		currentTab = new Property!(XA_CARDINAL, false)(windowHandle, "_FLATMAN_TAB");
		currentTabs = new Property!(XA_CARDINAL, false)(windowHandle, "_FLATMAN_TABS");
		workspaceProperty = new Property!(XA_CARDINAL, false)(windowHandle, "_NET_WM_DESKTOP");
		workspace = workspaceProperty.get;
	}
	
	void createPicture(){
		if(hidden)
			return;
		if(pixmap)
			XFreePixmap(wm.displayHandle, pixmap);
		if(picture)
			XRenderFreePicture(wm.displayHandle, picture);
		"create picture %s".format(getTitle).writeln;
		if(!XGetWindowAttributes(wm.displayHandle, windowHandle, &a)){
			"could not get attributes".writeln;
			return;
		}
		if(!(a.map_state & IsViewable))
			return;
		XRenderPictFormat* format = XRenderFindVisualFormat(wm.displayHandle, a.visual);
		if(!format){
			"failed to find format".writeln;
			return;
		}
		hasAlpha = (format.type == PictTypeDirect && format.direct.alphaMask);
		XRenderPictureAttributes pa;
		pa.subwindow_mode = IncludeInferiors;
		pixmap = XCompositeNameWindowPixmap(wm.displayHandle, windowHandle);

		x11.X.Window root_return;
		int int_return;
		uint short_return;
		auto s = XGetGeometry(wm.displayHandle, pixmap, &root_return, &int_return, &int_return, &short_return, &short_return, &short_return, &short_return);
		if(!s){
			"XCompositeNameWindowPixmap failed for ".writeln(windowHandle);
			pixmap = None;
			picture = None;
			return;
		}

		picture = XRenderCreatePicture(wm.displayHandle, pixmap, format, CPSubwindowMode, &pa);
		XRenderSetPictureFilter(wm.displayHandle, picture, "best", null, 0);
	}
	
	void destroy(){
		if(pixmap)
			XFreePixmap(wm.displayHandle, pixmap);
		if(picture)
			XRenderFreePicture(wm.displayHandle, picture);
		if(resizeGhostPixmap)
			XFreePixmap(wm.displayHandle, resizeGhostPixmap);
		if(resizeGhost)
			XRenderFreePicture(wm.displayHandle, resizeGhost);
	}

	override void resize(int[2] size){
		hidden = false;
		auto spd = (animation.size.x.calculate + animation.size.y.calculate + 0.0).sqrt/1000;
		animation.size.x.change(size.x);
		animation.size.y.change(size.y);
		resizeGhostSize = this.size;
		this.size = size;
		"resize %s %s".format(getTitle, size).writeln;
		
		if(resizeGhostPixmap)
			XFreePixmap(wm.displayHandle, resizeGhostPixmap);
		resizeGhostPixmap = pixmap;
		pixmap = None;
		
		if(resizeGhost)
			XRenderFreePicture(wm.displayHandle, resizeGhost);
		resizeGhost = picture;
		picture = None;
		
		createPicture;
	}

	override void move(int[2] pos){
		if(pos.y <= this.pos.y-manager.height)
			return;
		auto spd = ((
				(pos.x-animation.pos.x.calculate).abs
				+ (pos.y-animation.pos.y.calculate).abs
			).sqrt/100).min(0.3);
		animation.pos.x.change(pos.x);
		animation.pos.y.change(pos.y);
		this.pos = pos;
	}

	void workspaceAnimation(long ws, long old){
		workspace = workspaceProperty.get;
		if(workspace < 0)
			return;
		//if(ws != workspace && workspace >= 0){
			auto target = ws > workspace ? -manager.height+pos.y : manager.height;
			if(ws == workspace)
				target = pos.y;
			if(target != animation.pos.y.end)
				animation.pos.y.change(target);
		//}else
		//	animation.pos.y.replace(ws > old ? manager.height+pos.y : -manager.height+pos.y, pos.y);
	}

	void switchTab(long dir, bool activate){
		/+
		if(activate){
			animation.pos.x.replace(pos.x-size.x/10*dir, pos.x);
			animation.fade.change(1);
		}else{
			animation.pos.x.change(pos.x-size.x/10*dir);
			animation.fade.change(0);
		}
		+/
	}

	override void onShow(){
		hidden = false;
		"onShow %s".format(getTitle).writeln;
		XSync(wm.displayHandle, false);
		XWindowAttributes wa;
		XGetWindowAttributes(wm.displayHandle, windowHandle, &wa);
		createPicture;
		animation.fade.change(1);
		animation.pos.x.replace(wa.x);
		animation.pos.y.replace(wa.y);
		animation.size.x.replace(wa.width);
		animation.size.y.replace(wa.height);
	}

	override void onHide(){
		hidden = true;
		"onHide %s".format(getTitle).writeln;
		animation.fade.change(0);
		if(resizeGhostPixmap)
			XFreePixmap(wm.displayHandle, resizeGhostPixmap);
		resizeGhostPixmap = None;
		if(resizeGhost)
			XRenderFreePicture(wm.displayHandle, resizeGhost);
		resizeGhost = None;
		//animation.pos.x.change(pos.x + (manager.currentTab > manager.lastTab ? -1 : 1) * size.x/10);
	}

	override void gcInit(){}

}


double sinApproach(double a){
	return (sin((a-0.5)*PI)+1)/2;
}


class ClientAnimation {

	Animation[2] pos;
	Animation[2] size;
	Animation fade;
	Animation scale;

	this(int[2] pos, int[2] size){
		this.pos = [new Animation(pos.x, pos.x, 0.3, &sinApproach), new Animation(pos.y, pos.y, 0.3, &sinApproach)];
		this.size = [new Animation(size.x, size.x, 0.3, &sinApproach), new Animation(size.y, size.y, 0.3, &sinApproach)];
		fade = new Animation(0, 0, 0.2, &sinApproach);
	}

}

