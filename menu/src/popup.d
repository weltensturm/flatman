module menu.popup;

import menu;

__gshared:


class ListPopup: ws.wm.Window {

	this(Button[] buttons){
		int width = buttons.map!(a=>a.text.length.to!int*12).reduce!max;
		int height = 25*buttons.length.to!int;
		auto list = addNew!List;
		foreach(button; buttons){
			button.resize([width,25]);
			button.leftClick ~= {hide;};
			list.add(button);
		}
		"size: %s".format([width,height]).writeln;
		resize([width,height]);
		int x;
		int y;
		ulong ulnull;
		int inull;
		uint uinull;
		XQueryPointer(dpy, .root, &ulnull, &ulnull, &x, &y, &inull, &inull, &uinull);
		move([x,y]);
		super(100, 100, "Popup");
	}

	override void drawInit(){
		_draw = new XDraw(dpy, DefaultScreen(dpy), windowHandle, size.w, size.h);
		_draw.setFont("Consolas:size=9", 9);
	}

	override void gcInit(){}

	override void resize(int[2] size){
		super.resize(size);
		foreach(c; children)
			c.resize(size);
	}

	override void onDraw(){
		if(!active)
			return;
		//draw.setColor([0.1,0.1,0.1]);
		draw.setColor([0.867,0.514,0]);
		draw.rect(pos, size);
		draw.setColor([0.1,0.1,0.1]);
		draw.rect(pos.a+[0,2], size.a-[2,2]);
		super.onDraw;
		draw.finishFrame;
	}

	override void show(){
		writeln("showing");
		new CardinalProperty(windowHandle, "_NET_WM_DESKTOP").set(-1);
		new AtomProperty(windowHandle, "_NET_WM_WINDOW_TYPE").set(atom("_NET_WM_WINDOW_TYPE_DIALOG"));
		XSync(dpy,false);
		super.show;
		XRaiseWindow(dpy, windowHandle);
	}

}
