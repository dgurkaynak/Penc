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


class ActivationWindow {
    public private(set) var appPid: pid_t
    public private(set) var runningApp: NSRunningApplication?
    public private(set) var windowNumber: Int
    public private(set) var zIndex: Int
    public private(set) var initialRect: CGRect // bottom-left originated
    var previousRectBeforeDblClick: CGRect? // bottom-left originated
    public private(set) var newRect: CGRect // bottom-left originated
    public private(set) var minimized = false
    
    public private(set) var rawAlignmentGuides: WindowAlignmentGuides = (horizontal: [], vertical: [])
    public private(set) var resizeHandleRects = [WindowResizeHandleRect]()
    
    let placeholder = PlaceholderPool.shared.acquire()
    
    private var _siWindow: SIWindow?
    
    init(appPid: pid_t, windowNumber: Int, zIndex: Int, frame: CGRect) {
        self.appPid = appPid
        self.runningApp = NSRunningApplication.init(processIdentifier: appPid)
        self.windowNumber = windowNumber
        self.zIndex = zIndex
        self.initialRect = frame
        self.newRect = frame
        
        // Get the app name and update placeholder window's title
        let appName = self.runningApp != nil ? self.runningApp!.localizedName ?? "Unknown App" : "Unknown App"
        self.placeholder.windowViewController.updateWindowTitleTextField(appName)
        
        // Update the placeholder window's icon
        let appIcon = self.runningApp != nil ? self.runningApp!.icon : nil
        self.placeholder.windowViewController.imageView.image = appIcon
        
        self.refreshRawAlignmentGuides()
        self.refreshResizeHandleRects()
    }
    
    func setFrame(_ newFrame: CGRect) {
        self.newRect = newFrame
        self.placeholder.window.setFrame(self.newRect, display: true, animate: false)
        self.placeholder.windowViewController.updateWindowSizeTextField(self.newRect)
        
        self.refreshRawAlignmentGuides()
        self.refreshResizeHandleRects()
    }
    
    func minimize() {
        self.minimized = true
    }
    
    func applyChanges() {
        if self.minimized {
            self.siWindow?.minimize()
            return
        }
        
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
    
    private func refreshResizeHandleRects() {
        self.resizeHandleRects = getWindowResizeHandleRects(self.newRect)
    }
    
    private func refreshRawAlignmentGuides() {
        self.rawAlignmentGuides = buildRawAlignmentGuides(ofWindow: self.newRect)
    }
    
    deinit {
        PlaceholderPool.shared.release(self.placeholder)
    }
}
