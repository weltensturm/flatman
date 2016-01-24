module menu.history;


import menu;


void addHistory(DynamicList list, Inotify.WatchStruct* watcher){
	auto buttonHistory = new RootButton("History");
	buttonHistory.resize([5,25]);
	auto history = list.addNew!Tree(buttonHistory);
	buttonHistory.set(history);
	history.expanded = true;
	history.padding = 0;
	auto changeHistory = (string p, string f){
		if(!f.endsWith(".exec") && !f.endsWith("current"))
			return;
		foreach(c; history.children){
			if(c != history.expander)
				history.remove(c);
		}
		foreach(entry; .history){
			auto split = entry.bangSplit;
			ButtonExec button;
			switch(split[0]){
				case "desktop":
					button = new ButtonDesktop(split[1]);
					break;
				case "script":
					button = new ButtonScript(split[1]);
					break;
				case "file":
					button = new ButtonFile(split[1], false);
					break;
				default:
					writeln("unknown type: ", split[0]);
			}
			if(button){
				button.resize([5,20]);
				button.parameter = split[2];
				history.add(button);
			}
		}
	};
	watcher.change ~= changeHistory;
	changeHistory("", ".exec");
}