module common.event;


import
    std.array,
    std.meta,
    std.functional,
    std.traits,
    std.typecons,
    std.algorithm,
    std.file;


enum AnyValueType { AnyValue }
alias AnyValue = AnyValueType.AnyValue;

template Event(alias Unique, Functions...) if(allSatisfy!(isFunctionPointer, Functions)) {

    alias Overloads = Functions;

    template callbacks(Fn){
        static void delegate(Parameters!Fn)[] callbacks;
    }

    template forgetters(T){
        static void delegate()[T] forgetters;
    }

    void registerCallback(Fn, Callback)(Fn fn, Callback callback){
        callbacks!Callback ~= callback;
        forgetters!(typeof(fn))[fn] = {
            callbacks!Callback = callbacks!Callback.filter!(a => a != callback).array;
        };
    }

    struct Event {

        static foreach(Overload; Overloads){

            static void opCall(Parameters!Overload args){
                callbacks!(void delegate(Parameters!Overload)).each!(a => a(args));
            }

            static void opOpAssign(string op: "~")(void delegate(Parameters!Overload) fn){
                registerCallback(fn, fn);
            }

            static void opOpAssign(string op: "~")(void function(Parameters!Overload) fn){
                registerCallback(fn, fn.toDelegate);
            }

        }

        static forget(Fn)(Fn fn) {
            static if(isDelegate!Fn) {
                alias Type = void delegate(Parameters!Fn);
            } else {
                alias Type = void function(Parameters!Fn);
            }
            forgetters!Type[fn]();
            forgetters!Type.remove(fn);
        }

        static opOpAssign(string op: "~", Fn)(Fn fn) {
            static assert(false, FunctionTypeOf!Fn.stringof ~ " does not match "
                          ~ Unique ~ " " ~ FunctionTypeOf!(Functions[0]).stringof);
        }

        static opIndex(FilterArgs...)(FilterArgs filter){
            return FilteredEvent!(Unique, Tuple!Functions, registerCallback, forget, FilterArgs)(filter);
        }

    }

}

struct FilteredEvent(alias Unique, alias Functions, alias registerCallback, alias forget_, FilterArgs...) {

    alias BaseEvent = Event!(Unique, Functions.Types);
    alias forget = forget_;

    FilterArgs filter;

    static foreach(Overload; Functions.Types){

        void opOpAssign(string op: "~")(void delegate(Parameters!Overload[FilterArgs.length..$]) fn) {
            auto wrapper = filteredCallback!(Tuple!(Parameters!Overload))(fn, filter);
            registerCallback(fn, wrapper);
        }

        void opOpAssign(string op: "~")(void function(Parameters!Overload[FilterArgs.length..$]) fn) {
            auto wrapper = filteredCallback!(Tuple!(Parameters!Overload))(fn, filter);
            registerCallback(fn, wrapper);
        }

    }

    void opOpAssign(string op, O)(O o) if(op == "~"){
        static assert(false, Tuple!(FilterArgs, Parameters!O).Types.stringof ~ " does not match "
                                ~ Unique ~ " " ~ FunctionTypeOf!(Functions[0]).stringof);
    }

}


struct FilteredEventStatic(alias Unique, alias Functions, alias registerCallback, alias forget_, FilterArgs...) {

    alias BaseEvent = Event!(Unique, Functions.Types);
    alias forget = forget_;

    static foreach(Overload; Functions.Types){

        void opOpAssign(string op: "~")(void delegate(Parameters!Overload[FilterArgs.length..$]) fn) {
            auto wrapper = filteredCallback!(Tuple!(Parameters!Overload))(fn, FilterArgs);
            registerCallback(fn, wrapper);
        }

        void opOpAssign(string op: "~")(void function(Parameters!Overload[FilterArgs.length..$]) fn) {
            auto wrapper = filteredCallback!(Tuple!(Parameters!Overload))(fn, FilterArgs);
            registerCallback(fn, wrapper);
        }

    }

    void opOpAssign(string op, O)(O o) if(op == "~"){
        static assert(false, Tuple!(FilterArgs, Parameters!O).Types.stringof ~ " does not match "
                                ~ Unique ~ " " ~ FunctionTypeOf!(Functions[0]).stringof);
    }

}


auto memberPointer(alias object, alias fn)() {
    enum member = __traits(identifier, fn);
    alias FnType = ReturnType!fn delegate(Parameters!fn);
    return cast(FnType)&__traits(getMember, object, member);
}


struct Events {

    static opOpAssign(string op, T)(T object) if(op == "~") {
        //static foreach(entry; membersByUDAs!(object, Event, FilteredEvent)){
         //   entry.uda ~= entry.member;
        //}
        static foreach(member; getSymbolsByUDA!(T, Event)){
            static foreach(uda; getUDAs!(member, Event)){
                uda ~= memberPointer!(object, member);
            }
        }
        static foreach(member; getSymbolsByUDA!(T, FilteredEvent)){
            static foreach(uda; getUDAs!(member, FilteredEvent)){
                uda ~= memberPointer!(object, member);
            }
        }
    }

    static register(alias mod)(){
        static foreach(member; getSymbolsByUDA!(mod, Event)){
            pragma(msg, &member);
            static foreach(uda; getUDAs!(member, Event)){
                pragma(msg, &member, ' ', uda);
                uda ~= &member;
            }
        }
        static foreach(member; getSymbolsByUDA!(mod, FilteredEvent)){
            pragma(msg, "- member: ", &member);
            static foreach(uda; getUDAs!(member, FilteredEvent)){
                pragma(msg, "- ", &member, ' ', uda);
                uda ~= &member;
            }
        }
        
        // static foreach(member_name; __traits(allMembers, mod)) {
        //     {
        //         alias member = __traits(getMember, mod, member_name);
        //         alias udas = __traits(getAttributes, member);
        //         pragma(msg, "UDAs for ", member_name, ": ", udas);

        //         mixin("alias member_huh = mod." ~ member_name ~ ";");
        //         alias udas_huh = __traits(getAttributes, member_huh);
        //         pragma(msg, "HUHs for ", member_name, ": ", udas_huh);

        //         static foreach(enum huh; __traits(getAttributes, member_huh)) {
        //             pragma(msg, "HUH for ", member_name, ": ", huh);
        //         }
                
        //         static foreach(uda; udas) {

        //             pragma(msg, "|||||||||||||||||||||||||||||||||");
        //             pragma(msg, uda);
        //             pragma(msg, typeof(uda[AnyValue]));
        //             pragma(msg, "is(typeof(uda)) ", is(typeof(uda)));
        //             pragma(msg, "is(typeof(FilteredEvent)) ", is(typeof(FilteredEvent)));
        //             pragma(msg, "__traits(isTemplate, FilteredEvent) ", __traits(isTemplate, FilteredEvent));
        //             pragma(msg, "isInstanceOf!(FilteredEvent, uda) ", isInstanceOf!(FilteredEvent, uda));
        //             pragma(msg, "isInstanceOf!(FilteredEvent, typeof(uda)) ", isInstanceOf!(FilteredEvent, typeof(uda)));
        //             pragma(msg, "is(uda == typeof(FilteredEvent)) ", is(uda == typeof(FilteredEvent)));
        //             pragma(msg, "is(typeof(uda) == FilteredEvent) ", is(typeof(uda) == FilteredEvent));

        //             pragma(msg, "module ", __traits(identifier, mod), " ", __traits(allMembers, uda));
        //             pragma(msg, hasUDA!(member, FilteredEvent));
        //             pragma(msg, isInstanceOf!(uda, Event[uda.filter]), " ", member_name, " ", uda);
        //             static if(isInstanceOf!(uda, FilteredEvent)) {
        //                 pragma(msg, "piss ", uda.BaseEvent);
        //             }
        //         }
        //     }
        // }
    }

    static forget(T)(T object){
        static foreach(member; getSymbolsByUDA!(T, Event)){
            static foreach(uda; getUDAs!(member, Event)){
                uda.forget(memberPointer!(object, member));
            }
        }
        static foreach(member; getSymbolsByUDA!(T, FilteredEvent)){
            static foreach(uda; getUDAs!(member, FilteredEvent)){
                uda.forget(memberPointer!(object, member));
            }
        }
    }

    static forget(alias mod)(){
        static foreach(member; getSymbolsByUDA!(mod, Event)){
            static foreach(uda; getUDAs!(member, Event)){
                uda.forget(&member);
            }
        }
        static foreach(member; getSymbolsByUDA!(mod, FilteredEvent)){
            static foreach(uda; getUDAs!(member, FilteredEvent)){
                uda.forget(&member);
            }
        }
    }

    static opIndex(FilterArgs...)(FilterArgs args){
        struct Filter {
            FilterArgs args;
            void opOpAssign(string op, T)(T object) if(op == "~") {
                static foreach(member; getSymbolsByUDA!(T, Event)){
                    static foreach(uda; getUDAs!(member, Event)){
                        uda[args] ~= memberPointer!(object, member);
                    }
                }
                static foreach(member; getSymbolsByUDA!(T, FilteredEvent)){
                    static foreach(uda; getUDAs!(member, FilteredEvent)){
                        pragma(msg, uda.filter, " // ", FilterArgs);
                        uda.BaseEvent[args, uda.filter[args.length .. $]] ~= memberPointer!(object, member);
                        // TODO: figure out combined usage with Event[_]
                    }
                }
            }
        }
        return Filter(args);
    }

}


template membersByUDAs(alias object, UDAs...) {
    template each_root_uda(alias UDA) {
        template each_symbol(alias Symbol) {
            template each_symbol_uda(alias SUDA) {
                template Result(alias member_, alias uda_){
                    enum member = cast(typeof(Symbol))&__traits(getMember, object, __traits(identifier, member_));
                    alias uda = uda_;
                }
                pragma(msg, &Symbol);
                pragma(msg, SUDA);
                alias each_symbol_uda = Result!(Symbol, SUDA);
            }
            alias each_symbol = staticMap!(each_symbol_uda, getUDAs!(Symbol, UDA));
        }
        alias each_root_uda = staticMap!(each_symbol, getSymbolsByUDA!(typeof(object), UDA));
    }
    alias membersByUDAs = staticMap!(each_root_uda, UDAs);
}


private auto filteredCallback(Args, Fn, Filter...)(Fn fn, Filter filter){
    return (Args.Types args){
        static foreach(i, Type; Filter){
            static if(!is(Type == AnyValueType)){
                if(filter[i] != args[i]){
                    return;
                }
            }
        }
        fn(args[Filter.length..$]);
    };
}


unittest {

    alias EventIntDouble = Event!("Event1", void function(int, double));

    int captured_i;
    double captured_d;
    auto first_handler = (int i, double d) {
        captured_i = i;
        captured_d = d;
    };
    EventIntDouble ~= first_handler;

    EventIntDouble(1, 0.5);
    assert(captured_i == 1);
    assert(captured_d == 0.5);

    EventIntDouble.forget(first_handler);
    EventIntDouble(2, 1.5);
    assert(captured_i == 1);
    assert(captured_d == 0.5);
    
    EventIntDouble[3] ~= (double d) {
        captured_d = d;
    };
    EventIntDouble(2, 1.5);
    assert(captured_d == 0.5);
    EventIntDouble(3, 2.5);
    assert(captured_d == 2.5);

}


unittest {

    alias EventIntDouble = Event!("Event1", void function(int, double));

    class Slots {

        int id;
        double d;

        this(int id){
            this.id = id;
            Events[id] ~= this;
        }

        void destroy(){
            Events.forget(this);
        }

        @EventIntDouble
        void handler(double d){
            this.d = d;
        }

    }

    auto slots1 = new Slots(1);
    auto slots2 = new Slots(2);

    EventIntDouble(1, 0.5);
    assert(slots1.d == 0.5);
    import std.math: isNaN;
    assert(slots2.d.isNaN);

    Events.forget(slots1);
    EventIntDouble(1, 1);
    assert(slots1.d == 0.5);

    EventIntDouble(2, 1);
    assert(slots2.d == 1);

}


unittest {

    alias Event1 = Event!("Event1", void function(int, double));
    alias Event2 = Event!("Event2", void function(int, string));

    class Slots {

        int id;
        double d;
        string s;
        bool received_test;
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

        @(Event2[AnyValue, "test"])
        void handler2_2() {
            received_test = true;
        }

    }

    auto slots1 = new Slots(1);
    auto slots2 = new Slots(2);

    Event1(1, 0.5);
    Event2(2, "teststr");

    assert(slots1.d == 0.5);
    assert(slots1.s == "");
    assert(slots2.s == "teststr");
    assert(!slots2.received_test);
    import std.math: isNaN;
    assert(slots2.d.isNaN);
    
    Event2(2, "test");
    assert(slots2.received_test);

    Events.forget(slots1);
    Event1(1, 1);
    assert(slots1.d == 0.5);

    Event1(2, 1);
    assert(slots2.d == 1);

    alias Event3 = Event!("Event3", void function(), void function(int));
    alias Event4 = Event!("Event4", void function(int));

    class Overloaded {

        bool first;
        bool second;

        @Event3 void test(){ first=true; }

        @Event3 void test(int){ second=true; }

    }

    auto instance = new Overloaded;

    Events ~= instance;

    Event3();
    assert(instance.first);
    assert(!instance.second);

    Event3(1);
    assert(instance.second);

}
