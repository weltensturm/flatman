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


class SinkRow: Base {

    Device sink;

    this(Device sink){
        this.sink = sink;
        import ws.gui.slider;
        auto slider = addNew!Slider;
        slider.set(sink.volume_percent, 0, 100);
        slider.onSlide ~= (value){
            writeln(value);
        };
    }

    override void resize(int[2] size){
        super.resize(size);
        foreach(c; children)
            c.resize([size.x, 20]);
    }

    override void onDraw(){
        draw.setColor([1,1,1]);
        draw.text([pos.x+5, pos.y+20], 30, sink.description);
        super.onDraw();
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
        super(600, 30, "Flatman Volume Panel", true);
    }

    override void onShow(){
        sinks = pa.sinks;
        sources = pa.sources;
        draw.setFont("sans", 9);
        auto width = sinks.map!(a => draw.width(a.description)).fold!max+20;
        resize([width, sinks.length.to!int*50]);
        writeln(icon.pos.x, ' ', size.w, ' ', icon.size.w);

        int x, y;
        x11.X.Window dummy;
        XTranslateCoordinates(wm.displayHandle, icon.windowHandle, DefaultRootWindow(wm.displayHandle), 0, 0, &x, &y, &dummy);

        move([x-size.w+icon.size.w, y+icon.size.h]);
        super.onShow;
    
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

        foreach(c; children)
            remove(c);
        foreach(i, sink; pa.sinks){
            auto row = addNew!SinkRow(sink);
            row.move([0,i.to!int*50]);
            row.resize([width, 50]);
        }
    }

    override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
        if(pressed && (x < 0 || y < 0 || x > size.w || y > size.h)){
            XUngrabPointer(wm.displayHandle, CurrentTime);
            hide;
        }
        super.onMouseButton(button, pressed, x, y);
    }

    override void onDraw(){
        draw.setColor([0.1,0.1,0.1]);
        draw.rect([0,0], size);
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