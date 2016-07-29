module bar.taskListEntry;

import bar;


class TaskListEntry: Base {

    Client client;
    Bar bar;

    this(Bar bar, Client client){
        this.bar = bar;
        this.client = client;
    }

    override void onDraw(){
        draw.clip(pos, size);

        if(!client.hidden)
            draw.setColor(config.titleTextNormal);
        else
            draw.setColor(config.titleTextHidden);
        auto txt = client.title;

        if(client == bar.currentClient){
            XRenderComposite(
                dpy,
                PictOpOver,
                bar.glow,
                None,
                draw.to!XDraw.frontBuffer,
                0,
                0,
                0,0,
                pos.x+size.w/2-100,
                pos.y,
                200,
                1
            );
            //draw.setColor([0.85,0.85,0.85]);
            //draw.rect(pos.a + [offset, 0], [size.w, 24]);
            draw.setColor(config.titleTextActive);
        }

        auto centerOffset = size.w/2.0 - draw.width(txt)/2.0;
        double iconWidth = 0;
        if(client.icon.length){
            auto scale = (20.0)/client.iconSize.h;
            iconWidth = client.iconSize.w*scale;
            centerOffset = (centerOffset - iconWidth).max(10);
            
            draw.text([pos.x + iconWidth.to!int + centerOffset.max(0).to!int - 5, 5], txt);

            if(!client.xicon){
                client.xicon = draw.to!XDraw.icon(client.icon, client.iconSize.to!(int[2]));
            }
            draw.to!XDraw.icon(client.xicon, pos.x + centerOffset.max(0).to!int, size.h-22, scale, client.hidden ? alpha[128] : None);
        }else if(txt.length){
            draw.text([pos.x + centerOffset.max(0).to!int, 5], txt);
        }else{
            draw.text([pos.x + centerOffset.max(0).to!int, 5], client.window.to!string);
        }
        draw.noclip;
    }

    override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
        if(button == Mouse.buttonLeft && !pressed){
            XClientMessageEvent xev;
            xev.type = ClientMessage;
            xev.window = client.window;
            xev.message_type = atoms._NET_ACTIVE_WINDOW;
            xev.format = 32;
            xev.data.l[0] = 2;
            xev.data.l[1] = CurrentTime;
            xev.data.l[2] = bar.currentWindow;
            xev.data.l[3] = 0;    /* manager specific data */
            xev.data.l[4] = 0;    /* manager specific data */
            XSendEvent(wm.displayHandle, .root, false, StructureNotifyMask, cast(XEvent*) &xev);
            super.onMouseButton(button, pressed, x, y);
        }else if(button == Mouse.buttonMiddle && !pressed){
            client.requestClose;
        }
    }

}