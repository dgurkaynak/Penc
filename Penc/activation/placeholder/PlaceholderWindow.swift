//
//  PlaceholderWindow.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 15.05.2018.
//  Copyright © 2018 Deniz Gurkaynak. All rights reserved.
//

import Cocoa

class PlaceholderWindow: NSWindow {
    // By default, macOS's window manager make sure you cannot resize
    // your window to be outside the screen frame. If we have multiple screen
    // connected to mac, this behaviour prevents us from moving the window freely
    // between screens. This seemingly-empty file overrides this behaviour.
    // https://stackoverflow.com/a/6303578
    //
    // TODO: However, this fix removes all the constraints. We may want to limit
    // this behaviour so that we can move between screens, while preventing
    // it from leaving from total visible screen space.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}
