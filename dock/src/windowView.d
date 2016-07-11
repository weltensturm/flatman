module dock.windowView;

import dock;

__gshared:


class WindowView: Base {

	Base dragGhost;
	int[2] dragOffset;
	Base dropTarget;

	CompositeClient window;
	int desktop;

	this(CompositeClient window, int desktop){
		this.window = window;
		this.desktop = desktop;
	}

	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		if(button == Mouse.buttonLeft){
			if(!pressed && dragGhost){
				root.remove(dragGhost);
				if(dropTarget)
					dropTarget.drop(x, y, dragGhost);
				dragGhost = null;
			}
		}
		super.onMouseButton(button, pressed, x, y);
	}

	override Base drag(int[2] offset){
		dragOffset = offset;
		return new Ghost(window, desktop);
	}

	override void onMouseMove(int x, int y){
		if(buttons.get(Mouse.buttonLeft, false) && !dragGhost){
			dragGhost = drag([x,y].a - pos);
			root.add(dragGhost);
			root.setTop(dragGhost);
			dragGhost.resize(size);
			writeln("dragStart");
		}
		if(dragGhost){
			dragGhost.move([x,y].a - dragOffset);
			if(root.dropTarget(x, y, dragGhost) != dropTarget){
				if(dropTarget)
					dropTarget.dropPreview(x, y, dragGhost, false);
				dropTarget = root.dropTarget(x, y, dragGhost);
				if(dropTarget)
					dropTarget.dropPreview(x, y, dragGhost, true);
			}
		}
		super.onMouseMove(x, y);
	}

	override void onDraw(){
		if(dragGhost)
			return;
		damage.remove(window.windowHandle);
		if(window.picture)
			composite.draw(window, pos, size);
		super.onDraw;
	}

}
