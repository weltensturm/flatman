module composite.animation;


import composite;




class OverviewAnimation {
    Animation[2] size;
    Animation[2] pos;
    this(int[2] pos, int[2] size){
    	enum duration = 0.2;
    	this.pos = [new Animation(pos.x, pos.x, duration/config.animationSpeed, &sigmoid),
    			    new Animation(pos.y, pos.y, duration/config.animationSpeed, &sigmoid)];
    	this.size = [new Animation(size.w, size.w, duration/config.animationSpeed, &sigmoid),
    				 new Animation(size.h, size.h, duration/config.animationSpeed, &sigmoid)];
    }
    void approach(int[2] pos, int[2] size){
    	if(this.pos.x.end.to!int != pos.x)
    		this.pos.x.change(pos.x);
    	if(this.pos.y.end.to!int != pos.y)
    		this.pos.y.change(pos.y);
    	if(this.size.w.end.to!int != size.w)
    		this.size.w.change(size.w);
    	if(this.size.h.end.to!int != size.h)
    		this.size.h.change(size.h);
    }
}



class Animation {

	static double time;
	static void update(){
		time = now;
	}

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
		this.timeStart = time;
		this.duration = duration;
		this.func = func;
	}

	void change(double value){
		start = calculate;
		end = value;
		timeStart = time;
	}

	void change(double value, double duration){
		change(value);
		this.duration = duration;
	}

	void change(double value, double function(double) func){
		change(value);
		this.func = func;
	}

	void replace(double start, double end){
		this.start = start;
		this.end = end;
		timeStart = time;
	}

	void replace(double end){
		this.start = end;
		this.end = end;
		timeStart = time;
	}

	double completion(){
		if(done)
			return 1;
		return (time - timeStart).min(duration)/duration;
	}

	double calculate(){
		if(done)
			return end;
		return start + (end-start)*func(completion).min(1).max(0);

	}

	bool done(){
		return timeStart+duration < time;
	}

	double timeCurrent(){
		return time;
	}

}

