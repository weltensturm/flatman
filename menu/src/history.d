module menu.history;

import menu;


ButtonExec[][string] histories;


void addHistory(DynamicList list){

	auto expander = new HistoryRootButton;
	expander.resize([5, config["button-tab", "height"].to!int]);
	auto tree = list.addNew!Tree(expander);
	tree.inset = 0;
	tree.tail = 10;
	expander.set(tree);
	tree.expanded = true;
	tree.padding = 0;

	auto watch = (string path, string file, int action){
		if(file.endsWith(".exec") || file.endsWith("current")){
			tree.children = [expander];
			expander.update = true;
		}
	};
	
	Inotify.watch("~/.flatman/".expandTilde, watch);

	watch("", ".exec", Inotify.Add);
}


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
			//button = new ButtonFile(split[1], split[0]=="directory", ButtonFile.ContextPath);
			break;
		default:
			writeln("unknown type: ", split[0]);
	}
	if(button){
		button.resize([5,20]);
		button.parameter = split[2];
		//button.status = h.status;
		//button.pid = h.pid;
	}
	if(contextPath !in histories)
		histories[contextPath] = [button];
	else
		histories[contextPath] = button ~ histories[contextPath];
	return button;
}


class HistoryRootButton: RootButton {

	shared Queue!CommandInfo queue;

	bool update;
	string context;

	this(){
		queue = new Queue!CommandInfo;
		super("History");
	}

	override void onDraw(){
		super.onDraw;
		draw.setColor([0.6,0.6,0.6]);
		draw.text(pos.a+[size.w,0], size.h, context, 1.75);
		if(update){
			shared auto queue = new Queue!CommandInfo;
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

		while(queue.has){
			auto h = queue.get;
			auto btn = .add(contextPath, h);
			if(btn){
				parent.to!Tree.add(btn, (e){
					if(!e)
						return true;
					if(typeid(e) == typeid(btn)){
						string a = e.to!ButtonExec.sortName;
						string b = btn.sortName;
						if(a.startsWith(".") != b.startsWith("."))
							return b.startsWith(".");
						//if(a.isDirectoryTree != b.isDirectoryTree)
						//	return a.isDirectoryTree;
						return a.toUpper > b.toUpper;	
					}
					if(typeid(btn) == typeid(ButtonDesktop) && (typeid(e) == typeid(ButtonFile) || typeid(e) == typeid(ButtonScript)))
						return true;
					if(typeid(btn) == typeid(ButtonScript) && (typeid(e) == typeid(ButtonFile)))
						return true;
					return false;
				});
			}
		}

	}

}
