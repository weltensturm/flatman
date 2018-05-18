module bar.plugins;

import bar;


static if(false){

	import commando;

	void loadGlobals(Stack stack){

		plugins["on"] = (Parameter[] params, Variable context){
			auto block = params[$-1].get(context).block;
			context[params[0].text(context)] = (Parameter[] params, Variable _){
				auto inner = .context(context);
				foreach(statement; block){
					auto res = statement.run(inner);
					if("__return" in inner.data.map)
						return [inner.data.map["__return"]];
				}
				return nothing;
			};
			return nothing;
		};

		plugins["plugin"] = (Parameter[] params, Variable context){
			auto block = params[$-1].get(context).block;
			auto plugin = .context(context);
			this.plugins[params[0].text(context)] = plugin;
			foreach(statement; block){
				auto res = statement.run(plugin);
			}
			return nothing;
		};

		plugins["color"] = (double r, double g, double b){
			bar.draw.setColor([r, g, b]);
		};

		plugins["rect"] = (int x, int y, int w, int h){
			bar.draw.rect([x, y], [w, h]);
		};

	}

	class Plugins {

		Variable[string] plugins;

		Interpreter commando;

		Bar bar;

		this(Bar bar){
			this.bar = bar;
			commando = new Interpreter;
			commando.load([&loadBuiltins, &loadEcho, &loadGlobals]);

            auto paths = ["plugins/test.cm", "plugins/taskList.cm"];
            foreach(p; paths){
                if(p.exists)
                    commando.load();
            }
		}

		void event(string name){
			try {
				foreach(p; plugins)
					p[name]([], Variable());
			}catch(CommandoError e){
				writeln("Exception:");
				writeln(e.to!string);
			}
		}

	}
	
}
