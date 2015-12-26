module composite.animation;


import composite;


class Animation {

	double start;
	double end;
	double timeStart;
	double duration;
	double function(double) func;

	this(double value){
		this(value, value, 1);
	}

	this(double value, double function(double) func){
		this(value, value, 1, func);
	}

	this(double start, double end, double duration){
		this(start, end, duration, a => a);
	}

	this(double start, double end, double duration, double function(double) func){
		this.start = start;
		this.end = end;
		this.timeStart = Clock.currSystemTick.msecs/1000.0;
		this.duration = duration;
		this.func = func;
	}

	void change(double value){
		start = calculate;
		end = value;
		timeStart = Clock.currSystemTick.msecs/1000.0;
	}

	void change(double value, double function(double) func){
		change(value);
		this.func = func;
	}

	void replace(double start, double end){
		this.start = start;
		this.end = end;
		timeStart = Clock.currSystemTick.msecs/1000.0;
	}

	double calculate(){
		double completion = (timeCurrent - timeStart).min(duration)/duration;
		return start + (end-start)*func(completion);
	}

	bool done(){
		return timeStart+duration < timeCurrent;
	}

	double timeCurrent(){
		return Clock.currSystemTick.msecs/1000.0;
	}

}


