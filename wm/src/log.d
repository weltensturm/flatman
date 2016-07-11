module flatman.log;


import flatman;


__gshared:


Tid loggerHandle;


void logger(){
	while(true){
		receive((string s){
			"/tmp/flatman.log".append(s);
		});
	}
}

shared static this(){
	loggerHandle = spawn(&logger);
}


void log(string s){
	auto text = "%s %s\n".format(Clock.currTime.toISOExtString[0..19], s);
	loggerHandle.send(text);
	text.write;
}
