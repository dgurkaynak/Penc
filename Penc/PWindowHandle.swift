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
    
    init(appPid: pid_t, windowNumber: Int, zIndex: Int, frame: CGRect) {
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
    
    func setFrame(_ newFrame: CGRect) {
        self.newRect = newFrame
        self.placeholder.window.setFrame(self.newRect, display: true, animate: false)
        self.placeholder.windowViewController.updateWindowSizeTextField(self.newRect)
        
        self.refreshResizeHandleRects()
    }
    
    func applyNewFrame() {
        // Ensure frame is changed
        guard self.newRect != self.initialRect else { return }
        self.initialRect = self.newRect
        self.siWindow?.setFrameBottomLeft(self.newRect)
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
}
