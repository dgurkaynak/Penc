//
//  WindowInfo.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 3.01.2021.
//  Copyright © 2021 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa

enum WindowInfoGetError: Error {
    case noScreens
    case unexpectedNilResponse
}

struct WindowInfo {
    var appPid: pid_t
    var windowNumber: Int
    var rect: CGRect // bottom-left originated
    var zIndex: Int
    
    // Order of windows starts from frontmost visible window
    static func getVisibleWindows() throws -> [WindowInfo] {
        guard NSScreen.screens.indices.contains(0) else {
            throw WindowInfoGetError.noScreens
        }
        
        let visibleWindowsInfo = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
        guard visibleWindowsInfo != nil else {
            throw WindowInfoGetError.unexpectedNilResponse
        }
        
        var visibleWindows: [WindowInfo] = []
        var zIndex = 0
        
        for windowInfo in visibleWindowsInfo as! [NSDictionary] {
            // Ignore dock, desktop, menubar stuff: https://stackoverflow.com/a/5286921
            let windowLayer = windowInfo["kCGWindowLayer"] as? Int
            guard windowLayer == 0 else { continue }
            
            let appPid = windowInfo["kCGWindowOwnerPID"] as? pid_t
            let windowNumber = windowInfo["kCGWindowNumber"] as? Int
            let windowBounds = windowInfo["kCGWindowBounds"] as? NSDictionary
            
            guard appPid != nil else { continue }
            guard windowNumber != nil else { continue }
            guard windowBounds != nil else { continue }
            
            let windowWidth = windowBounds!["Width"] as? Int
            let windowHeight = windowBounds!["Height"] as? Int
            let windowX = windowBounds!["X"] as? Int
            let windowY = windowBounds!["Y"] as? Int // top-left origined
            
            guard windowWidth != nil else { continue }
            guard windowHeight != nil else { continue }
            guard windowX != nil else { continue }
            guard windowY != nil else { continue }
            
            let rect = CGRect(x: windowX!, y: windowY!, width: windowWidth!, height: windowHeight!).topLeft2bottomLeft(NSScreen.screens[0])
            let window = WindowInfo(appPid: appPid!, windowNumber: windowNumber!, rect: rect, zIndex: zIndex)
            visibleWindows.append(window)
            
            zIndex = zIndex - 1
        }
        
        return visibleWindows
    }
}
