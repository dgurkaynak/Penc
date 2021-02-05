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
    // overlay windows
    private let overlayWindows: [(bg: NSWindow, gesture: GestureOverlayWindow)]

    private let allWindows: [ActivationWindow] // ordered from frontmost to backmost
    private var selectedWindow: ActivationWindow? = nil
    
    // TODO: let olabilir mi
    private var windowAlignmentManager: WindowAlignmentManager? = nil
    
    // resizing stuff
    private var activeResizeHandle: WindowResizeHandleType?
    private var activeAlignedWindowsToResizeSimultaneously = [(
        resizingEdge: WindowResizeHandleType,
        window: ActivationWindow
    )]()
    
    init() throws {
        // If there is no screen
        guard NSScreen.screens.indices.contains(0) else {
            throw ActivationError.noScreens
        }
        
        // Get visible windows (its order is frontmost to backmost)
        let visibleWindowsInfo = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
        guard visibleWindowsInfo != nil else {
            throw ActivationError.unexpectedWindowListError
        }
        
        var visibleWindows: [ActivationWindow] = []
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
            let window = ActivationWindow(
                appPid: appPid!,
                windowNumber: windowNumber!,
                zIndex: zIndex,
                frame: rect
            )
            visibleWindows.append(window)
            
            zIndex = zIndex - 1
        }
        
        // Filter out the windows of disabled apps
        self.allWindows = visibleWindows.filter({ (window) -> Bool in
            if window.runningApp == nil { return true }
            if window.runningApp!.bundleIdentifier == nil { return true }
            return !Preferences.shared.disabledApps.contains(window.runningApp!.bundleIdentifier!)
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
        }
        
        // Determine the window under cursor and select it initially
        let mouseX = NSEvent.mouseLocation.x
        let mouseY = NSEvent.mouseLocation.y // bottom-left origined
        let initialSelectedWindow = self.getFrontmostWindow(byCoordinate: (x: mouseX, y: mouseY))
        self.selectWindow(initialSelectedWindow)
    }
    
    // expects bottom-left
    private func getFrontmostWindow(byCoordinate pos: (x: CGFloat, y: CGFloat)) -> ActivationWindow? {
        for window in self.allWindows {
            if window.newRect.contains(CGPoint(x: pos.x, y: pos.y)) {
                return window
            }
        }
        
        return nil
    }
    
    // TODO: Test this
    var backmostGestureOverlayWindow: GestureOverlayWindow {
        return self.overlayWindows.map({ $0.gesture }).min { a,b in a.orderedIndex < b.orderedIndex }!
    }
    
    private func selectWindow(_ newWindow: ActivationWindow?) {
        // If trying to select already-selected one, NOOP
        // TODO: Hata var, rapid sekilde change yaptiginda selected window normal bi sekilde kalabiliyor
//        if newWindow != nil &&
//            self.selectedWindow != nil &&
//            newWindow!.windowNumber == self.selectedWindow!.windowNumber {
//            return
//        }
        
        // If there is already selected one, update its style
        if self.selectedWindow != nil {
            self.selectedWindow!.placeholder.windowViewController.styleNormal()
        }
        
        // If no window is selected, early terminate
        if newWindow == nil {
            self.selectedWindow = nil
            return
        }
        
        newWindow!.placeholder.windowViewController.styleSelected()
        self.selectedWindow = newWindow
        
        // If there are multiple screens, only the frontmost gesture overlay window
        // recieves magnify events. I guess this is one of macOS's restrictions and
        // we can't do anything. However, the only thing we can do is that we can set
        // the gesture overlay window in the selected window's screen as the frontmost
        // window.
        let newScreen = newWindow!.placeholder.window.screen
        if newScreen != nil {
            let overlayWindow = self.overlayWindows.first { (item) -> Bool in
                return item.gesture.screen === newScreen
            }
            overlayWindow?.gesture.makeKeyAndOrderFront(overlayWindow?.gesture)
        }
        
        // TODO
        self.reloadWindowAlignmentManager()
    }
    
    // If the selected window is changed, or one of the other window's
    // frame or zIndex is changed, we need to re-calculate window alignment
    // targets in the WindowAlignmentManager. The only optimization we can
    // do is: when changing the frame of selected window, calling
    // self.windowAlignmentManager.updateSelectedWindowFrame(_: CGRect) method,
    // instead of a hard reload.
    private func reloadWindowAlignmentManager() {
        guard self.selectedWindow != nil else { return }

        var otherWindowsDictionary = [Int: ActivationWindow]()
        self.allWindows.forEach { (window) in
            guard window.windowNumber != self.selectedWindow!.windowNumber else { return }
            otherWindowsDictionary[window.windowNumber] = window
        }
        self.windowAlignmentManager = WindowAlignmentManager(
            selectedWindowFrame: self.selectedWindow!.newRect,
            otherWindows: otherWindowsDictionary
        )
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
    
    func onScrollGesture(delta: (x: CGFloat, y: CGFloat, timestamp: Double)) {
        guard self.selectedWindow != nil else { return }
        guard self.selectedWindow!.siWindow?.isMovable() ?? false else { return }
        guard self.windowAlignmentManager != nil else { return }
        
        let rect = self.selectedWindow!.newRect
        let newMovement = self.windowAlignmentManager!.map(movement: (x: -delta.x, y: delta.y), timestamp: delta.timestamp)
        let newRect = CGRect(
            x: rect.origin.x + newMovement.x,
            y: rect.origin.y + newMovement.y,
            width: rect.width,
            height: rect.height
        )
        self.selectedWindow!.setFrame(newRect)
        self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
        
        NSCursor.arrow.set()
        self.activeResizeHandle = nil
        self.activeAlignedWindowsToResizeSimultaneously.forEach { (item) in
            item.window.placeholder.windowViewController.styleNormal()
        }
        self.activeAlignedWindowsToResizeSimultaneously = []
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
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindow!.newRect.setPositionOf(
                    anchorPoint: .TOP_CENTER,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .TOP_CENTER)
                )
                self.selectedWindow!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
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
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindow!.newRect.setPositionOf(
                    anchorPoint: .TOP_RIGHT,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .TOP_RIGHT)
                )
                self.selectedWindow!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
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
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindow!.newRect.setPositionOf(
                    anchorPoint: .RIGHT_CENTER,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .RIGHT_CENTER)
                )
                self.selectedWindow!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
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
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindow!.newRect.setPositionOf(
                    anchorPoint: .BOTTOM_RIGHT,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .BOTTOM_RIGHT)
                )
                self.selectedWindow!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
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
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindow!.newRect.setPositionOf(
                    anchorPoint: .BOTTOM_CENTER,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .BOTTOM_CENTER)
                )
                self.selectedWindow!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
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
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindow!.newRect.setPositionOf(
                    anchorPoint: .BOTTOM_LEFT,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .BOTTOM_LEFT)
                )
                self.selectedWindow!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
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
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindow!.newRect.setPositionOf(
                    anchorPoint: .LEFT_CENTER,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .LEFT_CENTER)
                )
                self.selectedWindow!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
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
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindow!.newRect.setPositionOf(
                    anchorPoint: .TOP_LEFT,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .TOP_LEFT)
                )
                self.selectedWindow!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
        }
        
        NSCursor.arrow.set()
        self.activeResizeHandle = nil
        self.activeAlignedWindowsToResizeSimultaneously.forEach { (item) in
            item.window.placeholder.windowViewController.styleNormal()
        }
        self.activeAlignedWindowsToResizeSimultaneously = []
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
        self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
        
        NSCursor.arrow.set()
        self.activeResizeHandle = nil
        self.activeAlignedWindowsToResizeSimultaneously.forEach { (item) in
            item.window.placeholder.windowViewController.styleNormal()
        }
        self.activeAlignedWindowsToResizeSimultaneously = []
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
            self.windowAlignmentManager?.updateSelectedWindowFrame(self.selectedWindow!.previousRectBeforeDblClick!)
            self.selectedWindow!.previousRectBeforeDblClick = nil
        } else {
            self.selectedWindow!.previousRectBeforeDblClick = self.selectedWindow!.newRect
            self.selectedWindow!.setFrame(newRect)
            self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
        }
        
        NSCursor.arrow.set()
        self.activeResizeHandle = nil
        self.activeAlignedWindowsToResizeSimultaneously.forEach { (item) in
            item.window.placeholder.windowViewController.styleNormal()
        }
        self.activeAlignedWindowsToResizeSimultaneously = []
    }
    
    func onMouseDragGesture(position: (x: CGFloat, y: CGFloat), delta: (x: CGFloat, y: CGFloat), timestamp: Double) {
        guard self.selectedWindow != nil else { return }
        guard self.selectedWindow!.siWindow?.isMovable() ?? false else { return }
        guard self.windowAlignmentManager != nil else { return }
        
        if self.activeResizeHandle == nil {
            // move window
            let rect = self.selectedWindow!.newRect
            let newMovement = self.windowAlignmentManager!.map(movement: (x: -delta.x, y: delta.y), timestamp: timestamp)
            let newRect = CGRect(
                x: rect.origin.x + newMovement.x,
                y: rect.origin.y + newMovement.y,
                width: rect.width,
                height: rect.height
            )
            self.selectedWindow!.setFrame(newRect)
            self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
        } else {
            // resize window
//            let newMovement = self.windowAlignmentManager!.map(movement: (x: -delta.x, y: delta.y), timestamp: timestamp)
            let newMovement = (x: -delta.x, y: delta.y)
            let newRect = self.selectedWindow!.newRect.resizeBy(
                handle: self.activeResizeHandle!,
                delta: newMovement
            )
            self.selectedWindow!.setFrame(newRect)
            self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            
            self.activeAlignedWindowsToResizeSimultaneously.forEach { (item) in
                let newRect = item.window.newRect.resizeBy(
                    handle: item.resizingEdge,
                    delta: newMovement
                )
                item.window.setFrame(newRect)
                // TODO: What about self.windowAlignmentManager
            }
        }
    }
    
    func onMouseMoveGesture(position: (x: CGFloat, y: CGFloat)) {
        // TODO: Should we throttle this?
        
        let mouseX = NSEvent.mouseLocation.x
        let mouseY = NSEvent.mouseLocation.y // bottom-left origined
        
        let windowUnderCursor = self.allWindows.first { (window) -> Bool in
            return window.newRect.contains(CGPoint(x: mouseX, y: mouseY))
        }
    
        // TODO: If windowUnderCursor === self.selectedWindow,
        // do we need to select window again?
        // Update from 5th Feb 2021 -- We did the NOOP if already selected one, test it
        
        self.selectWindow(windowUnderCursor)
        
        self.activeResizeHandle = nil
        self.activeAlignedWindowsToResizeSimultaneously.forEach { (item) in
            item.window.placeholder.windowViewController.styleNormal()
        }
        self.activeAlignedWindowsToResizeSimultaneously = []
        
        var cursor = NSCursor.arrow
        
        if self.selectedWindow != nil {
            let resizeHandleUnderCursor = self.selectedWindow!.resizeHandleRects.first { (resizeHandle) -> Bool in
                return resizeHandle.rect.contains(CGPoint(x: mouseX, y: mouseY))
            }
            
            if resizeHandleUnderCursor != nil {
                switch resizeHandleUnderCursor!.type {
                case .TOP:
                    cursor = NSCursor.resizeUpDown
                    self.activeResizeHandle = .TOP
                    let alignedWindows = getAlignedWindowsToResizeSimultaneously(
                        window: self.selectedWindow!,
                        resizeHandle: .TOP,
                        allWindows: self.allWindows
                    )
                    self.activeAlignedWindowsToResizeSimultaneously = alignedWindows.map({ (window) -> (resizingEdge: WindowResizeHandleType, window: ActivationWindow) in
                        return (
                            resizingEdge: .BOTTOM,
                            window: window
                        )
                    })
                case .TOP_LEFT:
                    cursor = NSCursor.resizeNorthWestSouthEast
                    self.activeResizeHandle = .TOP_LEFT
                case .LEFT:
                    cursor = NSCursor.resizeLeftRight
                    self.activeResizeHandle = .LEFT
                    let alignedWindows = getAlignedWindowsToResizeSimultaneously(
                        window: self.selectedWindow!,
                        resizeHandle: .LEFT,
                        allWindows: self.allWindows
                    )
                    self.activeAlignedWindowsToResizeSimultaneously = alignedWindows.map({ (window) -> (resizingEdge: WindowResizeHandleType, window: ActivationWindow) in
                        return (
                            resizingEdge: .RIGHT,
                            window: window
                        )
                    })
                case .BOTTOM_LEFT:
                    cursor = NSCursor.resizeNorthEastSouthWest
                    self.activeResizeHandle = .BOTTOM_LEFT
                case .BOTTOM:
                    cursor = NSCursor.resizeUpDown
                    self.activeResizeHandle = .BOTTOM
                    let alignedWindows = getAlignedWindowsToResizeSimultaneously(
                        window: self.selectedWindow!,
                        resizeHandle: .BOTTOM,
                        allWindows: self.allWindows
                    )
                    self.activeAlignedWindowsToResizeSimultaneously = alignedWindows.map({ (window) -> (resizingEdge: WindowResizeHandleType, window: ActivationWindow) in
                        return (
                            resizingEdge: .TOP,
                            window: window
                        )
                    })
                case .BOTTOM_RIGHT:
                    cursor = NSCursor.resizeNorthWestSouthEast
                    self.activeResizeHandle = .BOTTOM_RIGHT
                case .RIGHT:
                    cursor = NSCursor.resizeLeftRight
                    self.activeResizeHandle = .RIGHT
                    let alignedWindows = getAlignedWindowsToResizeSimultaneously(
                        window: self.selectedWindow!,
                        resizeHandle: .RIGHT,
                        allWindows: self.allWindows
                    )
                    self.activeAlignedWindowsToResizeSimultaneously = alignedWindows.map({ (window) -> (resizingEdge: WindowResizeHandleType, window: ActivationWindow) in
                        return (
                            resizingEdge: .LEFT,
                            window: window
                        )
                    })
                case .TOP_RIGHT:
                    cursor = NSCursor.resizeNorthEastSouthWest
                    self.activeResizeHandle = .TOP_RIGHT
                }
            }
        }
        
        cursor.set()
        
        self.activeAlignedWindowsToResizeSimultaneously.forEach { (item) in
            item.window.placeholder.windowViewController.styleSelected()
        }
    }
    
    func complete() {
        self.allWindows.forEach { (window) in
            window.applyNewFrame()
            window.placeholder.window.orderOut(window.placeholder.window)
        }
        self.overlayWindows.forEach { (item) in
            item.bg.orderOut(item.bg)
            item.gesture.orderOut(item.gesture)
            item.gesture.clear()
        }
        
        NSCursor.arrow.set()
    }
    
    func abort() {
        self.allWindows.forEach { (window) in
            window.placeholder.window.orderOut(window.placeholder.window)
        }
        self.overlayWindows.forEach { (item) in
            item.bg.orderOut(item.bg)
            item.gesture.orderOut(item.gesture)
            item.gesture.clear()
        }
        
        NSCursor.arrow.set()
    }
    
    deinit {
        self.overlayWindows.forEach { (item) in
            OverlayWindowPool.shared.release(item)
        }
        
        self.selectedWindow = nil
        self.windowAlignmentManager = nil
        self.activeResizeHandle = nil
    }
}
