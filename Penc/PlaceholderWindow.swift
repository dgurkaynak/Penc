//
//  PlaceholderWindow.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 15.05.2018.
//  Copyright © 2018 Deniz Gurkaynak. All rights reserved.
//

import Cocoa

class PlaceholderWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}
