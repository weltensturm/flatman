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
    x11.Xlib,

    ws.gui.base,
    ws.wm,

    common.atoms,

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


class TrayIcon: ws.wm.Window {

    Pulseaudio pa;

    this(Pulseaudio pa){
        this.pa = pa;
        super(10, 10, "Flatman Volume Icon", true);
    }

    void dock(){
        auto tray = XGetSelectionOwner(wm.displayHandle, Atoms._NET_SYSTEM_TRAY_S0);
        writeln(tray);
        sendMessage(tray, Atoms._NET_SYSTEM_TRAY_OPCODE, [SYSTEM_TRAY_REQUEST_DOCK, windowHandle, 0, 0]);
    }

    override void show(){
        super.show();
    }

    override void onDraw(){
        if(hidden)
            return;
        draw.setColor([0,0,0]);
        draw.rect([0,0], size);
        if(pa.defaultSink){
            draw.setColor([1,1,1]);
            foreach(bar; 0..size.w/2){
                if(size.w*pa.defaultSink.volume_percent/100.0 <= bar*2)
                    break;
                if(size.w*(pa.defaultSink.volume_percent-100)/100.0 <= bar*2)
                    draw.setColor([1,1,1]);
                else
                    draw.setColor([1,0.3,0.3]);
                draw.rect([bar*2,size.w/2-bar], [1, bar*2]);
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
        slider.set(sink.volume_percent, 0, 100);
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
        /+
        draw.clip(pos.a+[15,20], [size.w-30, 30]);
        draw.text([pos.x+15, pos.y+20], 30, sink.description, 0);
        draw.noclip;
        +/
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
        foreach(i, sink; pa.sources){
            auto row = addNew!SinkRow(pa, sink);
            row.move([0,idx.to!int*50]);
            row.resize([width, 50]);
                idx += 1;
        }
        foreach(i, sink; pa.sinks){
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
    auto pa = new Pulseaudio("Flatman Volume Settings");
    auto icon = new TrayIcon(pa);
    auto main = new AudioPanel(icon, pa);
    Event!IconClicked ~= &main.show;
    wm.add(icon);
    wm.add(main);
    icon.show;
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
