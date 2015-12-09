module dock.watcher;

import dock;

__gshared:


class Watcher(T) {

	T[] data;

	void check(T[] data){
		data = data.sort!"a < b".array;
		if(this.data != data){
			foreach(delta; data.setDifference(this.data))
				foreach(event; add)
					event(delta);
			foreach(delta; this.data.setDifference(data))
				foreach(event; remove)
					event(delta);
			foreach(event; update)
				event();
			this.data = data;
		}
	}

	void delegate(T)[] add;
	void delegate(T)[] remove;
	void delegate()[] update;

}
