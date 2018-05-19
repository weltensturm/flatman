
import
    std.stdio,
    std.string,
    std.conv,
    std.math,
    std.algorithm,
    pulseaudio_h;


extern(C){
    void state_cb(pa_context* context, void* user) {
        Pulseaudio pulseaudio = cast(Pulseaudio)user;
        switch(pa_context_get_state(context)){
            case PA_CONTEXT_READY:
                pulseaudio.state = Pulseaudio.State.connected;
                break;
            case PA_CONTEXT_FAILED:
                pulseaudio.state = Pulseaudio.State.error;
                break;
            default:
                break;
        }
    }

    void sink_list_cb(pa_context* c, const pa_sink_info* i, int eol, void *user) {
        if(eol)
            return;
        auto devices = cast(DeviceList)user;
        devices.list ~= new Device(i);
    }

    void source_list_cb(pa_context* c, const pa_source_info* i, int eol, void *user) {
        if(eol)
            return;
        auto devices = cast(DeviceList)user;
        devices.list ~= new Device(i);
    }

    void server_info_cb(pa_context* context, const pa_server_info* i, void* user) {
        auto pulseaudio = cast(Pulseaudio)user;
        pulseaudio.info.default_sink_name = i.default_sink_name.to!string;
        pulseaudio.info.default_source_name = i.default_source_name.to!string;
    }

    void success_cb(pa_context* context, int success, void* user) {}

    void event_cb(pa_context* c, pa_subscription_event_type_t t, uint idx, void* user){
        if((t & PA_SUBSCRIPTION_EVENT_FACILITY_MASK) == PA_SUBSCRIPTION_EVENT_SINK){
            if((t & PA_SUBSCRIPTION_EVENT_TYPE_MASK) == PA_SUBSCRIPTION_EVENT_NEW){
                (cast(Pulseaudio)user).doUpdate = true;
            }
            if((t & PA_SUBSCRIPTION_EVENT_TYPE_MASK) == PA_SUBSCRIPTION_EVENT_CHANGE){
                (cast(Pulseaudio)user).doUpdate = true;
            }
        }else if((t & PA_SUBSCRIPTION_EVENT_FACILITY_MASK) == PA_SUBSCRIPTION_EVENT_SERVER){
            if((t & PA_SUBSCRIPTION_EVENT_TYPE_MASK) == PA_SUBSCRIPTION_EVENT_CHANGE){
                (cast(Pulseaudio)user).doUpdate = true;
            }
        }
        (cast(Pulseaudio)user).eventReceived = true;
    }
}


class Device {

    Pulseaudio pulseaudio;

    enum Type { source, sink }

    uint index;
    Type type;
    string name;
    string description;
    pa_cvolume volume;
    pa_volume_t volume_avg;
    int volume_percent;
    bool mute;

    this(const pa_source_info* info){
        type            = Type.source;
        index           = info.index;
        name            = info.name.to!string;
        description     = info.description.to!string;
        mute            = info.mute == 1;
        setVolume(&(info.volume));
    }

    this(const pa_sink_info* info) {
        type            = Type.sink;
        index           = info.index;
        name            = info.name.to!string;
        description     = info.description.to!string;
        mute            = info.mute == 1;
        setVolume(&(info.volume));
    }

    void setVolume(const pa_cvolume* v) {
        volume         = *v;
        volume_avg     = pa_cvolume_avg(v);
        volume_percent = (volume_avg*100.0/PA_VOLUME_NORM).lround.to!int;
    }
    
};


class DeviceList {
    Device[] list;
}


class ServerInfo {
    string default_source_name;
    string default_sink_name;
};



class Pulseaudio {

    pa_mainloop* mainloop;
    pa_mainloop_api* mainloop_api;
    pa_context* context;
    int retval;
    bool doUpdate = false;
    bool eventReceived;

    ServerInfo info;
    Device defaultSink;
    Device defaultSource;

    void run(Op, Cb, Args...)(Op operation, Args args, Cb cb, void* user){
        pa_operation* op = operation(context, args, cb, user);
        assert(op);
        while(pa_operation_get_state(op) == PA_OPERATION_RUNNING){
            pa_mainloop_iterate(mainloop, 1, &retval);
        }
        pa_operation_unref(op);
    }

    void run(){
        eventReceived = true;
        while(eventReceived){
            eventReceived = false;
            pa_mainloop_iterate(mainloop, 0, &retval);
        }
        if(doUpdate)
            update;
        doUpdate = false;
    }

    enum State {
        connecting,
        connected,
        error
    }

    State state;

    this(string client_name){
        info = new ServerInfo;
        mainloop = pa_mainloop_new();
        mainloop_api = pa_mainloop_get_api(mainloop);
        context = pa_context_new(mainloop_api, client_name.toStringz());
        pa_context_set_state_callback(context, &state_cb, cast(void*)this);
        state = State.connecting;
        pa_context_connect(context, null, PA_CONTEXT_NOFLAGS, null);
        while(state == State.connecting){
            pa_mainloop_iterate(mainloop, 1, &retval);
        }
        if(state != State.connected)
            throw new Exception("Failed to connect to pulseaudio");
        pa_context_set_subscribe_callback(context, &event_cb, cast(void*)this);
        pa_context_subscribe(context, PA_SUBSCRIPTION_MASK_ALL, &success_cb, cast(void*)this);
        run;
        doUpdate = true;
    }

    ~this(){
        if (state == State.connected)
            pa_context_disconnect(context);
        pa_mainloop_free(mainloop);
    }

    void update(){
        writeln("update");
        run(&pa_context_get_server_info, &server_info_cb, cast(void*)this);
        writeln(info.default_sink_name);
        writeln(info.default_source_name);
        defaultSink = sink(info.default_sink_name);
        defaultSource = source(info.default_source_name);
    }

    Device[] sinks(){
        auto sinks = new DeviceList;
        run(&pa_context_get_sink_info_list, &sink_list_cb, cast(void*)sinks);
        return sinks.list;
    }

    Device[] sources(){
        auto sources = new DeviceList;
        run(&pa_context_get_source_info_list, &source_list_cb, cast(void*)sources);
        return sources.list;
    }

    Device sink(uint index){
        auto sinks = new DeviceList;
        run(&pa_context_get_sink_info_by_index, index, &sink_list_cb, cast(void*)sinks);
        if(!sinks.list.length)
            throw new Exception("Sink %s does not exist".format(index));
        return sinks.list[0];
    }

    Device sink(string name){
        auto sinks = new DeviceList;
        run(&pa_context_get_sink_info_by_name, name.toStringz, &sink_list_cb, cast(void*)sinks);
        if(!sinks.list.length)
            throw new Exception("Sink \"%s\" does not exist".format(name));
        return sinks.list[0];
    }

    Device source(uint index){
        auto sources = new DeviceList;
        run(&pa_context_get_source_info_by_index, index, &source_list_cb, cast(void*)sources);
        if(!sources.list.length)
            throw new Exception("Source %s does not exist".format(index));
        return sources.list[0];
    }

    Device source(string name){
        auto sources = new DeviceList;
        run(&pa_context_get_source_info_by_name, name.toStringz(), &source_list_cb, cast(void*)sources);
        if(!sources.list.length)
            throw new Exception("Source \"%s\" does not exist".format(name));
        return sources.list[0];
    }
    
    void volume(Device device, double new_volume){
         volume(device, (new_volume*PA_VOLUME_NORM).lround.max(0).min(PA_VOLUME_MAX).to!pa_volume_t);
    }

    void volume(Device device, pa_volume_t new_volume){
        if (new_volume > PA_VOLUME_MAX) {
            new_volume = PA_VOLUME_MAX;
        }
        pa_cvolume* new_cvolume = pa_cvolume_set(&device.volume, device.volume.channels, new_volume);
        if (device.type == Device.Type.sink)
            run(&pa_context_set_sink_volume_by_index, device.index, new_cvolume, &success_cb, null);
        else
            run(&pa_context_set_source_volume_by_index, device.index, new_cvolume, &success_cb, null);
    }

    void mute(Device device, bool mute){
        if (device.type == Device.Type.sink)
            run(&pa_context_set_sink_mute_by_index, device.index, cast(int)mute, &success_cb, null);
        else
            run(&pa_context_set_source_mute_by_index, device.index, cast(int)mute, &success_cb, null);
    }
};

