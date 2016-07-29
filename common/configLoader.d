module common.configLoader;


import
    std.traits,
    std.path,
    std.string,
    std.conv,
    std.file,
    std.algorithm,
    std.array,
    ws.decode;


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

    foreach(path; paths)
        loadBlock!T(path.expandTilde.readText, "", values);

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
            throw new Exception("Error in config: could not find value " ~ splitName);
        
        mixin("enum isList = is(typeof(T." ~ field ~ ") == string[]);");
        
        try {
            static if(isList){
                foreach(entry; filtered)
                    mixin("config." ~ field ~ " ~= entry.value;");
            }else{
                mixin("config." ~ field ~ " = filtered[$-1].value.to!(typeof(T." ~ field ~ "));");
            }
        }catch(Exception e){
            throw new Exception("Error in config at \"%s\", matches \"%s\"".format(splitName, filtered), e);
        }
    }
}
