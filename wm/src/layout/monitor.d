module flatman.layout.monitor;

import flatman;

__gshared:


class Monitor {

    int id;
    int[2] pos;
    int[2] size;

    Workspace[] workspaces;
    Client[] globals;

    int workspaceActive;
    int globalActive;
    bool focusGlobal;

    this(int[2] pos, int[2] size){
        this.pos = pos;
        this.size = size;
        Inotify.watch("~/.flatman".expandTilde, (path, file, action){
            if(action != Inotify.Modify)
                return;
            if(workspace && file.endsWith("current")){
                workspace.updateContext("~/.flatman/current".expandTilde.readText);
            }
            if(file.endsWith("current") || file.endsWith(".context"))
                ewmh.updateDesktopNames;
        });
    }

    Client active(){
        if(focusGlobal)
            return globals[globalActive];
        else
            return workspace.active;
    }

    void setActive(Client client){
        with(Log("monitor.setActive %s".format(client))){
            if(globals.canFind(client)){
                foreach(i, global; globals){
                    if(global == client){
                        globalActive = cast(int)i;
                        "focus global".log;
                    }
                }
            }else{
                foreach(i, ws; workspaces){
                    if(ws.clients.canFind(client)){
                        ws.active = client;
                        switchWorkspace(cast(int)i);
                        return;
                    }
                }
            }
        }
    }

    Workspace workspace(){
        return workspaces[workspaceActive];
    }

    void add(Client client, long workspace=-1){
        with(Log("%s.add %s workspace=%s".format(this, client, workspace))){
            if(workspace < 0)
                client.global = true;
            if(!client.global){
                if(client.isFloating && !drag.dragging){
                    if(!client.isfullscreen && client.size >= size.a-[2,2] && size != this.workspace.size){
                        Log("%s.isfullscreen = true".format(client));
                        client.isfullscreen = true;
                        client.updateFullscreen;
                    }else if(client.size >= size.a*0.8){
                        Log("%s.isFloating = false".format(client));
                        client.isFloating = false;
                    }
                }
                if(workspace == -1)
                    this.workspace.add(client);
                else{
                    workspaces[workspace.max(0).min(workspaces.length-1)].add(client);
                }
            }else{
                client.global = true;
                globals ~= client;
                assert(!client.parent);
                //client.moveResize(client.posFloating, client.sizeFloating);
            }
        }
    }

    void move(Client client, int workspace){
        with(Log("%s.move %s workspace=%s".format(this, client, workspace))){
            auto l = workspaces.length;
            auto pos = workspaces.countUntil!(a => a.clients.canFind(client));
            this.workspace.remove(client);
            if(l+1 < workspaces.length){
                if(workspace < pos)
                    workspace--;
                ewmh.updateWorkspaces();
            }
            workspaces[workspace].add(client);
        }
    }

    void remove(Client client){
        with(Log("%s.remove %s".format(this, client))){
            bool found;
            foreach(ws; workspaces){
                if(ws.clients.canFind(client)){
                    ws.remove(client);
                    found = true;
                    break;
                }
            }
            if(!found && globals.canFind(client)){
                found = true;
                globals = globals.without(client);
            }
            if(!found)
                throw new Exception("Monitor does not have %s".format(client));
            if(client.strut)
                resize(size);
        }
    }

    void update(Client client){
        foreach(ws; workspaces){
            if(ws.clients.canFind(client))
                workspace.update(client);
        }
    }

    void destroy(){
        foreach(ws; workspaces)
            ws.destroy;
    }

    Client[] clients(){
        Client[] c;
        if(workspaces.length > 1)
            c = workspaces
                .without(workspace)
                .map!"a.clients"
                .reduce!"a ~ b";
        return c ~ workspace.clients ~ globals;
    }

    Client[] clientsVisible(){
        return (workspace.clients ~ globals).filter!(a=>a.isVisible).array;
    }

    int[4] calculateStrut(){
        int[4] reserve;
        foreach(c; clients){
            if(!c.strut)
                continue;
            auto strutNormalized = [
                    (c.pos.x - pos.x + c.size.w/2.0)/size.w,
                    (c.pos.y - pos.y + c.size.h/2.0)/size.h
            ];
            "strut normalized %s %s".format(c, strutNormalized).log;
            reserve[0] += strutNormalized.y < 1-strutNormalized.x && strutNormalized.y > strutNormalized.x ? c.size.w : 0;
            reserve[1] += strutNormalized.y > 1-strutNormalized.x && strutNormalized.y < strutNormalized.x ? c.size.w : 0;
            reserve[2] += strutNormalized.y < strutNormalized.x && strutNormalized.y < 1-strutNormalized.x ? c.size.h : 0;
            reserve[3] += strutNormalized.y > strutNormalized.x && strutNormalized.y > 1-strutNormalized.x ? c.size.h : 0;
        }
        return reserve;
    }

    void resize(int[2] size){
        with(Log("monitor.resize %s".format(size))){
            this.size = size;
            int[4] reserve = calculateStrut;
            foreach(ref r; reserve){
                if(r > size.w || r > size.h)
                    r = 0;
            }
            "monitor strut %s".format(reserve).log;
            foreach(ws; workspaces){
                ws.move(pos.a + [reserve[0].to!int, cast(int)reserve[2]]);
                ws.resize([(size.w-reserve[1]-reserve[0]).to!int, (size.h-reserve[2]-reserve[3]).to!int]);
            }
        }
    }

    void resize(Workspace ws){
        with(Log("%s.resizeWorkspace %s".format(this, size))){
            this.size = size;
            int[4] reserve = calculateStrut;
            foreach(ref r; reserve){
                if(r > size.w || r > size.h)
                    r = 0;
            }
            "monitor strut %s".format(reserve).log;
            ws.move(pos.a + [reserve[0].to!int, cast(int)reserve[2]]);
            ws.resize([(size.w-reserve[1]-reserve[0]).to!int, (size.h-reserve[2]-reserve[3]).to!int]);
        }
    }

    override string toString(){
        return Log.YELLOW ~ "monitor(%s)".format(id) ~ Log.DEFAULT;
    }

}
