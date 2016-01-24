module menu.queue;


import menu;


shared class Queue(T) {

	private immutable(T)[] data;

	synchronized void add(immutable T entry){
		data ~= entry;
	}

	synchronized immutable(T) get(){
		if(!has)
			throw new Exception("no elements");
		auto entry = data[0];
		data = data[1..$];
		return entry;
	}

	synchronized bool has(){
		return data.length > 0;
	}

}