module flatman.log;


import flatman;


__gshared:


private static Mutex mutex;

shared static this(){
	Log.loggerHandle = spawn(&Log.logger);
	mutex = new Mutex;
}


struct Log {

	string dummy;

	enum DEFAULT = "\033[0m";
	enum RED = "\033[31m";
	enum GREEN = "\033[32m";
	enum YELLOW = "\033[33m";
	enum GREY = "\033[90m";
	enum BOLD = "\033[1m";

	private static Tid loggerHandle;

	private static void logger(){
		while(true){
			receive((string s){
				"/tmp/flatman.log".append(s);
			});
		}
	}

	static int indent;

	this(string s){
		info(s);
		synchronized(mutex)
			indent++;
	}

	~this(){
		synchronized(mutex)
			indent--;
	}

	static string format(string s){
		int indent;
		synchronized(mutex)
			indent = this.indent;
		return "%s%s.%02d%s %s\n".format(
				GREY,
				Clock.currTime.toISOExtString[0..19],
				Clock.currTime.fracSecs.total!"msecs"/10,
				" ".replicate(indent*8),
				DEFAULT ~ s ~ DEFAULT
		);
	}

	static void error(string s){
		auto text = format(s);
		"/tmp/flatman.log".append(s);
		text.write;
	}

	static void fallback(string s){
		auto text = format(s);
		"/tmp/flatman.log".append(s);
		text.write;
	}

	static void info(string s){
		auto text = format(s); 
		loggerHandle.send(text);
		text.write;
	}

}


void log(string s){
	Log.info(s);
}
