module volumeNotify;


import
	core.thread,
    std.conv,
	std.datetime,
	std.algorithm,
	std.stdio,
	ws.math,
	ws.wm,
	pactl;


class NotifyWindow: Window {

	this(){
		super(200, 40, "Volume Notify", true);
		move([50, 50+40]);
	}

    long volume;
    int margin = 5;
    int barHeight = 4;
    SysTime showTime;

    override void onDraw(){
        draw.setColor([0,0,0]);
        draw.rect([0,0], size);
        draw.setColor([0.3,0.3,0.3]);
        draw.rect([margin, size.h/2-barHeight/2], [size.w-margin*2, barHeight]);
        draw.setColor([1, 0.5, 0]);
        auto width = (volume.min(100)/100.0*(size.w-margin*2)).to!int;
        draw.rect([margin, size.h/2-barHeight/2], [width, barHeight]);
        width = ((volume-100).max(0)/100.0*(size.w-margin*2)).to!int;
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
        auto selected = sinks.selected;
        auto volume = (selected.volume*100).to!int;
        if(window.volume != volume){
        	window.volume = volume;
        	window.showTime = Clock.currTime;
        	window.show;
        }else if(window.showTime < Clock.currTime - 2.seconds)
        	window.hide;
    	Thread.sleep(20.msecs);
    }

}
