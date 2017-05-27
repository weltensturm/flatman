module flatman.layout.tabs;

import flatman;

__gshared:

Atom currentTab;
Atom currentTabs;
Atom tabDirection;
Atom tabsWidth;


class Tabs: Container {

	bool showTabs = true;
	bool mouseFocus;
	bool mousePressed;
	bool containerFocused;

	this(){
		size = [10,10];
		hidden = true;
		if(!currentTab)
			currentTab = XInternAtom(dpy, "_FLATMAN_TAB", false);
		if(!currentTabs)
			currentTabs = XInternAtom(dpy, "_FLATMAN_TABS", false);
		if(!currentTab)
			"error".log;
		if(!tabsWidth)
			tabsWidth = XInternAtom(dpy, "_FLATMAN_WIDTH", false);

		if(!tabDirection)
			tabDirection = XInternAtom(dpy, "_FLATMAN_TAB_DIR", false);
	}

	void restack(){
		"tabs.restack".log;
		if(active){
			if(!active.isfullscreen)
				active.raise;
			else
				active.lower;
		}
	}

	override void show(){
		if(!hidden)
			return;
		hidden = false;
		resize(size);
		if(active)
			active.showSoft;
	}

	override void hide(){
		if(hidden)
			return;
		hidden = true;
		resize(size);
		if(active)
            active.hideSoft;
	}

	void destroy(){
	}

	alias add = Base.add;

	override void add(Client client){
		//add(client.to!Base);
		if(clientActive+1 < children.length)
			children = children[0..clientActive+1] ~ client ~ children[clientActive+1..$];
		else
			add(client.to!Base);
		foreach(c; clients)
			if(c != client)
				c.hide;
		updateHints;
		resize(size);
	}

	alias remove = Base.remove;

	override void remove(Client client){
		"tabs.remove %s".format(client).log;
		super.remove(client);
		if(any)
			active = any;
		client.win.replace(currentTabs, 0L);
		updateHints;
	}

	void updateHints(){
		foreach(i, c; children.to!(Client[])){
			c.win.replace(currentTab, cast(long)i);
			c.win.replace(currentTabs, parent.children.countUntil(this)+1);
		}
		XSync(dpy, false);
	}

	Client next(){
		if(!children.length || clientActive == children.length-1)
			return null;
		return children[clientActive+1].to!Client;
	}

	Client prev(){
		if(!children.length || clientActive == 0)
			return null;
		return children[clientActive-1].to!Client;
	}

	void moveLeft(){
		if(clientActive <= 0)
			return;
		swap(children[clientActive], children[clientActive-1]);
		clientActive--;
		updateHints;
	}

	void moveRight(){
		if(clientActive >= children.length-1)
			return;
		swap(children[clientActive], children[clientActive+1]);
		clientActive++;
		updateHints;
	}

	Client any(){
		if(active)
			return active;
		auto a = clientActive.min(children.length-1).max(0);
		if(a >= 0 && a < children.length)
			return children[a].to!Client;
		return null;
	}

	alias active = Container.active;

	@property
	override void active(Client client){
		bool activePassed;
		bool newPassed;
		foreach(i, c; children.to!(Client[])){
			if(c == active)
				activePassed = true;
			if(c == client)
				newPassed = true;
			else
				c.win.replace(tabDirection, newPassed && activePassed ? 1L : -1L);
		}
		if(active && active != client)
			active.hide;
		if(!hidden && client.hidden){
			client.show;
			client.configure;
		}
		"tabs.active %s".format(client).log;
		super.active = client;
		if(!hidden)
			resize(size);
		XSync(dpy, false);
	}

	override void resize(int[2] size){
		with(Log("tabs.resize %s".format(size))){
			super.resize(size);
			auto padding = cfg.tabsPadding;
			if(active){
				if(active.isfullscreen){
					active.moveResize(active.monitor.pos.a + [0, hidden ? -rootSize.h : 0], active.monitor.size);
				}else{
					active.moveResize(
						pos.a + [padding[0], showTabs ? 0 : padding[2] - (hidden ? active.monitor.size.h : 0)],
						size.a - [padding[0]+padding[1], (showTabs ? 0 : padding[2])+padding[3]]
					);
				}
			}
			foreach(client; children.to!(Client[])){
				client.win.replace(tabsWidth, (size.w-padding[0]-padding[1]).to!long);
			}
		}
	}

}
