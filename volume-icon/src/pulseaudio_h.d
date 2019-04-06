module pulseaudio_h;


extern(C):


enum PA_CHANNELS_MAX = 32U;


alias pa_sample_format_t = int;
/** Sample format */
enum: pa_sample_format_t {
    PA_SAMPLE_U8,
    /**< Unsigned 8 Bit PCM */

    PA_SAMPLE_ALAW,
    /**< 8 Bit a-Law */

    PA_SAMPLE_ULAW,
    /**< 8 Bit mu-Law */

    PA_SAMPLE_S16LE,
    /**< Signed 16 Bit PCM, little endian (PC) */

    PA_SAMPLE_S16BE,
    /**< Signed 16 Bit PCM, big endian */

    PA_SAMPLE_FLOAT32LE,
    /**< 32 Bit IEEE floating point, little endian (PC), range -1.0 to 1.0 */

    PA_SAMPLE_FLOAT32BE,
    /**< 32 Bit IEEE floating point, big endian, range -1.0 to 1.0 */

    PA_SAMPLE_S32LE,
    /**< Signed 32 Bit PCM, little endian (PC) */

    PA_SAMPLE_S32BE,
    /**< Signed 32 Bit PCM, big endian */

    PA_SAMPLE_S24LE,
    /**< Signed 24 Bit PCM packed, little endian (PC). \since 0.9.15 */

    PA_SAMPLE_S24BE,
    /**< Signed 24 Bit PCM packed, big endian. \since 0.9.15 */

    PA_SAMPLE_S24_32LE,
    /**< Signed 24 Bit PCM in LSB of 32 Bit words, little endian (PC). \since 0.9.15 */

    PA_SAMPLE_S24_32BE,
    /**< Signed 24 Bit PCM in LSB of 32 Bit words, big endian. \since 0.9.15 */

    PA_SAMPLE_MAX,
    /**< Upper limit of valid sample types */

    PA_SAMPLE_INVALID = -1
    /**< An invalid value */
}


alias pa_channel_position_t = int;
/** A list of channel labels */
enum: pa_channel_position_t {
    PA_CHANNEL_POSITION_INVALID = -1,
    PA_CHANNEL_POSITION_MONO = 0,

    PA_CHANNEL_POSITION_FRONT_LEFT,               /**< Apple, Dolby call this 'Left' */
    PA_CHANNEL_POSITION_FRONT_RIGHT,              /**< Apple, Dolby call this 'Right' */
    PA_CHANNEL_POSITION_FRONT_CENTER,             /**< Apple, Dolby call this 'Center' */

/** \cond fulldocs */
    PA_CHANNEL_POSITION_LEFT = PA_CHANNEL_POSITION_FRONT_LEFT,
    PA_CHANNEL_POSITION_RIGHT = PA_CHANNEL_POSITION_FRONT_RIGHT,
    PA_CHANNEL_POSITION_CENTER = PA_CHANNEL_POSITION_FRONT_CENTER,
/** \endcond */

    PA_CHANNEL_POSITION_REAR_CENTER,              /**< Microsoft calls this 'Back Center', Apple calls this 'Center Surround', Dolby calls this 'Surround Rear Center' */
    PA_CHANNEL_POSITION_REAR_LEFT,                /**< Microsoft calls this 'Back Left', Apple calls this 'Left Surround' (!), Dolby calls this 'Surround Rear Left'  */
    PA_CHANNEL_POSITION_REAR_RIGHT,               /**< Microsoft calls this 'Back Right', Apple calls this 'Right Surround' (!), Dolby calls this 'Surround Rear Right'  */

    PA_CHANNEL_POSITION_LFE,                      /**< Microsoft calls this 'Low Frequency', Apple calls this 'LFEScreen' */
/** \cond fulldocs */
    PA_CHANNEL_POSITION_SUBWOOFER = PA_CHANNEL_POSITION_LFE,
/** \endcond */

    PA_CHANNEL_POSITION_FRONT_LEFT_OF_CENTER,     /**< Apple, Dolby call this 'Left Center' */
    PA_CHANNEL_POSITION_FRONT_RIGHT_OF_CENTER,    /**< Apple, Dolby call this 'Right Center */

    PA_CHANNEL_POSITION_SIDE_LEFT,                /**< Apple calls this 'Left Surround Direct', Dolby calls this 'Surround Left' (!) */
    PA_CHANNEL_POSITION_SIDE_RIGHT,               /**< Apple calls this 'Right Surround Direct', Dolby calls this 'Surround Right' (!) */

    PA_CHANNEL_POSITION_AUX0,
    PA_CHANNEL_POSITION_AUX1,
    PA_CHANNEL_POSITION_AUX2,
    PA_CHANNEL_POSITION_AUX3,
    PA_CHANNEL_POSITION_AUX4,
    PA_CHANNEL_POSITION_AUX5,
    PA_CHANNEL_POSITION_AUX6,
    PA_CHANNEL_POSITION_AUX7,
    PA_CHANNEL_POSITION_AUX8,
    PA_CHANNEL_POSITION_AUX9,
    PA_CHANNEL_POSITION_AUX10,
    PA_CHANNEL_POSITION_AUX11,
    PA_CHANNEL_POSITION_AUX12,
    PA_CHANNEL_POSITION_AUX13,
    PA_CHANNEL_POSITION_AUX14,
    PA_CHANNEL_POSITION_AUX15,
    PA_CHANNEL_POSITION_AUX16,
    PA_CHANNEL_POSITION_AUX17,
    PA_CHANNEL_POSITION_AUX18,
    PA_CHANNEL_POSITION_AUX19,
    PA_CHANNEL_POSITION_AUX20,
    PA_CHANNEL_POSITION_AUX21,
    PA_CHANNEL_POSITION_AUX22,
    PA_CHANNEL_POSITION_AUX23,
    PA_CHANNEL_POSITION_AUX24,
    PA_CHANNEL_POSITION_AUX25,
    PA_CHANNEL_POSITION_AUX26,
    PA_CHANNEL_POSITION_AUX27,
    PA_CHANNEL_POSITION_AUX28,
    PA_CHANNEL_POSITION_AUX29,
    PA_CHANNEL_POSITION_AUX30,
    PA_CHANNEL_POSITION_AUX31,

    PA_CHANNEL_POSITION_TOP_CENTER,               /**< Apple calls this 'Top Center Surround' */

    PA_CHANNEL_POSITION_TOP_FRONT_LEFT,           /**< Apple calls this 'Vertical Height Left' */
    PA_CHANNEL_POSITION_TOP_FRONT_RIGHT,          /**< Apple calls this 'Vertical Height Right' */
    PA_CHANNEL_POSITION_TOP_FRONT_CENTER,         /**< Apple calls this 'Vertical Height Center' */

    PA_CHANNEL_POSITION_TOP_REAR_LEFT,            /**< Microsoft and Apple call this 'Top Back Left' */
    PA_CHANNEL_POSITION_TOP_REAR_RIGHT,           /**< Microsoft and Apple call this 'Top Back Right' */
    PA_CHANNEL_POSITION_TOP_REAR_CENTER,          /**< Microsoft and Apple call this 'Top Back Center' */

    PA_CHANNEL_POSITION_MAX
}


/** A sample format and attribute specification */
struct pa_sample_spec {
    pa_sample_format_t format;
    /**< The sample format */

    uint rate;
    /**< The sample rate. (e.g. 44100) */

    ubyte channels;
    /**< Audio channels. (1 for mono, 2 for stereo, ...) */
}


struct pa_channel_map {
    ubyte channels;
    /**< Number of channels */

    pa_channel_position_t[PA_CHANNELS_MAX] map;
    /**< Channel labels */
}


/** Normal volume (100%, 0 dB) */
enum PA_VOLUME_NORM = 0x10000U;

/** Muted (minimal valid) volume (0%, -inf dB) */
enum PA_VOLUME_MUTED = 0U;

/** Maximum valid volume we can store. \since 0.9.15 */
enum PA_VOLUME_MAX = uint.max/2;


alias pa_volume_t = uint;


/** A structure encapsulating a per-channel volume */
struct pa_cvolume {
    ubyte channels;                     /**< Number of channels */
    pa_volume_t[PA_CHANNELS_MAX] values;  /**< Per-channel volume */
}


alias pa_usec_t = ulong;


alias pa_sink_state_t = int;
/** Sink state. \since 0.9.15 */
enum: pa_sink_state_t { /* enum: serialized in u8 */
    PA_SINK_INVALID_STATE = -1,
    /**< This state is used when the server does not support sink state introspection \since 0.9.15 */

    PA_SINK_RUNNING = 0,
    /**< Running, sink is playing and used by at least one non-corked sink-input \since 0.9.15 */

    PA_SINK_IDLE = 1,
    /**< When idle, the sink is playing but there is no non-corked sink-input attached to it \since 0.9.15 */

    PA_SINK_SUSPENDED = 2,
    /**< When suspended, actual sink access can be closed, for instance \since 0.9.15 */

/** \cond fulldocs */
    /* PRIVATE: Server-side values -- DO NOT USE THIS ON THE CLIENT
     * SIDE! These values are *not* considered part of the official PA
     * API/ABI. If you use them your application might break when PA
     * is upgraded. Also, please note that these values are not useful
     * on the client side anyway. */

    PA_SINK_INIT = -2,
    /**< Initialization state */

    PA_SINK_UNLINKED = -3
    /**< The state when the sink is getting unregistered and removed from client access */
/** \endcond */

}


alias pa_sink_flags_t = int;
/** Special sink flags. */
enum: pa_sink_flags_t {
    PA_SINK_NOFLAGS = 0x0000U,
    /**< Flag to pass when no specific options are needed (used to avoid casting)  \since 0.9.19 */

    PA_SINK_HW_VOLUME_CTRL = 0x0001U,
    /**< Supports hardware volume control. This is a dynamic flag and may
     * change at runtime after the sink has initialized */

    PA_SINK_LATENCY = 0x0002U,
    /**< Supports latency querying */

    PA_SINK_HARDWARE = 0x0004U,
    /**< Is a hardware sink of some kind, in contrast to
     * "virtual"/software sinks \since 0.9.3 */

    PA_SINK_NETWORK = 0x0008U,
    /**< Is a networked sink of some kind. \since 0.9.7 */

    PA_SINK_HW_MUTE_CTRL = 0x0010U,
    /**< Supports hardware mute control. This is a dynamic flag and may
     * change at runtime after the sink has initialized \since 0.9.11 */

    PA_SINK_DECIBEL_VOLUME = 0x0020U,
    /**< Volume can be translated to dB with pa_sw_volume_to_dB(). This is a
     * dynamic flag and may change at runtime after the sink has initialized
     * \since 0.9.11 */

    PA_SINK_FLAT_VOLUME = 0x0040U,
    /**< This sink is in flat volume mode, i.e.\ always the maximum of
     * the volume of all connected inputs. \since 0.9.15 */

    PA_SINK_DYNAMIC_LATENCY = 0x0080U,
    /**< The latency can be adjusted dynamically depending on the
     * needs of the connected streams. \since 0.9.15 */

    PA_SINK_SET_FORMATS = 0x0100U,
    /**< The sink allows setting what formats are supported by the connected
     * hardware. The actual functionality to do this might be provided by an
     * extension. \since 1.0 */

}

struct pa_proplist {}


alias pa_encoding_t = int;
/** Represents the type of encoding used in a stream or accepted by a sink. \since 1.0 */
enum: pa_encoding_t {
    PA_ENCODING_ANY,
    /**< Any encoding format, PCM or compressed */

    PA_ENCODING_PCM,
    /**< Any PCM format */

    PA_ENCODING_AC3_IEC61937,
    /**< AC3 data encapsulated in IEC 61937 header/padding */

    PA_ENCODING_EAC3_IEC61937,
    /**< EAC3 data encapsulated in IEC 61937 header/padding */

    PA_ENCODING_MPEG_IEC61937,
    /**< MPEG-1 or MPEG-2 (Part 3, not AAC) data encapsulated in IEC 61937 header/padding */

    PA_ENCODING_DTS_IEC61937,
    /**< DTS data encapsulated in IEC 61937 header/padding */

    PA_ENCODING_MPEG2_AAC_IEC61937,
    /**< MPEG-2 AAC data encapsulated in IEC 61937 header/padding. \since 4.0 */

    PA_ENCODING_MAX,
    /**< Valid encoding types must be less than this value */

    PA_ENCODING_INVALID = -1,
    /**< Represents an invalid encoding */
}


/** Stores information about a specific port of a sink.  Please
 * note that this structure can be extended as part of evolutionary
 * API updates at any time in any new release. \since 0.9.16 */
struct pa_sink_port_info {
    const char *name;                   /**< Name of this port */
    const char *description;            /**< Description of this port */
    uint priority;                  /**< The higher this value is, the more useful this port is as a default. */
    int available;                      /**< A flags (see #pa_port_available), indicating availability status of this port. \since 2.0 */
}


/** Represents the format of data provided in a stream or processed by a sink. \since 1.0 */
struct pa_format_info {
    pa_encoding_t encoding;
    /**< The encoding used for the format */

    pa_proplist *plist;
    /**< Additional encoding-specific properties such as sample rate, bitrate, etc. */
}


struct pa_sink_info {
    const char *name;                  /**< Name of the sink */
    uint index;                    /**< Index of the sink */
    const char *description;           /**< Description of this sink */
    pa_sample_spec sample_spec;        /**< Sample spec of this sink */
    pa_channel_map channel_map;        /**< Channel map */
    uint owner_module;             /**< Index of the owning module of this sink, or PA_INVALID_INDEX. */
    pa_cvolume volume;                 /**< Volume of the sink */
    int mute;                          /**< Mute switch of the sink */
    uint monitor_source;           /**< Index of the monitor source connected to this sink. */
    const char *monitor_source_name;   /**< The name of the monitor source. */
    pa_usec_t latency;                 /**< Length of queued audio in the output buffer. */
    const char *driver;                /**< Driver name */
    pa_sink_flags_t flags;             /**< Flags */
    pa_proplist* proplist;             /**< Property list \since 0.9.11 */
    pa_usec_t configured_latency;      /**< The latency this device has been configured to. \since 0.9.11 */
    pa_volume_t base_volume;           /**< Some kind of "base" volume that refers to unamplified/unattenuated volume in the context of the output device. \since 0.9.15 */
    pa_sink_state_t state;             /**< State \since 0.9.15 */
    uint n_volume_steps;           /**< Number of volume steps for sinks which do not support arbitrary volumes. \since 0.9.15 */
    uint card;                     /**< Card index, or PA_INVALID_INDEX. \since 0.9.15 */
    uint n_ports;                  /**< Number of entries in port array \since 0.9.16 */
    pa_sink_port_info** ports;         /**< Array of available ports, or NULL. Array is terminated by an entry set to NULL. The number of entries is stored in n_ports. \since 0.9.16 */
    pa_sink_port_info* active_port;    /**< Pointer to active port in the array, or NULL. \since 0.9.16 */
    ubyte n_formats;                 /**< Number of formats supported by the sink. \since 1.0 */
    pa_format_info **formats;          /**< Array of formats supported by the sink. \since 1.0 */
}


alias pa_source_flags_t = int;
/** Special source flags.  */
enum: pa_source_flags_t {
    PA_SOURCE_NOFLAGS = 0x0000U,
    /**< Flag to pass when no specific options are needed (used to avoid casting)  \since 0.9.19 */

    PA_SOURCE_HW_VOLUME_CTRL = 0x0001U,
    /**< Supports hardware volume control. This is a dynamic flag and may
     * change at runtime after the source has initialized */

    PA_SOURCE_LATENCY = 0x0002U,
    /**< Supports latency querying */

    PA_SOURCE_HARDWARE = 0x0004U,
    /**< Is a hardware source of some kind, in contrast to
     * "virtual"/software source \since 0.9.3 */

    PA_SOURCE_NETWORK = 0x0008U,
    /**< Is a networked source of some kind. \since 0.9.7 */

    PA_SOURCE_HW_MUTE_CTRL = 0x0010U,
    /**< Supports hardware mute control. This is a dynamic flag and may
     * change at runtime after the source has initialized \since 0.9.11 */

    PA_SOURCE_DECIBEL_VOLUME = 0x0020U,
    /**< Volume can be translated to dB with pa_sw_volume_to_dB(). This is a
     * dynamic flag and may change at runtime after the source has initialized
     * \since 0.9.11 */

    PA_SOURCE_DYNAMIC_LATENCY = 0x0040U,
    /**< The latency can be adjusted dynamically depending on the
     * needs of the connected streams. \since 0.9.15 */

    PA_SOURCE_FLAT_VOLUME = 0x0080U,
    /**< This source is in flat volume mode, i.e.\ always the maximum of
     * the volume of all connected outputs. \since 1.0 */

}


alias pa_source_state_t = int;
/** Source state. \since 0.9.15 */
enum: pa_source_state_t {
    PA_SOURCE_INVALID_STATE = -1,
    /**< This state is used when the server does not support source state introspection \since 0.9.15 */

    PA_SOURCE_RUNNING = 0,
    /**< Running, source is recording and used by at least one non-corked source-output \since 0.9.15 */

    PA_SOURCE_IDLE = 1,
    /**< When idle, the source is still recording but there is no non-corked source-output \since 0.9.15 */

    PA_SOURCE_SUSPENDED = 2,
    /**< When suspended, actual source access can be closed, for instance \since 0.9.15 */

/** \cond fulldocs */
    /* PRIVATE: Server-side values -- DO NOT USE THIS ON THE CLIENT
     * SIDE! These values are *not* considered part of the official PA
     * API/ABI. If you use them your application might break when PA
     * is upgraded. Also, please note that these values are not useful
     * on the client side anyway. */

    PA_SOURCE_INIT = -2,
    /**< Initialization state */

    PA_SOURCE_UNLINKED = -3
    /**< The state when the source is getting unregistered and removed from client access */
/** \endcond */

}


/** Stores information about a specific port of a source.  Please
 * note that this structure can be extended as part of evolutionary
 * API updates at any time in any new release. \since 0.9.16 */
struct pa_source_port_info {
    const char *name;                   /**< Name of this port */
    const char *description;            /**< Description of this port */
    uint priority;                  /**< The higher this value is, the more useful this port is as a default. */
    int available;                      /**< A flags (see #pa_port_available), indicating availability status of this port. \since 2.0 */
}


struct pa_context {}
struct pa_mainloop {}
struct pa_mainloop_api {}


/** Stores information about sources. Please note that this structure
 * can be extended as part of evolutionary API updates at any time in
 * any new release. */
struct pa_source_info {
    const char *name;                   /**< Name of the source */
    uint index;                     /**< Index of the source */
    const char *description;            /**< Description of this source */
    pa_sample_spec sample_spec;         /**< Sample spec of this source */
    pa_channel_map channel_map;         /**< Channel map */
    uint owner_module;              /**< Owning module index, or PA_INVALID_INDEX. */
    pa_cvolume volume;                  /**< Volume of the source */
    int mute;                           /**< Mute switch of the sink */
    uint monitor_of_sink;           /**< If this is a monitor source, the index of the owning sink, otherwise PA_INVALID_INDEX. */
    const char *monitor_of_sink_name;   /**< Name of the owning sink, or NULL. */
    pa_usec_t latency;                  /**< Length of filled record buffer of this source. */
    const char *driver;                 /**< Driver name */
    pa_source_flags_t flags;            /**< Flags */
    pa_proplist *proplist;              /**< Property list \since 0.9.11 */
    pa_usec_t configured_latency;       /**< The latency this device has been configured to. \since 0.9.11 */
    pa_volume_t base_volume;            /**< Some kind of "base" volume that refers to unamplified/unattenuated volume in the context of the input device. \since 0.9.15 */
    pa_source_state_t state;            /**< State \since 0.9.15 */
    uint n_volume_steps;            /**< Number of volume steps for sources which do not support arbitrary volumes. \since 0.9.15 */
    uint card;                      /**< Card index, or PA_INVALID_INDEX. \since 0.9.15 */
    uint n_ports;                   /**< Number of entries in port array \since 0.9.16 */
    pa_source_port_info** ports;        /**< Array of available ports, or NULL. Array is terminated by an entry set to NULL. The number of entries is stored in n_ports. \since 0.9.16  */
    pa_source_port_info* active_port;   /**< Pointer to active port in the array, or NULL. \since 0.9.16  */
    ubyte n_formats;                  /**< Number of formats supported by the source. \since 1.0 */
    pa_format_info **formats;           /**< Array of formats supported by the source. \since 1.0 */
}


/** Server information. Please note that this structure can be
 * extended as part of evolutionary API updates at any time in any new
 * release. */
struct pa_server_info {
    const char *user_name;              /**< User name of the daemon process */
    const char *host_name;              /**< Host name the daemon is running on */
    const char *server_version;         /**< Version string of the daemon */
    const char *server_name;            /**< Server package name (usually "pulseaudio") */
    pa_sample_spec sample_spec;         /**< Default sample specification */
    const char *default_sink_name;      /**< Name of default sink. */
    const char *default_source_name;    /**< Name of default source. */
    uint cookie;                    /**< A random cookie for identifying this instance of PulseAudio. */
    pa_channel_map channel_map;         /**< Default channel map. \since 0.9.15 */
}


alias pa_context_state_t = int;
/** The state of a connection context */
enum: pa_context_state_t {
    PA_CONTEXT_UNCONNECTED,    /**< The context hasn't been connected yet */
    PA_CONTEXT_CONNECTING,     /**< A connection is being established */
    PA_CONTEXT_AUTHORIZING,    /**< The client is authorizing itself to the daemon */
    PA_CONTEXT_SETTING_NAME,   /**< The client is passing its application name to the daemon */
    PA_CONTEXT_READY,          /**< The connection is established, the context is ready to execute operations */
    PA_CONTEXT_FAILED,         /**< The connection failed or was disconnected */
    PA_CONTEXT_TERMINATED      /**< The connection was terminated cleanly */
}


/** Return the current context status */
pa_context_state_t pa_context_get_state(pa_context *c);

/** Allocate a new main loop object */
pa_mainloop* pa_mainloop_new();

/** Return the abstract main loop abstraction layer vtable for this
    main loop. No need to free the API as it is owned by the loop
    and is destroyed when the loop is freed. */
pa_mainloop_api* pa_mainloop_get_api(pa_mainloop* m);

/** Instantiate a new connection context with an abstract mainloop API
 * and an application name. It is recommended to use pa_context_new_with_proplist()
 * instead and specify some initial properties.*/
pa_context *pa_context_new(pa_mainloop_api* mainloop, const char* name);

/** Generic notification callback prototype */
alias pa_context_notify_cb_t = void function(pa_context *c, void *userdata);

/** Set a callback function that is called whenever the context status changes */
void pa_context_set_state_callback(pa_context *c, pa_context_notify_cb_t cb, void *userdata);

alias pa_context_flags_t = int;
/** Some special flags for contexts. */
enum: pa_context_flags_t {
    PA_CONTEXT_NOFLAGS = 0x0000U,
    /**< Flag to pass when no specific options are needed (used to avoid casting)  \since 0.9.19 */
    PA_CONTEXT_NOAUTOSPAWN = 0x0001U,
    /**< Disabled autospawning of the PulseAudio daemon if required */
    PA_CONTEXT_NOFAIL = 0x0002U
    /**< Don't fail if the daemon is not available when pa_context_connect() is called, instead enter PA_CONTEXT_CONNECTING state and wait for the daemon to appear.  \since 0.9.15 */
}

/** Connect the context to the specified server. If server is NULL,
connect to the default server. This routine may but will not always
return synchronously on error. Use pa_context_set_state_callback() to
be notified when the connection is established. If flags doesn't have
PA_CONTEXT_NOAUTOSPAWN set and no specific server is specified or
accessible a new daemon is spawned. If api is non-NULL, the functions
specified in the structure are used when forking a new child
process. */
int pa_context_connect(pa_context *c, const char *server, pa_context_flags_t flags, const pa_spawn_api *api);

/** A structure for the spawn api. This may be used to integrate auto
 * spawned daemons into your application. For more information see
 * pa_context_connect(). When spawning a new child process the
 * waitpid() is used on the child's PID. The spawn routine will not
 * block or ignore SIGCHLD signals, since this cannot be done in a
 * thread compatible way. You might have to do this in
 * prefork/postfork. */
struct pa_spawn_api {
    void function() prefork;
    /**< Is called just before the fork in the parent process. May be
     * NULL. */

    void function() postfork;
    /**< Is called immediately after the fork in the parent
     * process. May be NULL.*/

    void function() atfork;
    /**< Is called immediately after the fork in the child
     * process. May be NULL. It is not safe to close all file
     * descriptors in this function unconditionally, since a UNIX
     * socket (created using socketpair()) is passed to the new
     * process. */
}

/** Run a single iteration of the main loop. This is a convenience function
for pa_mainloop_prepare(), pa_mainloop_poll() and pa_mainloop_dispatch().
Returns a negative value on error or exit request. If block is nonzero,
block for events if none are queued. Optionally return the return value as
specified with the main loop's quit() routine in the integer variable retval points
to. On success returns the number of sources dispatched in this iteration. */
int pa_mainloop_iterate(pa_mainloop *m, int block, int *retval);

/** Terminate the context connection immediately */
void pa_context_disconnect(pa_context *c);

/** Free a main loop object */
void pa_mainloop_free(pa_mainloop* m);

struct pa_operation {}

/** Callback prototype for pa_context_get_sink_info_by_name() and friends */
alias pa_sink_info_cb_t = void function(pa_context *c, const pa_sink_info *i, int eol, void *userdata);

/** Get the complete sink list */
pa_operation* pa_context_get_sink_info_list(pa_context *c, pa_sink_info_cb_t cb, void *userdata);

/** Callback prototype for pa_context_get_source_info_by_name() and friends */
alias pa_source_info_cb_t = void function(pa_context *c, const pa_source_info *i, int eol, void *userdata);

/** Get the complete source list */
pa_operation* pa_context_get_source_info_list(pa_context *c, pa_source_info_cb_t cb, void *userdata);


alias pa_operation_state_t = int;
/** The state of an operation */
enum: pa_operation_state_t {
    PA_OPERATION_RUNNING,
    /**< The operation is still running */
    PA_OPERATION_DONE,
    /**< The operation has completed */
    PA_OPERATION_CANCELLED
    /**< The operation has been cancelled. Operations may get cancelled by the
     * application, or as a result of the context getting disconneted while the
     * operation is pending. */
}


/** A generic callback for operation completion */
alias pa_context_success_cb_t = void function(pa_context *c, int success, void *userdata);

/** Return the current status of the operation */
pa_operation_state_t pa_operation_get_state(pa_operation *o);

/** Decrease the reference count by one */
void pa_operation_unref(pa_operation *o);

/** Get information about a sink by its index */
pa_operation* pa_context_get_sink_info_by_index(pa_context *c, uint idx, pa_sink_info_cb_t cb, void *userdata);

/** Get the complete sink list */
pa_operation* pa_context_get_sink_info_list(pa_context *c, pa_sink_info_cb_t cb, void *userdata);

/** Set the volume of a sink device specified by its index */
pa_operation* pa_context_set_sink_volume_by_index(pa_context *c, uint idx, const pa_cvolume *volume, pa_context_success_cb_t cb, void *userdata);

/** Set the volume of a sink device specified by its name */
pa_operation* pa_context_set_sink_volume_by_name(pa_context *c, const char *name, const pa_cvolume *volume, pa_context_success_cb_t cb, void *userdata);

/** Set the mute switch of a sink device specified by its index */
pa_operation* pa_context_set_sink_mute_by_index(pa_context *c, uint idx, int mute, pa_context_success_cb_t cb, void *userdata);

/** Set the mute switch of a sink device specified by its name */
pa_operation* pa_context_set_sink_mute_by_name(pa_context *c, const char *name, int mute, pa_context_success_cb_t cb, void *userdata);

/** Suspend/Resume a sink. \since 0.9.7 */
pa_operation* pa_context_suspend_sink_by_name(pa_context *c, const char *sink_name, int suspend, pa_context_success_cb_t cb, void* userdata);

/** Suspend/Resume a sink. If idx is PA_INVALID_INDEX all sinks will be suspended. \since 0.9.7 */
pa_operation* pa_context_suspend_sink_by_index(pa_context *c, uint idx, int suspend,  pa_context_success_cb_t cb, void* userdata);

/** Change the profile of a sink. \since 0.9.16 */
pa_operation* pa_context_set_sink_port_by_index(pa_context *c, uint idx, const char*port, pa_context_success_cb_t cb, void *userdata);

/** Change the profile of a sink. \since 0.9.15 */
pa_operation* pa_context_set_sink_port_by_name(pa_context *c, const char*name, const char*port, pa_context_success_cb_t cb, void *userdata);

/** Get information about a sink by its name */
pa_operation* pa_context_get_sink_info_by_name(pa_context *c, const char *name, pa_sink_info_cb_t cb, void *userdata);

/** Get information about a sink by its index */
pa_operation* pa_context_get_sink_info_by_index(pa_context *c, uint idx, pa_sink_info_cb_t cb, void *userdata);

/** Get the complete sink list */
pa_operation* pa_context_get_sink_info_list(pa_context *c, pa_sink_info_cb_t cb, void *userdata);

/** Set the volume of a sink device specified by its index */
pa_operation* pa_context_set_sink_volume_by_index(pa_context *c, uint idx, const pa_cvolume *volume, pa_context_success_cb_t cb, void *userdata);

/** Set the volume of a sink device specified by its name */
pa_operation* pa_context_set_sink_volume_by_name(pa_context *c, const char *name, const pa_cvolume *volume, pa_context_success_cb_t cb, void *userdata);

/** Set the mute switch of a sink device specified by its index */
pa_operation* pa_context_set_sink_mute_by_index(pa_context *c, uint idx, int mute, pa_context_success_cb_t cb, void *userdata);

/** Set the mute switch of a sink device specified by its name */
pa_operation* pa_context_set_sink_mute_by_name(pa_context *c, const char *name, int mute, pa_context_success_cb_t cb, void *userdata);

/** Suspend/Resume a sink. \since 0.9.7 */
pa_operation* pa_context_suspend_sink_by_name(pa_context *c, const char *sink_name, int suspend, pa_context_success_cb_t cb, void* userdata);

/** Suspend/Resume a sink. If idx is PA_INVALID_INDEX all sinks will be suspended. \since 0.9.7 */
pa_operation* pa_context_suspend_sink_by_index(pa_context *c, uint idx, int suspend,  pa_context_success_cb_t cb, void* userdata);

/** Change the profile of a sink. \since 0.9.16 */
pa_operation* pa_context_set_sink_port_by_index(pa_context *c, uint idx, const char*port, pa_context_success_cb_t cb, void *userdata);

/** Change the profile of a sink. \since 0.9.15 */
pa_operation* pa_context_set_sink_port_by_name(pa_context *c, const char*name, const char*port, pa_context_success_cb_t cb, void *userdata);

/** Get information about a source by its name */
pa_operation* pa_context_get_source_info_by_name(pa_context *c, const char *name, pa_source_info_cb_t cb, void *userdata);

/** Get information about a source by its index */
pa_operation* pa_context_get_source_info_by_index(pa_context *c, uint idx, pa_source_info_cb_t cb, void *userdata);

/** Get the complete source list */
pa_operation* pa_context_get_source_info_list(pa_context *c, pa_source_info_cb_t cb, void *userdata);

/** Set the volume of a source device specified by its index */
pa_operation* pa_context_set_source_volume_by_index(pa_context *c, uint idx, const pa_cvolume *volume, pa_context_success_cb_t cb, void *userdata);

/** Set the volume of a source device specified by its name */
pa_operation* pa_context_set_source_volume_by_name(pa_context *c, const char *name, const pa_cvolume *volume, pa_context_success_cb_t cb, void *userdata);

/** Set the mute switch of a source device specified by its index */
pa_operation* pa_context_set_source_mute_by_index(pa_context *c, uint idx, int mute, pa_context_success_cb_t cb, void *userdata);

/** Set the mute switch of a source device specified by its name */
pa_operation* pa_context_set_source_mute_by_name(pa_context *c, const char *name, int mute, pa_context_success_cb_t cb, void *userdata);

/** Suspend/Resume a source. \since 0.9.7 */
pa_operation* pa_context_suspend_source_by_name(pa_context *c, const char *source_name, int suspend, pa_context_success_cb_t cb, void* userdata);

/** Suspend/Resume a source. If idx is PA_INVALID_INDEX, all sources will be suspended. \since 0.9.7 */
pa_operation* pa_context_suspend_source_by_index(pa_context *c, uint idx, int suspend, pa_context_success_cb_t cb, void* userdata);

/** Change the profile of a source. \since 0.9.16 */
pa_operation* pa_context_set_source_port_by_index(pa_context *c, uint idx, const char*port, pa_context_success_cb_t cb, void *userdata);

/** Change the profile of a source. \since 0.9.15 */
pa_operation* pa_context_set_source_port_by_name(pa_context *c, const char*name, const char*port, pa_context_success_cb_t cb, void *userdata);

/** Callback prototype for pa_context_get_server_info() */
alias pa_server_info_cb_t = void function(pa_context *c, const pa_server_info*i, void *userdata);

/** Get some information about the server */
pa_operation* pa_context_get_server_info(pa_context *c, pa_server_info_cb_t cb, void *userdata);

/** Set the volume of the specified number of channels to the volume v */
pa_cvolume* pa_cvolume_set(pa_cvolume *a, uint channels, pa_volume_t v);

/** Return the average volume of all channels */
pa_volume_t pa_cvolume_avg(const pa_cvolume *a);


alias pa_subscription_event_type_t = int;
/** Subscription event types, as used by pa_context_subscribe() */
enum: pa_subscription_event_type_t {
    PA_SUBSCRIPTION_EVENT_SINK = 0x0000U,
    /**< Event type: Sink */

    PA_SUBSCRIPTION_EVENT_SOURCE = 0x0001U,
    /**< Event type: Source */

    PA_SUBSCRIPTION_EVENT_SINK_INPUT = 0x0002U,
    /**< Event type: Sink input */

    PA_SUBSCRIPTION_EVENT_SOURCE_OUTPUT = 0x0003U,
    /**< Event type: Source output */

    PA_SUBSCRIPTION_EVENT_MODULE = 0x0004U,
    /**< Event type: Module */

    PA_SUBSCRIPTION_EVENT_CLIENT = 0x0005U,
    /**< Event type: Client */

    PA_SUBSCRIPTION_EVENT_SAMPLE_CACHE = 0x0006U,
    /**< Event type: Sample cache item */

    PA_SUBSCRIPTION_EVENT_SERVER = 0x0007U,
    /**< Event type: Global server change, only occurring with PA_SUBSCRIPTION_EVENT_CHANGE. */

/** \cond fulldocs */
    PA_SUBSCRIPTION_EVENT_AUTOLOAD = 0x0008U,
    /**< \deprecated Event type: Autoload table changes. */
/** \endcond */

    PA_SUBSCRIPTION_EVENT_CARD = 0x0009U,
    /**< Event type: Card \since 0.9.15 */

    PA_SUBSCRIPTION_EVENT_FACILITY_MASK = 0x000FU,
    /**< A mask to extract the event type from an event value */

    PA_SUBSCRIPTION_EVENT_NEW = 0x0000U,
    /**< A new object was created */

    PA_SUBSCRIPTION_EVENT_CHANGE = 0x0010U,
    /**< A property of the object was modified */

    PA_SUBSCRIPTION_EVENT_REMOVE = 0x0020U,
    /**< An object was removed */

    PA_SUBSCRIPTION_EVENT_TYPE_MASK = 0x0030U
    /**< A mask to extract the event operation from an event value */

}


alias pa_subscription_mask_t = int;
/** Subscription event mask, as used by pa_context_subscribe() */
enum: pa_subscription_mask_t {
    PA_SUBSCRIPTION_MASK_NULL = 0x0000U,
    /**< No events */

    PA_SUBSCRIPTION_MASK_SINK = 0x0001U,
    /**< Sink events */

    PA_SUBSCRIPTION_MASK_SOURCE = 0x0002U,
    /**< Source events */

    PA_SUBSCRIPTION_MASK_SINK_INPUT = 0x0004U,
    /**< Sink input events */

    PA_SUBSCRIPTION_MASK_SOURCE_OUTPUT = 0x0008U,
    /**< Source output events */

    PA_SUBSCRIPTION_MASK_MODULE = 0x0010U,
    /**< Module events */

    PA_SUBSCRIPTION_MASK_CLIENT = 0x0020U,
    /**< Client events */

    PA_SUBSCRIPTION_MASK_SAMPLE_CACHE = 0x0040U,
    /**< Sample cache events */

    PA_SUBSCRIPTION_MASK_SERVER = 0x0080U,
    /**< Other global server changes. */

/** \cond fulldocs */
    PA_SUBSCRIPTION_MASK_AUTOLOAD = 0x0100U,
    /**< \deprecated Autoload table events. */
/** \endcond */

    PA_SUBSCRIPTION_MASK_CARD = 0x0200U,
    /**< Card events. \since 0.9.15 */

    PA_SUBSCRIPTION_MASK_ALL = 0x02ffU
    /**< Catch all events */
}


/** Subscription event callback prototype */
alias pa_context_subscribe_cb_t = void function(pa_context *c, pa_subscription_event_type_t t, uint idx, void *userdata);


/** Enable event notification */
pa_operation* pa_context_subscribe(pa_context *c, pa_subscription_mask_t m, pa_context_success_cb_t cb, void *userdata);


/** Set the context specific call back function that is called whenever the state of the daemon changes */
void pa_context_set_subscribe_callback(pa_context *c, pa_context_subscribe_cb_t cb, void *userdata);


/** Set the name of the default sink. */
pa_operation* pa_context_set_default_sink(pa_context *c, const char *name, pa_context_success_cb_t cb, void *userdata);

/** Set the name of the default source. */
pa_operation* pa_context_set_default_source(pa_context *c, const char *name, pa_context_success_cb_t cb, void *userdata);

/** Move the specified sink input to a different sink. \since 0.9.5 */
pa_operation* pa_context_move_sink_input_by_index(pa_context *c, uint idx, uint sink_idx, pa_context_success_cb_t cb, void* userdata);

/** Move the specified source output to a different source. \since 0.9.5 */
pa_operation* pa_context_move_source_output_by_index(pa_context *c, uint idx, uint source_idx, pa_context_success_cb_t cb, void* userdata);

/** Stores information about source outputs. Please note that this structure
 * can be extended as part of evolutionary API updates at any time in
 * any new release. */
struct pa_source_output_info {
    uint index;                      /**< Index of the source output */
    const char *name;                    /**< Name of the source output */
    uint owner_module;               /**< Index of the module this source output belongs to, or PA_INVALID_INDEX when it does not belong to any module. */
    uint client;                     /**< Index of the client this source output belongs to, or PA_INVALID_INDEX when it does not belong to any client. */
    uint source;                     /**< Index of the connected source */
    pa_sample_spec sample_spec;          /**< The sample specification of the source output */
    pa_channel_map channel_map;          /**< Channel map */
    pa_usec_t buffer_usec;               /**< Latency due to buffering in the source output, see pa_timing_info for details. */
    pa_usec_t source_usec;               /**< Latency of the source device, see pa_timing_info for details. */
    const char *resample_method;         /**< The resampling method used by this source output. */
    const char *driver;                  /**< Driver name */
    pa_proplist *proplist;               /**< Property list \since 0.9.11 */
    int corked;                          /**< Stream corked \since 1.0 */
    pa_cvolume volume;                   /**< The volume of this source output \since 1.0 */
    int mute;                            /**< Stream muted \since 1.0 */
    int has_volume;                      /**< Stream has volume. If not set, then the meaning of this struct's volume member is unspecified. \since 1.0 */
    int volume_writable;                 /**< The volume can be set. If not set, the volume can still change even though clients can't control the volume. \since 1.0 */
    pa_format_info *format;              /**< Stream format information. \since 1.0 */
}

/** Stores information about sink inputs. Please note that this structure
 * can be extended as part of evolutionary API updates at any time in
 * any new release. */
struct pa_sink_input_info {
    uint index;                      /**< Index of the sink input */
    const char *name;                    /**< Name of the sink input */
    uint owner_module;               /**< Index of the module this sink input belongs to, or PA_INVALID_INDEX when it does not belong to any module. */
    uint client;                     /**< Index of the client this sink input belongs to, or PA_INVALID_INDEX when it does not belong to any client. */
    uint sink;                       /**< Index of the connected sink */
    pa_sample_spec sample_spec;          /**< The sample specification of the sink input. */
    pa_channel_map channel_map;          /**< Channel map */
    pa_cvolume volume;                   /**< The volume of this sink input. */
    pa_usec_t buffer_usec;               /**< Latency due to buffering in sink input, see pa_timing_info for details. */
    pa_usec_t sink_usec;                 /**< Latency of the sink device, see pa_timing_info for details. */
    const char *resample_method;         /**< The resampling method used by this sink input. */
    const char *driver;                  /**< Driver name */
    int mute;                            /**< Stream muted \since 0.9.7 */
    pa_proplist *proplist;               /**< Property list \since 0.9.11 */
    int corked;                          /**< Stream corked \since 1.0 */
    int has_volume;                      /**< Stream has volume. If not set, then the meaning of this struct's volume member is unspecified. \since 1.0 */
    int volume_writable;                 /**< The volume can be set. If not set, the volume can still change even though clients can't control the volume. \since 1.0 */
    pa_format_info *format;              /**< Stream format information. \since 1.0 */
}

/** Callback prototype for pa_context_get_sink_input_info() and friends */
alias pa_sink_input_info_cb_t = void function(pa_context *c, const pa_sink_input_info *i, int eol, void *userdata);

/** Get the complete sink input list */
pa_operation* pa_context_get_sink_input_info_list(pa_context *c, pa_sink_input_info_cb_t cb, void *userdata);

/** Callback prototype for pa_context_get_source_output_info() and friends */
alias pa_source_output_info_cb_t = void function(pa_context *c, const pa_source_output_info *i, int eol, void *userdata);

/** Get the complete list of source outputs */
pa_operation* pa_context_get_source_output_info_list(pa_context *c, pa_source_output_info_cb_t cb, void *userdata);
