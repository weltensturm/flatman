module battery.main;


import
	core.thread,
	core.stdc.signal,
	std.traits,
	std.math,
	std.stdio,
	std.file,
	std.conv,
	std.string,
	std.datetime,
	std.algorithm,
	x11.X,
	x11.Xlib,
	ws.gui.input,
	ws.wm,
	common.atoms;

enum SYSTEM_TRAY_REQUEST_DOCK =    0;

void sendMessage(x11.X.Window window, long type, long[4] data){
	XClientMessageEvent ev;
	ev.type = ClientMessage;
	ev.window = window;
	ev.message_type = type;
	ev.format = 32;
	ev.data.l[0] = CurrentTime;
	ev.data.l[1] = data[0];
	ev.data.l[2] = data[1];
	ev.data.l[3] = data[2];
	ev.data.l[4] = data[3];
	XSendEvent(wm.displayHandle, window, false, StructureNotifyMask, cast(XEvent*) &ev);
}


struct Atoms {
	Atom WM_PROTOCOLS;
	Atom WM_DELETE_WINDOW;
	Atom _NET_WM_NAME;
	Atom _NET_WM_MOVERESIZE;
	Atom _NET_ACTIVE_WINDOW;
	Atom UTF8_STRING;
	Atom NET_NAME;
	Atom _XEMBED;
	Atom _XEMBED_INFO;
	Atom _NET_SYSTEM_TRAY_OPCODE;
	Atom _NET_SYSTEM_TRAY_S0;
	Atom _NET_SYSTEM_TRAY_ORIENTATION;
	Atom MANAGER;
}

Atoms atoms;

class Icon: ws.wm.Window {

	long lastCharge;
	SysTime lastChargeTime;

	string status;
	long current;

	this(){
		super(1, 1, "flatman-battery-icon");
		lastCharge = "/sys/class/power_supply/BAT0/charge_now".readText.strip.to!long;
		lastChargeTime = Clock.currTime;
		dock;
	}

	void dock(){
		auto tray = XGetSelectionOwner(wm.displayHandle, atoms._NET_SYSTEM_TRAY_S0);
		writeln(tray);
		sendMessage(tray, atoms._NET_SYSTEM_TRAY_OPCODE, [SYSTEM_TRAY_REQUEST_DOCK, windowHandle, 0, 0]);
	}

	override void show(){
		writeln("show");
		super.show;
	}

	override void onHide(){
		writeln("hide");
	}

	override void onDraw(){
		auto status = "/sys/class/power_supply/BAT0/status".readText.strip;
		auto current = "/sys/class/power_supply/BAT0/charge_now".readText.strip.to!long;
		if(status == this.status && current == this.current)
			return;
		this.status = status;
		this.current = current;
		/+
		draw.setColor([1,0,0]);
		draw.rect([0,0], size);
		+/
		draw.setColor([0,0,0]);
		draw.rect([0,0], size);

		if(status == "Charging")
			draw.setColor([0,0.8,0]);
		else
			draw.setColor([0.5,0.5,0.5]);
		draw.rect([5, 3], [size[0]-10, 2]);
		draw.rect([5, size[1]-6], [size[0]-10, 2]);
		draw.rect([5, 3], [2, size[1]-7]);
		draw.rect([size[0]-7, 3], [2, size[1]-7]);
		draw.rect([7, size[1]-4], [size[0]-14, 2]);

		auto full = "/sys/class/power_supply/BAT0/charge_full".readText.strip.to!long;
		if(current != lastCharge){
			auto diff = (current-lastCharge).abs;
			auto diffTime = Clock.currTime - lastChargeTime;
			lastCharge = current;
			lastChargeTime += diffTime;
			if(status == "Charging")
				writeln((full-current)/diff*diffTime, " | ", diffTime);
			else
				writeln(current/diff*diffTime, " | ", diffTime);
		}
		auto charge = sqrt(current.to!double/full);
		auto height = (size[1]-11).to!int;
		auto chargeDec = (charge*height - (charge*height).to!int);
		//writeln(charge, ' ', chargeDec, ' ', charge*height);
		draw.setColor([1,1,1]);
		draw.rect([7, 5], [size[0]-14, ((size[1]-11)*charge.min(1)).to!int]);
		if(charge < 1){
			draw.setColor([chargeDec, chargeDec, chargeDec]);
			draw.rect([7, ((size[1]-11)*charge.min(1)).to!int+5], [size[0]-14, 1]);
		}
		draw.finishFrame;
	}

	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		writeln(button, ' ', pressed, ' ', x, ' ', y);
	}

}


bool running = true;


extern(C) nothrow @nogc @system void stop(int){
	running = false;
}


void main(){
	atoms.fillAtoms;
	auto icon = new Icon;
	writeln("add");
	wm.add(icon);
	icon.status = "";
	signal(SIGINT, &stop);	
	while(wm.hasActiveWindows && running){
		wm.processEvents;
		icon.onDraw;
		Thread.sleep(40.msecs);
	}
}
