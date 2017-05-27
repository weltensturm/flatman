module composite.overview;


import composite;


class Overview {

    CompositeManager manager;

    Properties!(
        "workspaceNames", "_NET_DESKTOP_NAMES", XA_STRING, false,
        "workspace", "_NET_CURRENT_DESKTOP", XA_CARDINAL, false,
        "workspaceCount", "_NET_NUMBER_OF_DESKTOPS", XA_CARDINAL, false
    ) properties;

    string[] workspaceNames;

    common.screens.Screen[int] screens;
    Monitor[] monitors;

    this(CompositeManager manager){
        this.manager = manager;
        properties.window(.root);
        wm.on(.root, [
            PropertyNotify: (XEvent* e) => properties.update(&e.xproperty),
            ConfigureNotify: (XEvent* e) => updateScreens
        ]);
        properties.workspaceNames ~= (string names){ workspaceNames = names.split("\0"); };
        properties.workspace ~= (long ws){

        };
        properties.update;
    }

    class WinInfo {
        CompositeClient window;
        int[2] pos;
        int[2] size;
        this(CompositeClient window){
            this.window = window;
        }
    }

    class Monitor {
        int[2] pos;
        int[2] size;
        Workspace[] workspaces;
        this(int[2] pos, int[2] size){
            this.pos = pos;
            this.size = size;
        }
    }

    class Workspace {
        string name;
        int[] separators;
        WinInfo[] windows;
    }

    void updateScreens(){
		screens = .screens(wm.displayHandle);
    }

    private void prefill(){
        monitors = [];
        foreach(screenI, screen; screens){
            auto m = new Monitor([screen.x, screen.y], [screen.w, screen.h]);
            monitors ~= m;
            foreach(i; 0..properties.workspaceCount.value){
                auto ws = new Workspace;
                m.workspaces ~= ws;
                foreach(client; manager.clients){
                	if(client.a.override_redirect
                            && client.properties.overviewHide.value != 1
                            || client.a.c_class == InputOnly)
                		continue;
                    if(client.properties.workspace.value == i && screenI == screens.findScreen(client.pos, client.size)){
                        ws.windows ~= new WinInfo(client);
                    }
                }
            }
        }
    }

    void calc(double[4] strut){
        prefill;
        struct Group {
            int width;
            WinInfo[] windows;
        }
        foreach(ref monitor; monitors){
        	auto mstrut = [strut[0]*monitor.size.w, strut[1]*monitor.size.w, strut[2]*monitor.size.h, strut[3]*monitor.size.h];
        	auto msize = [monitor.size.w - mstrut[0] - mstrut[1],
        				  monitor.size.h - mstrut[2] - mstrut[2]];
			auto mpos = [monitor.pos.x + mstrut[0],
						 monitor.pos.y + mstrut[2]];
            foreach(ref ws; monitor.workspaces){
                Group[long] groups;
                long unscaledWidth;
                foreach(w; ws.windows){
                    auto tabs = w.window.properties.tabs.value.max(0);
                    if(tabs !in groups){
                        auto width = tabs > 0 ? w.window.properties.width.value.to!int : (msize.w/5).to!int;
                        groups[tabs] = Group(width);
                        unscaledWidth += width;
                    }
                    groups[tabs].windows ~= w;
                }
                auto containerScale = unscaledWidth.to!double / msize.w;
                import std.typecons;
                int offsetX;
                foreach(k, v; sort(groups.keys).map!(a => tuple(a, groups[a]))){
                    auto width = (v.width/containerScale).floor;
                    ws.separators ~= offsetX+width.to!int;
                    auto count = v.windows.length.to!double;
                    auto columns = k == 0 && groups.length > 1 ? 1 : sqrt(count).ceil.lround.to!double;
            		auto padding = [msize.w/40.0, msize.h/40];
                    foreach(w; v.windows){
                        auto targetWidth = (width-padding.w).max(1)/columns-padding.w;
                        w.size = [
                            targetWidth.to!int,
                            (w.window.animation.size.h.calculate*targetWidth/w.window.animation.size.w.calculate).to!int
                        ];
                		auto maxY = ((count/columns).ceil)*(w.size.h+padding.h)-padding.h;
                		auto offsetY = msize.h/2-maxY/2;
                        w.pos = [
                            (mpos.x
                            	+ offsetX
                            	+ (padding.w + (w.window.properties.tab % columns)*(w.size.w+padding.w))
                            	).to!int,
                            (mpos.y
                            	+ (w.window.properties.tab / columns).floor*(w.size.h+padding.h)
                            	+ (w.window.properties.workspace.value.to!int-manager.workspaceAnimation)*monitor.size.h
                            	+ offsetY
                            	).to!int
                        ];
                    }
                    offsetX += width.to!int;
                }
                if(ws.separators.length)
                    ws.separators = ws.separators[0..$-1];
            }
        }
    }


	void window(CompositeClient client, ref int[2] pos, ref double[2] offset, ref int[2] size, ref double scale, ref double alpha){
        foreach(m; monitors){
            foreach(wsi, ws; m.workspaces){
                foreach(w; ws.windows){
                	if(w.window == client){
						if(manager.overviewState < 0.000001)
							return;
                        /+
                        auto tabWidth = w.window.properties.width.value;
                        if(w.window.properties.tabs.value <= 0 || w.window == manager.clients[$-1])
                            tabWidth = 0;
                        +/
                        auto tabWidth = 0;
						double flop;
						if(client.hidden){
							flop = 1;
							alpha = manager.overviewState.sinApproach;
						}else{
							flop = manager.overviewState.sinApproach;
							alpha = 0.75 + alpha*0.25;
						}
						if(client.properties.workspace.value < 0 || client.properties.overviewHide.value == 1){
							alpha = 1-flop;
							return;
						}
						scale = animate(scale, (w.size.w/size.w.to!double).min(w.size.h.to!double/size.h), flop);
						pos = [
							animate(pos.x, w.pos.x, flop).lround.to!int,
							animate(pos.y, w.pos.y, flop).lround.to!int
						];
						size = [
							animate(tabWidth ? tabWidth : size.w, w.size.w, flop).to!int,
							animate(size.h, w.size.h, flop).to!int
						];
                		return;
                	}
            	}
            }
        }
	}

	void predraw(XDraw xdraw){

        foreach(ref m; monitors){
            foreach(wsi, ref ws; m.workspaces){
                foreach(w; ws.windows){
                	if(!w.window.picture){
	                	xdraw.setColor([0,0,0,0.3*manager.overviewState]);
	                	xdraw.rect([w.pos.x, m.size.h-w.pos.y-w.size.h], w.size);	
                	}
                }
            }
        }
	}

    void draw(XDraw xdraw){
        foreach(ref m; monitors){
            foreach(wsi, ws; m.workspaces){

                if(wsi != manager.workspace)
                    continue;
            	foreach(sep; ws.separators){
            		xdraw.setColor([1,1,1,0.03*manager.overviewState^^2]);
            		xdraw.rect([sep-1, m.size.h/20-1], [4, m.size.h-m.size.h/10+2]);
            		xdraw.setColor([0,0,0,0.3*manager.overviewState^^2]);
            		xdraw.rect([sep, m.size.h/20], [2, m.size.h-m.size.h/10]);
            	}
                foreach(w; ws.windows){
                }
            }
        }
    }

    void drawDock(XDraw xdraw){
        auto state = manager.overviewState.sinApproach;
        foreach(m; monitors){
            auto scale = (1/7.5).min(0.9/m.workspaces.length);
            auto ssize = [m.size.w*scale, m.size.h*scale];
            auto height = (ssize.h+20)*m.workspaces.length;
            foreach(i, ws; m.workspaces){

                auto wsp = [
                    m.pos.x + m.size.w-scale*m.size.w*state,
                    m.pos.y + m.size.h/2-height/2 + (ssize.h+20)*i
                ].to!(int[2]);

                foreach(w; ws.windows){          
                    auto c = w.window;
                    if(!c.picture)
                        continue;
                    c.updateScale(scale);
                    XRenderComposite(
                        wm.displayHandle,
                        state < 1 || c.hasAlpha ? PictOpOver : PictOpSrc,
                        c.picture,
                        state < 1 ? manager.alpha[(state*manager.ALPHA_STEPS).to!int] : None,
                        manager.backBuffer,
                        0,0,
                        0,0,
                        (c.pos.x*scale+wsp.x - m.pos.x*scale).to!int,
                        (c.pos.y*scale+wsp.y).to!int,
                        (c.size.w*scale).to!int,
                        (c.size.h*scale).to!int
                    );
                }

                if(i != manager.workspace)
                    xdraw.setColor([0,0,0,0.3*state]);
                else
                    xdraw.setColor([1,1,1,0.1*state]);
                xdraw.rect(wsp.translate(m.size.h + (manager.height - m.size.h), ssize.h), ssize.to!(int[2]));
                auto wsname = workspaceNames[i];
                auto textp = wsp.translate(m.size.h+2 + (manager.height - m.size.h));
                textp.x += ssize.x.to!int - xdraw.width(wsname) - 10;
                xdraw.setColor([0,0,0,0.5*state]);
                xdraw.rect([wsp.x, textp.y-2], [ssize.w.to!int, 20]);
                auto last = wsname.split("/").length-1;
                xdraw.setColor([0.7,0.7,0.7,state]);
                foreach(ti, part; wsname.split("/")){
                    if(ti == last)
                        xdraw.setColor([1,1,1,state]);
                    textp.x += xdraw.text(textp, part);
                    if(ti != last)
                        textp.x += xdraw.text(textp, "/");
                }
            }
        }
    }

}

int[2] translate(T1, T2, T3)(T1[2] pos, T2 h, T3 h2=0){
    return [pos.x, h-h2-pos.y].to!(int[2]);
}

