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
	Property!(XA_CARDINAL, false) tabDirectionProperty;
	int tabDirection;

	override void hide(){}

	this(x11.X.Window window, int[2] pos, int[2] size, XWindowAttributes a){
		super(window);
		this.pos = pos;
		this.size = size;
		this.a = a;
		animation = new ClientAnimation(pos, size);
		isActive = true;
		XSelectInput(wm.displayHandle, windowHandle, PropertyChangeMask);
		currentTab = new Property!(XA_CARDINAL, false)(windowHandle, "_FLATMAN_TAB");
		currentTabs = new Property!(XA_CARDINAL, false)(windowHandle, "_FLATMAN_TABS");
		tabDirectionProperty = new Property!(XA_CARDINAL, false)(windowHandle, "_FLATMAN_TAB_DIR");
		workspaceProperty = new Property!(XA_CARDINAL, false)(windowHandle, "_NET_WM_DESKTOP");
		workspace = workspaceProperty.get;
		if(a.map_state & IsViewable)
			onShow;
	}
	
	void createPicture(){
		if(hidden)
			return;
		cleanup;
		"create picture".writeln;
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

		scale = 0;
		resizeGhostScale = 0;
	}
	
	void cleanup(){
		if(pixmap){
			XFreePixmap(wm.displayHandle, pixmap);
			pixmap = None;
		}
		if(picture){
			XRenderFreePicture(wm.displayHandle, picture);
			picture = None;
		}
	}

	double scale;

	void updateScale(double scale){
		if(this.scale == scale)
			return;
		this.scale = scale;
		XTransform xf = {[
			[XDoubleToFixed( 1 ), XDoubleToFixed( 0 ), XDoubleToFixed( 0 )],
			[XDoubleToFixed( 0 ), XDoubleToFixed( 1 ), XDoubleToFixed( 0 )],
			[XDoubleToFixed( 0 ), XDoubleToFixed( 0 ), XDoubleToFixed( scale )]
		]};
		XRenderSetPictureTransform(wm.displayHandle, picture, &xf);
	}

	double resizeGhostScale;

	void updateResizeGhostScale(double scale){
		if(scale == resizeGhostScale)
			return;
		resizeGhostScale = scale;
		XTransform xf = {[
			[XDoubleToFixed( 1 ), XDoubleToFixed( 0 ), XDoubleToFixed( 0 )],
			[XDoubleToFixed( 0 ), XDoubleToFixed( 1 ), XDoubleToFixed( 0 )],
			[XDoubleToFixed( 0 ), XDoubleToFixed( 0 ), XDoubleToFixed( scale )]
		]};
		XRenderSetPictureTransform(wm.displayHandle, resizeGhost, &xf);
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

	override void resized(int[2] size){
		if(animation.fade.completion < 0.1){
			animation.size.x.replace(size.x, size.x);
			animation.size.y.replace(size.y, size.y);
		}else{
			if(animation.size.w.done && animation.size.h.done){
				animation.size.x.change(size.x);
				animation.size.y.change(size.y);
			}else{
				animation.size.x.replace(size.x);
				animation.size.y.replace(size.y);
			}
		}
		resizeGhostSize = this.size;
		"resize %s %s old %s".format(getTitle, size, this.size).writeln;
		this.size = size;
		
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

	override void moved(int[2] pos){
		if(pos.y <= this.pos.y-manager.height || pos == this.pos)
			return;
		if(a.override_redirect || workspace == manager.workspace || workspace < 0){
			if(animation.fade.completion < 0.1){
				animation.pos.x.replace(pos.x, pos.x);
				animation.pos.y.replace(pos.y, pos.y);
			}else{
				if(animation.pos.x.done && animation.pos.y.done){
					animation.pos.x.change(pos.x);
					animation.pos.y.change(pos.y);
				}else{
					animation.pos.x.replace(pos.x);
					animation.pos.y.replace(pos.y);
				}
			}
		}
		this.pos = pos;
	}

	void workspaceAnimation(long ws, long old){
		workspace = workspaceProperty.get;
		if(workspace < 0)
			return;
		auto target = ws > workspace ? -manager.height+pos.y : manager.height;
		if(ws == workspace)
			target = pos.y;
		if(target != animation.pos.y.end)
			animation.pos.y.change(target);
	}

	override void onShow(){
		hidden = false;
		"onShow %s".format(getTitle).writeln;
		XSync(wm.displayHandle, false);
		createPicture;
		if(tabDirection){
			animation.fade.replace(1);
			if(tabDirection > 0){
				animation.pos.x.replace(pos.x+size.w, pos.x);
				animation.size.w.replace(0, size.w);
				animation.renderOffset.x.replace(0);
			}else{
				animation.pos.x.replace(pos.x);
				animation.renderOffset.x.replace(size.w, 0);
			}
			animation.pos.y.replace(pos.y);
			animation.size.w.replace(0, size.w);
			animation.size.h.replace(size.h);
		}else{
			animation.fade.change(1);
			animation.pos.x.replace(pos.x);
			animation.pos.y.replace(pos.y);
			animation.size.w.replace(size.w);
			animation.size.h.replace(size.h);
		}
	}

	override void onHide(){
		hidden = true;
		"onHide %s".format(getTitle).writeln;
		if(destroyed){
			animation.fade.change(0);
			animation.pos.x.replace(animation.pos.x.calculate);
			animation.pos.y.replace(animation.pos.y.calculate);
			animation.size.h.change(0);
		}else if(tabDirection){
			if(tabDirection > 0){
				animation.pos.x.change(pos.x+size.w);
				animation.size.w.change(0);
				animation.renderOffset.x.change(0);
			}else{
				animation.size.w.change(0);
				animation.renderOffset.x.change(size.w);
			}
		}else{
			animation.fade.change(0);
		}
		if(resizeGhostPixmap)
			XFreePixmap(wm.displayHandle, resizeGhostPixmap);
		resizeGhostPixmap = None;
		if(resizeGhost)
			XRenderFreePicture(wm.displayHandle, resizeGhost);
		resizeGhost = None;
	}

	override void gcInit(){}

}


double sinApproach(double a){
	return (sin((a-0.5)*PI)+1)/2;
}


class ClientAnimation {

	Animation[2] pos;
	Animation[2] size;
	Animation[2] renderOffset;
	Animation fade;
	Animation scale;

	this(int[2] pos, int[2] size){
		enum duration = 0.3;
		this.pos = [
			new Animation(pos.x, pos.x, duration, &sinApproach),
			new Animation(pos.y, pos.y, duration, &sinApproach)
		];
		this.size = [
			new Animation(size.x, size.x, duration, &sinApproach),
			new Animation(size.y, size.y, duration, &sinApproach)
		];
		this.renderOffset = [
			new Animation(0, 0, duration, &sinApproach),
			new Animation(0, 0, duration, &sinApproach)
		];
		fade = new Animation(0, 0, duration/2, &sinApproach);
	}

}

