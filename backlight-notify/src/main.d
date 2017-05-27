module volumeNotify;


import
    core.thread,
    std.conv,
	std.datetime,
	std.algorithm,
	std.stdio,
    std.process,
    std.string,
	ws.math,
	ws.wm;


int getBacklight(){
    auto c = "xbacklight -get".executeShell;
    if(c.status)
        writeln("failed");
    return c.output.strip.to!double.lround.to!int;
}


class NotifyWindow: Window {

	this(){
		super(200, 40, "Backlight Notify", true);
		move([50, 50]);
	}

    long backlight;
    int margin = 5;
    int barHeight = 4;
    SysTime showTime;

    override void onDraw(){
        draw.setColor([0,0,0]);
        draw.rect([0,0], size);
        draw.setColor([0.3,0.3,0.3]);
        draw.rect([margin, size.h/2-barHeight/2], [size.w-margin*2, barHeight]);
        draw.setColor([1, 1, 1]);
        auto width = (backlight.min(100)/100.0*(size.w-margin*2)).to!int;
        draw.rect([margin, size.h/2-barHeight/2], [width, barHeight]);
        width = ((backlight-100).max(0)/100.0*(size.w-margin*2)).to!int;
        draw.setColor([1,0,0]);
        draw.rect([margin, size.h/2-barHeight/2], [width, barHeight]);
        draw.finishFrame;
    }

}


void main(){
    auto window = new NotifyWindow;
    wm.add(window);
    window.hide;
    while(wm.hasActiveWindows){
        wm.processEvents;
        window.onDraw;
        auto backlight = getBacklight;
        if(window.backlight != backlight){
        	window.backlight = backlight;
        	window.showTime = Clock.currTime;
        	window.show;
        }else if(window.showTime < Clock.currTime - 2.seconds){
        	window.hide;
        }
        Thread.sleep(20.msecs);
    }

}
