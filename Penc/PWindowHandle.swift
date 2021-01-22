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

let WINDOW_RESIZE_HANDLE_SIZE: CGFloat = 20

enum PWindowResizeHandle {
    case TOP
    case TOP_LEFT
    case LEFT
    case BOTTOM_LEFT
    case BOTTOM
    case BOTTOM_RIGHT
    case RIGHT
    case TOP_RIGHT
}

enum PWindowHandleError: Error {
    case noScreens
    case unexpectedNilResponse
}

class PWindowHandle {
    public private(set) var appPid: pid_t
    public private(set) var runningApp: NSRunningApplication?
    public private(set) var windowNumber: Int
    public private(set) var zIndex: Int
    public private(set) var initialRect: CGRect // bottom-left originated
    var previousRectBeforeDblClick: CGRect? // bottom-left originated
    public private(set) var newRect: CGRect // bottom-left originated
    public private(set) var resizeHandleRects = [(
        type: PWindowResizeHandle,
        rect: CGRect
    )]()
    
    let placeholder = PlaceholderPool.shared.acquire()
    
    private var _siWindow: SIWindow?
    
    private init(appPid: pid_t, windowNumber: Int, zIndex: Int, frame: CGRect) {
        self.appPid = appPid
        self.runningApp = NSRunningApplication.init(processIdentifier: appPid)
        self.windowNumber = windowNumber
        self.zIndex = zIndex
        self.initialRect = frame
        self.newRect = frame
        
        self.refreshResizeHandleRects()
    }
    
    func refreshResizeHandleRects() {
        self.resizeHandleRects = [
            (
                type: .TOP,
                rect: CGRect(
                    x: self.newRect.origin.x + WINDOW_RESIZE_HANDLE_SIZE,
                    y: self.newRect.origin.y + self.newRect.size.height - WINDOW_RESIZE_HANDLE_SIZE,
                    width: self.newRect.size.width - (2 * WINDOW_RESIZE_HANDLE_SIZE),
                    height: WINDOW_RESIZE_HANDLE_SIZE
                )
            ),
            (
                type: .TOP_LEFT,
                rect: CGRect(
                    x: self.newRect.origin.x,
                    y: self.newRect.origin.y + self.newRect.size.height - WINDOW_RESIZE_HANDLE_SIZE,
                    width: WINDOW_RESIZE_HANDLE_SIZE,
                    height: WINDOW_RESIZE_HANDLE_SIZE
                )
            ),
            (
                type: .LEFT,
                rect: CGRect(
                    x: self.newRect.origin.x,
                    y: self.newRect.origin.y + WINDOW_RESIZE_HANDLE_SIZE,
                    width: WINDOW_RESIZE_HANDLE_SIZE,
                    height: self.newRect.size.height - (2 * WINDOW_RESIZE_HANDLE_SIZE)
                )
            ),
            (
                type: .BOTTOM_LEFT,
                rect: CGRect(
                    x: self.newRect.origin.x,
                    y: self.newRect.origin.y,
                    width: WINDOW_RESIZE_HANDLE_SIZE,
                    height: WINDOW_RESIZE_HANDLE_SIZE
                )
            ),
            (
                type: .BOTTOM,
                rect: CGRect(
                    x: self.newRect.origin.x + WINDOW_RESIZE_HANDLE_SIZE,
                    y: self.newRect.origin.y,
                    width: self.newRect.size.width - (2 * WINDOW_RESIZE_HANDLE_SIZE),
                    height: WINDOW_RESIZE_HANDLE_SIZE
                )
            ),
            (
                type: .BOTTOM_RIGHT,
                rect: CGRect(
                    x: self.newRect.origin.x + self.newRect.size.width - WINDOW_RESIZE_HANDLE_SIZE,
                    y: self.newRect.origin.y,
                    width: WINDOW_RESIZE_HANDLE_SIZE,
                    height: WINDOW_RESIZE_HANDLE_SIZE
                )
            ),
            (
                type: .RIGHT,
                rect: CGRect(
                    x: self.newRect.origin.x + self.newRect.size.width - WINDOW_RESIZE_HANDLE_SIZE,
                    y: self.newRect.origin.y + WINDOW_RESIZE_HANDLE_SIZE,
                    width: WINDOW_RESIZE_HANDLE_SIZE,
                    height: self.newRect.size.height - (2 * WINDOW_RESIZE_HANDLE_SIZE)
                )
            ),
            (
                type: .TOP_RIGHT,
                rect: CGRect(
                    x: self.newRect.origin.x + self.newRect.size.width - WINDOW_RESIZE_HANDLE_SIZE,
                    y: self.newRect.origin.y + self.newRect.size.height - WINDOW_RESIZE_HANDLE_SIZE,
                    width: WINDOW_RESIZE_HANDLE_SIZE,
                    height: WINDOW_RESIZE_HANDLE_SIZE
                )
            )
        ]
    }
    
    func refreshPlaceholderTitle() {
        let title = self._siWindow != nil ? self._siWindow!.title() ?? "Untitled Window" : "Untitled Window"
        self.placeholder.windowViewController.updateWindowTitleTextField(title)
    }
    
    func refreshAppIconImage() {
        if self.runningApp == nil {
            self.placeholder.windowViewController.imageView.image = nil
            return
        }
        
        self.placeholder.windowViewController.imageView.image = self.runningApp!.icon
    }
    
    func updateFrame(_ newFrame: CGRect) {
        self.newRect = newFrame
        self.placeholder.window.setFrame(self.newRect, display: true, animate: false)
        self.placeholder.windowViewController.updateWindowSizeTextField(self.newRect)
        
        self.refreshResizeHandleRects()
    }
    
    func applyNewFrame() {
        guard self.isChanged() else { return }
        self.initialRect = self.newRect
        self.siWindow?.setFrameBottomLeft(self.newRect)
    }
    
    func isChanged() -> Bool {
        return self.newRect != self.initialRect
    }
    
    var siWindow: SIWindow? {
        set { self._siWindow = newValue }
        get {
            if self._siWindow != nil { return self._siWindow! }
            
            if let runningApp = self.runningApp {
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
    
    // Returns ordered from frontmost to backmost
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
            let windowHandle = PWindowHandle(
                appPid: appPid!,
                windowNumber: windowNumber!,
                zIndex: zIndex,
                frame: rect
            )
            visibleWindowHandles.append(windowHandle)
            
            zIndex = zIndex - 1
        }
        
        return visibleWindowHandles
    }
}
