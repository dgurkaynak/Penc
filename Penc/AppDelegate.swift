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
        colorOverlayWindow.backgroundColor = NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.75)
        
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
            gestureOverlayWindow.swipeThreshold = preferences.swipeThreshold
            gestureOverlayWindow.reverseScroll = preferences.reverseScroll
        }
        // TODO: Delete this
//        self.placeholderWindowViewController.toggleWindowSizeTextField(preferences.showWindowSize)
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
        
        if Preferences.shared.windowSelection == "focused" && focusedWindow != nil {
            let focusedWindowNumber = focusedWindow!.windowID()
            initiallySelectedWindowHandle = visibleWindowHandles.first(where: { (windowHandle) -> Bool in
                return windowHandle.windowNumber == focusedWindowNumber
            })
        } else if Preferences.shared.windowSelection == "underCursor" {
            let mouseX = NSEvent.mouseLocation.x
            let mouseY = NSEvent.mouseLocation.y // bottom-left origined
            Logger.shared.debug("Looking for the window under mouse cursor -- X=\(mouseX), Y=\(mouseY)")
            
            for windowHandle in visibleWindowHandles {
                if windowHandle.newRect.contains(CGPoint(x: mouseX, y: mouseY)) {
                    initiallySelectedWindowHandle = windowHandle
                    break
                }
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
        
        // Check if the window's app is ignored
        if let app = NSRunningApplication.init(processIdentifier: newWindowHandle!.appPid) {
            if let appBundleId = app.bundleIdentifier {
                if Preferences.shared.disabledApps.contains(appBundleId) {
                    self.selectedWindowHandle = nil
                    return
                }
            }
        }
        
        let _ = newWindowHandle!.siWindow // force to get siwindow instance
        newWindowHandle!.refreshPlaceholderTitle()
        newWindowHandle!.placeholder.windowViewController.styleHover()
        self.selectedWindowHandle = newWindowHandle
        
        // TODO: Do this once, just on activatation start
        // Setup window alignment manager
        // TODO: This is not working i guess?
        var otherWindowHandlesDictionary = [Int: PWindowHandle]()
        self.windowHandles.forEach { (windowHandle) in
            guard windowHandle.windowNumber != newWindowHandle!.windowNumber else { return }
            otherWindowHandlesDictionary[windowHandle.windowNumber] = windowHandle
        }
        self.windowAlignmentManager = WindowAlignmentManager(
            selectedWindowFrame: newWindowHandle!.newRect,
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
    
    func onScrollGesture(delta: (x: CGFloat, y: CGFloat), timestamp: Double) {
        guard self.active else { return }
        guard self.selectedWindowHandle != nil else { return }
        guard self.selectedWindowHandle!.siWindow?.isMovable() ?? false else { return }
        guard self.windowAlignmentManager != nil else { return }
        
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
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .TOP_CENTER,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .TOP_CENTER)
                )
                self.selectedWindowHandle!.updateFrame(newRect)
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
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .TOP_RIGHT,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .TOP_RIGHT)
                )
                self.selectedWindowHandle!.updateFrame(newRect)
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
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .RIGHT_CENTER,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .RIGHT_CENTER)
                )
                self.selectedWindowHandle!.updateFrame(newRect)
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
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .BOTTOM_RIGHT,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .BOTTOM_RIGHT)
                )
                self.selectedWindowHandle!.updateFrame(newRect)
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
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .BOTTOM_CENTER,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .BOTTOM_CENTER)
                )
                self.selectedWindowHandle!.updateFrame(newRect)
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
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .BOTTOM_LEFT,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .BOTTOM_LEFT)
                )
                self.selectedWindowHandle!.updateFrame(newRect)
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
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .LEFT_CENTER,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .LEFT_CENTER)
                )
                self.selectedWindowHandle!.updateFrame(newRect)
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
            }
            
            if isMovable {
                let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                    anchorPoint: .TOP_LEFT,
                    toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .TOP_LEFT)
                )
                self.selectedWindowHandle!.updateFrame(newRect)
            }
        }
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
        
        if isResizable {
            let newRect = self.selectedWindowHandle!.newRect.resizeBy(
                screen: placeholderWindowScreen!,
                ratio: (
                    width: CGFloat(actions["dblClick"]![0]),
                    height: CGFloat(actions["dblClick"]![1])
                )
            )
            self.selectedWindowHandle!.updateFrame(newRect)
        }
        
        if isMovable {
            let newRect = self.selectedWindowHandle!.newRect.setPositionOf(
                anchorPoint: .CENTER,
                toPosition: placeholderWindowScreen!.visibleFrame.getPointOf(anchorPoint: .CENTER)
            )
            self.selectedWindowHandle!.updateFrame(newRect)
        }
    }
    
    func onMouseMoveGesture(position: (x: CGFloat, y: CGFloat)) {
        guard self.active else { return }
        // TODO: Throttle this
        
        let mouseX = NSEvent.mouseLocation.x
        let mouseY = NSEvent.mouseLocation.y // bottom-left origined
        
        var windowUnderCursor: PWindowHandle? = nil
        
        for windowHandle in self.windowHandles {
            if windowHandle.newRect.contains(CGPoint(x: mouseX, y: mouseY)) {
                windowUnderCursor = windowHandle
                break
            }
        }
        
        self.selectWindow(windowUnderCursor)
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



