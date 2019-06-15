
module flatman.layout.tabs;

import flatman;

__gshared:


class Tabs: Container {

    bool showTabs = true;
    bool mouseFocus;
    bool mousePressed;
    bool containerFocused;

    this(){
        size = [10,10];
        hidden = true;
        Events ~= this;
    }

    WindowHandle[] stack(){
        return (active ? [active.win] : [])
               ~ clients.filter!(a => a != active).map!(a => a.win).array;
    }

    override void show(){
        if(!hidden)
            return;
        hidden = false;
        resize(size);
        if(active)
            active.configure;
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
        Events.forget(this);
    }

    alias add = Base.add;

    override void add(Client client){
        //add(client.to!Base);
        if(config.tabs.sortBy == config.tabs.sortBy.history){
            children = client ~ children;
            client.parent = this;
            clientActive += 1;
        }else if(clientActive+1 < children.length){
            children = children[0..clientActive+1] ~ client ~ children[clientActive+1..$];
            client.parent = this;
        }else
            add(client.to!Base);
        active = client;
        updateHints;
        resize(size);
    }

    alias remove = Base.remove;

    override void remove(Client client){
        "tabs.remove %s".format(client).log;
        super.remove(client);
        if(any)
            active = any;
        client.win.replace(Atoms._FLATMAN_TABS, 0L);
        updateHints;
    }

    void updateHints(){
        foreach(i, c; children.to!(Client[])){
            c.win.replace(Atoms._FLATMAN_TAB, cast(long)i);
            c.win.replace(Atoms._FLATMAN_TABS, parent.children.countUntil(this)+1);
        }
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

    Client clientDir(short direction){
        auto target = clientActive+direction;
        if(target < 0 || target >= children.length)
            return null;
        return children[target].to!Client;
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
    }

    override void resize(int[2] size){
        with(Log("tabs.resize %s".format(size))){
            super.resize(size);
            auto padding = config.tabs.padding;
            if(active){
                auto monitor = findMonitor(active);
                if(active.isfullscreen){
                    active.moveResize(monitor.pos.a + [0, hidden ? rootSize.h : 0], monitor.size);
                }else{
                    active.moveResize(
                        pos.a + [padding[0], showTabs ? 0 : padding[2] - (hidden ? monitor.size.h : 0)],
                        size.a - [padding[0]+padding[1], (showTabs ? 0 : padding[2])+padding[3]]
                    );
                }
            }
        }
    }

    @Overview
    void onOverview(bool enter){
        if(config.tabs.sortBy == config.tabs.SortBy.history && !enter){
            if(clientActive != 0){
                Log("%s %s %s %s".format(config.tabs.sortBy, enter, clientActive, children.length));
                children = children[clientActive] ~ children[0..clientActive] ~ children[clientActive+1..$];
                clientActive = 0;
                updateHints;
            }
        }
    }

}
