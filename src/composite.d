module flatman.composite;

import flatman;

__gshared:


class CompositeManager {

	Picture backBuffer;
	Picture frontBuffer;

	int width;
	int height;

	//Damage damage;
	bool initialRepaint;

	this(){

		width = DisplayWidth(dpy, DefaultScreen(dpy));
		height = DisplayHeight(dpy, DefaultScreen(dpy));

	    Window w = XCreateSimpleWindow(dpy, RootWindow(dpy, 0), 0, 0, 1, 1, 0, None, None);
	    Xutf8SetWMProperties(dpy, w, cast(char*)"xcompmgr".toStringz, cast(char*)"xcompmgr".toStringz, null, 0, null, null, null);
	    Atom a = XInternAtom(dpy, "_NET_WM_CM_S0", False);
	    XSetSelectionOwner (dpy, a, w, 0);

		XCompositeRedirectSubwindows(dpy, root, CompositeRedirectManual);
		auto visual = DefaultVisual(dpy, screen);
		auto format = XRenderFindVisualFormat(dpy, visual);

		XRenderPictureAttributes pa;
		pa.subwindow_mode = IncludeInferiors;
		frontBuffer = XRenderCreatePicture(dpy, root, format, CPSubwindowMode, &pa);
		Pixmap pixmap = XCreatePixmap(dpy, root, DisplayWidth(dpy, screen), DisplayHeight(dpy, screen), DefaultDepth(dpy, screen));
		backBuffer = XRenderCreatePicture(dpy, pixmap, format, 0, null);
		XFreePixmap(dpy, pixmap); // The picture owns the pixmap now
		XSync(dpy, false);
	}

	void draw(){

		//XRectangle r = {0, 0, cast(ushort)width, cast(ushort)height};
		//XserverRegion region = XFixesCreateRegion( dpy, &r, 1 );
		//if(damage)
		//	XFixesDestroyRegion(dpy, damage);
		//auto damage = region;

		//XFixesSetPictureClipRegion(dpy, frontBuffer, 0, 0, damage);

		/+
		foreach(mon; monitors){
			for(auto client = mon.clients; client; client = client.next){
				//if(!client.isVisible || !client.isPainted)
				//	continue;
				// Update the region containing the area the window was last rendered at.
				//client.updateOnScreenRegion;
				// Only draw the window if it's opaque
				//if(client.isOpaque){
					// Set the clip region for the backbuffer to the damage region, and
					// subtract the clients shape from the damage region
					//XFixesSetPictureClipRegion(dpy, backBuffer, 0, 0, damage);
					//XFixesSubtractRegion(dpy, damage, damage, client.shape);
					XRenderComposite(dpy, PictOpSrc, client.picture,
							None, backBuffer, 0, 0, 0, 0,
							client.pos.x,
							client.pos.y,
							client.size.w,
							client.size.h);
				//}
				// Save the clip region before the next client shape is subtracted from it.
				// We need to restore it later when we're drawing the shadow.
				//client.setShapeClip(damage);
				//translucents = client ~ translucents;
			}
		}
		+/

		// Draw any areas of the root window not covered by windows
		//XFixesSetPictureClipRegion(dpy, backBuffer, 0, 0, damage);
		//XRenderComposite(dpy, PictOpSrc, wallpaper, None, backBuffer, 0, 0, 0, 0, 0, 0, width, height);
		// Destroy the damage region
		//XFixesDestroyRegion(dpy, damage);
		//damage = None;
		// Copy the back buffer contents to the root window
		//XFixesSetPictureClipRegion(dpy, backBuffer, 0, 0, None);
		XRenderComposite(dpy, PictOpSrc, backBuffer, None, frontBuffer, 0, 0, 0, 0, 0, 0, width, height);
		/+
		// If there's no damage, update the whole display
		if(damage == None || initialRepaint){
			XRectangle r = {0, 0, width, height};
			XserverRegion region = XFixesCreateRegion( dpy, &r, 1 );
			if(damage)
				XFixesDestroyRegion(dpy, damage);
			damage = region;
			initialRepaint = false;
		}
		// Use the damage region as the clip region for the root window
		XFixesSetPictureClipRegion(dpy, frontBuffer, 0, 0, damage);
		// Draw each opaque window top to bottom, subtracting the bounding rect of
		// each drawn window from the clip region.
		ClientList::ConstIterator end = mList.constEnd();
		Client[] translucents;
		for(ClientList::ConstIterator it = mList.constBegin(); it != end; ++it){
			if(!client.isVisible || !client.isPainted)
				continue;
			// Update the region containing the area the window was last rendered at.
			client.updateOnScreenRegion;
			// Only draw the window if it's opaque
			if(client.isOpaque{
				// Set the clip region for the backbuffer to the damage region, and
				// subtract the clients shape from the damage region
				XFixesSetPictureClipRegion(dpy, backBuffer, 0, 0, damage);
				XFixesSubtractRegion(dpy, damage, damage, client.shape;
				XRenderComposite(dpy, PictOpSrc, client.picture,
						None, backBuffer, 0, 0, 0, 0,
						client.pos.x, client.pos.y,
						client.size.w + client.borderWidth * 2,
						client.size.h + client.borderWidth * 2);
			}
			// Save the clip region before the next client shape is subtracted from it.
			// We need to restore it later when we're drawing the shadow.
			client.setShapeClip(damage);
			translucents = client ~ translucents;
		}
		// Draw any areas of the root window not covered by windows
		XFixesSetPictureClipRegion(dpy, backBuffer, 0, 0, damage);
		XRenderComposite(dpy, PictOpSrc, rootTile, None, backBuffer, 0, 0, 0, 0, 0, 0, width(), height());
		// Now walk the list backwards, drawing translucent windows and shadows.
		// That we draw bottom to top is important now since we're drawing translucent windows.
		end = translucents.constEnd();
		foreach(client; translucents){
			// Restore the previously saved clip region
			XFixesSetPictureClipRegion(dpy, backBuffer, 0, 0, client.shapeClip;
			// Only draw the window if it's translucent
			// (we drew the opaque ones in the previous loop)
			if(!client.isOpaque
				XRenderComposite(dpy, PictOpOver, client.picture,
					    client.alphaMask, backBuffer, 0, 0, 0, 0,
						client.pos.x + client.borderWidth,
						client.pos.y + client.borderWidth,
						client.width, client.height;
			// We don't need the clip region anymore
			client.destroyShapeClip;
		}
		translucents.clear;
		// Destroy the damage region
		XFixesDestroyRegion(dpy, damage);
		damage = None;
		// Copy the back buffer contents to the root window
		XFixesSetPictureClipRegion(dpy, backBuffer, 0, 0, None);
		XRenderComposite(dpy, PictOpSrc, backBuffer, None, frontBuffer, 0, 0, 0, 0, 0, 0, width, height;
			+/
	}

}

