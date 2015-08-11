module dock.watcher;

import dock;

__gshared:


class Watcher(T) {
	
	ref T data;
	T copy;
	void delegate() callback;
	
	this(ref T data, void delegate() callback){
		this.data = data;
		this.copy = data;
		this.callback = callback;
	} 
	
	void tick(){
		if(data != copy){
			data = copy;
			callback;
		}
	}
	
}