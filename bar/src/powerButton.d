module bar.powerButton;

import bar;


class PowerButton: Base {

    bool mouseFocus;
    Bar bar;

    this(Bar bar){
        this.bar = bar;
    }

    override void onMouseFocus(bool focus){
        mouseFocus = focus;
        bar.second = 0;
    }

    override void onDraw(){
        draw.setColor(mouseFocus ? 0xeeeeee : 0x999999);
        draw.rect(pos, size);
    }

}