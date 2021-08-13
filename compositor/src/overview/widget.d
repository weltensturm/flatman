module composite.overview.widget;

import
    std.math,
    std.conv,
    ws.gui.base,
    composite.damage
    ;



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
            damage.damage(pos, size);
        };
        if(tagged)
            translatedDamage(pos, size);
        tagged = false;

        foreach(dmg; trackedDamage)
            translatedDamage(dmg.pos, dmg.size);
        trackedDamage = [];
    }

}
