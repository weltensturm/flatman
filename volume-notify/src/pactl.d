module pactl;


import
	std.process,
	std.string,
	std.stdio,
	std.algorithm,
	std.regex,
	std.conv,
	std.math;

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
			}else if(s.canFind("Volume: front")){
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
