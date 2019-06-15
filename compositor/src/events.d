module composite.events;


import
    x11.X,
    x11.Xlib,
    common.event;

import ws.wm: wm;


alias Tick = Event!("Tick", void function());
alias OverviewState = Event!("OverviewState", void function(double));
