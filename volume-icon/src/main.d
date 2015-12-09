module icon;

import
	std.algorithm,
	std.array,
	std.regex,
	std.process,
	std.stdio,
	std.string,
	std.conv,
	std.math,
	gdk.Screen,
	gdk.Rectangle,
	glib.ListSG,
	glib.Timeout,
	cairo.Context,
	gtk.Main,
	gtk.VBox,
	gtk.Grid,
	gtk.Scale,
	gtk.Label,
	gtk.RadioButton,
	gtk.Table,
	gtk.Notebook,
	gtk.DrawingArea,
	gtk.StatusIcon,
	gtk.Separator,
	gtk.IconTheme,
	gtk.MainWindow;



class DeviceViewer: Scale {

	Device device;

	this(Device device){
		super(GtkOrientation.HORIZONTAL, 0, 100, 1);
		this.device = device;
		setShowFillLevel(false);
		setValue(cast(long)(device.volume*100));
		addOnValueChanged((range){
			device.setVolume(getValue/100.0);
		});
		setMinSliderSize(100);
	}

}


class DeviceContainer: Table {

	Device[] devices;
	Device[] apps;

	this(Device[] devices, Device[] apps){
		super(cast(uint)(devices.length+apps.length+1), 2, 0);
		this.devices = devices;
		this.apps = apps;
		setBorderWidth(10);
		setColSpacings(10);
		RadioButton radio;
		int row;
		devices.each!((Device device){
			if(!radio)
				radio = new RadioButton(cast(ListSG)null, device.name);
			else
				radio = new RadioButton(radio, device.name);
			if(device.selected)
				radio.setActive(true);
			attach(
				radio,
				0, 1,
				row, row+1,
				GtkAttachOptions.FILL, GtkAttachOptions.SHRINK,
				0, 0
			);
			radio.addOnToggled((self){
				if(!radio && self.getActive){
					device.select;
				}
			});
			auto deviceViewer = new DeviceViewer(device);
			deviceViewer.setSizeRequest(50, 0);
			attach(
				deviceViewer,
				1, 2,
				row, row+1,
				GtkAttachOptions.FILL|GtkAttachOptions.EXPAND, GtkAttachOptions.SHRINK,
				0, 0
			);
			row++;
		});
		radio = null;
		attach(
			new Separator(GtkOrientation.VERTICAL), 0, 2, row, row+1,
			GtkAttachOptions.EXPAND|GtkAttachOptions.FILL, GtkAttachOptions.SHRINK,
			10, 10
		);
		row++;
		apps.each!((Device device){
			auto label = new Label(device.name);
			label.setJustify(GtkJustification.LEFT);
			attach(
				label,
				0, 1,
				row, row+1,
				GtkAttachOptions.SHRINK, GtkAttachOptions.SHRINK,
				0, 0
			);
			auto deviceViewer = new DeviceViewer(device);
			deviceViewer.setSizeRequest(50, 0);
			attach(
				deviceViewer,
				1, 2,
				row, row+1,
				GtkAttachOptions.FILL|GtkAttachOptions.EXPAND, GtkAttachOptions.SHRINK,
				0, 0
			);
			row++;
		});
	}

}

void spawnMainWindow(GdkRectangle area, int iconSize){
	auto w = new MainWindow("Sound Settings");
	w.setModal(true);
	w.setBorderWidth(2);
	w.setDefaultSize(300, cast(int)(sinks.length+sources.length*40));
	/+
	auto vbox = new VBox(true, 0);
	vbox.packStart(new DeviceContainer(sinks, "Output"), false, false, 0);
	vbox.packStart(new DeviceContainer(sources, "Input"), false, false, 0);
	w.add(vbox);
	+/
	auto nb = new Notebook;
	auto sinks = sinks.sort!("toUpper(a.name) < toUpper(b.name)", SwapStrategy.stable);
	auto sources = sources.sort!("toUpper(a.name) < toUpper(b.name)", SwapStrategy.stable);
	auto appsInput = appsInput.sort!("toUpper(a.name) < toUpper(b.name)", SwapStrategy.stable);
	auto appsOutput = appsOutput.sort!("toUpper(a.name) < toUpper(b.name)", SwapStrategy.stable);
	nb.appendPage(new DeviceContainer(sinks.array, appsOutput.array), "Output");
	nb.appendPage(new DeviceContainer(sources.array, appsInput.array), "Input");
	w.add(nb);
	bool focus;
	w.addOnFocusIn((GdkEventFocus* c, w){
		focus = true;
		return true;
	});
	w.addOnFocusOut((GdkEventFocus* c, w){
		if(focus)
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
	string visual;
	auto updateIcon = (int size){
		auto old = visual;
		auto sink = sinks.selected;
		if(sink.muted || sink.volume <= 0)
			visual = "audio-volume-muted";
		else if(sink.volume > 2.0/3)
			visual = "audio-volume-high";
		else if(sink.volume > 1.0/3)
			visual = "audio-volume-medium";
		else
			visual = "audio-volume-low";
		if(visual != old)
			icon.setFromGicon(IconTheme.getDefault.loadIcon(visual, size, GtkIconLookupFlags.DIR_LTR));
	};
	icon.addOnScroll((GdkEventScroll* event, icon){
		auto sink = sinks.selected;
		writeln("vol ", sink.volume);
		if(event.direction == GdkScrollDirection.UP)
			sink.setVolume((sink.volume+0.05).min(1));
		else if(event.direction == GdkScrollDirection.DOWN)
			sink.setVolume((sink.volume-0.05).max(0));
		updateIcon(icon.getSize);
		return true;
	});
	icon.addOnSizeChanged((size, icon){
		updateIcon(size);
		return true;
	});
	updateIcon(icon.getSize);
	new Timeout(400, { updateIcon(icon.getSize); return true; });
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
	auto p = executeShell("pactl list sinks");
	Device[] devices;
	foreach(s; p.output.splitLines){
		if(s.canFind("Sink #")){
			devices ~= new Sink;
			devices[$-1].index = s.matchFirst(r"Sink #([0-9]+)")[1].to!int;
		}else{
			if(s.canFind("Mute: "))
				devices[$-1].muted = s.canFind("Mute: yes");
			else if(s.canFind("Name: ")){
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
	auto p = executeShell("pactl list sources");
	Device[] devices;
	foreach(s; p.output.splitLines){
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
			}
		}
	}
	return devices;
}

Device selected(Device[] sinks){
	auto p = executeShell("pactl info");
	foreach(s; p.output.splitLines){
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


Device[] appsInput(){
	auto p = executeShell("pactl list source-outputs");
	Device[] devices;
	foreach(s; p.output.splitLines){
		if(s.canFind("Source Output #")){
			devices ~= new AppOutput;
			devices[$-1].index = s.matchFirst(r"Source Output #([0-9]+)")[1].to!int;
			devices[$-1].name = "unknown";
		}else if(s.canFind("application.name")){
			devices[$-1].name = s.matchFirst(`application.name = "(.*)"`)[1].to!string;
		}else if(s.canFind("Volume: ")){
			devices[$-1].volume = s.matchFirst(r"([0-9]+)%")[1].to!double/100;
		}
	}
	return devices;
}


Device[] appsOutput(){
	auto p = executeShell("pactl list sink-inputs");
	Device[] devices;
	foreach(s; p.output.splitLines){
		if(s.canFind("Sink Input #")){
			devices ~= new AppOutput;
			devices[$-1].index = s.matchFirst(r"Sink Input #([0-9]+)")[1].to!int;
			devices[$-1].name = "unknown";
		}else if(s.canFind("application.name")){
			devices[$-1].name = s.matchFirst(`application.name = "(.*)"`)[1].to!string;
		}else if(s.canFind("Volume: ")){
			devices[$-1].volume = s.matchFirst(r"([0-9]+)%")[1].to!double/100;
		}
	}
	return devices;
}


class Device {

	int index;
	string systemName;
	string name;
	double volume;
	bool muted;

	void select(){}

	void setVolume(double){}

	bool selected(){return false;}

}

class Sink: Device {

	override void select(){
		"pactl set-default-sink %s".format(systemName).run;
		auto p = executeShell("pactl list sink-inputs");
		foreach(s; p.output.splitLines){
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
		auto p = executeShell("pactl info");
		foreach(s; p.output.splitLines){
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
		auto p = executeShell("pactl list source-outputs");
		foreach(s; p.output.splitLines){
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

class AppInput: Device {

	override void setVolume(double volume){
		"pactl set-source-output-volume %s %s%%".format(index, (volume*100).lround).run;
		this.volume = volume;
	}

}

class AppOutput: Device {

	override void setVolume(double volume){
		"pactl set-sink-input-volume %s %s%%".format(index, (volume*100).lround).run;
		this.volume = volume;
	}

}