//
//  AppDelegate.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 31.10.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Cocoa
import Foundation
import ApplicationServices
import Silica
import Sparkle

let WINDOW_ADJECENT_RESIZE_DETECTION_SIZE: CGFloat = 10

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, GestureOverlayWindowDelegate, KeyboardListenerDelegate, PreferencesDelegate, NSMenuDelegate {
    
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    var colorOverlayWindows = [NSWindow]()
    var gestureOverlayWindows = [GestureOverlayWindow]()
    let preferencesWindowController = PreferencesWindowController.freshController()
    let aboutWindow = NSWindow(contentViewController: AboutViewController.freshController())
    var focusedWindow: SIWindow? = nil
    var selectedWindowHandle: PWindowHandle? = nil
    var windowHandles = [PWindowHandle]() // ordered from frontmost to backmost
    let keyboardListener = KeyboardListener()
    var disabled = false
    var windowAlignmentManager: WindowAlignmentManager? = nil
    var active = false
    var updater = SUUpdater()
    
    let abortSound = NSSound(named: "Funk")
    
    var activeResizeHandle: PWindowResizeHandle?
    var alignedWindowHandlesToResizeSimultaneously = [(
        resizingEdge: PWindowResizeHandle,
        windowHandle: PWindowHandle
    )]()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        Logger.shared.info("Booting...")
        
        let launcherAppId = "com.denizgurkaynak.PencLauncher"
        let runningApps = NSWorkspace.shared.runningApplications
        let isLauncherRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty
        if isLauncherRunning {
            Logger.shared.debug("Launcher is running, killing it...")
            DistributedNotificationCenter.default().post(name: .killLauncher, object: Bundle.main.bundleIdentifier!)
        }
        
        if let button = self.statusItem.button {
            button.image = NSImage(named:"penc-menu-icon")
        }
        
        Logger.shared.info("Checking accessibility permissions...")
        
        if checkPermissions() {
            constructMenu()
            Preferences.shared.setDelegate(self)
            self.keyboardListener.setDelegate(self)
            
            self.setupAboutWindow()
            self.onPreferencesChanged()
            
            Logger.shared.info("Boot successful")
        } else {
            let warnAlert = NSAlert();
            warnAlert.messageText = "Accessibility permissions needed";
            warnAlert.informativeText = "Penc relies upon having permission to 'control your computer'. If the permission prompt did not appear automatically, go to System Preferences, Security & Privacy, Accessibility, and add Penc to the list of allowed apps. Then relaunch Penc."
            warnAlert.layout()
            warnAlert.runModal()
            NSApplication.shared.terminate(self)
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func checkPermissions() -> Bool {
        if AXIsProcessTrusted() {
            Logger.shared.info("We're trusted accessibility client")
            return true
        } else {
            let options = NSDictionary(object: kCFBooleanTrue, forKey: kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString) as CFDictionary
            let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
            Logger.shared.warn("We're NOT trusted accessibility client, manual check result: \(accessibilityEnabled)")
            return accessibilityEnabled
        }
    }
    
    func constructMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        let aboutMenuItem = NSMenuItem(title: "About Penc", action: #selector(AppDelegate.openAboutWindow(_:)), keyEquivalent: "")
        menu.addItem(aboutMenuItem)
        
        let checkForUpdatesMenuItem = NSMenuItem(title: "Check for updates", action: #selector(AppDelegate.checkForUpdates(_:)), keyEquivalent: "")
        menu.addItem(checkForUpdatesMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let disableToggleMenuItem = NSMenuItem(title: "Disable", action: #selector(AppDelegate.toggleDisable(_:)), keyEquivalent: "")
        disableToggleMenuItem.tag = 1
        menu.addItem(disableToggleMenuItem)
        
        let disableAppToggleMenuItem = NSMenuItem(title: "Disable for current app", action: #selector(AppDelegate.toggleDisableApp(_:)), keyEquivalent: "")
        disableAppToggleMenuItem.isEnabled = false
        disableAppToggleMenuItem.tag = 2
        menu.addItem(disableAppToggleMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let preferencesMenuItem = NSMenuItem(title: "Preferences...", action: #selector(AppDelegate.openPreferencesWindow(_:)), keyEquivalent: ",")
        menu.addItem(preferencesMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitMenuItem)
        
        self.statusItem.menu = menu
        self.statusItem.menu?.delegate = self
    }
    
    func createGestureOverlayWindow() -> GestureOverlayWindow {
        let gestureOverlayWindow = GestureOverlayWindow(contentRect: CGRect(x: 0, y: 0, width: 0, height: 0), styleMask: [NSWindow.StyleMask.borderless], backing: NSWindow.BackingStoreType.buffered, defer: true)
        gestureOverlayWindow.setDelegate(self)
        
        gestureOverlayWindow.swipeDetectionVelocityThreshold = Preferences.shared.swipeDetectionVelocityThreshold
        
        gestureOverlayWindow.level = .popUpMenu
        gestureOverlayWindow.isOpaque = false
        gestureOverlayWindow.ignoresMouseEvents = false
        gestureOverlayWindow.acceptsMouseMovedEvents = true
        gestureOverlayWindow.contentView!.allowedTouchTypes = [.indirect]
        gestureOverlayWindow.backgroundColor = NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        
        return gestureOverlayWindow
    }
    
    func createColorOverlayWindow() -> NSWindow {
        let colorOverlayWindow = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 0, height: 0), styleMask: [NSWindow.StyleMask.borderless], backing: NSWindow.BackingStoreType.buffered, defer: true)
        
        colorOverlayWindow.level = .popUpMenu
        colorOverlayWindow.isOpaque = false
        
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
            let blurView = NSVisualEffectView(frame: colorOverlayWindow.frame)
            blurView.blendingMode = .behindWindow
            blurView.material = .dark
            blurView.state = .active
            blurView.autoresizingMask = [.width, .height]
            colorOverlayWindow.contentView?.addSubview(blurView)
        } else {
            colorOverlayWindow.backgroundColor = NSColor(white: 0.15, alpha: 0.8)
        }
        
        return colorOverlayWindow
    }
    
    @objc func openPreferencesWindow(_ sender: Any?) {
        self.preferencesWindowController.showWindow(self)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func setupAboutWindow() {
        self.aboutWindow.titleVisibility = .hidden
        self.aboutWindow.styleMask.remove(.resizable)
        self.aboutWindow.styleMask.remove(.miniaturizable)
    }
    
    @objc func openAboutWindow(_ sender: Any?) {
        self.aboutWindow.makeKeyAndOrderFront(self.aboutWindow)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func onPreferencesChanged() {
        let preferences = Preferences.shared
        self.keyboardListener.activationModifierKey = preferences.activationModifierKey
        self.keyboardListener.secondActivationModifierKeyPress = Double(preferences.activationSensitivity)
        self.keyboardListener.holdActivationModifierKeyTimeout = Double(preferences.holdDuration)
        self.gestureOverlayWindows.forEach { (gestureOverlayWindow) in
            gestureOverlayWindow.swipeDetectionVelocityThreshold = preferences.swipeDetectionVelocityThreshold
            gestureOverlayWindow.reverseScroll = preferences.reverseScroll
        }
    }
    
    func onActivationStarted() {
        guard !self.disabled else {
            Logger.shared.info("Not gonna activate, Penc is disabled globally")
            self.abortSound?.play()
            return
        }
        
        guard NSScreen.screens.indices.contains(0) else {
            Logger.shared.info("Not gonna activate, there is no screen at all")
            self.abortSound?.play()
            return
        }
        
        // Get visible windows on the screen
        var visibleWindowHandles = [PWindowHandle]()
        do {
            visibleWindowHandles = try PWindowHandle.visibleWindowHandles()
            
            // Filter the windows owned by disabled apps
            visibleWindowHandles = visibleWindowHandles.filter({ (windowHandle) -> Bool in
                if windowHandle.runningApp == nil { return true }
                if windowHandle.runningApp!.bundleIdentifier == nil { return true }
                return !Preferences.shared.disabledApps.contains(windowHandle.runningApp!.bundleIdentifier!)
            })
        } catch {
            Logger.shared.error("Not gonna activate, could not get visible windows: \(error.localizedDescription)")
            self.abortSound?.play()
            return
        }
        
        var focusedWindow = SIWindow.focused()
        // If focused window is finder's desktop window, ignore
        if focusedWindow?.title() == nil {
            if let focusedApp = focusedWindow?.app() {
                if focusedApp.title() == "Finder" {
                    Logger.shared.debug("Desktop is focused, ignoring")
                    focusedWindow = nil
                }
            }
        }
        
        var initiallySelectedWindowHandle: PWindowHandle? = nil
        
        // Select the window under cursor
        let mouseX = NSEvent.mouseLocation.x
        let mouseY = NSEvent.mouseLocation.y // bottom-left origined
        Logger.shared.debug("Looking for the window under mouse cursor -- X=\(mouseX), Y=\(mouseY)")
        
        for windowHandle in visibleWindowHandles {
            if windowHandle.newRect.contains(CGPoint(x: mouseX, y: mouseY)) {
                initiallySelectedWindowHandle = windowHandle
                break
            }
        }
        
        self.active = true
        self.focusedWindow = focusedWindow
        self.windowHandles = visibleWindowHandles
        
        // Show color overlay windows for each screen
        for (index, screen) in NSScreen.screens.enumerated() {
            if !self.colorOverlayWindows.indices.contains(index) {
                self.colorOverlayWindows.append(self.createColorOverlayWindow())
            }
            
            let colorOverlayWindow = self.colorOverlayWindows[index]
            colorOverlayWindow.setFrame(screen.frame, display: true, animate: false)
            colorOverlayWindow.makeKeyAndOrderFront(colorOverlayWindow)
        }
        
        // Set-up initial placeholder windows & order them
        self.windowHandles.reversed().forEach { (windowHandle) in
            windowHandle.updateFrame(windowHandle.newRect)
            windowHandle.placeholder.windowViewController.styleNormal()
            
            let _ = windowHandle.siWindow // force to get siwindow instance
            windowHandle.refreshPlaceholderTitle()
            windowHandle.refreshAppIconImage()
            
            windowHandle.placeholder.window.makeKeyAndOrderFront(windowHandle.placeholder.window)
        }
        
        // Now handle the initially selected window
        self.selectWindow(initiallySelectedWindowHandle)
        
        // Show gesture overlay window for each screen
        for (index, screen) in NSScreen.screens.enumerated() {
            if !self.gestureOverlayWindows.indices.contains(index) {
                self.gestureOverlayWindows.append(self.createGestureOverlayWindow())
            }
            
            let gestureOverlayWindow = self.gestureOverlayWindows[index]
            gestureOverlayWindow.setFrame(screen.frame, display: true, animate: false)
            gestureOverlayWindow.makeKeyAndOrderFront(gestureOverlayWindow)
        }
        
        // If there are multiple screens, only the frontmost gesture overlay window
        // recieves magnify events. I guess this is one of macOS's restrictions and
        // we can't do anything. However, the only thing we can do is that we can set
        // the gesture overlay window in the selected window's screen as the frontmost
        // window, so when a person activates the Penc, it can do magnify gesture right away.
        let initiallySelectedWindowScreen = initiallySelectedWindowHandle?.placeholder.window.screen
        if initiallySelectedWindowScreen != nil {
            let gestureOverlayWindow = self.gestureOverlayWindows.first { (window) -> Bool in
                return window.screen === initiallySelectedWindowScreen
            }
            gestureOverlayWindow?.makeKeyAndOrderFront(gestureOverlayWindow)
        }
        
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func selectWindow(_ newWindowHandle: PWindowHandle?) {
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
        
        self.reloadWindowAlignmentManager()
    }
    
    // If the selected window is changed, or one of the other window's
    // frame or zIndex is changed, we need to re-calculate window alignment
    // targets in the WindowAlignmentManager. The only optimization we can
    // do is: when changing the frame of selected window, calling
    // self.windowAlignmentManager.updateSelectedWindowFrame(_: CGRect) method,
    // instead of a hard reload.
    func reloadWindowAlignmentManager() {
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
    
    func onActivationCompleted() {
        guard self.active else { return }
        
        guard NSScreen.screens.indices.contains(0) else {
            Logger.shared.info("Not gonna complete activation, there is no screen -- force cancelling")
            self.onActivationAborted()
            return
        }
        
        self.focusedWindow?.focusThisWindowOnly()
        
        self.windowHandles.forEach { (windowHandle) in
            windowHandle.applyNewFrame()
            windowHandle.placeholder.window.orderOut(windowHandle.placeholder.window)
        }
        self.colorOverlayWindows.forEach { (colorOverlayWindow) in
            colorOverlayWindow.orderOut(colorOverlayWindow)
        }
        self.gestureOverlayWindows.forEach { (gestureOverlayWindow) in
            gestureOverlayWindow.orderOut(gestureOverlayWindow)
            gestureOverlayWindow.clear()
        }
        
        self.windowAlignmentManager = nil
        self.focusedWindow = nil
        self.selectedWindowHandle = nil
        self.windowHandles = []
        self.active = false
        NSCursor.arrow.set()
        self.activeResizeHandle = nil
    }
    
    func onActivationAborted() {
        guard self.active else { return }
        
        Logger.shared.info("Aborted activation")
        
        self.focusedWindow?.focus()
        
        self.windowHandles.forEach { (windowHandle) in
            windowHandle.placeholder.window.orderOut(windowHandle.placeholder.window)
        }
        self.colorOverlayWindows.forEach { (colorOverlayWindow) in
            colorOverlayWindow.orderOut(colorOverlayWindow)
        }
        self.gestureOverlayWindows.forEach { (gestureOverlayWindow) in
            gestureOverlayWindow.orderOut(gestureOverlayWindow)
            gestureOverlayWindow.clear()
        }
        
        self.windowAlignmentManager = nil
        self.focusedWindow = nil
        self.selectedWindowHandle = nil
        self.windowHandles = []
        self.active = false
        NSCursor.arrow.set()
        self.activeResizeHandle = nil
    }
    
    func onKeyDownWhileActivated(pressedKeys: Set<UInt16>) {
        guard self.active else { return }
        
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
        guard self.active else { return }
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
        self.selectedWindowHandle!.updateFrame(newRect)
        self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
        
        NSCursor.arrow.set()
        self.activeResizeHandle = nil
        self.alignedWindowHandlesToResizeSimultaneously.forEach { (data) in
            data.windowHandle.placeholder.windowViewController.styleNormal()
        }
        self.alignedWindowHandlesToResizeSimultaneously = []
    }
    
    func onSwipeGesture(type: SwipeGestureType) {
        guard self.active else { return }
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
                self.selectedWindowHandle!.updateFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .TOP_CENTER,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .TOP_CENTER)
                )
                self.selectedWindowHandle!.updateFrame(newRect)
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
                self.selectedWindowHandle!.updateFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .TOP_RIGHT,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .TOP_RIGHT)
                )
                self.selectedWindowHandle!.updateFrame(newRect)
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
                self.selectedWindowHandle!.updateFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .RIGHT_CENTER,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .RIGHT_CENTER)
                )
                self.selectedWindowHandle!.updateFrame(newRect)
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
                self.selectedWindowHandle!.updateFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .BOTTOM_RIGHT,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .BOTTOM_RIGHT)
                )
                self.selectedWindowHandle!.updateFrame(newRect)
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
                self.selectedWindowHandle!.updateFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .BOTTOM_CENTER,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .BOTTOM_CENTER)
                )
                self.selectedWindowHandle!.updateFrame(newRect)
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
                self.selectedWindowHandle!.updateFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .BOTTOM_LEFT,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .BOTTOM_LEFT)
                )
                self.selectedWindowHandle!.updateFrame(newRect)
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
                self.selectedWindowHandle!.updateFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .LEFT_CENTER,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .LEFT_CENTER)
                )
                self.selectedWindowHandle!.updateFrame(newRect)
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
                self.selectedWindowHandle!.updateFrame(newRect)
                self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .TOP_LEFT,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .TOP_LEFT)
                )
                self.selectedWindowHandle!.updateFrame(newRect)
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
        guard self.active else { return }
        guard self.selectedWindowHandle != nil else { return }
        let placeholderWindowScreen = self.selectedWindowHandle!.placeholder.window.screen
        guard placeholderWindowScreen != nil else { return }
        guard self.selectedWindowHandle!.siWindow?.isResizable() ?? false else { return }
        
        let newRect = self.selectedWindowHandle!.newRect
            .resizeBy(factor: factor)
            .fitInVisibleFrame(ofScreen: placeholderWindowScreen!)
        self.selectedWindowHandle!.updateFrame(newRect)
        self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
        
        NSCursor.arrow.set()
        self.activeResizeHandle = nil
        self.alignedWindowHandlesToResizeSimultaneously.forEach { (data) in
            data.windowHandle.placeholder.windowViewController.styleNormal()
        }
        self.alignedWindowHandlesToResizeSimultaneously = []
    }
    
    func onDoubleClickGesture() {
        guard self.active else { return }
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
            self.selectedWindowHandle!.updateFrame(self.selectedWindowHandle!.previousRectBeforeDblClick!)
            self.windowAlignmentManager?.updateSelectedWindowFrame(self.selectedWindowHandle!.previousRectBeforeDblClick!)
            self.selectedWindowHandle!.previousRectBeforeDblClick = nil
        } else {
            self.selectedWindowHandle!.previousRectBeforeDblClick = self.selectedWindowHandle!.newRect
            self.selectedWindowHandle!.updateFrame(newRect)
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
        guard self.active else { return }
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
            self.selectedWindowHandle!.updateFrame(newRect)
            self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
        } else {
            // resize window
//            let newMovement = self.windowAlignmentManager!.map(movement: (x: -delta.x, y: delta.y), timestamp: timestamp)
            let newMovement = (x: -delta.x, y: delta.y)
            let newRect = self.selectedWindowHandle!.newRect.resizeBy(
                handle: self.activeResizeHandle!,
                delta: newMovement
            )
            self.selectedWindowHandle!.updateFrame(newRect)
            self.windowAlignmentManager?.updateSelectedWindowFrame(newRect)
            
            self.alignedWindowHandlesToResizeSimultaneously.forEach { (data) in
                let newRect = data.windowHandle.newRect.resizeBy(
                    handle: data.resizingEdge,
                    delta: newMovement
                )
                data.windowHandle.updateFrame(newRect)
                // TODO: What about self.windowAlignmentManager
            }
        }
    }
    
    func onMouseMoveGesture(position: (x: CGFloat, y: CGFloat)) {
        guard self.active else { return }
        // TODO: Should we throttle this?
        
        let mouseX = NSEvent.mouseLocation.x
        let mouseY = NSEvent.mouseLocation.y // bottom-left origined
        
        let windowUnderCursor = self.windowHandles.first { (windowHandle) -> Bool in
            return windowHandle.newRect.contains(CGPoint(x: mouseX, y: mouseY))
        }
    
        // TODO: If windowUnderCursor === self.selectedWindowHandle,
        // do we need to select window again?
        
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
    
    func getAlignedWindowHandlesToResizeSimultaneously(selectedResizeHandle: PWindowResizeHandle) -> [PWindowHandle] {
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
    
    func menuWillOpen(_ menu: NSMenu) {
        let disableToggleMenuItem = menu.item(withTag: 1)
        disableToggleMenuItem!.title = self.disabled ? "Enable" : "Disable"
        
        let disableAppToggleMenuItem = menu.item(withTag: 2)
        if let app = NSWorkspace.shared.frontmostApplication {
            if let appName = app.localizedName, let appBundleId = app.bundleIdentifier {
                if Preferences.shared.disabledApps.contains(appBundleId) {
                    disableAppToggleMenuItem!.title = "Enable for \"\(appName)\""
                } else {
                    disableAppToggleMenuItem!.title = "Disable for \"\(appName)\""
                }
                
                disableAppToggleMenuItem!.isEnabled = true
            }
        } else {
            disableAppToggleMenuItem!.title = "Disable for current app"
            disableAppToggleMenuItem!.isEnabled = false
        }
    }
    
    @objc func toggleDisable(_ sender: Any?) {
        self.disabled = !self.disabled
        Logger.shared.info(self.disabled ? "Disabled globally" : "Enabled globally")
    }
    
    @objc func toggleDisableApp(_ sender: Any?) {
        if let app = NSWorkspace.shared.frontmostApplication {
            if let appBundleId = app.bundleIdentifier {
                if Preferences.shared.disabledApps.contains(appBundleId) {
                    let i = Preferences.shared.disabledApps.firstIndex(of: appBundleId)
                    Preferences.shared.disabledApps.remove(at: i!)
                    Logger.shared.info("Enabled back for \(appBundleId)")
                } else {
                    Preferences.shared.disabledApps.append(appBundleId)
                    Logger.shared.info("Disabled for \(appBundleId)")
                }
                
                Preferences.shared.disabledApps = Preferences.shared.disabledApps
            }
        }
    }
    
    @objc func checkForUpdates(_ sender: Any?) {
        Logger.shared.info("Checking for updates")
        self.updater.checkForUpdates(nil)
    }
    
}



