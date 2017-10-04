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

	void restack(){
		"floating(%s).restack".format(cast(void*)this).log;
		foreach(i, client; clients){
			client.raise;
		}
	}

	override void show(){
		if(!hidden)
			return;
		foreach(c; clients)
			c.showSoft;
		hidden = false;
	}

	override void hide(){
		if(hidden)
			return;
		foreach(c; clients)
			c.hideSoft;
		hidden = true;
	}

	override void onDraw(){
		foreach(c; clients)
			if(c.frame)
				c.frame.onDraw;
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
		onDraw;
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

	void focusDir(int dir){
		if(!children.length)
			return;
		auto newActive = clientActive+dir;
		if(newActive >= children.length)
			newActive = 0;
		else if(newActive < 0)
			newActive = children.length-1;
		children[newActive].to!Client.focus;
	}

}
