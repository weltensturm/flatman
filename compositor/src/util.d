module composite.util;

import composite;

/+
double rip(double dist, double a, double b, double delta){
    // t(dist) = sqrt(dist+a)/b
    // dist = (t*b)^^2-a
    // jump = dist(t) - dist(t-delta)
    return (((sqrt(dist)/b+delta)*b)^^2 - dist).max(a*delta).min(dist);
}
+/
double rip(double dist, double a, double b, double delta){
    // t(dist) = cbrt(dist+a)/b
    // dist = (t*b)^^3-a
    // jump = dist(t) - dist(t-delta)
    b /= 4;
    return (((cbrt(dist)/b+delta)*b)^^3 - dist).max(a*delta).min(dist);
}

double rip(double current, double target, double a, double b, double delta){
    return current + rip((current-target).abs, a, b, delta)*(current < target ? 1 : -1);
}

void rip(ref double[2] current, double[2] target, double a, double b, double delta){
    double[2] dir = [target.x - current.x, target.y - current.y];
    auto dist = sqrt(dir.x^^2 + dir.y^^2);
    if(dist <= 0.0000001) // dividing by zero is not good
        return;
    double[2] normalized = [dir.x/dist, dir.y/dist];
    auto jump = rip(dist, a, b, delta);
    current.x += normalized.x*jump;
    current.y += normalized.y*jump;
}


class X {
    // the things I do for debugging
    template opDispatch(string s){
        static auto opDispatch(Args...)(Args args){
            mixin("alias returns = ReturnType!(X" ~ s ~ ");");
            static if(!is(returns == void)){
                mixin("auto result = X" ~ s ~ "(args);");
                debug {
                    checkXerror;
                }
                return result;
            }else{
                mixin("X" ~ s ~ "(args);");
                debug {
                    checkXerror;
                }
            }
        }
    }
}

bool inside(int[2] pos, int[2] rectPos, int[2] rectSize, int height){
    return 
        pos.x > rectPos.x
        && pos.y > height - rectPos.y - rectSize.h
        && pos.x < rectPos.x + rectSize.w
        && pos.y < height - rectPos.y;
}


int[2] translate(T1, T2, T3)(T1[2] pos, T2 h, T3 h2=0){
    return [pos.x, h-h2-pos.y].to!(int[2]);
}


double animate(double start, double end, double state){
    return start + (end - start)*state;
}


double sinApproach(double a){
    return (sin((a-0.5)*PI)+1)/2;
}


struct Profile {
    __gshared size_t level;
    string name;
    double start;
    bool force;
    this(string name, bool force=false){
        level++;
        this.force = force;
        debug(Profile){
            this.force = true;
        }
        this.name = name;
        start = now;
    }

    ~this(){
        level--;
        auto diff = now - start;
        if(force || diff > 1/60.0/2 && name != "Sleep"){
            writeln(" ".replicate(level*4) ~ "%3.5f".format(diff) ~ ": " ~ name);
        }
    }
}


x11.X.Window[] queryTree(){
    x11.X.Window[] result;
    XGrabServer(wm.displayHandle);
    x11.X.Window root_return, parent_return;
    x11.X.Window* children;
    uint count;
    XQueryTree(wm.displayHandle, root, &root_return, &parent_return, &children, &count);
    if(children && root == root_return){
        result = children[0..count].dup;
        XFree(children);
    }
    XUngrabServer(wm.displayHandle);
    return result;
}


struct RotatingArray(size_t Size, T) {
    T[Size] elements = [0].replicate(Size);
    size_t counter;
    void opOpAssign(string op)(T value) if(op == "~"){
        elements[counter++] = value;
        if(counter >= Size)
            counter = 0;
    }
    T first(){
        return elements[counter];
    }
    int opApply(int delegate(T value) dg){
        return opApply((size_t, T value){ return dg(value); });
    }
    int opApply(int delegate(size_t idx, T value) dg){
        int res = 0;
        foreach(i; counter..Size+counter){
            res = dg(i-counter, elements[i >= Size ? i-Size : i]);
            if(res)
                break;
        }
        return res;
    }
    int size(){
        return Size.to!int;
    }
}


Picture colorPicture(bool argb, double a, double r, double g, double b){
    auto pixmap = XCreatePixmap(wm.displayHandle, root, 1, 1, argb ? 32 : 8);
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


enum XRequestCodes = [
    1:		"X_CreateWindow",
    2:		"X_ChangeWindowAttributes",
    3:		"X_GetWindowAttributes",
    4:		"X_DestroyWindow",
    5:		"X_DestroySubwindows",
    6:		"X_ChangeSaveSet",
    7:		"X_ReparentWindow",
    8:		"X_MapWindow",
    9:		"X_MapSubwindows",
    10:		"X_UnmapWindow",
    11:		"X_UnmapSubwindows",
    12:		"X_ConfigureWindow",
    13:		"X_CirculateWindow",
    14:		"X_GetGeometry",
    15:		"X_QueryTree",
    16:		"X_InternAtom",
    17:		"X_GetAtomName",
    18:		"X_ChangeProperty",
    19:		"X_DeleteProperty",
    20:		"X_GetProperty",
    21:		"X_ListProperties",
    22:		"X_SetSelectionOwner",
    23:		"X_GetSelectionOwner",
    24:		"X_ConvertSelection",
    25:		"X_SendEvent",
    26:		"X_GrabPointer",
    27:		"X_UngrabPointer",
    28:		"X_GrabButton",
    29:		"X_UngrabButton",
    30:		"X_ChangeActivePointerGrab",
    31:		"X_GrabKeyboard",
    32:		"X_UngrabKeyboard",
    33:		"X_GrabKey",
    34:		"X_UngrabKey",
    35:		"X_AllowEvents",
    36:		"X_GrabServer",
    37:		"X_UngrabServer",
    38:		"X_QueryPointer",
    39:		"X_GetMotionEvents",
    40:		"X_TranslateCoords",
    41:		"X_WarpPointer",
    42:		"X_SetInputFocus",
    43:		"X_GetInputFocus",
    44:		"X_QueryKeymap",
    45:		"X_OpenFont",
    46:		"X_CloseFont",
    47:		"X_QueryFont",
    48:		"X_QueryTextExtents",
    49:		"X_ListFonts",
    50:		"X_ListFontsWithInfo",
    51:		"X_SetFontPath",
    52:		"X_GetFontPath",
    53:		"X_CreatePixmap",
    54:		"X_FreePixmap",
    55:		"X_CreateGC",
    56:		"X_ChangeGC",
    57:		"X_CopyGC",
    58:		"X_SetDashes",
    59:		"X_SetClipRectangles",
    60:		"X_FreeGC",
    61:		"X_ClearArea",
    62:		"X_CopyArea",
    63:		"X_CopyPlane",
    64:		"X_PolyPoint",
    65:		"X_PolyLine",
    66:		"X_PolySegment",
    67:		"X_PolyRectangle",
    68:		"X_PolyArc",
    69:		"X_FillPoly",
    70:		"X_PolyFillRectangle",
    71:		"X_PolyFillArc",
    72:		"X_PutImage",
    73:		"X_GetImage",
    74:		"X_PolyText8",
    75:		"X_PolyText16",
    76:		"X_ImageText8",
    77:		"X_ImageText16",
    78:		"X_CreateColormap",
    79:		"X_FreeColormap",
    80:		"X_CopyColormapAndFree",
    81:		"X_InstallColormap",
    82:		"X_UninstallColormap",
    83:		"X_ListInstalledColormaps",
    84:		"X_AllocColor",
    85:		"X_AllocNamedColor",
    86:		"X_AllocColorCells",
    87:		"X_AllocColorPlanes",
    88:		"X_FreeColors",
    89:		"X_StoreColors",
    90:		"X_StoreNamedColor",
    91:		"X_QueryColors",
    92:		"X_LookupColor",
    93:		"X_CreateCursor",
    94:		"X_CreateGlyphCursor",
    95:		"X_FreeCursor",
    96:		"X_RecolorCursor",
    97:		"X_QueryBestSize",
    98:		"X_QueryExtension",
    99:		"X_ListExtensions",
    100:	"X_ChangeKeyboardMapping",
    101:	"X_GetKeyboardMapping",
    102:	"X_ChangeKeyboardControl",
    103:	"X_GetKeyboardControl",
    104:	"X_Bell",
    105:	"X_ChangePointerControl",
    106:	"X_GetPointerControl",
    107:	"X_SetScreenSaver",
    108:	"X_GetScreenSaver",
    109:	"X_ChangeHosts",
    110:	"X_ListHosts",
    111:	"X_SetAccessControl",
    112:	"X_SetCloseDownMode",
    113:	"X_KillClient",
    114:	"X_RotateProperties",
    115:	"X_ForceScreenSaver",
    116:	"X_SetPointerMapping",
    117:	"X_GetPointerMapping",
    118:	"X_SetModifierMapping",
    119:	"X_GetModifierMapping",
    127:	"X_NoOperation"
];

