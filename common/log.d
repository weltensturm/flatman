module common.log;


import
    core.sync.mutex,
    std.algorithm,
    std.stdio,
    std.string,
    std.file,
    std.range,
    std.datetime,
    std.concurrency;


private {
    __gshared Tid logger;
    shared Mutex mutex;
    __gshared int indent;
    __gshared void function(string)[] handlers;

    shared static this(){
        mutex = new shared Mutex;
        logger = spawn({
            bool run = true;
            while(run){
                receive(
                    (string s){
                        foreach(handler; handlers)
                            handler(s);
                        s.write;
                    },
                    (void function(string) handler){
                        handlers ~= handler;
                    },
                    (bool){
                        run = false;
                    }
                );
            }
        });
    }

    shared static ~this(){
        writeln("wtf");
        logger.send(false);
    }
}


struct Log {

    enum DEFAULT = "\033[0m";
    enum RED = "\033[31m";
    enum GREEN = "\033[32m";
    enum YELLOW = "\033[33m";
    enum GREY = "\033[90m";
    enum BOLD = "\033[1m";

    enum Level {
        dbg = 0,
        info = 1,
        warning = 2,
        error = 3
    }

    this(lazy string s, Level level=Level.info, string mod=__MODULE__){
        log(s, level, mod);
        synchronized(mutex)
            indent++;
    }

    ~this(){
        synchronized(mutex)
            indent--;
    }
    
    static void log(lazy string s, Level level, string mod=__MODULE__){
        if(level >= this.level){
            string text = format(s(), mod);
            logger.send(text);
        }
    }

    static void dbg(lazy string s, string mod=__MODULE__){
        log(s, Level.dbg, mod);
    }

    static void info(lazy string s, string mod=__MODULE__){
        log(s, Level.info, mod);
    }

    static void warning(lazy string s, string mod=__MODULE__){
        log(s, Level.warning, mod);
    }

    static void error(string s, string mod=__MODULE__){
        string text = format(RED ~ s, mod);
        logger.send(text);
    }

    static void setLevel(Level level){
        synchronized(mutex)
            this.level = level;
    }

    static void addHandler(void function(string) handler){
        logger.send(handler);
    }

    static void shutdown(){
        logger.send(false);
    }

    static string format(string s, string mod){
        int indent;
        synchronized(mutex)
            indent = .indent;
        auto currTime = Clock.currTime;
        return "%s%s.%03d%s %s%s %s\n".format(
                GREY,
                currTime.toISOExtString[0..19],
                min(currTime.fracSecs.total!"msecs", 999),
                GREEN,
                " ".replicate(indent*2),
                mod,
                DEFAULT ~ s ~ DEFAULT
        );
    }

    private shared static Level level = Level.error;

}


void log(lazy string s, string mod=__MODULE__){
    Log.info(s, mod);
}



