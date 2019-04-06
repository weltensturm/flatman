module volumeNotify;


import
    core.thread,
    std.conv,
	std.datetime,
	std.algorithm,
	std.stdio,
    std.process,
    std.string,
    std.file,
    std.path,
    ws.math,
	ws.wm;


int getBacklight(string path){
    auto current = path.buildPath("brightness").readText.strip.to!float;
    auto max = path.buildPath("max_brightness").readText.strip.to!float;
    return (current/max*100).to!int;
}


string backlightPath(){
    foreach(path; "/sys/class/backlight/".dirEntries(SpanMode.shallow)){
        writeln(path);
        if(path.buildPath("brightness").exists && path.buildPath("max_brightness").exists)
            return path;
    }
    throw new Exception("No backlight found");
}


class NotifyWindow: Window {

	this(){
		super(200, 40, "Backlight Notify", true);
		move([50, 50]);
	}

    long brightness;
    int margin = 5;
    int barHeight = 4;
    SysTime showTime;

    override void onDraw(){
        draw.setColor([0,0,0]);
        draw.rect([0,0], size);
        draw.setColor([0.3,0.3,0.3]);
        draw.rect([margin, size.h/2-barHeight/2], [size.w-margin*2, barHeight]);
        draw.setColor([1, 1, 1]);
        auto width = (brightness.min(100)/100.0*(size.w-margin*2)).to!int;
        draw.rect([margin, size.h/2-barHeight/2], [width, barHeight]);
        width = ((brightness-100).max(0)/100.0*(size.w-margin*2)).to!int;
        draw.setColor([1,0,0]);
        draw.rect([margin, size.h/2-barHeight/2], [width, barHeight]);
        draw.finishFrame;
    }

}


void main(){

	version(unittest){ import core.stdc.stdlib: exit; exit(0); }

    auto path = backlightPath;
    auto window = new NotifyWindow;
    wm.add(window);
    window.hide;
    while(wm.hasActiveWindows){
        wm.processEvents;
        auto brightness = getBacklight(path);
        if(window.brightness != brightness){
        	window.brightness = brightness;
        	window.showTime = Clock.currTime;
        	window.show;
        }else if(window.showTime < Clock.currTime - 2.seconds){
        	window.hide;
        }
        if(!window.hidden)
            window.onDraw;
        Thread.sleep(16.msecs);
    }

}
