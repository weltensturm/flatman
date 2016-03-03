module menu.popup;

import menu;

__gshared:


class ListPopup: ws.wm.Window {

	bool hasMouseFocus;

	struct Action {
		string name;
		void delegate() action;
	}

	this(Action[] actions){
		writeln("popup.new");
		Button[] buttons;
		foreach(action; actions){
			auto b = new Button(action.name);
			b.font = "Arial";
			b.fontSize = 9;
			b.style.bg.hover = [0.3,0.3,0.3,1];
			b.leftClick ~= action.action;
			buttons ~= b;
		}
		this(buttons);
	}

	this(Button[] buttons){
		super(1, 1, "Popup");

		int width = buttons.map!(a=>draw.width(a.text)).reduce!max+8;
		int height = 20*buttons.length.to!int;
		auto list = addNew!List;
		list.moveLocal([1,1]);
		list.entryHeight = 20;
		list.padding = 0;
		foreach(button; buttons){
			button.leftClick ~= {
				hide;
			};
			list.add(button);
		}

		int x;
		int y;
		ulong ulnull;
		int inull;
		uint uinull;
		XQueryPointer(dpy, .root, &ulnull, &ulnull, &x, &y, &inull, &inull, &uinull);
		x = x.max(0).min(menuWindow.size.w-width);
		y = y.max(0).min(menuWindow.size.h-height);
		XMoveResizeWindow(wm.displayHandle, windowHandle, x-1, y-1, width+4, height+4);
	}

	override void drawInit(){
		_draw = new XDraw(dpy, DefaultScreen(dpy), windowHandle, size.w, size.h);
		_draw.setFont("Arial", 9);
	}

	override void gcInit(){}

	override void resize(int[2] size){
		this.size = size;
		super.resize(size);
		foreach(c; children)
			c.resize(size.a-[2,2]);
		onDraw;
	}

	override void onDraw(){
		//if(!active)
		//	return;
		//draw.setColor([0.1,0.1,0.1]);
		draw.setColor([0.867,0.514,0]);
		draw.rect([0,0], size);
		super.onDraw;
		draw.finishFrame;
	}

	override void onMouseFocus(bool focus){
		hasMouseFocus = focus;
		onMouseMove(-5, -5);
		onDraw;
	}

	override void onMouseMove(int x, int y){
		super.onMouseMove(x, y);
		onDraw;
	}

	override void hide(){
		writeln("popup.hide");
		super.hide();
		menuWindow.popups = menuWindow.popups.without(this);
	}

	override void show(){
		writeln("popup.show");
		new CardinalProperty(windowHandle, "_NET_WM_DESKTOP").set(-1);
		new AtomProperty(windowHandle, "_NET_WM_WINDOW_TYPE").set(atom("_NET_WM_WINDOW_TYPE_DIALOG"));
		XSync(dpy,false);
		super.show;
		XRaiseWindow(dpy, windowHandle);
	}

}
