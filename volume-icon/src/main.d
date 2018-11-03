module icon;

import
	core.thread,

	std.algorithm,
	std.array,
	std.regex,
	std.process,
	std.stdio,
	std.string,
	std.conv,
	std.math,
	std.traits,

	x11.X,
	x11.Xatom,
	x11.Xlib,
	x11.Xutil,

	ws.gui.base,
	ws.wm,
	ws.x.draw,
	ws.x.drawSimple,
	ws.x.property,

	common.atoms,
	common.xembed,

	pulseaudio_h,
	pulseaudio;


enum SYSTEM_TRAY_REQUEST_DOCK = 0;


void delegate() IconClicked;
void delegate() OtherEvent;


template Event(alias T) if(isSomeFunction!T) {
	pragma(msg, fullyQualifiedName!T);
	static ReturnType!T delegate(Parameters!T)[] callbacks;
	struct Event {
		static void opCall(Args...)(Args args){
			foreach(cb; callbacks){
				cb(args);
			}
		}
		static void opOpAssign(string op)(ReturnType!T delegate(Parameters!T) cb) if(op == "~"){
			callbacks ~= cb;
		}
	}
}


void sendMessage(x11.X.Window window, long type, long[4] data){
	XClientMessageEvent ev;
	ev.type = ClientMessage;
	ev.window = window;
	ev.message_type = type;
	ev.format = 32;
	ev.data.l = [cast(long)CurrentTime] ~ data;
	XSendEvent(wm.displayHandle, window, false, StructureNotifyMask, cast(XEvent*) &ev);
}


auto sorted(alias Fn, T)(T array){
	array.sort!Fn;
	return array;
}


Atom[] listProperties(WindowHandle window){
	int returned;
	auto list = XListProperties(wm.displayHandle, window, &returned);
	auto result = list[0..returned].dup;
	XFree(list);
	return result;
}


auto bindNames(alias fn)() if(isCallable!fn) {
	class Wrapper {

		Parameters!fn parameterStorage;

		this(){
			parameterStorage = ParameterDefaults!fn;
		}

		static foreach(i, name; ParameterIdentifierTuple!fn){
			mixin("auto " ~ name ~ "(Parameters!fn[i] value){ parameterStorage[i] = value; return this; }");
			static if(is(Parameters!fn[i] == bool)){
				mixin("auto " ~ name ~ "(){ parameterStorage[i] = true; return this; }");
			}
		}

		auto opCall(){
			return fn(parameterStorage);
		}

	}

	return new Wrapper;

}


WindowHandle spawnWindow(
	int[2] pos = [0, 0],
	int[2] size = [1, 1],
	int[2] sizeMin = [1, 1],
	int[2] sizeMax = [int.max, int.max],
	bool inputOnly = false,
	ulong visualid = 0,
	bool redirect = false
){

	Visual* visual;
	int depth;

	if(visualid != 0){
		XVisualInfo visualQuery;
		visualQuery.visualid = visualid;
		int returned;
		auto visuals = XGetVisualInfo(wm.displayHandle, VisualIDMask, &visualQuery, &returned);
		visual = visuals[0].visual;
		depth = visuals[0].depth;
		XFree(visuals);
	}else{
		auto v = new XVisualInfo;
		XMatchVisualInfo(wm.displayHandle, DefaultScreen(wm.displayHandle), 32, TrueColor, v);
		visual = v.visual;
		depth = v.depth;
	}

	XSetWindowAttributes wa;
	wa.override_redirect = redirect;
	wa.bit_gravity = NorthWestGravity;
	wa.colormap = XCreateColormap(wm.displayHandle, DefaultRootWindow(wm.displayHandle), visual, AllocNone);

	ulong windowMask =
			CWBorderPixel |
			CWBitGravity |
			CWColormap |
			CWBackPixmap |
			(redirect ? CWOverrideRedirect : 0);

	auto window = XCreateWindow(
		wm.displayHandle,
		DefaultRootWindow(wm.displayHandle),
		pos.x, pos.y, size.w, size.h, 0,
		depth,
		inputOnly ? InputOnly : InputOutput,
		visual,
		windowMask,
		&wa
	);

	XSizeHints *size_hints  = XAllocSizeHints();
	size_hints.flags       = PSize | PBaseSize | PMinSize | PMaxSize;
	size_hints.base_width  = size.w;
	size_hints.base_height = size.h;
	size_hints.min_width   = sizeMin.w;
	size_hints.min_height  = sizeMin.h;
	size_hints.max_width   = sizeMax.w;
	size_hints.max_height  = sizeMax.h;
	XSetWMNormalHints(wm.displayHandle, window, size_hints);
	XFree(size_hints);

	return window;
}


class TrayIcon: ws.wm.Window {

	Pulseaudio pa;
	WindowHandle tray;

	this(Pulseaudio pa){
		this.pa = pa;

		tray = XGetSelectionOwner(wm.displayHandle, Atoms._NET_SYSTEM_TRAY_S0);

		auto visualid = new Property!(XA_VISUALID, false)(tray, "_NET_SYSTEM_TRAY_VISUAL").get.to!ulong;

		auto window = (bindNames!spawnWindow
			.visualid(visualid)
			.size([8,8])
			.sizeMin([8, 8])());

		super(window);
		setTitle("Flatman Volume Icon");
		new Property!(XA_CARDINAL, true)(window, "_XEMBED_INFO").set([XEMBED_VERSION, XEMBED_MAPPED]);
		_draw = new XDraw(this);
		wm.on(
			window,
			(XClientMessageEvent* e){
				writeln(*e);
				auto name = XGetAtomName(wm.displayHandle, e.message_type);
				XFree(name);
				if(e.message_type == Atoms._XEMBED){
					writeln(e.data.l);
					if(e.data.l[1] == XEMBED_EMBEDDED_NOTIFY){
						//show;
						//resize([32, 32]);
					}
				}
			},
			(XReparentEvent* e){
				if(e.parent != tray){
					writeln("reparent");
					hide;
				}
			}
		);

		auto eventMask =
				ExposureMask |
				StructureNotifyMask |
				SubstructureRedirectMask |
				KeyPressMask |
				KeyReleaseMask |
				KeymapStateMask |
				PointerMotionMask |
				ButtonPressMask |
				ButtonReleaseMask |
				EnterWindowMask |
				LeaveWindowMask |
				FocusChangeMask;

		XSelectInput(wm.displayHandle, window, eventMask);
	}

	void dock(){
		writeln("Docking to ", tray);
		tray = XGetSelectionOwner(wm.displayHandle, Atoms._NET_SYSTEM_TRAY_S0);
		sendMessage(tray, Atoms._NET_SYSTEM_TRAY_OPCODE, [SYSTEM_TRAY_REQUEST_DOCK, windowHandle, 0, 0]);
	}

	override void onDraw(){
		if(hidden)
			return;
		draw.clear;
		if(pa.defaultSink){
			draw.setColor([1,1,1]);
			auto barsWidth = size.w*2/3;
			draw.setColor([0.4,0.4,0.4,1]);
			foreach(barIndex; 0..barsWidth/2){
				draw.rect([size.w-barsWidth+barIndex*2,size.h/2-(size.h/5/2+barIndex)], [1, size.h/5+barIndex*2]);

			}
			foreach(barIndex; 0..barsWidth/2){
				if(pa.defaultSink.mute)
					break;
				double volume = pa.defaultSink.volume_percent/100.0;
				double barStrength = (barsWidth*volume - barIndex*2).max(0).min(1);
				if(!barStrength)
					break;
				if(barsWidth*(volume-1) <= barIndex*2)
					draw.setColor([1,1,1]);
				else
					draw.setColor([1,0.3,0.3]);
				int height = ((size.h/5/2+barIndex)*barStrength).lround.to!int;
				draw.rect([size.w-barsWidth+barIndex*2,size.h/2-height], [1, height*2]);
			}
			draw.setColor([0.7,0.7,0.7]);
			draw.rect([0, size.h/2-3], [size.w-barsWidth-1, 6]);
			foreach(i; 0..4){
				draw.rect([size.w-barsWidth-5+i, size.h/2-3-i], [1, 6+i*2]);
			}
		}
		super.onDraw;
	}

	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		if(button == Mouse.wheelDown || button == Mouse.wheelUp){
			auto direction = button == Mouse.wheelDown ? -1 : 1;
			if(pa.defaultSink){
				writeln(direction, " ", pa.defaultSink.volume_percent);
				pa.volume(pa.defaultSink, (pa.defaultSink.volume_percent/100.0+direction/30.0).min(2));
				resize(size);
			}
		}else if(button == Mouse.buttonLeft && !pressed){
			Event!IconClicked();
		}
	}

}

class Button: Base {

	void delegate()[] leftClick;
	void delegate()[] rightClick;

	bool pressed;
	bool mouseFocus;
	bool noClick;
	string text;

	this(string t, bool noClick){
		text = t;
		this.noClick = noClick;
	}

	override void onDraw(){
		if(!noClick && mouseFocus || pressed){
			draw.setColor([1,1,1, (!noClick && mouseFocus?0.2:0)+(pressed?0.1:0)]);
			draw.rect(pos, size);
		}
		draw.clip(pos.a+[15,0], [size.w-30, 30]);
		draw.setFont("Arial", 9);
		draw.text([pos.x+15, pos.y], size.h+1, text, 0);
		draw.noclip;
		super.onDraw();
	}

	override void onMouseButton(Mouse.button button, bool p, int x, int y){
		super.onMouseButton(button, p, x, y);
		if(!p && pressed){
			if(button == Mouse.buttonLeft)
				leftClick.each!(a => a());
			else if(button == Mouse.buttonRight)
				rightClick.each!(a => a());
			pressed = false;
		}
		pressed = p;
	}


	override void onMouseFocus(bool focus){
		mouseFocus = focus;
		if(!focus)
			pressed = false;
	}


}




class SinkRow: Base {

	Device sink;
	bool inUse;

	Slider slider;
	Button button;

	this(Pulseaudio pa, Device sink){
		this.sink = sink;
		float[3] yellow = [0.833f, 0.5f, 0.2f];
		float[3] green = [0, 0.7, 0.2];
		slider = addNew!CustomSlider(sink.type == sink.Type.sink ? yellow : green);
		slider.set(sink.volume_percent.min(100), 0, 100);
		slider.onSlide ~= (value){
			writeln(value);
			pa.volume(sink, value/100);
		};
		inUse = pa.defaultSink.index == sink.index && sink.type == sink.Type.sink
				|| pa.defaultSource.index == sink.index && sink.type == sink.Type.source;
		button = addNew!Button(sink.description, inUse);
		button.leftClick ~= {
			pa.setDefault(sink);
		};
	}

	override void resize(int[2] size){
		super.resize(size);
		button.move(pos.a+[0, 20]);
		button.resize([size.x, 20]);
		slider.move(pos.a+[15, 5]);
		slider.resize([size.x-30, 20]);
	}

	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		if(button == Mouse.wheelUp || button == Mouse.wheelDown){
			foreach(c; children)
				c.onMouseButton(button, pressed, x, y);
		}else{
			super.onMouseButton(button, pressed, x, y);
		}
	}

	override void onDraw(){
		if(inUse){
			draw.setColor([0.3,0.3,0.3]);
			draw.rect(pos, size);
		}
		draw.setColor([inUse ? 1 : 0.7,inUse ? 1 : 0.7,inUse ? 1 : 0.7]);
		super.onDraw();
	}

}


import ws.gui.slider;

class CustomSlider: Slider {

	float[3] color;

	this(float[3] color){
		this.color = color;
	}

	override void onDraw(){
		draw.setColor([0,0,0,1]);
		draw.rect(pos.a + [0, size.y/2-1], [size.x, 2]);
		auto pad = 6;
		auto width = size.h-pad*2;
		int x = cast(int)((current - min)/(max-min) * (size.x-width) + pos.x+width/2);
		draw.setColor(color);
		draw.rect(pos.a + [0, size.y/2-1], [x-pos.x, 2]);
		float[3] strong = color[]*1.2;
		draw.setColor(strong);
		draw.rect(pos.a + [x-pos.x-width/2, pad], [width,width]);
		float[3] weak = color[]/2;
		draw.setColor(weak);
		draw.rect(pos.a + [x-pos.x-width/2+pad/2, pad+pad/2], [width-pad,width-pad]);
	}

}


class AudioPanel: ws.wm.Window {

	Device[] sinks;
	Device[] sources;
	Pulseaudio pa;
	TrayIcon icon;

	this(TrayIcon icon, Pulseaudio pa){
		this.icon = icon;
		this.pa = pa;
		pa.onUpdate ~= &update;
		super(600, 30, "Flatman Volume Panel", true);
	}

	override void onShow(){
		update;
		XGrabPointer(
				wm.displayHandle,
				windowHandle,
				False,
				ButtonPressMask | ButtonReleaseMask | PointerMotionMask,
				GrabModeAsync,
				GrabModeAsync,
				None,
				None,
				CurrentTime
		);
		super.onShow;
	}

	override void onHide(){
		XUngrabPointer(wm.displayHandle, CurrentTime);
		super.onHide;
	}

	void update(){
		sinks = pa.sinks;
		sources = pa.sources;
		draw.setFont("Arial", 9);
		auto width = 400;//(sinks ~ sources).map!(a => draw.width(a.description)).fold!max+20;
		resize([width, (sinks ~ sources).length.to!int*50+20]);

		int x, y;
		x11.X.Window dummy;
		XTranslateCoordinates(wm.displayHandle, icon.windowHandle,
			DefaultRootWindow(wm.displayHandle), 0, 0, &x, &y, &dummy);

		move([x-width+icon.size.w, y+icon.size.h]);

		foreach(c; children)
			remove(c);
		long idx;
		foreach(i, sink; pa.sources.sorted!((a,b) => a.description > b.description)){
			auto row = addNew!SinkRow(pa, sink);
			row.move([0,idx.to!int*50]);
			row.resize([width, 50]);
				idx += 1;
		}
		foreach(i, sink; pa.sinks.sorted!((a,b) => a.description > b.description)){
			auto row = addNew!SinkRow(pa, sink);
			row.move([0,idx.to!int*50+20]);
			row.resize([width, 50]);
				idx += 1;
		}
	}

	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		if(pressed && (x < 0 || y < 0 || x > size.w || y > size.h)){
			hide;
		}
		super.onMouseButton(button, pressed, x, y);
	}

	override void onDraw(){
		draw.setColor([0.1,0.1,0.1]);
		draw.rect([0,0], size);
		draw.setColor([0.3,0.3,0.3]);
		draw.rect([15, sources.length.to!int*50+10], [size.w-30, 1]);
		super.onDraw;
	}

}


void main(string[] args){

	version(unittest){ import core.stdc.stdlib: exit; exit(0); }

	auto pa = new Pulseaudio("Flatman Volume Settings");
	auto icon = new TrayIcon(pa);
	auto main = new AudioPanel(icon, pa);
	Event!IconClicked ~= &main.show;
	wm.add(icon);
	wm.add(main);
	//icon.show;
	icon.dock;
	while(wm.hasActiveWindows){
		icon.onDraw;
		if(!main.hidden){
			main.onDraw;
		}
		pa.run;
		wm.processEvents;
		Thread.sleep(12.msecs);
	}
}
