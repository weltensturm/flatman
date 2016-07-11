module bar.alpha;

import bar;


enum ALPHA_STEPS = 256;

Picture[ALPHA_STEPS] alpha;

Picture colorPicture(bool argb, double a, double r, double g, double b){
    auto pixmap = XCreatePixmap(wm.displayHandle, .root, 1, 1, argb ? 32 : 8);
    if(!pixmap)
        return None;
    XRenderPictureAttributes pa;
    pa.repeat = True;
    auto picture = XRenderCreatePicture(wm.displayHandle, pixmap, XRenderFindStandardFormat(wm.displayHandle, argb 	? PictStandardARGB32 : PictStandardA8), CPRepeat, &pa);
    if(!picture){
        XFreePixmap(wm.displayHandle, pixmap);
        return None;
    }
    XRenderColor c;
    c.alpha = (a * 0xffff).to!ushort;
    c.red =   (r * 0xffff).to!ushort;
    c.green = (g * 0xffff).to!ushort;
    c.blue =  (b * 0xffff).to!ushort;
    XRenderFillRectangle(wm.displayHandle, PictOpSrc, picture, &c, 0, 0, 1, 1);
    XFreePixmap(wm.displayHandle, pixmap);
    return picture;
}

void initAlpha(){
    foreach(i; 0..ALPHA_STEPS){
        if(i < ALPHA_STEPS-1)
            alpha[i] = colorPicture(false, i/cast(float)(ALPHA_STEPS-1), 0, 0, 0);
        else
            alpha[i] = None;				
    }
}
