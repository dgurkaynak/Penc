//
//  SIWindowExtension.swift
//  Penc
//
//  Created by Lukas Stabe on 07.03.2019
//  Copyright © 2019 Deniz Gurkaynak. All rights reserved.
//

import Silica

extension SIWindow {
    func focusThisWindowOnly() {
        NSRunningApplication(processIdentifier: processIdentifier())?.activate(options: .activateIgnoringOtherApps)
        AXUIElementSetAttributeValue(axElementRef, NSAccessibility.Attribute.main.rawValue as CFString, kCFBooleanTrue)
    }
    
    // Silica uses top-left corner of the main screen as origin and
    // (x, y) refers to top-left corner of a window.
    // However Cocoa uses bottom-left corner of the main screen
    // as origin (increasing bottom to top) and bottom-left corner
    // of a window as (x, y).
    //
    // This method returns a Cocoa-friendly frame
    //
    // ENSURE THAT NSScreen.screens IS NOT EMPTY BEFORE USE THIS METHOD
    func getFrameBottomLeft() -> CGRect {
        return self.frame().topLeft2bottomLeft(NSScreen.screens[0])
    }
    
    // This method accepts Cocoa-friendly bottom-left origined CGRect,
    // and converts it to Silica's top-left CGRect
    //
    // ENSURE THAT NSScreen.screens IS NOT EMPTY BEFORE USE THIS METHOD
    func setFrameBottomLeft(_ rect: CGRect) {
        self.setFrame(rect.topLeft2bottomLeft(NSScreen.screens[0]))
    }
}
