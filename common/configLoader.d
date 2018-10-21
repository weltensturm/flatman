module common.configLoader;


import
    std.process,
    std.traits,
    std.stdio,
    std.path,
    std.string,
    std.conv,
    std.file,
    std.algorithm,
    std.array,
    std.range,
    ws.decode,
    ws.inotify;


class ConfigException: Exception {
    this(string msg){
        super(msg);
    }
}


private {

    struct Entry {
        string name;
        string value;
    }

    bool endpoint(T)(string name){
        foreach(field; FieldNameTuple!T){
            string splitName;
            foreach(c; field){
                if(c.toUpper == c.to!dchar && c != '_')
                    splitName ~= " " ~ c.toLower.to!string;
                else if(c == '_')
                    splitName ~= "-";
                else
                    splitName ~= c;
            }
            if(splitName == name){
                mixin("return is(typeof(T." ~ field ~ ") == string[]);");
            }
        }
        return false;
    }

    void loadBlock(T)(string block, string namespace, ref Entry[] values){
        Decode.text(block, (name, value, isBlock){
            if(isBlock && !endpoint!T(name))
                loadBlock!T(value, namespace ~ " " ~ name, values);
            else
                foreach(l; value.splitLines)
                    values ~= Entry((namespace ~ " " ~ name).strip, l.strip);
        });
    }

}


void fillConfig(T)(ref T config, string[] paths){

    Entry[] values;

    foreach(path; paths){
        if(!path.exists){
            try {
                path.write("");
            }catch(FileException e){}
        }else{
            loadBlock!T(path.expandTilde.readText, "", values);
        }
    }

    foreach(field; FieldNameTuple!T){
        string splitName;
        foreach(c; field){
            if(c.toUpper == c.to!dchar && c != '_')
                splitName ~= " " ~ c.toLower.to!string;
            else if(c == '_')
                splitName ~= "-";
            else
                splitName ~= c;
        }
        auto filtered = values.filter!(a => a.name == splitName && a.value.strip.length).array;

        if(!filtered.length)
            throw new ConfigException("Error in config: could not find value " ~ splitName);
        
        mixin("enum isList = is(typeof(T." ~ field ~ ") == string[]);");
        
        try {
            static if(isList){
                foreach(entry; filtered)
                    mixin("config." ~ field ~ " ~= entry.value;");
            }else{
                mixin("config." ~ field ~ " = filtered[$-1].value.to!(typeof(T." ~ field ~ "));");
            }
        }catch(Exception e){
        	writeln(e.toString);
            throw new ConfigException("Error in config at \"%s\", matches \"%s\"".format(splitName, filtered.map!(a => a.name).array));
        }
    }
}

string camelToDashed(string input){
    return input
        .map!(a => a.toLower != a ? "-"d ~ a.toLower : ""d ~ a)
        .join
        .to!string;
}

void fillStruct(T)(ref T value, string prefix, Entry[] values){
    foreach(field; FieldNameTuple!T){
        auto name = (prefix ~ " " ~ field.camelToDashed).strip;
        auto filtered = values.filter!(a => (a.name ~ " ").startsWith(name ~ " ") && a.value.strip.length).array;
        try {
            if(!filtered.length)
                throw new ConfigException("No value for config field \"" ~ name ~ "\"");

            static if(isType!field)
                return;

            mixin("alias Raw = typeof(value." ~ field ~ ");");

            static if(isDynamicArray!Raw && !is(Raw == string) || isAssociativeArray!Raw)
                alias Field = ForeachType!Raw;
            else
                alias Field = Raw;

            enum isFillable = isAggregateType!Field && !__traits(hasMember, Field, "__ctor");

            static if(isAssociativeArray!Raw){
                foreach(v; filtered){
                    auto shortname = v.name.chompPrefix(prefix).chompPrefix(field).split[0].to!string;
                    static if(isFillable){
                        Field temp;
                        temp.fillStruct(name ~ " " ~ shortname, filtered);
                        mixin("value." ~ field ~ "[shortname] = temp;");
                    }else{
                        mixin("value." ~ field ~ "[shortname] = v.value.to!Field;");
                    }
                }
            }else static if(isDynamicArray!Raw){
                foreach(v; filtered){
                    static if(isFillable){
                        Field temp;
                        temp.fillStruct(name, filtered);
                        mixin("value." ~ field ~ " ~= temp;");
                    }else{
                        mixin("value." ~ field ~ " ~= v.value.to!Field;");
                    }
                }
            }else static if(isFillable){
                mixin("value." ~ field ~ ".fillStruct(name, filtered);");
            }else{
                mixin("value." ~ field ~ " = filtered[$-1].value.to!Field;");
            }
        }catch(ConfigException e){
            throw e;
        }catch(Exception e){
        	writeln(e.toString);
            throw new ConfigException("Error in config at \"%s\", matches \"%s\": %s".format(name, filtered.map!(a => a.name).join(", "), e));
        }
    }
}

void fillConfigNested(T)(ref T config, string[] paths){

    Entry[] values;

    foreach(path; paths){
        path = path.expandTilde;
        if(!path.exists){
            try {
                std.file.write(path, "");
            }catch(FileException e){}
        }else{
            loadBlock!T(path.expandTilde.readText, "", values);
        }
    }

    config.fillStruct("", values);

}


void loadAndWatch(T)(auto ref T config, string[] configs, void delegate() cb){
    foreach(file; configs){
        if(file.exists)
            continue;
		["mkdir", "-p", file.expandTilde.dirName].execute;
		["touch", file.expandTilde].execute;
    }
    auto cfgReload = {
        try{
            config.fillConfigNested(configs);
        }catch(ConfigException e){
            ["notify-send", "-a", configs.join(", "), e.msg].execute;
        }catch(Exception e){
            //Log.fallback(Log.RED ~ e.to!string);
            ["notify-send", "-a", configs.join(", "), e.toString].execute;
        }
        cb();
    };
    cfgReload();
    foreach(file; configs){
        file = file.expandTilde;
        if(!file.exists)
            continue;
        Inotify.watch(file, (d,f,m){
            cfgReload();
        });
    }

}

