module common.event;


import
    std.meta,
    std.functional,
    std.traits,
    std.typecons,
    std.algorithm;


enum AnyValueType { AnyValue }
alias AnyValue = AnyValueType.AnyValue;

template Event(alias Unique, Functions...) if(allSatisfy!(isFunctionPointer, Functions)) {

    alias Overloads = Functions;

    template callbacks(Args...){
    	static void delegate(Args)[] callbacks;
    }

    template forgetters(T){
        static void delegate()[T] forgetters;
    }

    void registerCallback(Fn, Callback)(Fn fn, Callback callback){
        callbacks!(Parameters!Callback) ~= callback;
        forgetters!(typeof(fn))[fn] = {
            callbacks!(Parameters!Callback) = callbacks!(Parameters!Callback).remove!(a => a == callback);
        };
    }

	struct Event {

        static foreach(Overload; Overloads){

    		static void opCall(Parameters!Overload args){
                callbacks!(Parameters!Overload).each!(a => a(args));
    		}

    		static void opOpAssign(string op)(void delegate(Parameters!Overload) fn) if(op == "~") {
                registerCallback(fn, fn);
    		}

    		static void opOpAssign(string op)(void function(Parameters!Overload) fn) if(op == "~") {
                registerCallback(fn, fn.toDelegate);
            }

        }

		static void opOpAssign(string op, Fn)(Fn fn) if(op == "~") {
            static assert(false, FunctionTypeOf!Fn.stringof ~ " does not match "
                                 ~ Unique ~ " " ~ FunctionTypeOf!(Functions[0]).stringof);
        }

        static auto opIndex(FilterArgs...)(FilterArgs filter){

            struct Filter {

                FilterArgs filter; // TODO: write dmd issue

                static foreach(Overload; Functions){

            		void opOpAssign(string op)(void delegate(Parameters!Overload[FilterArgs.length..$]) fn)
                    if(op == "~"){
                        auto wrapper = filteredCallback!(Tuple!(Parameters!Overload))(fn, filter);
                        registerCallback(fn, wrapper);
                    }

            		void opOpAssign(string op)(void function(Parameters!Overload[FilterArgs.length..$]) fn)
                    if(op == "~"){
                        auto wrapper = filteredCallback!(Tuple!(Parameters!Overload))(fn, filter);
                        registerCallback(fn, wrapper);
                    }

                }

        		void opOpAssign(string op, O)(O o) if(op == "~"){
                    static assert(false, Tuple!(FilterArgs, Parameters!O).Types.stringof ~ " does not match "
                                         ~ Unique ~ " " ~ FunctionTypeOf!(Functions[0]).stringof);
                }

            }

            return Filter(filter);
        }

        static void forget(Fn)(Fn fn){
            forgetters!(typeof(fn))[fn]();
            forgetters!(typeof(fn)).remove(fn);
        }

	}

}


struct Events {

    static opOpAssign(string op, T)(T object) if(op == "~") {
        static foreach(member; getMembersByUDA!(T, Event)){
            static foreach(uda; member.uda){
                uda ~= getMemberPointer!(member.name, T, member.signature)(object);
            }
        }

    }

    static void forget(T)(T object){
        static foreach(member; getMembersByUDA!(T, Event)){
            static foreach(uda; member.uda){
                uda.forget(getMemberPointer!(member.name, T, member.signature)(object));
            }
        }
    }

    static auto opIndex(FilterArgs...)(FilterArgs args){
        struct Filter {
            FilterArgs args;
            void opOpAssign(string op, T)(T object) if(op == "~") {

                static foreach(member; getMembersByUDA!(T, Event)){
                    static foreach(uda; member.uda){
                        uda[args] ~= getMemberPointer!(member.name, T, member.signature)(object);
                    }
                }
            }
        }
        return Filter(args);
    }

}


auto getMemberPointer(string name, T, Signature)(T object){
    mixin("return cast(Signature)&object." ~ name ~ ";");
}


template getMembersByUDA(alias object, alias uda){
    alias getMembersByUDA = getMembersByUDAImpl!(object, uda, __traits(allMembers, object));
}

template getMembersByUDAImpl(alias object, alias uda, names...){
    static if(names.length == 0){
        alias getMembersByUDAImpl = AliasSeq!();
    }else{
        alias tail = getMembersByUDAImpl!(object, uda, names[1..$]);
        static if(!__traits(compiles, __traits(getMember, object, names[0]))){
            alias getMembersByUDAImpl = tail;
        }else{
            alias member = AliasSeq!(__traits(getMember, object, names[0]));
            static if(hasUDA!(member, uda)){
                enum hasSpecificUDA(alias member) = hasUDA!(member, uda);
                import std.meta : Filter;
                alias overloadsWithUDA = Filter!(hasSpecificUDA, __traits(getOverloads, object, names[0]));
                alias getMembersByUDAImpl = AliasSeq!(functionOverloadsByUDA!(names[0], uda, overloadsWithUDA),
                                                      tail);
            }else{
                alias getMembersByUDAImpl = tail;
            }
        }
    }

}


private template functionOverloadsByUDA(string name, alias uda, Fn...) {

    template Result(string name_, signature_, uda_...){
        enum name = name_;
        alias signature = signature_;
        alias uda = AliasSeq!(uda_);
    }

    static if(Fn.length == 0){
        alias functionOverloadsByUDA = AliasSeq!();
    }else{
        alias Tail = Fn[1..$];
        alias FunctionType = ReturnType!(Fn[0]) delegate(Parameters!(Fn[0]));
        alias functionOverloadsByUDA = AliasSeq!(
            Result!(
                name,
                FunctionType,
                AliasSeq!(getUDAs!(Fn[0], uda))
            ),
            functionOverloadsByUDA!(name, uda, Tail)
        );
    }

}


private auto filteredCallback(Args, Fn, Filter...)(Fn fn, Filter filter){
    return (Args.Types args){
        static foreach(i, Type; Filter){
            if(!is(Type == AnyValueType) && filter[i] != args[i]){
                return;
            }
        }
        fn(args[Filter.length..$]);
    };
}


unittest {

    alias Event1 = Event!("Event1", void function(int, double));

    alias Event2 = Event!("Event2", void function(int, string));

    class Slots {

        int id;
        double d;
        string s;
        double asdf;

        this(int id){
            this.id = id;
            Events[id] ~= this;
        }

        void destroy(){
            Events.forget(this);
        }

        @Event1
        void handler1(double d=asdf){
            this.d = d;
        }

        @Event2
        void handler2(string s){
            this.s = s;
        }

    }

    auto slots1 = new Slots(1);
    auto slots2 = new Slots(2);

    Event1(1, 0.5);
    Event2(2, "test");

    assert(slots1.d == 0.5);
    assert(slots1.s == "");
    assert(slots2.s == "test");
    import std.math: isNaN;
    assert(slots2.d.isNaN);


    alias Event3 = Event!("Event3", void function(), void function(int));

    alias Event4 = Event!("Event4", void function(int));

    Event4 ~= (int=5){};

    class Overloaded {

        bool first;
        bool second;

        @Event3 void test(){ first=true; }

        @Event3 void test(int){ second=true; }

    }

    auto instance = new Overloaded;

    Events ~= instance;

    Event3();
    Event3(1);

    assert(instance.first);
    assert(instance.second);

}
