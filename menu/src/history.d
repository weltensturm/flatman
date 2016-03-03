module menu.history;


import menu;



ButtonExec[][string] histories;


private ButtonExec add(string contextPath, CommandInfo h){
	auto split = h.serialized.bangSplit;
	ButtonExec button;
	switch(split[0]){
		case "desktop":
			button = new ButtonDesktop(split[1]);
			break;
		case "script":
			button = new ButtonScript(split[1]);
			break;
		case "file":
		case "directory":
			button = new ButtonFile(split[1], split[0]=="directory", ButtonFile.ContextPath);
			break;
		default:
			writeln("unknown type: ", split[0]);
	}
	if(button){
		button.resize([5,20]);
		button.parameter = split[2];
		button.status = h.status;
		button.pid = h.pid;
	}
	if(contextPath !in histories)
		histories[contextPath] = [button];
	else
		histories[contextPath] = button ~ histories[contextPath];
	return button;
}


void addHistory(DynamicList list, Inotify.WatchStruct* watcher){

	auto expander = new HistoryRootButton;
	expander.resize([5, config["button-tab", "height"].to!int]);
	auto tree = list.addNew!Tree(expander);
	tree.inset = 0;
	tree.tail = 10;
	expander.set(tree);
	tree.expanded = false;
	tree.padding = 0;

	expander.leftClick ~= {
		foreach(c; list.children){
			if(auto t = cast(Tree)c){
				if(t != tree && t.expanded)
					t.toggle;
			}
		}
	};
	
	auto changeHistory = (string p, string f){
		if(f.endsWith(".exec") || f.endsWith("current")){
			tree.children = [expander];
			expander.update = true;
		}
	};
	watcher.change ~= changeHistory;
	changeHistory("", ".exec");
}

class HistoryRootButton: RootButton {

	shared Queue!CommandInfo queue;

	bool update;
	string context;

	int[] preview;

	this(){
		queue = new Queue!CommandInfo;
		super("History");
	}

	override void onDraw(){
		super.onDraw;
		foreach(i, status; preview){
			if(i*2 >= size.h)
				continue;
			if(status == int.max)
				draw.setColor([0.7,0.7,0.7]);
			else if(status != 0)
				draw.setColor([1,0,0]);
			else
				draw.setColor([0.4,0.4,0.4]);
			draw.rect(pos.a+[0, size.h-i*2-2], [2,2]);
		}
		draw.setColor([0.6,0.6,0.6]);
		draw.text(pos.a+[size.w,0], size.h, context, 1.75);
		if(update){
			shared auto queue = new Queue!CommandInfo;
			preview = [];
			parent.children = [this];
			update = false;
			task({
				context = .context.nice;
				auto contextPath = contextPath;
				string[] alreadyAdded;
				foreach_reverse(h; .historyInfo){
					auto btn = .add(contextPath, h);
					if(!btn || alreadyAdded.canFind(btn.exec))
						continue;
					alreadyAdded ~= btn.exec;
					queue.add(h);
				}	
			}).executeInNewThread;
			this.queue = queue;
		}

		if(queue.has){
			auto h = queue.get;
			auto btn = .add(contextPath, h);
			if(btn){
				parent.add(btn);
				preview ~= h.status;
			}
		}

	}

}