module flatman.floating;

import flatman;

__gshared:


long find(T)(T[] array, T what){
	long i;
	foreach(e; array){
		if(e == what)
			return i;
		i++;
	}
	return -1;
}


class Floating: Container {

	this(int[2] pos, int[2] size){
		move(pos);
		resize(size);
	}

	override void show(){
		if(!hidden)
			return;
		foreach(c; hiddenChildren){
			c.show;
			updateClient(c);
		}
		hidden = false;
	}

	override void hide(){
		if(hidden)
			return;
		foreach(c; children)
			c.hide;
		hidden = true;
	}

	void updateClient(Base client){
		XRaiseWindow(dpy, (cast(Client)client).win);
	}

	alias add = Base.add;

	override void add(Client client){
		"split adding %s".format(client.name).log;
		add(cast(Base)client);
		if(!client.isfullscreen && !client.isfixed && !client.pos.x && !client.pos.y)
			client.moveResize([pos.x/2-client.size.w/2, size.h-client.size.h], client.size);
	}

	override Client[] clients(){
		return children.map!(a=>cast(Client)a).array;
	}

	void destroy(){
		foreach(c; children)
			unmanage(cast(Client)c, false);
	}

	void focusDir(int dir){
		auto newActive = clientActive+dir;
		if(newActive >= children.length)
			newActive = 0;
		else if(newActive < 0)
			newActive = children.length-1;
		focus(children[newActive].to!Client);
	}

}
