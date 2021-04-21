//
//  Activation.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 30.01.2021.
//  Copyright © 2021 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa


enum ActivationError: Error {
    case noScreens
    case unexpectedWindowListError
}

class Activation: GestureOverlayWindowDelegate {
    private let overlayWindows: [(bg: NSWindow, gesture: GestureOverlayWindow)]
    private let allWindows: [ActivationWindow] // ordered from frontmost to backmost
    private var selectedWindow: ActivationWindow? = nil
    
    // Window alignment stuff
    private var windowMovementProcessingState = WindowMovementProcessingState()
    
    // Window resizing stuff
    private var selectedWindowResizeHandle: WindowResizeHandleType?
    private var alignedWindowsToResizeSimultaneously = [(
        resizingEdge: WindowResizeHandleType,
        window: ActivationWindow
    )]()
    
    init() throws {
        let startTime = Date().timeIntervalSince1970
        
        // If there is no screen
        guard NSScreen.screens.indices.contains(0) else {
            throw ActivationError.noScreens
        }
        Logger.shared.log("Screen frames:", NSScreen.screens.map({ $0.frame }))
        
        // Get visible windows (its order is frontmost to backmost)
        let visibleWindowsInfo = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
        guard visibleWindowsInfo != nil else {
            throw ActivationError.unexpectedWindowListError
        }
        Logger.shared.log("CGWindowListCopyWindowInfo dump:", visibleWindowsInfo!)
        
        // Check the screens for having fullscreen'd window (or two windows in split-view).
        // We want to ignore the windows in a fullscreen'd screen.
        //
        // According to my observations, when a screen is in fullscreen mode, the following
        // entry is missing (for that screen's frame):
        //   kCGWindowLayer = "-2147483603";
        //   kCGWindowOwnerName = Finder;
        //
        // This is the only way that I can find to detect whether we're
        // activated in a fullscreen window(s) set-up.
        var isFullscreen = Array(repeating: true, count: NSScreen.screens.count)
        for windowInfo in visibleWindowsInfo as! [NSDictionary] {
            let windowLayer = windowInfo["kCGWindowLayer"] as? Int
            guard windowLayer != nil && windowLayer! < 0 else { continue }
            
            let windowOwnerName = windowInfo["kCGWindowOwnerName"] as? String
            guard windowOwnerName == "Finder" else { continue }
            
            let windowBounds = windowInfo["kCGWindowBounds"] as? NSDictionary
            guard windowBounds != nil else { continue }
            
            let windowWidth = windowBounds!["Width"] as? Int
            let windowHeight = windowBounds!["Height"] as? Int
            let windowX = windowBounds!["X"] as? Int
            let windowY = windowBounds!["Y"] as? Int // top-left origined
            guard windowWidth != nil else { continue }
            guard windowHeight != nil else { continue }
            guard windowX != nil else { continue }
            guard windowY != nil else { continue }
            
            let windowFrame = CGRect(
                x: windowX!,
                y: windowY!,
                width: windowWidth!,
                height: windowHeight!
            ).topLeft2bottomLeft(NSScreen.screens[0]) // convert to bottom-left
            
            // Find out the screen
            let screenIndex = NSScreen.screens.firstIndex { $0.frame == windowFrame }
            guard screenIndex != nil else { continue }
            isFullscreen[screenIndex!] = false
        }
        Logger.shared.log("Are screens displaying fullscreen'd window(s):", isFullscreen)
        
        // Get the visible windows
        var visibleWindows: [ActivationWindow] = []
        var zIndex = 0
        
        for windowInfo in visibleWindowsInfo as! [NSDictionary] {
            // Ignore dock, desktop, menubar stuff by just filtering
            // windows at the level zero -- https://stackoverflow.com/a/5286921
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
            
            let windowFrame = CGRect(x: windowX!, y: windowY!, width: windowWidth!, height: windowHeight!).topLeft2bottomLeft(NSScreen.screens[0])
            
            // If window is a fullscreen'd screen, ignore it
            let screenIndex = NSScreen.screens.firstIndex { $0.frame.contains(windowFrame) }
            if screenIndex != nil && isFullscreen[screenIndex!] == true { continue }
            
            let window = ActivationWindow(
                appPid: appPid!,
                windowNumber: windowNumber!,
                zIndex: zIndex,
                frame: windowFrame
            )
            visibleWindows.append(window)
            
            zIndex = zIndex - 1
        }
        
        // Filter out the windows of disabled apps
        self.allWindows = visibleWindows.filter({ (window) -> Bool in
            if window.runningApp == nil { return true }
            if window.runningApp!.bundleIdentifier == nil { return true }
            
            let isDisabled = Preferences.shared.disabledApps.contains(window.runningApp!.bundleIdentifier!)
            if isDisabled {
                Logger.shared.log("Ignoring a window of disabled app: \(window.runningApp!.bundleIdentifier!)")
            }
            
            return !isDisabled
        })
        
        // Setup bg & gesture overlay windows for each screen
        self.overlayWindows = NSScreen.screens.map({ _ in OverlayWindowPool.shared.acquire() })
        for (index, screen) in NSScreen.screens.enumerated() {
            let bgWindow = self.overlayWindows[index].bg
            bgWindow.setFrame(screen.frame, display: true, animate: false)
            bgWindow.makeKeyAndOrderFront(bgWindow)
        }
        for (index, screen) in NSScreen.screens.enumerated() {
            let gestureWindow = self.overlayWindows[index].gesture
            gestureWindow.setDelegate(self)
            gestureWindow.setFrame(screen.frame, display: true, animate: false)
            gestureWindow.makeKeyAndOrderFront(gestureWindow)
        }
        
        // Initial set-up & display placeholder windows
        let backmostGestureOverlayWindow = self.backmostGestureOverlayWindow
        self.allWindows.reversed().forEach { (window) in
            window.setFrame(window.newRect)
            window.placeholder.windowViewController.styleNormal()
            window.placeholder.window.order(.below, relativeTo: backmostGestureOverlayWindow.windowNumber)
            window.placeholder.windowViewController.toggleWindowSizeTextField(Preferences.shared.showWindowSize)
        }
        
        // Determine the window under cursor and select it initially
        let mouseX = NSEvent.mouseLocation.x
        let mouseY = NSEvent.mouseLocation.y // bottom-left origined
        let initialSelectedWindow = self.getFrontmostWindow(byCoordinate: (x: mouseX, y: mouseY))
        self.selectWindow(initialSelectedWindow)
        self.handleTooltipOnMouseMove()
        
        Logger.shared.log("Activation started w/ \(self.allWindows.count) window(s) in \((Date().timeIntervalSince1970 - startTime) * 1000)ms")
    }
    
    // expects bottom-left
    private func getFrontmostWindow(byCoordinate pos: (x: CGFloat, y: CGFloat)) -> ActivationWindow? {
        for window in self.allWindows {
            if window.minimized {
                continue
            }
            
            if window.newRect.contains(CGPoint(x: pos.x, y: pos.y)) {
                return window
            }
        }
        
        return nil
    }
    
    var backmostGestureOverlayWindow: GestureOverlayWindow {
        return self.overlayWindows.map({ $0.gesture }).min { a,b in a.orderedIndex < b.orderedIndex }!
    }
    
    private func selectWindow(_ newWindow: ActivationWindow?) {
        self.selectedWindow?.placeholder.windowViewController.styleNormal()
        newWindow?.placeholder.windowViewController.styleSelected()
        
        // If there are multiple screens, only the frontmost gesture overlay window
        // recieves magnify events. I guess this is one of macOS's restrictions and
        // we can't do anything. However, the only thing we can do is that we can set
        // the gesture overlay window in the selected window's screen as the frontmost
        // window.
        if let newScreen = newWindow?.placeholder.window.screen {
            let overlayWindow = self.overlayWindows.first { (item) -> Bool in
                return item.gesture.screen === newScreen
            }
            overlayWindow?.gesture.makeKeyAndOrderFront(overlayWindow?.gesture)
        }
        
        if self.selectedWindow !== newWindow {
            self.windowMovementProcessingState.reset()
        }
        
        self.selectedWindow = newWindow
    }
    
    // Builds alignment guides for the selected window.
    private func buildAlignmentGuidesForSelectedWindow() -> WindowAlignmentGuides {
        let otherWindows = self.allWindows.filter { (window) -> Bool in
            // Ignore minimized windows
            if window.minimized { return false }
            
            // Ignore the selected window
            if window.windowNumber == self.selectedWindow?.windowNumber { return false }
            
            // Ignore the windows that we resize simultaneously
            let isResizingSimultaneously = self.alignedWindowsToResizeSimultaneously.contains { (windowToResizeSimultaneously) -> Bool in
                return windowToResizeSimultaneously.window.windowNumber == window.windowNumber
            }
            if isResizingSimultaneously { return false }
            
            return true
        }
        
        return buildActualAlignmentGuides(otherWindows: otherWindows, addScreenEdges: true)
    }
    
    func onKeyDown(pressedKeys: Set<UInt16>) {
        let isLeftKeyPressed = pressedKeys.contains(123)
        let isRightKeyPressed = pressedKeys.contains(124)
        let isDownKeyPressed = pressedKeys.contains(125)
        let isUpKeyPressed = pressedKeys.contains(126)
        let isEnterKeyPressed = pressedKeys.contains(36)
        
        if isLeftKeyPressed && isUpKeyPressed { self.onSwipeGesture(type: .SWIPE_TOP_LEFT) }
        else if isLeftKeyPressed && isDownKeyPressed { self.onSwipeGesture(type: .SWIPE_BOTTOM_LEFT) }
        else if isRightKeyPressed && isUpKeyPressed { self.onSwipeGesture(type: .SWIPE_TOP_RIGHT) }
        else if isRightKeyPressed && isDownKeyPressed { self.onSwipeGesture(type: .SWIPE_BOTTOM_RIGHT) }
        else if isLeftKeyPressed { self.onSwipeGesture(type: .SWIPE_LEFT) }
        else if isRightKeyPressed { self.onSwipeGesture(type: .SWIPE_RIGHT) }
        else if isUpKeyPressed { self.onSwipeGesture(type: .SWIPE_TOP) }
        else if isDownKeyPressed { self.onSwipeGesture(type: .SWIPE_BOTTOM) }
        else if isEnterKeyPressed { self.onDoubleClickGesture() }
    }
    
    func onTrackpadScrollGesture(delta: (x: CGFloat, y: CGFloat, timestamp: Double)) {
        guard self.selectedWindow != nil else { return }
        guard self.selectedWindow!.siWindow?.isMovable() ?? false else { return }
        
        let rect = self.selectedWindow!.newRect
        let newMovement = processWindowMovementConsideringAlignment(
            windowRect: self.selectedWindow!.newRect,
            alignmentGuides: self.buildAlignmentGuidesForSelectedWindow(),
            state: self.windowMovementProcessingState,
            movement: (x: -delta.x, y: delta.y),
            timestamp: delta.timestamp
        )
        let newRect = CGRect(
            x: rect.origin.x + newMovement.x,
            y: rect.origin.y + newMovement.y,
            width: rect.width,
            height: rect.height
        )
        self.selectedWindow!.setFrame(newRect)
        
        NSCursor.arrow.set()
        self.selectedWindowResizeHandle = nil
        self.alignedWindowsToResizeSimultaneously.forEach { (item) in
            item.window.placeholder.windowViewController.styleNormal()
        }
        self.alignedWindowsToResizeSimultaneously = []
    }
    
    func onTrackpadScrollGestureBegan() {
        self.windowMovementProcessingState.reset()
    }
    
    func onTrackpadScrollGestureEnded() {
        self.windowMovementProcessingState.reset()
    }
    
    func onSwipeGesture(type: SwipeGestureType) {
        guard self.selectedWindow != nil else { return }
        let placeholderWindowScreen = self.selectedWindow!.placeholder.window.screen
        guard placeholderWindowScreen != nil else { return }
        
        let screenNumber = placeholderWindowScreen!.getScreenNumber()
        guard screenNumber != nil else { return }
        let actions = Preferences.shared.getCustomActions(forScreenNumber: screenNumber!)
        
        let isResizable = self.selectedWindow!.siWindow?.isResizable() ?? false
        let isMovable = self.selectedWindow!.siWindow?.isMovable() ?? false
        
        switch (type) {
        case .SWIPE_TOP:
            if isResizable {
                let newRect = self.selectedWindow!.newRect.resizeBy(
                    screen: placeholderWindowScreen!,
                    ratio: (
                        width: CGFloat(actions["top"]![0]),
                        height: CGFloat(actions["top"]![1])
                    )
                )
                self.selectedWindow!.setFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindow!.newRect.setPositionOf(
                    anchorPoint: .TOP_CENTER,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .TOP_CENTER)
                )
                self.selectedWindow!.setFrame(newRect)
            }
        case .SWIPE_TOP_RIGHT:
            if isResizable {
                let newRect = self.selectedWindow!.newRect.resizeBy(
                    screen: placeholderWindowScreen!,
                    ratio: (
                        width: CGFloat(actions["topRight"]![0]),
                        height: CGFloat(actions["topRight"]![1])
                    )
                )
                self.selectedWindow!.setFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindow!.newRect.setPositionOf(
                    anchorPoint: .TOP_RIGHT,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .TOP_RIGHT)
                )
                self.selectedWindow!.setFrame(newRect)
            }
        case .SWIPE_RIGHT:
            if isResizable {
                let newRect = self.selectedWindow!.newRect.resizeBy(
                    screen: placeholderWindowScreen!,
                    ratio: (
                        width: CGFloat(actions["right"]![0]),
                        height: CGFloat(actions["right"]![1])
                    )
                )
                self.selectedWindow!.setFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindow!.newRect.setPositionOf(
                    anchorPoint: .RIGHT_CENTER,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .RIGHT_CENTER)
                )
                self.selectedWindow!.setFrame(newRect)
            }
        case .SWIPE_BOTTOM_RIGHT:
            if isResizable {
                let newRect = self.selectedWindow!.newRect.resizeBy(
                    screen: placeholderWindowScreen!,
                    ratio: (
                        width: CGFloat(actions["bottomRight"]![0]),
                        height: CGFloat(actions["bottomRight"]![1])
                    )
                )
                self.selectedWindow!.setFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindow!.newRect.setPositionOf(
                    anchorPoint: .BOTTOM_RIGHT,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .BOTTOM_RIGHT)
                )
                self.selectedWindow!.setFrame(newRect)
            }
        case .SWIPE_BOTTOM:
            if isResizable {
                let newRect = self.selectedWindow!.newRect.resizeBy(
                    screen: placeholderWindowScreen!,
                    ratio: (
                        width: CGFloat(actions["bottom"]![0]),
                        height: CGFloat(actions["bottom"]![1])
                    )
                )
                self.selectedWindow!.setFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindow!.newRect.setPositionOf(
                    anchorPoint: .BOTTOM_CENTER,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .BOTTOM_CENTER)
                )
                self.selectedWindow!.setFrame(newRect)
            }
        case .SWIPE_BOTTOM_LEFT:
            if isResizable {
                let newRect = self.selectedWindow!.newRect.resizeBy(
                    screen: placeholderWindowScreen!,
                    ratio: (
                        width: CGFloat(actions["bottomLeft"]![0]),
                        height: CGFloat(actions["bottomLeft"]![1])
                    )
                )
                self.selectedWindow!.setFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindow!.newRect.setPositionOf(
                    anchorPoint: .BOTTOM_LEFT,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .BOTTOM_LEFT)
                )
                self.selectedWindow!.setFrame(newRect)
            }
        case .SWIPE_LEFT:
            if isResizable {
                let newRect = self.selectedWindow!.newRect.resizeBy(
                    screen: placeholderWindowScreen!,
                    ratio: (
                        width: CGFloat(actions["left"]![0]),
                        height: CGFloat(actions["left"]![1])
                    )
                )
                self.selectedWindow!.setFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindow!.newRect.setPositionOf(
                    anchorPoint: .LEFT_CENTER,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .LEFT_CENTER)
                )
                self.selectedWindow!.setFrame(newRect)
            }
        case .SWIPE_TOP_LEFT:
            if isResizable {
                let newRect = self.selectedWindow!.newRect.resizeBy(
                    screen: placeholderWindowScreen!,
                    ratio: (
                        width: CGFloat(actions["topLeft"]![0]),
                        height: CGFloat(actions["topLeft"]![1])
                    )
                )
                self.selectedWindow!.setFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindow!.newRect.setPositionOf(
                    anchorPoint: .TOP_LEFT,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .TOP_LEFT)
                )
                self.selectedWindow!.setFrame(newRect)
            }
        }
        
        NSCursor.arrow.set()
        self.selectedWindowResizeHandle = nil
        self.alignedWindowsToResizeSimultaneously.forEach { (item) in
            item.window.placeholder.windowViewController.styleNormal()
        }
        self.alignedWindowsToResizeSimultaneously = []
    }
    
    func onMagnifyGesture(factor: (width: CGFloat, height: CGFloat)) {
        guard self.selectedWindow != nil else { return }
        let placeholderWindowScreen = self.selectedWindow!.placeholder.window.screen
        guard placeholderWindowScreen != nil else { return }
        guard self.selectedWindow!.siWindow?.isResizable() ?? false else { return }
        
        let newRect = self.selectedWindow!.newRect
            .resizeBy(factor: factor)
            .fitInVisibleFrame(ofScreen: placeholderWindowScreen!)
        self.selectedWindow!.setFrame(newRect)
        
        NSCursor.arrow.set()
        self.selectedWindowResizeHandle = nil
        self.alignedWindowsToResizeSimultaneously.forEach { (item) in
            item.window.placeholder.windowViewController.styleNormal()
        }
        self.alignedWindowsToResizeSimultaneously = []
    }
    
    func onMouseScrollGesture(delta: (x: CGFloat, y: CGFloat)) {
        guard self.selectedWindow != nil else { return }
        let placeholderWindowScreen = self.selectedWindow!.placeholder.window.screen
        guard placeholderWindowScreen != nil else { return }
        guard self.selectedWindow!.siWindow?.isResizable() ?? false else { return }
        
        let newRect = self.selectedWindow!.newRect
            .resizeBy(delta: (
                x: delta.y * CGFloat(Preferences.shared.mouseScrollWheelToResizeSensitivity), // ignore delta.x
                y: delta.y * CGFloat(Preferences.shared.mouseScrollWheelToResizeSensitivity)
            ))
            .fitInVisibleFrame(ofScreen: placeholderWindowScreen!)
        self.selectedWindow!.setFrame(newRect)
        
        NSCursor.arrow.set()
        self.selectedWindowResizeHandle = nil
        self.alignedWindowsToResizeSimultaneously.forEach { (item) in
            item.window.placeholder.windowViewController.styleNormal()
        }
        self.alignedWindowsToResizeSimultaneously = []
    }
    
    func onDoubleClickGesture() {
        guard self.selectedWindow != nil else { return }
        let placeholderWindowScreen = self.selectedWindow!.placeholder.window.screen
        guard placeholderWindowScreen != nil else { return }
        
        let screenNumber = placeholderWindowScreen!.getScreenNumber()
        guard screenNumber != nil else { return }
        let actions = Preferences.shared.getCustomActions(forScreenNumber: screenNumber!)
        
        let isResizable = self.selectedWindow!.siWindow?.isResizable() ?? false
        let isMovable = self.selectedWindow!.siWindow?.isMovable() ?? false
        
        var newRect = self.selectedWindow!.newRect
        
        if isResizable {
            newRect = newRect.resizeBy(
                screen: placeholderWindowScreen!,
                ratio: (
                    width: CGFloat(actions["dblClick"]![0]),
                    height: CGFloat(actions["dblClick"]![1])
                )
            )
        }
        
        if isMovable {
            newRect = newRect.setPositionOf(
                anchorPoint: .CENTER,
                toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .CENTER)
            )
        }
        
        if self.selectedWindow!.previousRectBeforeDblClick != nil &&
            self.selectedWindow!.newRect == newRect {
            self.selectedWindow!.setFrame(self.selectedWindow!.previousRectBeforeDblClick!)
            self.selectedWindow!.previousRectBeforeDblClick = nil
        } else {
            self.selectedWindow!.previousRectBeforeDblClick = self.selectedWindow!.newRect
            self.selectedWindow!.setFrame(newRect)
        }
        
        NSCursor.arrow.set()
        self.selectedWindowResizeHandle = nil
        self.alignedWindowsToResizeSimultaneously.forEach { (item) in
            item.window.placeholder.windowViewController.styleNormal()
        }
        self.alignedWindowsToResizeSimultaneously = []
    }
    
    func onRightClickGesture() {
        guard self.selectedWindow != nil else { return }
        
        // Minimize the window
        self.selectedWindow!.minimize()
        self.selectedWindow!.placeholder.window.orderOut(self.selectedWindow!.placeholder.window)
        
        // Update selected window
        let mouseX = NSEvent.mouseLocation.x
        let mouseY = NSEvent.mouseLocation.y // bottom-left origined
        let selectedWindow = self.getFrontmostWindow(byCoordinate: (x: mouseX, y: mouseY))
        self.selectWindow(selectedWindow)
        
    }
    
    func onMouseDragGesture(position: (x: CGFloat, y: CGFloat), delta: (x: CGFloat, y: CGFloat, timestamp: Double)) {
        guard self.selectedWindow != nil else { return }
        guard self.selectedWindow!.siWindow?.isMovable() ?? false else { return }
        
        if self.selectedWindowResizeHandle == nil {
            // move window
            let rect = self.selectedWindow!.newRect
            let newMovement = processWindowMovementConsideringAlignment(
                windowRect: self.selectedWindow!.newRect,
                alignmentGuides: self.buildAlignmentGuidesForSelectedWindow(),
                state: self.windowMovementProcessingState,
                movement: (x: -delta.x, y: delta.y),
                timestamp: delta.timestamp
            )
            let newRect = CGRect(
                x: rect.origin.x + newMovement.x,
                y: rect.origin.y + newMovement.y,
                width: rect.width,
                height: rect.height
            )
            self.selectedWindow!.setFrame(newRect)
        } else {
            // resize window
            let newMovement = processWindowMovementConsideringAlignment(
                windowRect: self.selectedWindow!.newRect,
                alignmentGuides: self.buildAlignmentGuidesForSelectedWindow(),
                state: self.windowMovementProcessingState,
                movement: (x: -delta.x, y: delta.y),
                timestamp: delta.timestamp
            )
            let newRect = self.selectedWindow!.newRect.resizeBy(
                handle: self.selectedWindowResizeHandle!,
                delta: newMovement
            )
            self.selectedWindow!.setFrame(newRect)
            
            self.alignedWindowsToResizeSimultaneously.forEach { (item) in
                let newRect = item.window.newRect.resizeBy(
                    handle: item.resizingEdge,
                    delta: newMovement
                )
                item.window.setFrame(newRect)
            }
        }
        
        self.handleTooltipOnMouseMove()
    }
    
    func onMouseUpGesture() {
        self.windowMovementProcessingState.reset()
    }
    
    func onMouseMoveGesture(position: (x: CGFloat, y: CGFloat)) {
        let mouseX = NSEvent.mouseLocation.x
        let mouseY = NSEvent.mouseLocation.y // bottom-left origined
        
        let windowUnderCursor = self.allWindows.first { (window) -> Bool in
            return !window.minimized && window.newRect.contains(CGPoint(x: mouseX, y: mouseY))
        }
        
        self.selectWindow(windowUnderCursor)
        
        self.selectedWindowResizeHandle = nil
        self.alignedWindowsToResizeSimultaneously.forEach { (item) in
            item.window.placeholder.windowViewController.styleNormal()
        }
        self.alignedWindowsToResizeSimultaneously = []
        
        var cursor = NSCursor.arrow
        
        if self.selectedWindow != nil {
            let resizeHandleUnderCursor = self.selectedWindow!.resizeHandleRects.first { (resizeHandle) -> Bool in
                return resizeHandle.rect.contains(CGPoint(x: mouseX, y: mouseY))
            }
            
            if resizeHandleUnderCursor != nil {
                let otherWindows = self.allWindows.filter {
                    !$0.minimized && $0.windowNumber != self.selectedWindow!.windowNumber
                }
                
                switch resizeHandleUnderCursor!.type {
                case .TOP:
                    cursor = NSCursor.resizeUpDown
                    self.selectedWindowResizeHandle = .TOP
                    let alignedWindows = getAlignedWindowsToResizeSimultaneously(
                        window: self.selectedWindow!,
                        resizeHandle: .TOP,
                        otherWindows: otherWindows
                    )
                    self.alignedWindowsToResizeSimultaneously = alignedWindows.map({ (window) -> (resizingEdge: WindowResizeHandleType, window: ActivationWindow) in
                        return (
                            resizingEdge: .BOTTOM,
                            window: window
                        )
                    })
                case .TOP_LEFT:
                    cursor = NSCursor.resizeNorthWestSouthEast
                    self.selectedWindowResizeHandle = .TOP_LEFT
                case .LEFT:
                    cursor = NSCursor.resizeLeftRight
                    self.selectedWindowResizeHandle = .LEFT
                    let alignedWindows = getAlignedWindowsToResizeSimultaneously(
                        window: self.selectedWindow!,
                        resizeHandle: .LEFT,
                        otherWindows: otherWindows
                    )
                    self.alignedWindowsToResizeSimultaneously = alignedWindows.map({ (window) -> (resizingEdge: WindowResizeHandleType, window: ActivationWindow) in
                        return (
                            resizingEdge: .RIGHT,
                            window: window
                        )
                    })
                case .BOTTOM_LEFT:
                    cursor = NSCursor.resizeNorthEastSouthWest
                    self.selectedWindowResizeHandle = .BOTTOM_LEFT
                case .BOTTOM:
                    cursor = NSCursor.resizeUpDown
                    self.selectedWindowResizeHandle = .BOTTOM
                    let alignedWindows = getAlignedWindowsToResizeSimultaneously(
                        window: self.selectedWindow!,
                        resizeHandle: .BOTTOM,
                        otherWindows: otherWindows
                    )
                    self.alignedWindowsToResizeSimultaneously = alignedWindows.map({ (window) -> (resizingEdge: WindowResizeHandleType, window: ActivationWindow) in
                        return (
                            resizingEdge: .TOP,
                            window: window
                        )
                    })
                case .BOTTOM_RIGHT:
                    cursor = NSCursor.resizeNorthWestSouthEast
                    self.selectedWindowResizeHandle = .BOTTOM_RIGHT
                case .RIGHT:
                    cursor = NSCursor.resizeLeftRight
                    self.selectedWindowResizeHandle = .RIGHT
                    let alignedWindows = getAlignedWindowsToResizeSimultaneously(
                        window: self.selectedWindow!,
                        resizeHandle: .RIGHT,
                        otherWindows: otherWindows
                    )
                    self.alignedWindowsToResizeSimultaneously = alignedWindows.map({ (window) -> (resizingEdge: WindowResizeHandleType, window: ActivationWindow) in
                        return (
                            resizingEdge: .LEFT,
                            window: window
                        )
                    })
                case .TOP_RIGHT:
                    cursor = NSCursor.resizeNorthEastSouthWest
                    self.selectedWindowResizeHandle = .TOP_RIGHT
                }
            }
        }
        
        cursor.set()
        
        self.alignedWindowsToResizeSimultaneously.forEach { (item) in
            item.window.placeholder.windowViewController.styleSelected()
        }
        
        self.handleTooltipOnMouseMove()
    }
    
    func handleTooltipOnMouseMove() {
        // If there is no selected window, hide all the tooltips
        guard self.selectedWindow != nil else {
            self.overlayWindows.forEach { $0.gesture.tooltipLabel.isHidden = true }
            return
        }
        
        self.overlayWindows.forEach { (item) in
            let doesContainMouse = item.gesture.frame.contains(NSEvent.mouseLocation)
            
            // If mouse is not this overlay, hide the tooltip
            if !doesContainMouse {
                item.gesture.tooltipLabel.isHidden = true
                return
            }
            
            // Try to get app name of selected window
            // If we could not get it, hide tooltip
            let appName = self.selectedWindow!.runningApp?.localizedName
            if appName == nil {
                item.gesture.tooltipLabel.isHidden = true
                return
            }
            
            // If center of the selected window is visible,
            // no need to show the tooltip
            let centerPoint = CGPoint(
                x: self.selectedWindow!.newRect.origin.x + (self.selectedWindow!.newRect.size.width / 2),
                y: self.selectedWindow!.newRect.origin.y + (self.selectedWindow!.newRect.size.height / 2)
            )
            let firstContainerWindow = self.allWindows.first { !$0.minimized && $0.newRect.contains(centerPoint) }
            if firstContainerWindow?.windowNumber == self.selectedWindow!.windowNumber {
                item.gesture.tooltipLabel.isHidden = true
                return
            }

            item.gesture.tooltipLabel.stringValue = appName!
            item.gesture.tooltipLabel.isHidden = false
            
            item.gesture.tooltipLabel.sizeToFit()
            let tooltipWidth = item.gesture.tooltipLabel.frame.size.width + 5 // 5 is for padding
            let tooltipHeight = 17 as CGFloat
            
            if NSEvent.mouseLocation.x <= item.gesture.frame.origin.x + item.gesture.frame.size.width - tooltipWidth {
                // Align to left
                item.gesture.tooltipLabel.alignment = .center
                item.gesture.tooltipLabel.frame = CGRect(
                    x: NSEvent.mouseLocation.x + 15,
                    y: NSEvent.mouseLocation.y - 16,
                    width: tooltipWidth,
                    height: tooltipHeight
                )
            } else {
                // Align to right
                item.gesture.tooltipLabel.alignment = .center
                item.gesture.tooltipLabel.frame = CGRect(
                    x: NSEvent.mouseLocation.x - 10 - tooltipWidth,
                    y: NSEvent.mouseLocation.y - 16,
                    width: tooltipWidth,
                    height: tooltipHeight
                )
            }
        }
    }
    
    func complete() {
        // When applying chages and if a window is minimized,
        // `applyChanges()` blocks the thread until minimize animation
        // is complete. This delays the removal of all the overlay
        // stuff. Let the apply minimized window changes at the end.
        var minimizedWindows = [ActivationWindow]()
        
        self.allWindows.forEach { (window) in
            if window.minimized {
                minimizedWindows.append(window)
            } else {
                window.applyChanges()
            }
            
            window.placeholder.window.orderOut(window.placeholder.window)
        }
        self.overlayWindows.forEach { (item) in
            item.bg.orderOut(item.bg)
            item.gesture.tooltipLabel.isHidden = true
            item.gesture.orderOut(item.gesture)
            item.gesture.clear()
        }
        
        NSCursor.arrow.set()
        
        // If we don't use dispatch queue, window minimize animation
        // still blocks :/
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            minimizedWindows.forEach { (window) in
                window.applyChanges()
            }
        }
    }
    
    func abort() {
        self.allWindows.forEach { (window) in
            window.placeholder.window.orderOut(window.placeholder.window)
        }
        self.overlayWindows.forEach { (item) in
            item.bg.orderOut(item.bg)
            item.gesture.tooltipLabel.isHidden = true
            item.gesture.orderOut(item.gesture)
            item.gesture.clear()
        }
        
        NSCursor.arrow.set()
    }
    
    deinit {
        self.overlayWindows.forEach { (item) in
            OverlayWindowPool.shared.release(item)
        }
    }
}
