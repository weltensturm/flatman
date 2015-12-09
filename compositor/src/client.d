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

	Animation[2] animatedPos;
	Animation[2] animatedSize;

	Animation fade;

	void hide(){}

	this(x11.X.Window window, int[2] pos, int[2] size, XWindowAttributes a){
		this.a = a;
		this.pos = pos;
		this.size = size;
		animatedPos = [new Animation(pos.x), new Animation(pos.y)];
		animatedSize = [new Animation(size.x), new Animation(size.y)];
		super(window);
		isActive = true;
		if(a.map_state & IsViewable)
			createPicture;
		workspaceProperty = new Property!(XA_CARDINAL, false)(windowHandle, "_NET_WM_DESKTOP");
		workspace = workspaceProperty.get;
		fade = new Animation(0, a.map_state & IsViewable, 0.3, a => a.pow(2));
	}

	void createPicture(){
		"create picture %s".format(getTitle).writeln;
		XWindowAttributes attr;
		XGetWindowAttributes(wm.displayHandle, windowHandle, &attr);
    	XRenderPictFormat *format = XRenderFindVisualFormat(wm.displayHandle, attr.visual);
		hasAlpha = (format.type == PictTypeDirect && format.direct.alphaMask);
		XRenderPictureAttributes pa;
		pa.subwindow_mode = IncludeInferiors;
		if(pixmap)
			XFreePixmap(wm.displayHandle, pixmap);
		pixmap = XCompositeNameWindowPixmap(wm.displayHandle, windowHandle);
		if(pixmap)
			picture = XRenderCreatePicture(wm.displayHandle, pixmap, format, CPSubwindowMode, &pa);
		else
			"could not create picture".writeln;
	}

	void destroy(){
		XFreePixmap(wm.displayHandle, pixmap);
	}

	override void resize(int[2] size){	
		auto spd = (this.animatedSize.x.calculate + this.animatedSize.y.calculate + 0.0).sqrt/1000;
		animatedSize = [
			new Animation(this.animatedSize.x.calculate, size.x, spd, a => a),
			new Animation(this.animatedSize.y.calculate, size.y, spd, a => a)
		];
		this.size = size;
		"resize %s %s".format(getTitle, size).writeln;
		createPicture;
	}

	override void move(int[2] pos){
		auto spd = (this.animatedPos.x.calculate + this.animatedPos.y.calculate + 0.0).sqrt/1000;
		animatedPos = [
			new Animation(this.animatedPos.x.calculate, pos.x, 0.2, a => a),
			new Animation(this.animatedPos.y.calculate, pos.y, 0.2, a => a)
		];
		this.pos = pos;
	}

	void workspaceAnimation(long ws){
		if(ws != workspace && workspace >= 0){
			if(ws > workspace){
				animatedPos.y = new Animation(this.animatedPos.y.calculate, -manager.height+pos.y, 0.3, a => a.pow(2));
			}else{
				animatedPos.y = new Animation(this.animatedPos.y.calculate, manager.height, 0.3, a => a.pow(2));
			}
		}else
			animatedPos.y = new Animation(this.animatedPos.y.calculate, pos.y, 0.3, a => a.pow(2));
	}

	override void onShow(){
		hidden = false;
		"onShow %s".format(getTitle).writeln;
		createPicture;
		fade = new Animation(fade.calculate, 1, 0.3, a => a.pow(2));
	}

	override void onHide(){
		hidden = true;
		"onHide %s".format(getTitle).writeln;
		fade = new Animation(fade.calculate, 0, 0.3, a => a.pow(2));
	}

	override void gcInit(){}

}
