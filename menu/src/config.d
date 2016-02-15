module menu.config;

import menu;

__gshared:


class Config {

	string[string[]] values;

	string opIndex(Args...)(Args selector){
		string[] arraySelector;
		foreach(v; selector)
			arraySelector ~= v;
		string result = "ff9999";
		size_t lastDiff = size_t.max;
		foreach(key, value; values){
			if(arraySelector.count!(a => key.canFind(a)) == arraySelector.length){
				if(key.length-arraySelector.length < lastDiff){
					result = value;
					lastDiff = key.length-arraySelector.length;
				}
			}
		}
		return result;
	}

	float[3] color(Args...)(Args name){
		auto clr = this[name];
		return [
				clr[0..2].to!int(16)/255.0,
				clr[2..4].to!int(16)/255.0,
				clr[4..6].to!int(16)/255.0
		]; 
	}

	string key(string name){
		return this[name];
	}

	void loadBlock(string block, string[] namespace){
		Decode.text(block, (name, value, isBlock){
			if(isBlock)
				loadBlock(value, namespace ~ name);
			else
				values[cast(immutable)(namespace ~ name ~ value.split[0..$-1])] = value.split[$-1];
		});
	}

	void load(){
		auto prioritizedPaths = [
			"/etc/flatman/menu",
			"~/.config/flatman/menu".expandTilde,
		];
		foreach(path; prioritizedPaths){
			try{
				loadBlock(path.readText, []);
				"loaded config %s".format(path).writeln;
			}catch(Exception e)
				e.toString.writeln;
		}
	}

}

Config config;


shared static this(){
	config = new Config;
	config.load;
}

void each(T)(T[] data, void delegate(size_t i, T data) dg){
	foreach(i, d; data)
		dg(i, d);
}
