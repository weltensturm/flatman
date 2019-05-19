module composite.overview.dock;


import
    std.stdio,
    std.algorithm,
    std.conv,
    std.range,
    std.math,

    x11.X,
    x11.Xatom,

    ws.gui.base,
    ws.x.property,

    common.atoms,
    common.event,

    composite.events,
    composite.util,
    composite.main,
    composite.animation,
    composite.overview.overview,
    composite.damage,
    composite.backend.backend;



class OverviewDock: Widget {

    Overview.Monitor monitor;
    WorkspaceIndicator indicator;
    WorkspaceIndicator indicatorEmpty;
    OverviewWorkspace[] workspaces;

    int[2] pos;
    int[2] size;

    this(Overview.Monitor monitor){
        writeln("new dock ", monitor);
        this.monitor = monitor;
        indicator = addNew!WorkspaceIndicator(IndicatorType.current);
        indicatorEmpty = addNew!WorkspaceIndicator(IndicatorType.empty);
        Events ~= this;
        updateWorkspaceCount;
    }

    void destroy(){
        writeln("destroy dock ", monitor);
        Events.forget(this);
    }

    override void move(int[2] pos){
        if(pos == this.pos)
            return;
        this.pos = pos;
        updateWorkspaceCount;
    }

    override void resize(int[2] size){
        if(size == this.size)
            return;
        this.size = size;
        updateWorkspaceCount;
    }

    override void damage(RootDamage damage){
        indicator.damage(damage);
        indicatorEmpty.damage(damage);
    }

    @Tick
    void tick(){
        indicator.animation.approach(indicator.targetPos, indicator.targetSize);
        indicator.move(indicator.animation.pos.calculate);
        indicator.resize(indicator.animation.size.calculate);
        indicatorEmpty.animation.approach(indicatorEmpty.targetPos, indicatorEmpty.targetSize);
        indicatorEmpty.move(indicatorEmpty.animation.pos.calculate);
        indicatorEmpty.resize(indicatorEmpty.animation.size.calculate);
    }

    @OverviewState
    void overviewState(double state){
        indicator.setState(state.sigmoid);
        indicatorEmpty.setState(state.sigmoid);
    }

    void calcWindow(Overview.WinInfo window){
        foreach(ws; workspaces)
            ws.calcWindow(window);
    }

    void draw(Backend backend, double state){
        backend.setColor([0, 0, 0, 0.7*state]);
        backend.rect(pos, size);
        indicator.draw(backend);
        indicatorEmpty.draw(backend);
        foreach(ws; workspaces)
            ws.draw(backend, state);
    }

    @WindowProperty
    void onProperty(x11.X.Window window, Atom atom){
        if(window != .root)
            return;
        if(atom == Atoms._NET_NUMBER_OF_DESKTOPS)
            updateWorkspaceCount;
        if(atom == Atoms._FLATMAN_WORKSPACE_HISTORY)
            updateWorkspaceSort;
        if(atom == Atoms._FLATMAN_WORKSPACE_EMPTY)
            updateWorkspaceSort;
        if(atom == Atoms._NET_CURRENT_DESKTOP)
            updateCurrentWorkspace;
    }

    void updateWorkspaceCount(){
        auto count = .root.props._NET_NUMBER_OF_DESKTOPS.get!long;
        foreach(workspace; workspaces){
            remove(workspace);
            workspace.destroy;
        }
        workspaces = [];
        foreach(i; 0..count){
            workspaces ~= addNew!OverviewWorkspace(this, i.to!int);
        }
        updateWorkspaceSort;
    }

    void updateWorkspaceSort(){
        workspaces = workspaces.sorted(manager.overview.properties.workspaceSort.get);
        auto empty = manager.overview.properties.workspaceEmpty.get;
        workspaces =
            workspaces
            .filter!(a => empty.canFind(a.index))
            .array
            ~
            workspaces
            .filter!(a => !empty.canFind(a.index))
            .array;
        updateWorkspacePositions;
    }

    void updateCurrentWorkspace(){
        updateWorkspaceIndicatorPosition;
    }

    void updateWorkspacePositions(){
        auto workspaceAspect = monitor.size.w.to!double / monitor.size.h;
        auto workspaceScale = size.h.to!double / monitor.size.h;
        int[2] workspaceSize = [
            (monitor.size.w*workspaceScale).lround.to!int,
            (monitor.size.h*workspaceScale).lround.to!int
        ];

        long start = pos.x + (size.w/2 - (workspaces.length.to!long*workspaceSize.w)/2)
                              .max(0); // TODO: scroll with many workspaces
        foreach(i, workspace; workspaces){
            workspace.sortIndex = i;
            workspace.move([start.to!int + i.to!int*workspaceSize.w, pos.y]);
            workspace.resize(workspaceSize);
        }

        updateWorkspaceIndicatorPosition;
        updateEmptyWorkspaceIndicatorPosition;
    }

    void updateWorkspaceIndicatorPosition(){
        foreach(ws; workspaces){
            if(ws.index == manager.properties.workspace.get){
                /+
                indicator.targetSize = [ws.size.h.to!int/2, ws.size.h.to!int/2];
                indicator.targetPos = [
                        ws.pos.x + (ws.size.w/2 - indicator.targetSize.w/2).to!int,
                        ws.pos.y + (ws.size.h/2 - indicator.targetSize.h/2).to!int
                ];
                +/
                indicator.index = ws.index;
                indicator.targetSize = ws.size;
                indicator.targetPos = ws.pos;
            }
        }
    }

    void updateEmptyWorkspaceIndicatorPosition(){
        foreach(i, ws; workspaces){
            if(i == 0){
                // TODO: better empty workspace detection
                indicatorEmpty.index = ws.index;
                indicatorEmpty.targetSize = [ws.size.h.to!int/2, ws.size.h.to!int/2];
                indicatorEmpty.targetPos = [
                        ws.pos.x + (ws.size.w/2 - indicatorEmpty.targetSize.w/2).to!int,
                        ws.pos.y + (ws.size.h/2 - indicatorEmpty.targetSize.h/2).to!int
                ];
            }
        }
    }

}


class Widget: Base {

    struct Damage {
        int[2] pos;
        int[2] size;
    }

    Damage[] trackedDamage;

    bool tagged;

    override void move(int[2] pos){
        if(pos == this.pos)
            return;
        damage(this.pos, size);
        this.pos = pos;
        damage;
    }

    void move(double[2] pos){
        move([
            pos.x.round.to!int,
            pos.y.round.to!int
        ]);
    }

    void resize(double[2] size){
        resize([
            size.w.round.to!int,
            size.h.round.to!int
        ]);
    }

    override void resize(int[2] size){
        if(size == this.size)
            return;
        damage(pos, this.size);
        this.size = size;
        damage;
    }

    void damage(int[2] pos, int[2] size){
        trackedDamage ~= Damage(pos, size);
    }

    void damage(){
        tagged = true;
    }

    void damage(RootDamage damage){
        auto translatedDamage = (int[2] pos, int[2] size){
            damage.damage(
                [pos.x, manager.height - pos.y - size.h],
                size
            );
        };
        if(tagged)
            translatedDamage(pos, size);
        tagged = false;

        foreach(dmg; trackedDamage)
            translatedDamage(dmg.pos, dmg.size);
        trackedDamage = [];
    }

}


class OverviewWorkspace: Widget {

    OverviewDock dock;
    int index;
    size_t sortIndex;
    string name;

    this(OverviewDock dock, int index){
        this.dock = dock;
        this.index = index;
        Events ~= this;
        updateWorkspaceName;
    }

    void destroy(){
        damage;
        Events.forget(this);
    }

    @WindowProperty
    void onProperty(x11.X.Window window, Atom atom){
        if(window == .root && atom == Atoms._NET_DESKTOP_NAMES)
            updateWorkspaceName;
    }

    void updateWorkspaceName(){
        auto names = manager.overview.workspaceNames;
        if(index >= 0 && index < names.length){
            name = names[index].shortenDirs;
            damage;
        }
    }

    void draw(Backend backend, double state){
        if(sortIndex == 0)
            return;
        int[2] textp = [pos.x, pos.y+10];

        textp.x += (size.w/2 - backend.width(name)/2).lround.to!int;
        auto last = name.split("/").length-1;
        backend.setColor([0.5,0.5,0.5,state]);
        foreach(ti, part; name.split("/")){
            if(ti == last)
                backend.setColor([1,1,1,state]);
            textp.x += backend.text(textp, part, 0);
            if(ti != last)
                textp.x += backend.text(textp, "/", 0);
        }
    }

    void calcWindow(Overview.WinInfo window){
        auto scale = size.w.to!double / dock.monitor.size.w / 1.1;
        auto offset = [
            (size.w - size.w/1.1)/2,
            (size.h - size.h/1.1)/2
        ];
        auto workspace = index < dock.monitor.workspaces.length ? dock.monitor.workspaces[index] : null;
        if(!workspace)
            return;
        foreach(winInfo; workspace.windows){
            if(winInfo.window == window.window){
                if(window.window.properties.workspace.value != manager.properties.workspace.value){
                    window.targetPos.y = manager.height - window.targetSize.h - window.targetPos.y - dock.pos.y;
                    // TODO: same coordinate system everywhere
                    window.targetSize = [
                        (window.targetSize.w*scale).to!int,
                        (window.targetSize.h*scale).to!int
                    ];
                    window.targetPos = [
                        (offset.x + window.targetPos.x*scale+pos.x - dock.monitor.pos.x*scale).to!int,
                        (offset.y + window.targetPos.y*scale+pos.y - dock.monitor.pos.y*scale + 6).to!int
                    ];
                    window.targetPos.y = manager.height - window.targetSize.h - window.targetPos.y;
                }
            }
        }
    }

    override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
        if(!pressed){
            manager.overview.window.properties.workspace.request([index, CurrentTime]);
        }
    }

}


enum IndicatorType {
    current,
    empty
}


class WorkspaceIndicator: Widget {

    int[2] targetPos;
    int[2] targetSize;
    const IndicatorType type;

    int index;

    OverviewAnimation animation;

    double state;

    this(IndicatorType type){
        animation = new OverviewAnimation(pos, size);
        this.type = type;
    }

    void setState(double state){
        if(state == this.state)
            return;
        this.state = state;
        damage;
    }

    void draw(Backend backend){
        enum border = 4;
        backend.setColor([1, 1, 1, state]);
        if(type == IndicatorType.current){
            /+
            backend.rect([pos.x, pos.y], [border, size.h]);
            backend.rect([pos.x+size.w-border, pos.y], [border, size.h]);
            backend.rect([pos.x+border, pos.y], [size.w-border*2, border]);
            backend.rect([pos.x+border, pos.y+size.h-border], [size.w-border*2, border]);
            +/
            backend.setColor([1, 1, 1, 0.1*state]);
            backend.rect(pos, size);
        }else{
            backend.rect([pos.x + border*2, pos.y + size.h/2 - border/2], [size.w-border*4, border]);
            backend.rect([pos.x + size.w/2 - border/2, pos.y + border*2], [border, size.h-border*4]);
        }
    }

    override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
        if(!pressed){
            manager.overview.window.properties.workspace.request([index, CurrentTime]);
        }
    }

}


class Dock {

    double state = 0;

    Overview overview;

    OverviewDock[] docks;

    this(Overview overview){
        this.overview = overview;
        Events ~= this;
    }

    @Tick
    void tick(){
        docks
            .filter!(a => !overview.monitors.canFind(a.monitor))
            .each!(a => a.destroy);
        docks = docks
            .filter!(a => overview.monitors.canFind(a.monitor))
            .array;

        docks ~= overview.monitors
            .filter!(a => !docks.canFind!(b => b.monitor.pos == a.pos))
            .map!(a => new OverviewDock(a))
            .array;

        foreach(i, m; overview.monitors){
            auto y = manager.height - m.pos.y - m.size.h;
            auto dock = docks[i];
            dock.move([m.pos.x, y]);
            dock.resize([m.size.w, m.size.h/8]);
        }
    }

    void calc(Overview.WinInfo window){
        foreach(dock; docks){
            dock.calcWindow(window);
        }
    }

    void damage(RootDamage damage){
        foreach(dock; docks) dock.damage(damage);
    }

    void draw(Backend backend, double state, Overview.Monitor[] monitors, string[] workspaceNames){
        state = state.sinApproach;
        this.state = state;
        foreach(dock; docks)
            dock.draw(backend, state);
    }

    void onMouseButton(Mouse.button button, bool pressed, int x, int y){
        foreach(dock; docks){
            if(dock.pos.x <= x && dock.pos.x+dock.size.w >= x
                && dock.pos.y <= y && dock.pos.y+dock.size.h >= y){
                dock.onMouseButton(button, pressed, x, y);
            }
        }
    }

    void onMouseMove(int x, int y){
        foreach(dock; docks){
            if(dock.pos.x <= x && dock.pos.x+dock.size.w >= x
                && dock.pos.y <= y && dock.pos.y+dock.size.h >= y){
                dock.onMouseMove(x, y);
            }
        }
    }

}


string shortenDirs(string dir){
    return dir
        .split("/")
        .reverse
        .enumerate
        .map!(a => a.index == 0 ? a.value : a.value[0..1])
        .array
        .reverse
        .join('/');
}


auto sorted(T)(T[] workspaces, long[] sorting){

    alias key = (a){
        return sorting.countUntil(a.index);
    };

    auto sortedWorkspaces = workspaces
        .sort!((a, b) => key(a) < key(b))
        .array;

    return sortedWorkspaces;

}
