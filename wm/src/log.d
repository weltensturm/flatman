module flatman.log;


import
	core.sync.mutex,
	std.stdio,
	std.string,
	std.file,
	std.range,
	std.datetime,
	std.concurrency,
	flatman.config;


private {
	__gshared Tid logger;
	shared Mutex mutex;
	__gshared int indent;

	shared static this(){
		mutex = new shared Mutex;
		logger = spawn({
            bool run = true;
			while(run){
				receive(
                    (string s){
					    "/tmp/flatman.log".append(s);
						s.write;
    				},
                    (bool){
                        run = false;
                    }
                );
			}
		});
	}
}


struct Log {

	enum DEFAULT = "\033[0m";
	enum RED = "\033[31m";
	enum GREEN = "\033[32m";
	enum YELLOW = "\033[33m";
	enum GREY = "\033[90m";
	enum BOLD = "\033[1m";

	this(lazy string s){
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
			indent = .indent;
		return "%s%s.%02d%s %s\n".format(
				GREY,
				Clock.currTime.toISOExtString[0..19],
				Clock.currTime.fracSecs.total!"msecs"/10,
				" ".replicate(indent*2),
				DEFAULT ~ s ~ DEFAULT
		);
	}

	static void error(string s){
		string text = format(RED ~ s);
		logger.send(s);
	}

	static void info(lazy string s){
		if(config.logging){
			string text = format(s());
			logger.send(text);
		}
	}

    static void shutdown(){
        logger.send(false);
    }

}


void log(lazy string s){
	Log.info(s);
}



