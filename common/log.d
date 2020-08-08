module common.log;


import
    core.sync.mutex,
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

    this(lazy string s, Level level=Level.info){
        log(s, level);
        synchronized(mutex)
            indent++;
    }

    ~this(){
        synchronized(mutex)
            indent--;
    }
    
    static void log(lazy string s, Level level){
        if(level >= this.level){
            string text = format(s());
            logger.send(text);
        }
    }

    static void dbg(lazy string s){
        log(s, Level.dbg);
    }

    static void info(lazy string s){
        log(s, Level.info);
    }

    static void warning(lazy string s){
        log(s, Level.warning);
    }

    static void error(string s){
        string text = format(RED ~ s);
        logger.send(s);
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

    private shared static Level level = Level.error;

}


void log(lazy string s){
    Log.info(s);
}



