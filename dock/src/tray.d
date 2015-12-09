module flatman.dock.tray;


import dock;

/+
/**
 * System tray plugin to lxpanel
 *
 * Copyright (c) 2008-2014 LxDE Developers, see the file AUTHORS for details.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 *
 */

/** Contains code adapted from na-tray-manager.c
 * Copyright (C) 2002 Anders Carlsson <andersca@gnu.org>
 * Copyright (C) 2003-2006 Vincent Untz */



/* Standards reference:  http://standards.freedesktop.org/systemtray-spec/ */

/* Protocol constants. */
enum SYSTEM_TRAY_REQUEST_DOCK = 0;
enum SYSTEM_TRAY_BEGIN_MESSAGE = 1;
enum SYSTEM_TRAY_CANCEL_MESSAGE = 2;

enum SYSTEM_TRAY_ORIENTATION_HORZ = 0;
enum SYSTEM_TRAY_ORIENTATION_VERT = 1;

/* Representative of a balloon message. */
struct BalloonMessage {
    BalloonMessage* flink;		/* Forward link */
    x11.X.Window window;				/* X window ID */
    long timeout;				/* Time in milliseconds to display message; 0 if no timeout */
    long length;				/* Message string length */
    long id;					/* Client supplied unique message ID */
    long remaining_length;			/* Remaining length expected of incomplete message */
    string text;				/* Message string */
}

/* Representative of a tray client. */
class TrayClient {
    TrayPlugin tray;			/* Back pointer to tray plugin */
    x11.X.Window window;				/* X window ID */
    Widget socket;				/* Socket */
}

/* Private context for system tray plugin. */
class TrayPlugin {

    Widget plugin;				/* Back pointer to Plugin */
    TrayClient[] clients;			/* List of tray clients */
    BalloonMessage[] incomplete_messages;	/* List of balloon messages for which we are awaiting data */
    BalloonMessage[] messages;			/* List of balloon messages actively being displayed or waiting to be displayed */
    gtk.Window.Window balloon_message_popup;		/* Popup showing balloon message */
    uint balloon_message_timer;		/* Timer controlling balloon message */
    Widget invisible;			/* Invisible window that holds manager selection */
    x11.X.Window invisible_window;			/* X window ID of invisible window */
    GdkAtom selection_atom;			/* Atom for _NET_SYSTEM_TRAY_S%d */

    /* Look up a client in the client list. */
    TrayClient client_lookup(x11.X.Window window){
        foreach(client; clients)
        	if(client.window == window)
        		return client;
        return null;
    }

    static if(false){
        void client_print(char c, TrayClient* tc, XClientMessageEvent* xevent){
                char *name = get_utf8_property(tc.window, a_NET_WM_NAME);
                int pid = get_net_wm_pid(tc.window);
                XClientMessageEvent xcm = {0};
                if (!xevent)
                    xevent = &xcm;
                g_debug("tray: %c%p, winid 0x%lx: %s (PID %d), plug %p, serial no %lu, send_event %c, format %d",
                        c, tc, tc.window, name, pid,
                        gtk_socket_get_plug_window(GTK_SOCKET(tc.socket)),
                        xevent.serial, xevent.send_event ? 'y' : 'n', xevent.format);
                g_free(name);
        }
    }

    /* Delete a client. */
    void client_delete(TrayClient client, bool remove, bool destroy){
        if(remove)
        	clients = clients.without(client);
        /* Clear out any balloon messages. */
        balloon_incomplete_message_remove(client.window, true, 0);
        balloon_message_remove(client.window, true, 0);
        /* Remove the socket from the icon grid. */
        /+
        if(destroy)
            gtk_widget_destroy(client.socket);
        +/
    }

    /*** Balloon message display ***/

    /* General code to deactivate a message and optionally display the next.
     * This is used in three scenarios: balloon clicked, timeout expired, destructor. */
    void balloon_message_advance(bool destroy_timer, bool display_next){
    	/+
        /* Remove the message from the queue. */
        BalloonMessage msg = messages[0];
        messages = messages.without(msg);
        /* Cancel the timer, if set.  This is not done when the timer has expired. */
        if ((destroy_timer) && (balloon_message_timer != 0))
            g_source_remove(balloon_message_timer);
        balloon_message_timer = 0;
        /* Destroy the widget. */
        if (balloon_message_popup != null)
            gtk_widget_destroy(balloon_message_popup);
        balloon_message_popup = null;
        /* Free the message. */
        balloon_message_free(msg);
        /* If there is another message waiting in the queue, display it.  This is not done in the destructor. */
        if ((display_next) && (messages != null))
            balloon_message_display(messages);
        +/
    }

    /* Handler for "button-press-event" from balloon message popup menu item. */
    static bool balloon_message_activate_event(Widget * widget, GdkEventButton * event, TrayPlugin* tr){
        //balloon_message_advance(true, true);
        return true;
    }

    /* Timer expiration for balloon message. */
    static bool balloon_message_timeout(TrayPlugin* tr){
        /+
        if (!g_source_is_destroyed(g_main_current_source()))
            balloon_message_advance(false, true);
        +/
    	return false;
    }

    /* Create the graphic elements to display a balloon message. */
    void balloon_message_display(BalloonMessage msg){
        /* Create a window and an item containing the text. */

        balloon_message_popup = new gtk.Window.Window(GtkWindowType.POPUP);
        auto balloon_text = new Label(msg.text);
        balloon_text.setLineWrap(true);
        balloon_text.setJustify(Justification.CENTER);
        balloon_message_popup.add(balloon_text);
        balloon_message_popup.setBorderWidth(4);
        /* Connect signals.  Clicking the popup dismisses it and displays the next message, if any. */
        balloon_message_popup.addOnButtonPress(&balloon_message_activate_event, tr);
        /* Compute the desired position in screen coordinates near the tray plugin. */
        int x;
        int y;
        lxpanel_plugin_popup_set_position_helper(panel, plugin, balloon_message_popup, &x, &y);
        /* Show the popup. */
        balloon_message_popup.move(x, y);
        balloon_message_popup.showAll;
        /* Set a timer, if the client specified one.  Both are in units of milliseconds. */
        if (msg.timeout != 0)
            balloon_message_timer = g_timeout_add(msg.timeout, cast(GSourceFunc) balloon_message_timeout, tr);
    }

    /* Add a balloon message to the tail of the message queue.  If it is the only element, display it immediately. */
    void balloon_message_queue(BalloonMessage msg){
        messages ~= msg;
        if(messages.length == 1)
			balloon_message_display(msg);
    }

    /* Remove an incomplete message from the queue, selected by window and optionally also client's ID.
     * Used in two scenarios: client issues CANCEL (ID significant), client plug removed (ID don't care). */
    void balloon_incomplete_message_remove(x11.X.Window window, bool all_ids, long id){
    	/+
        BalloonMessage msg_pred = null;
        BalloonMessage msg = incomplete_messages;
        while (msg != null){
            /* Establish successor in case of deletion. */
            BalloonMessage* msg_succ = msg.flink;
            if ((msg.window == window) && ((all_ids) || (msg.id == id))){
                /* Found a message matching the criteria.  Unlink and free it. */
                if (msg_pred == null)
                    incomplete_messages = msg.flink;
                else
                    msg_pred.flink = msg.flink;
                balloon_message_free(msg);
            }else
                msg_pred = msg;
            /* Advance to successor. */
            msg = msg_succ;
        }
        +/
    }

    /* Remove a message from the message queue, selected by window and optionally also client's ID.
     * Used in two scenarios: client issues CANCEL (ID significant), client plug removed (ID don't care). */
    void balloon_message_remove(x11.X.Window window, bool all_ids, long id){
    	/+
        BalloonMessage* msg_pred = null;
        BalloonMessage* msg_head = messages;
        BalloonMessage* msg = msg_head;
        while (msg != null){
            /* Establish successor in case of deletion. */
            BalloonMessage* msg_succ = msg.flink;
            if ((msg.window == window) && ((all_ids) || (msg.id == id))){
                /* Found a message matching the criteria. */
                if (msg_pred == null){
                    /* The message is at the queue head, so is being displayed.  Stop the display. */
                    messages = msg.flink;
                    if (balloon_message_timer != 0){
                        g_source_remove(balloon_message_timer);
                        balloon_message_timer = 0;
                    }
                    if (balloon_message_popup != null){
                        gtk_widget_destroy(balloon_message_popup);
                        balloon_message_popup = null;
                    }
                }else
                    msg_pred.flink = msg.flink;
                /* Free the message. */
                balloon_message_free(msg);
            }
            else
                msg_pred = msg;
            /* Advance to successor. */
            msg = msg_succ;
        }
        /* If there is a new message head, display it now. */
        if ((messages != msg_head) && (messages != null))
            balloon_message_display(messages);
        +/
    }

    /*** Event interfaces ***/

    /* Handle a balloon message SYSTEM_TRAY_BEGIN_MESSAGE event. */
    void balloon_message_begin_event(XClientMessageEvent* xevent){
        TrayClient* client = client_lookup(xevent.window);
        if (client != null){
            /* Check if the message ID already exists. */
            balloon_incomplete_message_remove(xevent.window, false, xevent.data.l[4]);

            /* Allocate a BalloonMessage structure describing the message. */
            BalloonMessage* msg = g_new0(BalloonMessage, 1);
            msg.window = xevent.window;
            msg.timeout = xevent.data.l[2];
            msg.length = xevent.data.l[3];
            msg.id = xevent.data.l[4];
            msg.remaining_length = msg.length;
            msg.text = g_new0!char(msg.length + 1);
            /* Message length of 0 indicates that no follow-on messages will be sent. */
            if(msg.length == 0)
                balloon_message_queue(msg);
            else{
                /* Add the new message to the queue to await its message text. */
                msg.flink = incomplete_messages;
                incomplete_messages = msg;
            }
        }
    }

    /* Handle a balloon message SYSTEM_TRAY_CANCEL_MESSAGE event. */
    void balloon_message_cancel_event(XClientMessageEvent * xevent){
        /* Remove any incomplete messages on this window with the specified ID. */
        balloon_incomplete_message_remove(xevent.window, true, 0);
        /* Remove any displaying or waiting messages on this window with the specified ID. */
        TrayClient* client = client_lookup(xevent.window);
        if (client != null)
            balloon_message_remove(xevent.window, false, xevent.data.l[2]);
    }

    /* Handle a balloon message _NET_SYSTEM_TRAY_MESSAGE_DATA event. */
    void balloon_message_data_event(XClientMessageEvent * xevent){
        /* Look up the pending message in the list. */
        BalloonMessage* msg_pred = null;
        BalloonMessage* msg;
        for (msg = incomplete_messages; msg != null; msg_pred = msg, msg = msg.flink){
            if (xevent.window == msg.window){
                /* Append the message segment to the message. */
                int length = MIN(msg.remaining_length, 20);
                memcpy((msg.text + msg.length - msg.remaining_length), &xevent.data, length);
                msg.remaining_length -= length;
                /* If the message has been completely collected, display it. */
                if (msg.remaining_length == 0){
                    /* Unlink the message from the structure. */
                    if (msg_pred == null)
                        incomplete_messages = msg.flink;
                    else
                        msg_pred.flink = msg.flink;
                    /* If the client window is valid, queue the message.  Otherwise discard it. */
                    TrayClient* client = client_lookup(msg.window);
                    if(client != null)
                        balloon_message_queue(msg);
                    else
                        balloon_message_free(msg);
                }
                break;
            }
        }
    }

    /* Handler for request dock message. */
    void trayclient_request_dock(XClientMessageEvent* xevent){
        /* Search for the window in the client list.  Set up context to do an insert right away if needed. */
        TrayClient* tc_pred = null;
        TrayClient* tc_cursor;
        for (tc_cursor = client_list; tc_cursor != null; tc_pred = tc_cursor, tc_cursor = tc_cursor.client_flink){
            if (tc_cursor.window == cast(x11.X.Window)xevent.data.l[2])
                return;     /* We already got this notification earlier, ignore this one. */
            if (tc_cursor.window > cast(x11.X.Window)xevent.data.l[2])
                break;
        }

        /* Allocate and initialize new client structure. */
        TrayClient* tc = g_new0(TrayClient, 1);
        tc.window = xevent.data.l[2];
        tc.tr = tr;

        /* Allocate a socket.  This is the tray side of the Xembed connection. */
        tc.socket = gtk_socket_new();

        /* Add the socket to the icon grid. */
        gtk_container_add(GTK_CONTAINER(plugin), tc.socket);
        gtk_widget_show(tc.socket);

        /* Connect the socket to the plug.  This can only be done after the socket is realized. */
        gtk_socket_add_id(GTK_SOCKET(tc.socket), tc.window);

        //fprintf(stderr, "Notice: checking plug %ud\n", tc.window );
        /* Checks if the plug has been created inside of the socket. */
        if (gtk_socket_get_plug_window ( GTK_SOCKET(tc.socket) ) == null) {
            //fprintf(stderr, "Notice: removing plug %ud\n", tc.window );
            gtk_widget_destroy(tc.socket);
            g_free(tc);
            return;
        }

        /* Link the client structure into the client list. */
        if (tc_pred == null)
        {
            tc.client_flink = client_list;
            client_list = tc;
        }
        else
        {
            tc.client_flink = tc_pred.client_flink;
            tc_pred.client_flink = tc;
        }
    }

    /* GDK event filter. */
    static GdkFilterReturn tray_event_filter(XEvent* xev, GdkEvent* event, TrayPlugin* tr){
        if(xev.type == DestroyNotify){
            /* Look for DestroyNotify events on tray icon windows and update state.
             * We do it this way rather than with a "plug_removed" event because delivery
             * of plug_removed events is observed to be unreliable if the client
             * disconnects within less than 10 ms. */
            XDestroyx11.X.WindowEvent * xev_destroy = cast(XDestroyx11.X.WindowEvent *) xev;
            TrayClient* tc = client_lookup(xev_destroy.window);
            if (tc != null)
                client_delete(tc, true, true);
        }else if (xev.type == ClientMessage){
            if (xev.xclient.message_type == a_NET_SYSTEM_TRAY_OPCODE){
                /* Client message of type _NET_SYSTEM_TRAY_OPCODE.
                 * Dispatch on the request. */
                switch (xev.xclient.data.l[1]){
                    case SYSTEM_TRAY_REQUEST_DOCK:
                        /* If a Request Dock event on the invisible window, which is holding the manager selection, execute it. */
                        if (xev.xclient.window == invisible_window){
                            trayclient_request_dock(cast(XClientMessageEvent *) xev);
                            return GDK_FILTER_REMOVE;
                        }
                        break;
                    case SYSTEM_TRAY_BEGIN_MESSAGE:
                        /* If a Begin Message event. look up the tray icon and execute it. */
                        balloon_message_begin_event(cast(XClientMessageEvent *) xev);
                        return GDK_FILTER_REMOVE;
                    case SYSTEM_TRAY_CANCEL_MESSAGE:
                        /* If a Cancel Message event. look up the tray icon and execute it. */
                        balloon_message_cancel_event(cast(XClientMessageEvent *) xev);
                        return GDK_FILTER_REMOVE;
                }
            }else if (xev.xclient.message_type == a_NET_SYSTEM_TRAY_MESSAGE_DATA){
                /* Client message of type _NET_SYSTEM_TRAY_MESSAGE_DATA.
                 * Look up the tray icon and execute it. */
                balloon_message_data_event(cast(XClientMessageEvent *) xev);
                return GDK_FILTER_REMOVE;
            }
        }else if(xev.type == SelectionClear && xev.xclient.window == invisible_window){
            /* Look for SelectionClear events on the invisible window, which is holding the manager selection.
             * This should not happen. */
            tray_unmanage_selection(tr);
        }
        return GDK_FILTER_CONTINUE;
    }

    /* Delete the selection on the invisible window. */
    void tray_unmanage_selection(TrayPlugin* tr){
        if (invisible != null){
            Widget* invisible = invisible;
            GdkDisplay* display = gtk_widget_get_display(invisible);
            if (gdk_selection_owner_get_for_display(display, selection_atom) == gtk_widget_get_window(invisible)){
                uint32 timestamp = gdk_x11_get_server_time(gtk_widget_get_window(invisible));
                gdk_selection_owner_set_for_display(
                    display,
                    null,
                    selection_atom,
                    timestamp,
                    true);
            }

            /* Destroy the invisible window. */
            invisible = null;
            invisible_window = None;
            gtk_widget_destroy(invisible);
            g_object_unref(G_OBJECT(invisible));
        }
    }

    /* Plugin constructor. */
    this(){
        Widget *p;
        /* Get the screen and display. */
        GdkScreen * screen = gtk_widget_get_screen(GTK_WIDGET(panel));
        Screen * xscreen = GDK_SCREEN_XSCREEN(screen);
        GdkDisplay* display = gdk_screen_get_display(screen);
        /* Create the selection atom.  This has the screen number in it, so cannot be done ahead of time. */
        char* selection_atom_name = g_strdup_printf("_NET_SYSTEM_TRAY_S%d", gdk_screen_get_number(screen));
        Atom selection_atom = gdk_x11_get_xatom_by_name_for_display(display, selection_atom_name);
        GdkAtom gdk_selection_atom = gdk_atom_intern(selection_atom_name, false);
        g_free(selection_atom_name);
        /* If the selection is already owned, there is another tray running. */
        if (XGetSelectionOwner(GDK_DISPLAY_XDISPLAY(display), selection_atom) != None){
            g_warning("tray: another systray already running");
            return null;
        }
        /* Create an invisible window to hold the selection. */
        Widget * invisible = gtk_invisible_new_for_screen(screen);
        gtk_widget_realize(invisible);
        gtk_widget_add_events(invisible, GDK_PROPERTY_CHANGE_MASK | GDK_STRUCTURE_MASK);
        /* Try to claim the _NET_SYSTEM_TRAY_Sn selection. */
        uint32 timestamp = gdk_x11_get_server_time(gtk_widget_get_window(invisible));
        if (gdk_selection_owner_set_for_display(
            display,
            gtk_widget_get_window(invisible),
            gdk_selection_atom,
            timestamp,
            true))
        {
            /* Send MANAGER client event (ICCCM). */
            XClientMessageEvent xev;
            xev.type = ClientMessage;
            xev.window = Rootx11.X.WindowOfScreen(xscreen);
            xev.message_type = a_MANAGER;
            xev.format = 32;
            xev.data.l[0] = timestamp;
            xev.data.l[1] = selection_atom;
            xev.data.l[2] = GDK_WINDOW_XID(gtk_widget_get_window(invisible));
            xev.data.l[3] = 0;    /* manager specific data */
            xev.data.l[4] = 0;    /* manager specific data */
            XSendEvent(GDK_DISPLAY_XDISPLAY(display), Rootx11.X.WindowOfScreen(xscreen), false, StructureNotifyMask, cast(XEvent*) &xev);
            /* Set the orientation property.
             * We always set "horizontal" since even vertical panels are designed to use a lot of width. */
            gulong data = SYSTEM_TRAY_ORIENTATION_HORZ;
            XChangeProperty(
                GDK_DISPLAY_XDISPLAY(display),
                GDK_WINDOW_XID(gtk_widget_get_window(invisible)),
                a_NET_SYSTEM_TRAY_ORIENTATION,
                XA_CARDINAL, 32,
                PropModeReplace,
                cast(guchar*)&data, 1);
        }else{
            gtk_widget_destroy(invisible);
            g_printerr("tray: System tray didn't get the system tray manager selection\n");
            return 0;
        }

        /* Allocate plugin context and set into Plugin private data pointer and static variable. */
        TrayPlugin* tr = g_new0(TrayPlugin, 1);
        selection_atom = gdk_selection_atom;
        /* Add GDK event filter. */
        gdk_window_add_filter(null, cast(GdkFilterFunc) tray_event_filter, tr);
        /* Reference the window since it is never added to a container. */
        invisible = g_object_ref_sink(G_OBJECT(invisible));
        invisible_window = GDK_WINDOW_XID(gtk_widget_get_window(invisible));

        /* Allocate top level widget and set into Plugin widget pointer. */
        plugin = p = panel_icon_grid_new(panel_get_orientation(panel),
                                             panel_get_icon_size(panel),
                                             panel_get_icon_size(panel),
                                             3, 0, panel_get_height(panel));
        lxpanel_plugin_set_data(p, tray_destructor);
        gtk_widget_set_name(p, "tray");
        panel_icon_grid_set_aspect_width(PANEL_ICON_GRID(p), true);

        return p;
    }

    /* Plugin destructor. */
    void tray_destructor(void* user_data){
        TrayPlugin* tr = user_data;
        /* Remove GDK event filter. */
        gdk_window_remove_filter(null, cast(GdkFilterFunc) tray_event_filter, tr);
        /* Make sure we drop the manager selection. */
        tray_unmanage_selection(tr);
        /* Deallocate incomplete messages. */
        while (incomplete_messages != null){
            BalloonMessage* msg_succ = incomplete_messages.flink;
            balloon_message_free(incomplete_messages);
            incomplete_messages = msg_succ;
        }
        /* Terminate message display and deallocate messages. */
        while (messages != null)
            balloon_message_advance(true, false);
        /* Deallocate client list - widgets are already destroyed. */
        while (client_list != null)
            client_delete(client_list, true, false);
        g_free(tr);
    }

    /+
    /* Callback when panel  changes. */
    void tray_panel_configuration_changed(LXPanel *panel, Widget *p){
        /* Set orientation into the icongrid. */
        panel_icon_grid_set_geometry(PANEL_ICON_GRID(p), panel_get_orientation(panel),                                      panel_get_icon_size(panel),
                                     panel_get_icon_size(panel),
                                         3, 0, panel_get_height(panel));
    }
    +/

    /+
    /* Plugin descriptor. */
    LXPanelPluginInit null = {
        .name = N_("System Tray"),
        .description = N_("System tray"),

    /* Set a flag to identify the system tray.  It is special in that only one per system can exist. */
    .one_per_system = true,

    .new_instance = tray_constructor,
    .reconfigure = tray_panel_configuration_changed
    };
    +/

}
+/