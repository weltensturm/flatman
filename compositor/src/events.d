module composite.events;


import
    common.event;

import ws.wm: wm;


alias Tick = Event!("Tick", void function());
alias OverviewState = Event!("OverviewState", void function(double));
