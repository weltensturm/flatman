module menu.history;


import menu;


ButtonExec[][string] histories;


private ButtonExec add(string contextPath, string text){
	auto split = text.bangSplit;
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
	}
	if(contextPath !in histories)
		histories[contextPath] = [button];
	else
		histories[contextPath] = button ~ histories[contextPath];
	return button;
}


void addHistory(DynamicList list, Inotify.WatchStruct* watcher){
	auto buttonHistory = new RootButton("History");
	buttonHistory.resize([5,25]);
	auto history = list.addNew!Tree(buttonHistory);
	buttonHistory.set(history);
	history.expanded = true;
	history.padding = 0;
	auto changeHistory = (string p, string f){
		auto contextPath = contextPath;
		if(f.endsWith(".exec")){
			
		}else if(f.endsWith("current")){
			if(contextPath !in histories){
				foreach(entry; .history){
					
				}
			}
		}
	};
	//watcher.change ~= changeHistory;
	changeHistory("", ".exec");
}
