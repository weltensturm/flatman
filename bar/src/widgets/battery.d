module bar.widget.battery;

import bar;



struct BatteryInfo {
    bool enabled;
    int hours;
    int minutes;
    int percent;
    bool charging;
}


BatteryInfo readBattery(){
    BatteryInfo result;
    try {
        result.enabled = true;
        auto match = ["acpi", "-b"].execute.output.matchFirst("([0-9]+)%, ((?:[0-9]+:?)+) (remaining|until charged)");
        if(!match.empty){
            auto split = match[2].split(":");
            result.hours = split[0].to!int;
            result.minutes = split[1].to!int;
            result.percent = match[1].to!int;
            result.charging = match[3] == "until charged";
        }
    }catch(Exception e){
        result.enabled = false;
    }
    return result;
}


class Battery: Widget {

    double lastUpdate = 0;

    enum UPDATE = 1;
    enum TIMEFRAME = 30;

    BatteryInfo batteryInfo;

    int[] battery;

    this(){
        lastUpdate = now;
    }

    override int width(){
        if(batteryInfo.enabled)
            return draw.width("000:0");
        return 0;
    }

    override void tick(){
        if(lastUpdate+UPDATE > now)
            return;
        lastUpdate += UPDATE;
        batteryInfo = readBattery;
        if(batteryInfo.enabled){
            battery ~= batteryInfo.hours*60+batteryInfo.minutes;
            if(battery.length > TIMEFRAME/UPDATE)
                battery = battery[$-(TIMEFRAME/UPDATE).to!int..$];
            auto avg = battery.sum/battery.length;
            auto averageMinutes = 0;
            foreach(v, i; battery){
                averageMinutes += v*i;
            }
            if(battery.length > 1)
                averageMinutes /= iota(1, battery.length).sum;
            batteryInfo.hours = averageMinutes/60;
            batteryInfo.minutes = averageMinutes - batteryInfo.hours*60;
        }
    }

    override void onDraw(){
        if(batteryInfo.enabled){
			enum baseline = 8.0;
			enum dangerRatio = 1/3.0;
            if(batteryInfo.charging){
                draw.setColor([0.3, 0.7, 0.3]);
            }else if(batteryInfo.hours == 0)
                draw.setColor([1, 0, 0]);
            else if(batteryInfo.hours*60+batteryInfo.minutes <= batteryInfo.percent*baseline*dangerRatio)
                draw.setColor([1, 1, 0]);
            else
                draw.setColor([0.9, 0.9, 0.9]);
            auto right = pos.x;
            right += draw.text([right, 5], "%02d".format(batteryInfo.percent.min(99)), 0);
            draw.setColor([0.5, 0.5, 0.5]);
            if(batteryInfo.hours < 10)
                draw.text([right, 5], "%01d:%01d".format(batteryInfo.hours, batteryInfo.minutes/10), 0);
            else
                draw.text([right, 5], "%01d:".format(batteryInfo.hours.min(99)), 0);
        }
    }

}
