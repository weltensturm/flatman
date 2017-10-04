module composite.damage;

import composite;


class WindowDamage {

    Damage damage;
    bool damaged;
    XRectangle[] areas;

    this(CompositeClient client){
        damage = XDamageCreate(wm.displayHandle, client.windowHandle, XDamageReportNonEmpty);
    }

    void destroy(){
        XDamageDestroy(wm.displayHandle, damage);
    }

}


class RootDamage {

    int damageEvent;
    int damageError;
    
    XserverRegion all;
    
    this(){
        XDamageQueryExtension(wm.displayHandle, &damageEvent, &damageError);
        wm.on([
            damageEvent + XDamageNotify: (XEvent* e){
                auto ev = cast(XDamageNotifyEvent*)e;
                if(auto w = manager.find(e.xany.window)){
                    w.damage.damaged = true;
                    areas(ev, (r){
                        w.damage.areas ~= *r;
                    });
                }else{
                    repair(ev);
                }
            }
        ]);
        manager.moved ~= (window, pos, size){
            window.damage.damaged = true;
            damage([pos.x, pos.y-20], [size.w, size.h+20]);
            debug(WindowsNostalgia){
                return;
            }else{
                damage([window.oldPos.x, window.oldPos.y-20], [window.oldSize.w, window.oldSize.h+20]);
            }
        };
        manager.alphaChanged ~= (window, alpha){
            window.damage.damaged = true;
            damage(window.animPos, window.animSize);
        };
        all = XFixesCreateRegion(wm.displayHandle, null, 0);
    }

    void reset(T)(T clients){
        XFixesSetRegion(wm.displayHandle, all, null, 0);
        foreach(c; clients){
            c.damaged = false;
            c.areas = [];
        }
    }

    void areas(XDamageNotifyEvent* e, void delegate(XRectangle*) dg){
        XserverRegion region = XFixesCreateRegion(wm.displayHandle, null, 0);
        XDamageSubtract(wm.displayHandle, e.damage, None, region);
        int count;
        auto area = X.FixesFetchRegion(wm.displayHandle, region, &count);
        if(area){
            foreach(r; area[0..count]){
                dg(&r);
            }
            XFree(area);
        }
        XFixesDestroyRegion(wm.displayHandle, region);
    }

    void repair(XDamageNotifyEvent* event){
        XDamageSubtract(wm.displayHandle, event.damage, None, None);
    }

    void damage(XDamageNotifyEvent* event){
        XserverRegion region = XFixesCreateRegion(wm.displayHandle, null, 0);
        XDamageSubtract(wm.displayHandle, event.damage, None, region);
        XFixesTranslateRegion(wm.displayHandle, region, event.geometry.x, event.geometry.y);
        XFixesUnionRegion(wm.displayHandle, all, all, region);
        //XFixesSetPictureClipRegion( dpy, picture, 0, 0, region );
        XFixesDestroyRegion(wm.displayHandle, region);
    }

    void damage(int[2] pos, int[2] size){
        XRectangle r;
        r.x = pos.x.to!short;
        r.y = pos.y.to!short;
        r.width = size.w.to!ushort;
        r.height = size.h.to!ushort;
        XserverRegion region = XFixesCreateRegion(wm.displayHandle, &r, 1);
        XFixesUnionRegion(wm.displayHandle, all, all, region);
        XFixesDestroyRegion(wm.displayHandle, region);
        foreach(client; manager.clients){
            if(!client.damage.damaged && intersectArea(client.pos, client.size, pos, size) > 0)
                client.damage.damaged = true;
        }
    }

    void clip(Picture picture){
         XFixesSetPictureClipRegion(wm.displayHandle, picture, 0, 0, all);
    }

}
