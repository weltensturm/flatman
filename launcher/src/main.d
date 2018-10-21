module launcher.main;


import
    core.thread,

    std.algorithm,
    std.conv,
    std.process,
    std.parallelism,
    std.stdio,
    std.math,
    std.string,

    ws.wm,
    ws.gui.point,
    ws.gui.input,
    ws.time,

    common.screens,
    common.configLoader,
    
    launcher.config;

import x11.Xlib: XGrabKeyboard, XUngrabKeyboard;
import x11.X: GrabModeAsync, CurrentTime;


double sinApproach(double a){
    return (sin((a-0.5)*PI)+1)/2;
}


class AskWindow: Window {

    double showTime;
    int screenIndex;
    Keyboard.key armed;

    void delegate(Keyboard.key)[] answer;

    this(int screenIndex, Screen screen, void delegate(Keyboard.key) answer){
        this.answer ~= answer;
        this.screenIndex = screenIndex;
        super(screen.w, screen.h, "", true);
        move([screen.x, screen.y]);
        showTime = now;
        show;
        if(screenIndex == 0){
            XGrabKeyboard(wm.displayHandle, windowHandle, true, GrabModeAsync, GrabModeAsync, CurrentTime);
        }
    }

    override void close(){
        if(screenIndex == 0){
            XUngrabKeyboard(wm.displayHandle, CurrentTime);
        }
        super.close;
    }

    override void onKeyboard(Keyboard.key key, bool pressed){
        if(pressed){
            armed = key;
        }else if(armed == key){
            foreach(fn; answer)
                fn(key);
        }
    }

    override void onDraw(){
        if(hidden)
            return;
        draw.clear;
        auto alpha = ((now - showTime)*2).min(1).sinApproach;

        draw.setColor([0,0,0, alpha.to!float*0.7]);
        draw.rect([0,0], size);

        if(screenIndex == 0){
            draw.setFont("Monospace", 15);
            draw.setColor([1,1,1,alpha.to!float]);
            draw.text([size.w/2, size.h/2], 1, "Flatman crashed. Restart? [y/N]", 0.5);
        }
        super.onDraw;
    }

}



bool ask(){

    AskWindow[] windows;

    bool answer;

    auto onKey = (Keyboard.key key){
        if(['y', 'n', Keyboard.enter, Keyboard.escape].canFind(key)){
            if(key == 'y')
                answer = true;
            foreach(window; windows){
                window.hide;
                window.close;
            }
            windows = [];
        }
    };

    foreach(i, screen; screens(wm.displayHandle)){
        auto window = new AskWindow(i, screen, onKey);
        wm.add(window);
        windows ~= window;
    }

    while(wm.hasActiveWindows){
        wm.processEvents;
        windows.each!(a => a.onDraw());
    }

    return answer;

}


void autostart(){

    auto config = launcher.config.Config();
    config.fillConfigNested(["/etc/flatman/autostart", "~/.config/flatman/autostart"]);

    auto run = (string command){
        if(!command.strip.length)
            return;
        writeln("autostart '%s'".format(command));
        auto t = new Thread({
            auto pipes = pipeShell(command);
            auto reader = new Thread({
                foreach(line; pipes.stdout.byLineCopy){
                    if(line.length)
                        writeln("STDOUT: %s".format(line));
                }
            });
            reader.isDaemon = true;
            reader.start;
            foreach(line; pipes.stderr.byLineCopy){
                if(line.length)
                    writeln("STDERR: %s".format(line));
            }
            reader.yield;
            writeln("QUIT: %s".format(command));
            pipes.pid.wait;
        });
        t.isDaemon = true;
        t.start;
    };

    config.autostart.each!run;
}


void main(){

    bool autostarted = false;

    while(true){

        if(!autostarted){
            task({
                Thread.sleep(1.seconds);
                autostart;
            }).executeInNewThread;
            autostarted = true;
        }

        //auto flatman = "valgrind flatman-wm >> /tmp/flatman-debug.log 2>&1".spawnShell;
        auto flatman = "flatman-wm".spawnShell;
        auto status = flatman.wait();

        if(status != 0){
            if(!ask){
                return;
            }
        }
    }

}


