//
//  NSCursorExtension.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 28.01.2021.
//  Copyright © 2021 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa

extension NSCursor {
    // NSCursor does not have diagonal resize cursor's built-in, so here comes some hack
    // https://stackoverflow.com/questions/49297201/diagonal-resizing-mouse-pointer#comment85695817_49344105
    static let resizeNorthWestSouthEast = NSCursor.init(
        image: NSImage(byReferencingFile: "/System/Library/Frameworks/WebKit.framework/Versions/Current/Frameworks/WebCore.framework/Resources/northWestSouthEastResizeCursor.png")!,
        hotSpot: NSPoint(x: 8, y: 8)
    )
    static let resizeNorthEastSouthWest = NSCursor.init(
        image: NSImage(byReferencingFile: "/System/Library/Frameworks/WebKit.framework/Versions/Current/Frameworks/WebCore.framework/Resources/northEastSouthWestResizeCursor.png")!,
        hotSpot: NSPoint(x: 8, y: 8)
    )
}
