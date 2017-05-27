module composite.client;


import composite;


class CompositeClient: ws.wm.Window {

	bool hasAlpha;
	Picture picture;
	Picture resizeGhost;
	Pixmap resizeGhostPixmap;
	int[2] resizeGhostSize;
	Pixmap pixmap;
	XWindowAttributes a;
	bool destroyed;

	ClientAnimation animation;

	Properties!(
		"workspace", "_NET_WM_DESKTOP", XA_CARDINAL, false,
		"tab", "_FLATMAN_TAB", XA_CARDINAL, false,
		"tabs", "_FLATMAN_TABS", XA_CARDINAL, false,
		"dir", "_FLATMAN_TAB_DIR", XA_CARDINAL, false,
		"width", "_FLATMAN_WIDTH", XA_CARDINAL, false,
		"overviewHide", "_FLATMAN_OVERVIEW_HIDE", XA_CARDINAL, false
	) properties;

	override void hide(){}

	this(x11.X.Window window, int[2] pos, int[2] size, XWindowAttributes a){
		super(window);
		this.pos = pos;
		this.size = size;
		this.a = a;
		hidden = true;
		animation = new ClientAnimation(pos, size);
		isActive = true;
		properties.window(window);
		XSync(wm.displayHandle, false);
		XSelectInput(wm.displayHandle, windowHandle, PropertyChangeMask);
		properties.workspace ~= (long workspace){
			workspaceAnimation(workspace, workspace);
		};
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
		if(a.override_redirect
				|| properties.workspace.value == manager.workspace
				|| properties.workspace.value < 0){
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
		if(properties.workspace.value < 0)
			return;
		auto target = ws > properties.workspace.value ? -manager.height+pos.y : manager.height;
		if(ws == properties.workspace.value)
			target = pos.y;
		if(target != animation.pos.y.end)
			animation.pos.y.change(target);
	}

	override void onShow(){
		hidden = false;
		"onShow %s".format(getTitle).writeln;
		XSync(wm.displayHandle, false);
		createPicture;
		animation.fade.change(1);
		animation.pos.x.replace(pos.x);
		animation.pos.y.replace(pos.y);
		animation.size.w.replace(size.w);
		animation.size.h.replace(size.h);
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
