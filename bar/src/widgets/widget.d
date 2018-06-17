module bar.widget.widget;


import bar;


class Widget: Base {

    int savedWidth;

    int width(){
        return 0;
    }

    void tick(){}

    void destroy(){}

    enum Alignment {
        left,
        right,
        center
    }

    Alignment alignment;

}
