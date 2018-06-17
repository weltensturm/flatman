module bar.widget.clock;


import bar;


class ClockWidget: Widget {

    override int width(){
        return draw.width("00:00:00");
    }

    override void onDraw(){
		auto time = Clock.currTime;
        draw.setColor(config.theme.foreground);
        draw.text(pos.a + [0, 5], "%02d:%02d:%02d".format(time.hour, time.minute, time.second), 0);
    }

}
