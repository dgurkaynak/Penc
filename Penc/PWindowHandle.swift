//
//  WindowHandle.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 11.01.2021.
//  Copyright © 2021 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa
import Silica

enum PWindowHandleError: Error {
    case noScreens
    case unexpectedNilResponse
}

class PWindowHandle {
    public private(set) var appPid: pid_t
    public private(set) var windowNumber: Int
    public private(set) var zIndex: Int
    public private(set) var oldRect: CGRect // bottom-left originated
    public private(set) var newRect: CGRect // bottom-left originated
    
    let placeholder = PlaceholderPool.shared.acquire()
    
    private var _siWindow: SIWindow?
    
    private init(appPid: pid_t, windowNumber: Int, zIndex: Int, frame: CGRect) {
        self.appPid = appPid
        self.windowNumber = windowNumber
        self.zIndex = zIndex
        self.oldRect = frame
        self.newRect = frame
    }
    
    func updateFrame(_ newFrame: CGRect) {
        self.newRect = newFrame
        self.placeholder.window.setFrame(self.newRect, display: true, animate: false)
        self.placeholder.windowViewController.updateWindowSizeTextField(self.newRect)
    }
    
    func applyNewFrame() {
        guard self.newRect != self.oldRect else { return }
        self.siWindow?.setFrameBottomLeft(self.newRect)
    }
    
    var siWindow: SIWindow? {
        set { self._siWindow = newValue }
        get {
            if self._siWindow != nil { return self._siWindow! }
            
            if let runningApp = NSRunningApplication.init(processIdentifier: self.appPid) {
                let app = SIApplication.init(runningApplication: runningApp)
                let visibleWindows = app.visibleWindows()

                for case let win as SIWindow in visibleWindows {
                    if Int(win.windowID()) == self.windowNumber {
                        self._siWindow = win
                    }
                }
            }
            
            return self._siWindow
        }
    }
    
    deinit {
        PlaceholderPool.shared.release(self.placeholder)
    }
    
    static func visibleWindowHandles() throws -> [PWindowHandle] {
        guard NSScreen.screens.indices.contains(0) else {
            throw PWindowHandleError.noScreens
        }
        
        let visibleWindowsInfo = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
        guard visibleWindowsInfo != nil else {
            throw PWindowHandleError.unexpectedNilResponse
        }
        
        var visibleWindowHandles: [PWindowHandle] = []
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
            let windowHandle = PWindowHandle(appPid: appPid!, windowNumber: windowNumber!, zIndex: zIndex, frame: rect)
            visibleWindowHandles.append(windowHandle)
            
            zIndex = zIndex - 1
        }
        
        return visibleWindowHandles
    }
}