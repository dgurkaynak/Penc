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
    
    // let olabilir mi windowHandles?
    private let windowHandles: [PWindowHandle] // ordered from frontmost to backmost
    private var selectedWindowHandle: PWindowHandle? = nil
    
    // TODO: let olabilir mi
    private var windowAlignmentManager: WindowAlignmentManager? = nil
    
    // resizing stuff, will change on mouse move
    private var activeResizeHandle: PWindowResizeHandle?
    private var alignedWindowHandlesToResizeSimultaneously = [(
        resizingEdge: PWindowResizeHandle,
        windowHandle: PWindowHandle
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
        
        // Filter out the windows of disabled apps
        self.windowHandles = visibleWindowHandles.filter({ (windowHandle) -> Bool in
            if windowHandle.runningApp == nil { return true }
            if windowHandle.runningApp!.bundleIdentifier == nil { return true }
            return !Preferences.shared.disabledApps.contains(windowHandle.runningApp!.bundleIdentifier!)
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
        self.windowHandles.reversed().forEach { (windowHandle) in
            windowHandle.setFrame(windowHandle.newRect)
            windowHandle.placeholder.windowViewController.styleNormal()
            
            let _ = windowHandle.siWindow // force to get siwindow instance
            windowHandle.refreshPlaceholderTitle()
            windowHandle.refreshAppIconImage()
            
            // TODO: Is `makeKey` required?
//            windowHandle.placeholder.window.makeKeyAndOrderFront(windowHandle.placeholder.window)
//            windowHandle.placeholder.window.makeKey()
            windowHandle.placeholder.window.order(.below, relativeTo: backmostGestureOverlayWindow.windowNumber)
        }
        
        // Determine the window under cursor and select it initially
        let mouseX = NSEvent.mouseLocation.x
        let mouseY = NSEvent.mouseLocation.y // bottom-left origined
        let initialSelectedWindow = self.getFrontmostWindow(byCoordinate: (x: mouseX, y: mouseY))
        self.selectWindow(initialSelectedWindow)
    }
    
    // expects bottom-left
    private func getFrontmostWindow(byCoordinate pos: (x: CGFloat, y: CGFloat)) -> PWindowHandle? {
        for windowHandle in self.windowHandles {
            if windowHandle.newRect.contains(CGPoint(x: pos.x, y: pos.y)) {
                return windowHandle
            }
        }
        
        return nil
    }
    
    // TODO: Test this
    var backmostGestureOverlayWindow: GestureOverlayWindow {
        return self.overlayWindows.map({ $0.gesture }).min { a,b in a.orderedIndex < b.orderedIndex }!
    }
    
    private func selectWindow(_ newWindowHandle: PWindowHandle?) {
        // If trying to select already-selected one, NOOP
        if newWindowHandle != nil &&
            self.selectedWindowHandle != nil &&
            newWindowHandle!.windowNumber == self.selectedWindowHandle!.windowNumber {
            return
        }
        
        // If there is already selected one, update its style
        if self.selectedWindowHandle != nil {
            self.selectedWindowHandle!.placeholder.windowViewController.styleNormal()
        }
        
        // If no window is selected, early terminate
        if newWindowHandle == nil {
            self.selectedWindowHandle = nil
            return
        }
        
        newWindowHandle!.placeholder.windowViewController.styleSelected()
        self.selectedWindowHandle = newWindowHandle
        
        // If there are multiple screens, only the frontmost gesture overlay window
        // recieves magnify events. I guess this is one of macOS's restrictions and
        // we can't do anything. However, the only thing we can do is that we can set
        // the gesture overlay window in the selected window's screen as the frontmost
        // window.
        let newScreen = newWindowHandle!.placeholder.window.screen
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
        guard self.selectedWindowHandle != nil else { return }

        var otherWindowHandlesDictionary = [Int: PWindowHandle]()
        self.windowHandles.forEach { (windowHandle) in
            guard windowHandle.windowNumber != self.selectedWindowHandle!.windowNumber else { return }
            otherWindowHandlesDictionary[windowHandle.windowNumber] = windowHandle
        }
        self.windowAlignmentManager = WindowAlignmentManager(
            selectedWindowFrame: self.selectedWindowHandle!.newRect,
            otherWindows: otherWindowHandlesDictionary
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
        guard self.selectedWindowHandle != nil else { return }
        guard self.selectedWindowHandle!.siWindow?.isMovable() ?? false else { return }
        guard self.windowAlignmentManager != nil else { return }
        
        let rect = self.selectedWindowHandle!.newRect
        let newMovement = self.windowAlignmentManager!.map(movement: (x: -delta.x, y: delta.y), timestamp: delta.timestamp)
        let newRect = CGRect(
            x: rect.origin.x + newMovement.x,
            y: rect.origin.y + newMovement.y,
            width: rect.width,
            height: rect.height
        )
        self.selectedWindowHandle!.setFrame(newRect)
        self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
        
        NSCursor.arrow.set()
        self.activeResizeHandle = nil
        self.alignedWindowHandlesToResizeSimultaneously.forEach { (data) in
            data.windowHandle.placeholder.windowViewController.styleNormal()
        }
        self.alignedWindowHandlesToResizeSimultaneously = []
    }
    
    func onSwipeGesture(type: SwipeGestureType) {
        guard self.selectedWindowHandle != nil else { return }
        let placeholderWindowScreen = self.selectedWindowHandle!.placeholder.window.screen
        guard placeholderWindowScreen != nil else { return }
        
        let screenNumber = placeholderWindowScreen!.getScreenNumber()
        guard screenNumber != nil else { return }
        let actions = Preferences.shared.getCustomActions(forScreenNumber: screenNumber!)
        
        let isResizable = self.selectedWindowHandle!.siWindow?.isResizable() ?? false
        let isMovable = self.selectedWindowHandle!.siWindow?.isMovable() ?? false
        
        switch (type) {
        case .SWIPE_TOP:
            if isResizable {
                let newRect = self.selectedWindowHandle!.newRect.resizeBy(
                    screen: placeholderWindowScreen!,
                    ratio: (
                        width: CGFloat(actions["top"]![0]),
                        height: CGFloat(actions["top"]![1])
                    )
                )
                self.selectedWindowHandle!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .TOP_CENTER,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .TOP_CENTER)
                )
                self.selectedWindowHandle!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
        case .SWIPE_TOP_RIGHT:
            if isResizable {
                let newRect = self.selectedWindowHandle!.newRect.resizeBy(
                    screen: placeholderWindowScreen!,
                    ratio: (
                        width: CGFloat(actions["topRight"]![0]),
                        height: CGFloat(actions["topRight"]![1])
                    )
                )
                self.selectedWindowHandle!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .TOP_RIGHT,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .TOP_RIGHT)
                )
                self.selectedWindowHandle!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
        case .SWIPE_RIGHT:
            if isResizable {
                let newRect = self.selectedWindowHandle!.newRect.resizeBy(
                    screen: placeholderWindowScreen!,
                    ratio: (
                        width: CGFloat(actions["right"]![0]),
                        height: CGFloat(actions["right"]![1])
                    )
                )
                self.selectedWindowHandle!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .RIGHT_CENTER,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .RIGHT_CENTER)
                )
                self.selectedWindowHandle!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
        case .SWIPE_BOTTOM_RIGHT:
            if isResizable {
                let newRect = self.selectedWindowHandle!.newRect.resizeBy(
                    screen: placeholderWindowScreen!,
                    ratio: (
                        width: CGFloat(actions["bottomRight"]![0]),
                        height: CGFloat(actions["bottomRight"]![1])
                    )
                )
                self.selectedWindowHandle!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .BOTTOM_RIGHT,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .BOTTOM_RIGHT)
                )
                self.selectedWindowHandle!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
        case .SWIPE_BOTTOM:
            if isResizable {
                let newRect = self.selectedWindowHandle!.newRect.resizeBy(
                    screen: placeholderWindowScreen!,
                    ratio: (
                        width: CGFloat(actions["bottom"]![0]),
                        height: CGFloat(actions["bottom"]![1])
                    )
                )
                self.selectedWindowHandle!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .BOTTOM_CENTER,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .BOTTOM_CENTER)
                )
                self.selectedWindowHandle!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
        case .SWIPE_BOTTOM_LEFT:
            if isResizable {
                let newRect = self.selectedWindowHandle!.newRect.resizeBy(
                    screen: placeholderWindowScreen!,
                    ratio: (
                        width: CGFloat(actions["bottomLeft"]![0]),
                        height: CGFloat(actions["bottomLeft"]![1])
                    )
                )
                self.selectedWindowHandle!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .BOTTOM_LEFT,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .BOTTOM_LEFT)
                )
                self.selectedWindowHandle!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
        case .SWIPE_LEFT:
            if isResizable {
                let newRect = self.selectedWindowHandle!.newRect.resizeBy(
                    screen: placeholderWindowScreen!,
                    ratio: (
                        width: CGFloat(actions["left"]![0]),
                        height: CGFloat(actions["left"]![1])
                    )
                )
                self.selectedWindowHandle!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .LEFT_CENTER,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .LEFT_CENTER)
                )
                self.selectedWindowHandle!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
        case .SWIPE_TOP_LEFT:
            if isResizable {
                let newRect = self.selectedWindowHandle!.newRect.resizeBy(
                    screen: placeholderWindowScreen!,
                    ratio: (
                        width: CGFloat(actions["topLeft"]![0]),
                        height: CGFloat(actions["topLeft"]![1])
                    )
                )
                self.selectedWindowHandle!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .TOP_LEFT,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .TOP_LEFT)
                )
                self.selectedWindowHandle!.setFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
        }
        
        NSCursor.arrow.set()
        self.activeResizeHandle = nil
        self.alignedWindowHandlesToResizeSimultaneously.forEach { (data) in
            data.windowHandle.placeholder.windowViewController.styleNormal()
        }
        self.alignedWindowHandlesToResizeSimultaneously = []
    }
    
    func onMagnifyGesture(factor: (width: CGFloat, height: CGFloat)) {
        guard self.selectedWindowHandle != nil else { return }
        let placeholderWindowScreen = self.selectedWindowHandle!.placeholder.window.screen
        guard placeholderWindowScreen != nil else { return }
        guard self.selectedWindowHandle!.siWindow?.isResizable() ?? false else { return }
        
        let newRect = self.selectedWindowHandle!.newRect
            .resizeBy(factor: factor)
            .fitInVisibleFrame(ofScreen: placeholderWindowScreen!)
        self.selectedWindowHandle!.setFrame(newRect)
        self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
        
        NSCursor.arrow.set()
        self.activeResizeHandle = nil
        self.alignedWindowHandlesToResizeSimultaneously.forEach { (data) in
            data.windowHandle.placeholder.windowViewController.styleNormal()
        }
        self.alignedWindowHandlesToResizeSimultaneously = []
    }
    
    func onDoubleClickGesture() {
        guard self.selectedWindowHandle != nil else { return }
        let placeholderWindowScreen = self.selectedWindowHandle!.placeholder.window.screen
        guard placeholderWindowScreen != nil else { return }
        
        let screenNumber = placeholderWindowScreen!.getScreenNumber()
        guard screenNumber != nil else { return }
        let actions = Preferences.shared.getCustomActions(forScreenNumber: screenNumber!)
        
        let isResizable = self.selectedWindowHandle!.siWindow?.isResizable() ?? false
        let isMovable = self.selectedWindowHandle!.siWindow?.isMovable() ?? false
        
        var newRect = self.selectedWindowHandle!.newRect
        
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
        
        if self.selectedWindowHandle!.previousRectBeforeDblClick != nil &&
            self.selectedWindowHandle!.newRect == newRect {
            self.selectedWindowHandle!.setFrame(self.selectedWindowHandle!.previousRectBeforeDblClick!)
            self.windowAlignmentManager?.updateSelectedWindowFrame(self.selectedWindowHandle!.previousRectBeforeDblClick!)
            self.selectedWindowHandle!.previousRectBeforeDblClick = nil
        } else {
            self.selectedWindowHandle!.previousRectBeforeDblClick = self.selectedWindowHandle!.newRect
            self.selectedWindowHandle!.setFrame(newRect)
            self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
        }
        
        NSCursor.arrow.set()
        self.activeResizeHandle = nil
        self.alignedWindowHandlesToResizeSimultaneously.forEach { (data) in
            data.windowHandle.placeholder.windowViewController.styleNormal()
        }
        self.alignedWindowHandlesToResizeSimultaneously = []
    }
    
    func onMouseDragGesture(position: (x: CGFloat, y: CGFloat), delta: (x: CGFloat, y: CGFloat), timestamp: Double) {
        guard self.selectedWindowHandle != nil else { return }
        guard self.selectedWindowHandle!.siWindow?.isMovable() ?? false else { return }
        guard self.windowAlignmentManager != nil else { return }
        
        if self.activeResizeHandle == nil {
            // move window
            let rect = self.selectedWindowHandle!.newRect
            let newMovement = self.windowAlignmentManager!.map(movement: (x: -delta.x, y: delta.y), timestamp: timestamp)
            let newRect = CGRect(
                x: rect.origin.x + newMovement.x,
                y: rect.origin.y + newMovement.y,
                width: rect.width,
                height: rect.height
            )
            self.selectedWindowHandle!.setFrame(newRect)
            self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
        } else {
            // resize window
//            let newMovement = self.windowAlignmentManager!.map(movement: (x: -delta.x, y: delta.y), timestamp: timestamp)
            let newMovement = (x: -delta.x, y: delta.y)
            let newRect = self.selectedWindowHandle!.newRect.resizeBy(
                handle: self.activeResizeHandle!,
                delta: newMovement
            )
            self.selectedWindowHandle!.setFrame(newRect)
            self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            
            self.alignedWindowHandlesToResizeSimultaneously.forEach { (data) in
                let newRect = data.windowHandle.newRect.resizeBy(
                    handle: data.resizingEdge,
                    delta: newMovement
                )
                data.windowHandle.setFrame(newRect)
                // TODO: What about self.windowAlignmentManager
            }
        }
    }
    
    func onMouseMoveGesture(position: (x: CGFloat, y: CGFloat)) {
        // TODO: Should we throttle this?
        
        let mouseX = NSEvent.mouseLocation.x
        let mouseY = NSEvent.mouseLocation.y // bottom-left origined
        
        let windowUnderCursor = self.windowHandles.first { (windowHandle) -> Bool in
            return windowHandle.newRect.contains(CGPoint(x: mouseX, y: mouseY))
        }
    
        // TODO: If windowUnderCursor === self.selectedWindowHandle,
        // do we need to select window again?
        // Update from 5th Feb 2021 -- We did the NOOP if already selected one, test it
        
        self.selectWindow(windowUnderCursor)
        
        self.activeResizeHandle = nil
        self.alignedWindowHandlesToResizeSimultaneously.forEach { (data) in
            data.windowHandle.placeholder.windowViewController.styleNormal()
        }
        self.alignedWindowHandlesToResizeSimultaneously = []
        
        var cursor = NSCursor.arrow
        
        if self.selectedWindowHandle != nil {
            let resizeHandleUnderCursor = self.selectedWindowHandle!.resizeHandleRects.first { (resizeHandle) -> Bool in
                return resizeHandle.rect.contains(CGPoint(x: mouseX, y: mouseY))
            }
            
            if resizeHandleUnderCursor != nil {
                switch resizeHandleUnderCursor!.type {
                case .TOP:
                    cursor = NSCursor.resizeUpDown
                    self.activeResizeHandle = .TOP
                    let alignedWindows = self.getAlignedWindowHandlesToResizeSimultaneously(selectedResizeHandle: .TOP)
                    self.alignedWindowHandlesToResizeSimultaneously = alignedWindows.map({ (windowHandle) -> (resizingEdge: PWindowResizeHandle, windowHandle: PWindowHandle) in
                        return (
                            resizingEdge: .BOTTOM,
                            windowHandle: windowHandle
                        )
                    })
                case .TOP_LEFT:
                    cursor = NSCursor.resizeNorthWestSouthEast
                    self.activeResizeHandle = .TOP_LEFT
                case .LEFT:
                    cursor = NSCursor.resizeLeftRight
                    self.activeResizeHandle = .LEFT
                    let alignedWindows = self.getAlignedWindowHandlesToResizeSimultaneously(selectedResizeHandle: .LEFT)
                    self.alignedWindowHandlesToResizeSimultaneously = alignedWindows.map({ (windowHandle) -> (resizingEdge: PWindowResizeHandle, windowHandle: PWindowHandle) in
                        return (
                            resizingEdge: .RIGHT,
                            windowHandle: windowHandle
                        )
                    })
                case .BOTTOM_LEFT:
                    cursor = NSCursor.resizeNorthEastSouthWest
                    self.activeResizeHandle = .BOTTOM_LEFT
                case .BOTTOM:
                    cursor = NSCursor.resizeUpDown
                    self.activeResizeHandle = .BOTTOM
                    let alignedWindows = self.getAlignedWindowHandlesToResizeSimultaneously(selectedResizeHandle: .BOTTOM)
                    self.alignedWindowHandlesToResizeSimultaneously = alignedWindows.map({ (windowHandle) -> (resizingEdge: PWindowResizeHandle, windowHandle: PWindowHandle) in
                        return (
                            resizingEdge: .TOP,
                            windowHandle: windowHandle
                        )
                    })
                case .BOTTOM_RIGHT:
                    cursor = NSCursor.resizeNorthWestSouthEast
                    self.activeResizeHandle = .BOTTOM_RIGHT
                case .RIGHT:
                    cursor = NSCursor.resizeLeftRight
                    self.activeResizeHandle = .RIGHT
                    let alignedWindows = self.getAlignedWindowHandlesToResizeSimultaneously(selectedResizeHandle: .RIGHT)
                    self.alignedWindowHandlesToResizeSimultaneously = alignedWindows.map({ (windowHandle) -> (resizingEdge: PWindowResizeHandle, windowHandle: PWindowHandle) in
                        return (
                            resizingEdge: .LEFT,
                            windowHandle: windowHandle
                        )
                    })
                case .TOP_RIGHT:
                    cursor = NSCursor.resizeNorthEastSouthWest
                    self.activeResizeHandle = .TOP_RIGHT
                }
            }
        }
        
        cursor.set()
        
        self.alignedWindowHandlesToResizeSimultaneously.forEach { (data) in
            data.windowHandle.placeholder.windowViewController.styleSelected()
        }
    }
    
    private func getAlignedWindowHandlesToResizeSimultaneously(selectedResizeHandle: PWindowResizeHandle) -> [PWindowHandle] {
        guard self.selectedWindowHandle != nil else { return [] }
        
        var windowHandles = [PWindowHandle]()
        
        switch selectedResizeHandle {
        case .TOP:
            let targetRect = CGRect(
                x: self.selectedWindowHandle!.newRect.origin.x,
                y: self.selectedWindowHandle!.newRect.origin.y + self.selectedWindowHandle!.newRect.size.height - (WINDOW_ADJECENT_RESIZE_DETECTION_SIZE / 2),
                width: self.selectedWindowHandle!.newRect.size.width,
                height: WINDOW_ADJECENT_RESIZE_DETECTION_SIZE
            )
            windowHandles = self.windowHandles.filter({ (windowHandle) -> Bool in
                let edge = windowHandle.newRect.getBottomEdge()
                let edgeRect = CGRect(x: edge.x1, y: edge.y, width: edge.x2 - edge.x1, height: 0)
                return targetRect.intersects(edgeRect)
            })
        case .TOP_LEFT:
            return []
        case .LEFT:
            let targetRect = CGRect(
                x: self.selectedWindowHandle!.newRect.origin.x - (WINDOW_ADJECENT_RESIZE_DETECTION_SIZE / 2),
                y: self.selectedWindowHandle!.newRect.origin.y,
                width: WINDOW_ADJECENT_RESIZE_DETECTION_SIZE,
                height: self.selectedWindowHandle!.newRect.size.height
            )
            windowHandles = self.windowHandles.filter({ (windowHandle) -> Bool in
                let edge = windowHandle.newRect.getRightEdge()
                let edgeRect = CGRect(x: edge.x, y: edge.y1, width: 0, height: edge.y2 - edge.y1)
                return targetRect.intersects(edgeRect)
            })
        case .BOTTOM_LEFT:
            return []
        case .BOTTOM:
            let targetRect = CGRect(
                x: self.selectedWindowHandle!.newRect.origin.x,
                y: self.selectedWindowHandle!.newRect.origin.y - (WINDOW_ADJECENT_RESIZE_DETECTION_SIZE / 2),
                width: self.selectedWindowHandle!.newRect.size.width,
                height: WINDOW_ADJECENT_RESIZE_DETECTION_SIZE
            )
            windowHandles = self.windowHandles.filter({ (windowHandle) -> Bool in
                let edge = windowHandle.newRect.getTopEdge()
                let edgeRect = CGRect(x: edge.x1, y: edge.y, width: edge.x2 - edge.x1, height: 0)
                return targetRect.intersects(edgeRect)
            })
        case .BOTTOM_RIGHT:
            return []
        case .RIGHT:
            let targetRect = CGRect(
                x: self.selectedWindowHandle!.newRect.origin.x + self.selectedWindowHandle!.newRect.size.width - (WINDOW_ADJECENT_RESIZE_DETECTION_SIZE / 2),
                y: self.selectedWindowHandle!.newRect.origin.y,
                width: WINDOW_ADJECENT_RESIZE_DETECTION_SIZE,
                height: self.selectedWindowHandle!.newRect.size.height
            )
            windowHandles = self.windowHandles.filter({ (windowHandle) -> Bool in
                let edge = windowHandle.newRect.getLeftEdge()
                let edgeRect = CGRect(x: edge.x, y: edge.y1, width: 0, height: edge.y2 - edge.y1)
                return targetRect.intersects(edgeRect)
            })
        case .TOP_RIGHT:
            return []
        }
        
        return windowHandles
    }
    
    func complete() {
        self.windowHandles.forEach { (windowHandle) in
            windowHandle.applyNewFrame()
            windowHandle.placeholder.window.orderOut(windowHandle.placeholder.window)
        }
        self.overlayWindows.forEach { (item) in
            item.bg.orderOut(item.bg)
            item.gesture.orderOut(item.gesture)
            item.gesture.clear()
        }
        
        NSCursor.arrow.set()
    }
    
    func abort() {
        self.windowHandles.forEach { (windowHandle) in
            windowHandle.placeholder.window.orderOut(windowHandle.placeholder.window)
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
        
        self.selectedWindowHandle = nil
        self.windowAlignmentManager = nil
        self.selectedWindowHandle = nil
        self.activeResizeHandle = nil
        // self.windowHandles = [] // Do we need this?
    }
}
