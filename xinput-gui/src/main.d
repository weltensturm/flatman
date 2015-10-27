module input.main;

import input;


Display* dpy;


void spawnMainWindow(){
	auto w = new MainWindow("Input Settings");
	w.setModal(true);
	w.setBorderWidth(2);
	w.setDefaultSize(1200, cast(int)(200));
	
	auto stack = new Stack;
	addDevices(stack);
	w.add(stack);
	//auto container = new StackSwitcher;
	//container.setStack(stack);
	//w.add(container);
	w.grabFocus;
	w.addOnFocusOut((GdkEventFocus* c, w){
		w.hide;
		return true;
	});
	w.showAll;
}

void main(string[] args){
	Main.init(args);
	Screen screen;
	GdkRectangle area;
	GtkOrientation orientation;
	spawnMainWindow;
	Main.run;
}

void addDevices(Stack stack){

	dpy = XOpenDisplay(null);
	int ret;
	auto devices = XIQueryDevice(dpy, XIAllDevices, &ret);
	foreach(i, device; devices[0..ret]){
		device.name.to!string.writeln;
		stack.addNamed(new DeviceContainer(device), "%s %s".format(i, device.name));
	}
	XIFreeDeviceInfo(devices);

}


class DeviceContainer: ListBox {

	this(XIDeviceInfo device){
		setBorderWidth(10);

		int ret;
		auto properties = XIListProperties(dpy, device.deviceid, &ret);
		foreach(property; properties[0..ret]){

			Atom type;
			int format;
			ulong num;
			ulong bytes;
			ubyte* data;

			auto success = XIGetProperty(dpy, device.deviceid, property, 0, 0, false, 0, &type, &format, &num, &bytes, &data);

			"\t%s = %s".format(property.name, data).writeln;

			insert(new Label(property.name), -1);

			XFree(data);
		}

	}

}

string name(Atom atom){
	auto s = XGetAtomName(dpy, atom);
	auto str = s.to!string;
	XFree(s);
	return str;
}