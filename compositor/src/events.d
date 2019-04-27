module composite.events;


import
    x11.X,
    x11.Xlib,
    common.event;

import ws.wm: wm;


alias WindowProperty = Event!("Property", void function(x11.X.Window, Atom));
alias Tick = Event!("Tick", void function());
alias OverviewState = Event!("OverviewState", void function(double));

void listen(){
    wm.on([
        PropertyNotify: (XEvent* e) => WindowProperty(e.xproperty.window, e.xproperty.atom)
    ]);
}


