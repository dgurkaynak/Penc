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
    let gestureOverlayWindow = GestureOverlayWindow(contentRect: CGRect(x: 0, y: 0, width: 0, height: 0), styleMask: [NSWindow.StyleMask.borderless], backing: NSWindow.BackingStoreType.buffered, defer: true)
    let placeholderWindow = PlaceholderWindow(contentRect: CGRect(x: 0, y: 0, width: 0, height: 0), styleMask: [NSWindow.StyleMask.borderless], backing: NSWindow.BackingStoreType.buffered, defer: true)
    let placeholderWindowViewController = PlaceholderWindowViewController.freshController()
    let preferencesWindowController = PreferencesWindowController.freshController()
    let aboutWindow = NSWindow(contentViewController: AboutViewController.freshController())
    var focusedWindow: SIWindow? = nil
    var selectedWindow: SIWindow? = nil
    let keyboardListener = KeyboardListener()
    var disabled = false
    let windowHelper = WindowHelper()
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
            self.gestureOverlayWindow.setDelegate(self)
            self.keyboardListener.setDelegate(self)
            
            self.setupPlaceholderWindow()
            self.setupOverlayWindow()
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
    
    func setupPlaceholderWindow() {
        self.placeholderWindow.level = .floating
        self.placeholderWindow.isOpaque = false
        self.placeholderWindow.backgroundColor = NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        self.placeholderWindow.contentViewController = self.placeholderWindowViewController
        self.placeholderWindow.delegate = self.placeholderWindowViewController
        
        self.placeholderWindowViewController.toggleWindowSizeTextField(Preferences.shared.showWindowSize)
    }
    
    func setupOverlayWindow() {
        self.gestureOverlayWindow.level = .popUpMenu
        self.gestureOverlayWindow.isOpaque = false
        self.gestureOverlayWindow.ignoresMouseEvents = false
        self.gestureOverlayWindow.contentView!.allowedTouchTypes = [.indirect]
        self.gestureOverlayWindow.backgroundColor = NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
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
        self.gestureOverlayWindow.swipeThreshold = preferences.swipeThreshold
        self.gestureOverlayWindow.reverseScroll = preferences.reverseScroll
        self.placeholderWindowViewController.toggleWindowSizeTextField(preferences.showWindowSize)
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
        
        self.focusedWindow = SIWindow.focused()
        self.selectedWindow = nil
        
        // If focused window is finder's desktop window, ignore
        if self.focusedWindow?.title() == nil {
            if let focusedApp = self.focusedWindow?.app() {
                if focusedApp.title() == "Finder" {
                    Logger.shared.debug("Desktop is focused, ignoring")
                    self.focusedWindow = nil
                }
            }
        }
        
        switch Preferences.shared.windowSelection {
        case "focused":
            self.selectedWindow = self.focusedWindow
        case "underCursor":
            var visibleWindows: [WindowInfo] = []
            
            do {
                visibleWindows = try WindowInfo.getVisibleWindows()
            } catch {
                Logger.shared.error("Not gonna activate, could not get visible windows")
                self.abortSound?.play()
                return
            }
            
            let mouseX = NSEvent.mouseLocation.x
            let mouseY = NSEvent.mouseLocation.y // bottom-left origined
            Logger.shared.debug("Looking for the window under mouse cursor -- X=\(mouseX), Y=\(mouseY)")
            
            for windowInfo in visibleWindows {
                let isInRange = (
                    x: mouseX >= windowInfo.rect.origin.x && mouseX <= (windowInfo.rect.origin.x + windowInfo.rect.size.width),
                    y: mouseY >= windowInfo.rect.origin.y && mouseY <= (windowInfo.rect.origin.y + windowInfo.rect.size.height)
                )

                if isInRange.x && isInRange.y {
                    Logger.shared.debug("Found a window: \(windowInfo)")
                    if let runningApp = NSRunningApplication.init(processIdentifier: windowInfo.appPid) {
                        let app = SIApplication.init(runningApplication: runningApp)
                        let visibleWindows = app.visibleWindows()

                        for case let win as SIWindow in visibleWindows {
                            if Int(win.windowID()) == windowInfo.windowNumber {
                                self.selectedWindow = win
                                break
                            }
                        }
                    }
                    break
                }
            }
        default:
            Logger.shared.error("Not gonna activate, unknown window selection: \(Preferences.shared.windowSelection)")
            self.abortSound?.play()
            return
        }
        
        Logger.shared.info("Activating... (Window selection: \(Preferences.shared.windowSelection) -- Focused window: \(self.focusedWindow.debugDescription) -- Selected window: \(self.selectedWindow.debugDescription))")
        
        guard self.selectedWindow != nil else {
            self.abortSound?.play()
            return
        }
        
        let selectedScreen = self.selectedWindow!.screen()
        guard selectedScreen != nil else {
            Logger.shared.info("Not gonna activate, there is no selected screen")
            self.abortSound?.play()
            return
        }
        
        if let app = NSRunningApplication.init(processIdentifier: self.selectedWindow!.processIdentifier()) {
            if let appBundleId = app.bundleIdentifier {
                if Preferences.shared.disabledApps.contains(appBundleId) {
                    Logger.shared.info("Not gonna activate, Penc is disabled for \(appBundleId)")
                    self.abortSound?.play()
                    return
                }
            }
        }
        
        self.active = true
        
        let selectedWindowRect = self.selectedWindow!.getFrameBottomLeft()
        self.placeholderWindow.setFrame(selectedWindowRect, display: true, animate: false)
        self.placeholderWindow.makeKeyAndOrderFront(self.placeholderWindow)
        
        self.placeholderWindowViewController.updateWindowSizeTextField(self.placeholderWindow.frame)
        
        self.gestureOverlayWindow.setFrame(selectedScreen!.frame, display: true, animate: false)
        self.gestureOverlayWindow.makeKeyAndOrderFront(self.gestureOverlayWindow)
        
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func onActivationCompleted() {
        guard self.active else { return }
        
        guard NSScreen.screens.indices.contains(0) else {
            Logger.shared.info("Not gonna complete activation, there is no screen -- force cancelling")
            self.onActivationAborted()
            return
        }
        
        self.selectedWindow!.setFrameBottomLeft(self.placeholderWindow.frame)
        self.focusedWindow?.focusThisWindowOnly()
        self.placeholderWindow.orderOut(self.placeholderWindow)
        self.gestureOverlayWindow.orderOut(self.gestureOverlayWindow)
        self.gestureOverlayWindow.clear()
        
        self.focusedWindow = nil
        self.selectedWindow = nil
        self.active = false
    }
    
    func onActivationAborted() {
        guard self.active else { return }
        
        Logger.shared.info("Aborted activation")
        
        self.focusedWindow?.focus()
        self.placeholderWindow.orderOut(self.placeholderWindow)
        self.gestureOverlayWindow.orderOut(self.gestureOverlayWindow)
        self.gestureOverlayWindow.clear()
        
        self.focusedWindow = nil
        self.selectedWindow = nil
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
    
    func onScrollGesture(delta: (x: CGFloat, y: CGFloat)) {
        guard self.active else { return }
        guard self.selectedWindow!.isMovable() else { return }
        
        let rect = self.windowHelper.moveWithSnappingScreenBoundaries(self.placeholderWindow, delta: delta)
        self.placeholderWindow.setFrame(rect, display: true, animate: false)
        
        self.placeholderWindowViewController.updateWindowSizeTextField(self.placeholderWindow.frame)
    }
    
    func onSwipeGesture(type: SwipeGestureType) {
        guard self.active else { return }
        guard self.placeholderWindow.screen != nil else { return }
        
        let screenNumber = self.placeholderWindow.screen?.getScreenNumber()
        guard screenNumber != nil else { return }
        let actions = Preferences.shared.getCustomActions(forScreenNumber: screenNumber!)
        
        switch (type) {
        case .SWIPE_TOP:
            if self.selectedWindow!.isResizable() {
                self.placeholderWindow.resizeBy(screenRatio: (
                    width: CGFloat(actions["top"]![0]),
                    height: CGFloat(actions["top"]![1])
                ))
            }
            
            if self.selectedWindow!.isMovable() {
                self.placeholderWindow.setPosition(
                    self.placeholderWindow.screen!.visibleFrame.getPointOf(anchorPoint: .TOP_CENTER),
                    byAnchorPoint: .TOP_CENTER
                )
            }
        case .SWIPE_TOP_RIGHT:
            if self.selectedWindow!.isResizable() {
                self.placeholderWindow.resizeBy(screenRatio: (
                    width: CGFloat(actions["topRight"]![0]),
                    height: CGFloat(actions["topRight"]![1])
                ))
            }
            
            if self.selectedWindow!.isMovable() {
                self.placeholderWindow.setPosition(
                    self.placeholderWindow.screen!.visibleFrame.getPointOf(anchorPoint: .TOP_RIGHT),
                    byAnchorPoint: .TOP_RIGHT
                )
            }
        case .SWIPE_RIGHT:
            if self.selectedWindow!.isResizable() {
                self.placeholderWindow.resizeBy(screenRatio: (
                    width: CGFloat(actions["right"]![0]),
                    height: CGFloat(actions["right"]![1])
                ))
            }
            
            if self.selectedWindow!.isMovable() {
                self.placeholderWindow.setPosition(
                    self.placeholderWindow.screen!.visibleFrame.getPointOf(anchorPoint: .RIGHT_CENTER),
                    byAnchorPoint: .RIGHT_CENTER
                )
            }
        case .SWIPE_BOTTOM_RIGHT:
            if self.selectedWindow!.isResizable() {
                self.placeholderWindow.resizeBy(screenRatio: (
                    width: CGFloat(actions["bottomRight"]![0]),
                    height: CGFloat(actions["bottomRight"]![1])
                ))
            }
            
            if self.selectedWindow!.isMovable() {
                self.placeholderWindow.setPosition(
                    self.placeholderWindow.screen!.visibleFrame.getPointOf(anchorPoint: .BOTTOM_RIGHT),
                    byAnchorPoint: .BOTTOM_RIGHT
                )
            }
        case .SWIPE_BOTTOM:
            if self.selectedWindow!.isResizable() {
                self.placeholderWindow.resizeBy(screenRatio: (
                    width: CGFloat(actions["bottom"]![0]),
                    height: CGFloat(actions["bottom"]![1])
                ))
            }
            
            if self.selectedWindow!.isMovable() {
                self.placeholderWindow.setPosition(
                    self.placeholderWindow.screen!.visibleFrame.getPointOf(anchorPoint: .BOTTOM_CENTER),
                    byAnchorPoint: .BOTTOM_CENTER
                )
            }
        case .SWIPE_BOTTOM_LEFT:
            if self.selectedWindow!.isResizable() {
                self.placeholderWindow.resizeBy(screenRatio: (
                    width: CGFloat(actions["bottomLeft"]![0]),
                    height: CGFloat(actions["bottomLeft"]![1])
                ))
            }
            
            if self.selectedWindow!.isMovable() {
                self.placeholderWindow.setPosition(
                    self.placeholderWindow.screen!.visibleFrame.getPointOf(anchorPoint: .BOTTOM_LEFT),
                    byAnchorPoint: .BOTTOM_LEFT
                )
            }
        case .SWIPE_LEFT:
            if self.selectedWindow!.isResizable() {
                self.placeholderWindow.resizeBy(screenRatio: (
                    width: CGFloat(actions["left"]![0]),
                    height: CGFloat(actions["left"]![1])
                ))
            }
            
            if self.selectedWindow!.isMovable() {
                self.placeholderWindow.setPosition(
                    self.placeholderWindow.screen!.visibleFrame.getPointOf(anchorPoint: .LEFT_CENTER),
                    byAnchorPoint: .LEFT_CENTER
                )
            }
        case .SWIPE_TOP_LEFT:
            if self.selectedWindow!.isResizable() {
                self.placeholderWindow.resizeBy(screenRatio: (
                    width: CGFloat(actions["topLeft"]![0]),
                    height: CGFloat(actions["topLeft"]![1])
                ))
            }
            
            if self.selectedWindow!.isMovable() {
                self.placeholderWindow.setPosition(
                    self.placeholderWindow.screen!.visibleFrame.getPointOf(anchorPoint: .TOP_LEFT),
                    byAnchorPoint: .TOP_LEFT
                )
            }
        }
        
        self.placeholderWindowViewController.updateWindowSizeTextField(self.placeholderWindow.frame)
    }
    
    func onMagnifyGesture(factor: (width: CGFloat, height: CGFloat)) {
        guard self.active else { return }
        guard self.selectedWindow!.isResizable() else { return }
        guard self.placeholderWindow.screen != nil else { return }
        
        self.placeholderWindow.resizeBy(factor: factor)
        
        self.placeholderWindowViewController.updateWindowSizeTextField(self.placeholderWindow.frame)
    }
    
    func onDoubleClickGesture() {
        guard self.active else { return }
        guard self.placeholderWindow.screen != nil else { return }
        
        let screenNumber = self.placeholderWindow.screen?.getScreenNumber()
        guard screenNumber != nil else { return }
        let actions = Preferences.shared.getCustomActions(forScreenNumber: screenNumber!)
        
        if self.selectedWindow!.isResizable() {
            self.placeholderWindow.resizeBy(screenRatio: (
                width: CGFloat(actions["dblClick"]![0]),
                height: CGFloat(actions["dblClick"]![1])
            ))
        }
        
        if self.selectedWindow!.isMovable() {
            self.placeholderWindow.setPosition(
                self.placeholderWindow.screen!.visibleFrame.getPointOf(anchorPoint: .CENTER),
                byAnchorPoint: .CENTER
            )
        }
        
        self.placeholderWindowViewController.updateWindowSizeTextField(self.placeholderWindow.frame)
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



