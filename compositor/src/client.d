module composite.client;


import composite;


class CompositeClient: ws.wm.Window {
	
	bool hasAlpha;
	Picture picture;
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
		XWindowAttributes attr;
		XGetWindowAttributes(wm.displayHandle, windowHandle, &attr);
    	XRenderPictFormat *format = XRenderFindVisualFormat(wm.displayHandle, attr.visual);
    	if(!format){
    		"failed to find format".writeln;
    		return;
    	}
		hasAlpha = (format.type == PictTypeDirect && format.direct.alphaMask);
		XRenderPictureAttributes pa;
		pa.subwindow_mode = IncludeInferiors;
		pixmap = XCompositeNameWindowPixmap(wm.displayHandle, windowHandle);
		if(pixmap)
			picture = XRenderCreatePicture(wm.displayHandle, pixmap, format, CPSubwindowMode, &pa);
		else
			"could not create picture".writeln;
		XRenderSetPictureFilter(wm.displayHandle, picture, "best", null, 0);
	}
	
	void destroy(){
		if(pixmap)
			XFreePixmap(wm.displayHandle, pixmap);
		if(picture)
			XRenderFreePicture(wm.displayHandle, picture);
	}

	override void resize(int[2] size){	
		auto spd = (animation.size.x.calculate + animation.size.y.calculate + 0.0).sqrt/1000;
		animation.size.x.change(size.x);
		animation.size.y.change(size.y);
		this.size = size;
		"resize %s %s".format(getTitle, size).writeln;
		createPicture;
	}

	override void move(int[2] pos){
		auto spd = (animation.pos.x.calculate + animation.pos.y.calculate + 0.0).sqrt/1000;
		animation.pos.x.change(pos.x);
		animation.pos.y.change(pos.y);
		this.pos = pos;
	}

	void workspaceAnimation(long ws, long old){
		workspace = workspaceProperty.get;
		if(workspace < 0)
			return;
		if(ws != workspace && workspace >= 0){
			if(ws > workspace)
				animation.pos.y.change(-manager.height+pos.y);
			else
				animation.pos.y.change(manager.height);
		}else
			animation.pos.y.replace(ws > old ? manager.height+pos.y : -manager.height+pos.y, pos.y);
	}

	void switchTab(long dir, bool activate){
		if(activate){
			animation.pos.x.replace(pos.x-size.x/10*dir, pos.x);
			animation.fade.change(1);
		}else{
			animation.pos.x.change(pos.x-size.x/10*dir);
			animation.fade.change(0);
		}
	}

	override void onShow(){
		hidden = false;
		"onShow %s".format(getTitle).writeln;
		createPicture;
		animation.fade.change(1);
		animation.pos.x.replace(pos.x, pos.x);
		animation.pos.y.replace(pos.y, pos.y);
		animation.size.x.replace(size.x, size.x);
		animation.size.y.replace(size.y, size.y);
	}

	override void onHide(){
		hidden = true;
		"onHide %s".format(getTitle).writeln;
		XSync(wm.displayHandle, false);
		animation.fade.change(0);
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
		scale = new Animation(1, 1, 0.3);
	}

}

