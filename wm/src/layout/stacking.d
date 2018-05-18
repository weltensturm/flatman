module flatman.layout.stacking;

import flatman;


enum Stacking {
    unmanaged,
    fullscreen,
    global,
    popup,
    floating,
    tabs
}


Stacking order(Client client){
    if(client.isfullscreen)
        return Stacking.fullscreen;
    if(client.global)
        return Stacking.global;
    if(client.isFloating)
        return Stacking.floating;
    else
        return Stacking.tabs;
}

