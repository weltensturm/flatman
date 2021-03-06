module flatman.layout.floating;

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

	WindowHandle[] stack(){
		WindowHandle[] result;
		foreach_reverse(w; clients){
			result ~= w.win;
			if(w.frame)
				result ~= w.frame.window;
		}
		return result;
	}

	override void show(){
		if(!hidden)
			return;
		hidden = false;
		foreach(c; clients)
			c.configure;
	}

	override void hide(){
		if(hidden)
			return;
		hidden = true;
		foreach(c; clients)
			c.configure;
	}

	void raise(Client client){
		children = children.without(client) ~ client;
		.restack;
	}

	void moveResizeClient(Client client){
		client.moveResize(client.posFloating, client.sizeFloating);
		if(client.frame)
			client.frame.moveResize(client.pos.a-[0, config.tabs.title.height], [client.size.w, config.tabs.title.height]);
	}

	alias add = Base.add;

	override void add(Client client){
		"floating(%s).add %s fullscreen=%s".format(cast(void*)this, client, client.isfullscreen).log;
		add(client.to!Base);
		if(client.decorations)
			client.frame = new Frame(client, client.posFloating.a - [0, config.tabs.title.height], [client.sizeFloating.w, config.tabs.title.height]);
		if(!client.posFloating.x && !client.posFloating.y || client.posFloating.x < 0 || client.posFloating.y < 0){
			client.moveResize([pos.x+size.w/2-client.sizeFloating.w/2, pos.y+size.h/2-client.sizeFloating.h/2], client.sizeFloating, true);
		}else
			client.moveResize(client.posFloating, client.sizeFloating);
		flatman.restack;
	}

	alias remove = Base.remove;

	override void remove(Client client){
		"floating(%s).remove %s".format(cast(void*)this, client).log;
		if(client.frame)
			client.frame.destroy;
		client.frame = null;
		super.remove(client);
	}
	alias active = Container.active;

	@property
	override void active(Client client){
		"floating(%s).active %s".format(cast(void*)this, client).log;
		raise(client);
		super.active = client;
	}

	override Client[] clients(){
		return children.to!(Client[]);
	}

	void destroy(){
		foreach(c; children.to!(Client[])){
			if(c.frame)
				c.frame.destroy;
			c.destroy;
		}
	}

	Client clientDir(short direction){

		auto sorted = children
			.enumerate
			.array
			.multiSort!(
				(a, b) => a.value.pos.x < b.value.pos.x,
				(a, b) => a.value.pos.y < b.value.pos.y,
				(a, b) => a.index < b.index
			);
		
		auto index = sorted.countUntil!(a => a.index == clientActive) + direction;

		if(index >= 0 && index < sorted.length)
			return children[sorted[index][0]].to!Client;

		return null;
	}

	void focusDir(int dir){
		if(!children.length)
			return;
		auto newActive = clientActive+dir;
		if(newActive >= children.length)
			newActive = 0;
		else if(newActive < 0)
			newActive = children.length-1;
		focus(children[newActive].to!Client);
	}

}
