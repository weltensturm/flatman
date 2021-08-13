module composite.overview.activeContainerIndicator;

import
    ws.math.vector,
    common.event,
    composite.util,
    composite.events,
    composite.overview.dock,
    composite.overview.widget,
    composite.animation,
    composite.backend.xrenderMultiDraw;


class ActiveContainerIndicator: Widget {

    int[2] targetPos;
    int[2] targetSize;

    OverviewAnimation animation;

    double state;

    this(){
        animation = new OverviewAnimation(pos, size);
        Events ~= this;
    }

    ~this(){
        Events.forget(this);
    }

    @OverviewState
    void onState(double state){
        if(state == this.state)
            return;
        this.state = state;
        damage;
    }

    @Tick
    void onTick(){
        animation.approach(targetPos, targetSize);
        move(animation.pos.calculate);
        resize(animation.size.calculate);
    }

    void draw(XRenderMultiDraw backend){
        enum border = 4;
        backend.setColor([1, 1, 1, state]);
        backend.rect([pos.x, pos.y], [border, size.h]);
        backend.rect([pos.x+size.w-border, pos.y], [border, size.h]);
        backend.rect([pos.x+border, pos.y], [size.w-border*2, border]);
        backend.rect([pos.x+border, pos.y+size.h-border], [size.w-border*2, border]);
    }

}
