module icon;

import
	std.algorithm,
	std.regex,
	std.process,
	std.stdio,
	std.string,
	std.conv,
	std.math,
	gdk.Screen,
	gdk.Rectangle,
	glib.ListSG,
	cairo.Context,
	gtk.Main,
	gtk.VBox,
	gtk.Grid,
	gtk.Scale,
	gtk.Label,
	gtk.RadioButton,
	gtk.DrawingArea,
	gtk.StatusIcon,
	gtk.IconTheme,
	gtk.MainWindow;



class DeviceViewer: VBox {

	Device device;

	this(Device device){
		super(true, 0);
		this.device = device;
		auto scale = new Scale(GtkOrientation.HORIZONTAL, 0, 100, 1);
		scale.setValue(cast(long)(device.volume*100));
		scale.addOnValueChanged((range){
			device.setVolume(scale.getValue/100.0);
		});
		packStart(scale, false, false, 0);
	}

}


class DeviceContainer: VBox {

	Device[] devices;

	this(Device[] devices, string label){
		super(true, 0);
		this.devices = devices;
		RadioButton radio;
		packStart(new Label(label), false, false, 0);
		devices.each!((Device device){
			if(!radio)
				radio = new RadioButton(cast(ListSG)null, device.name);
			else
				radio = new RadioButton(radio, device.name);
			if(device.selected)
				radio.setActive(true);
			packStart(radio, false, false, 0);
			radio.addOnToggled((self){
				if(!radio && self.getActive){
					device.select;
				}
			});
			packStart(new DeviceViewer(device), false, false, 0);
		});
		radio = null;
	}

}


void spawnMainWindow(GdkRectangle area, int iconSize){
	auto w = new MainWindow("Sound Settings");
	w.setModal(true);
	w.setDefaultSize(300, cast(int)(sinks.length+sources.length*40+20));
	auto vbox = new VBox(true, 0);
	vbox.packStart(new DeviceContainer(sinks, "Output"), false, false, 0);
	vbox.packStart(new DeviceContainer(sources, "Input"), false, false, 0);
	w.add(vbox);
	w.grabFocus;
	w.addOnFocusOut((GdkEventFocus* c, w){
		w.hide;
		return true;
	});
	w.showAll;
	w.move(area.x-300+iconSize, area.y+iconSize);
}


void main(string[] args){
	Main.init(args);
	auto icon = new StatusIcon;
	icon.addOnButtonPress((GdkEventButton* event, icon){
		//spawnProcess("/home/weltensturm/Projects/d/flatman/speakers/flatman-speaker-menu");
		Screen screen;
		GdkRectangle area;
		GtkOrientation orientation;
		icon.getGeometry(screen, area, orientation);
		spawnMainWindow(area, icon.getSize);
		return true;
	});
	string visual = "audio-volume-medium";
	auto updateIcon = (int size){
		icon.setFromGicon(IconTheme.getDefault.loadIcon(visual, size, GtkIconLookupFlags.DIR_LTR));
	};
	icon.addOnScroll((GdkEventScroll* event, icon){
		auto sink = sinks.selected;
		writeln("vol ", sink.volume);
		if(event.direction == GdkScrollDirection.UP)
			sink.setVolume((sink.volume+0.05).min(1));
		else if(event.direction == GdkScrollDirection.DOWN)
			sink.setVolume((sink.volume-0.05).max(0));
		if(sink.volume > 2.0/3)
			visual = "audio-volume-high";
		else if(sink.volume > 1.0/3)
			visual = "audio-volume-medium";
		else
			visual = "audio-volume-low";
		updateIcon(icon.getSize);
		return true;
	});
	icon.addOnSizeChanged((size, icon){
		updateIcon(size);
		return true;
	});
	updateIcon(icon.getSize);
	Main.run;
}


string run(string command){
	auto c = command.executeShell;
	writeln(command);
	if(c.status)
		writeln("%s failed".format(command));
	return c.output;
}


Device[] sinks(){
	auto p = pipeShell("pactl list sinks");
	Device[] devices;
	foreach(s; p.stdout.byLine){
		if(s.canFind("Sink #")){
			devices ~= new Sink;
			devices[$-1].index = s.matchFirst(r"Sink #([0-9]+)")[1].to!int;
		}else{
			if(s.canFind("Name: ")){
				devices[$-1].systemName = s.matchFirst(r"Name: (.*)")[1].to!string;
			}else if(s.canFind("device.description")){
				devices[$-1].name = s.matchFirst(`device.description = "(.*)"`)[1].to!string;
			}else if(s.canFind("Volume: front")){
				devices[$-1].volume = s.matchFirst(r"([0-9]+)%")[1].to!double/100;
			}
		}
	}
	return devices;
}

Device[] sources(){
	auto p = pipeShell("pactl list sources");
	Device[] devices;
	foreach(s; p.stdout.byLine){
		if(s.canFind("Source #")){
			devices ~= new Source;
			devices[$-1].index = s.matchFirst(r"Source #([0-9]+)")[1].to!int;
		}else{
			if(s.canFind("Name: ")){
				devices[$-1].systemName = s.matchFirst(r"Name: (.*)")[1].to!string;
			}else if(s.canFind("device.description")){
				devices[$-1].name = s.matchFirst(`device.description = "(.*)"`)[1].to!string;
			}else if(s.canFind("Base Volume: ")){
				devices[$-1].volume = s.matchFirst(r"([0-9]+)%")[1].to!double/100;
				writeln(devices[$-1].volume);
			}
		}
	}
	return devices;
}

Device selected(Device[] sinks){
	auto p = pipeShell("pactl info");
	foreach(s; p.stdout.byLine){
		if(s.canFind("Default Sink:")){
			auto name = s.matchFirst(r"Default Sink: (.*)")[1];
			foreach(sink; sinks){
				if(sink.systemName == name)
					return sink;
			}
		}
	}
	return null;
}

class Device {

	int index;
	string systemName;
	string name;
	double volume;

	void select(){}

	void setVolume(double){}

	bool selected(){return false;}

}

class Sink: Device {

	override void select(){
		"pactl set-default-sink %s".format(systemName).run;
		auto p = pipeShell("pactl list sink-inputs");
		foreach(s; p.stdout.byLine){
			if(s.canFind("Sink Input #")){
				"pactl move-sink-input %s %s".format(s.matchFirst("Sink Input #([0-9]+)")[1], systemName).run;
			}
		}
	}

	override void setVolume(double volume){
		"pactl set-sink-volume %s %s%%".format(systemName, (volume*100).lround).run;
		this.volume = volume;
	}

	override bool selected(){
		auto p = pipeShell("pactl info");
		foreach(s; p.stdout.byLine){
			if(s.canFind("Default Sink:")){
				auto name = s.matchFirst(r"Default Sink: (.*)")[1];
				return systemName == name;
			}
		}
		return false;
	}

}

class Source: Device {

	override void select(){
		"pactl set-default-source %s".format(systemName).run;
		auto p = pipeShell("pactl list source-outputs");
		foreach(s; p.stdout.byLine){
			if(s.canFind("Source Output #")){
				"pactl move-source-output %s %s".format(s.matchFirst("Source Output #([0-9]+)")[1], systemName).run;
			}
		}
	}

	override void setVolume(double volume){
		"pactl set-source-volume %s %s%%".format(systemName, (volume*100).lround).run;
		this.volume = volume;
	}

	override bool selected(){
		auto p = executeShell("pactl info");
		return p.output.canFind("Default Source: %s".format(systemName));
	}
}
