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
import SwiftyBeaver
import Sparkle


let log = SwiftyBeaver.self

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, GestureOverlayWindowDelegate, ActivationHandlerDelegate, PreferencesDelegate, NSMenuDelegate {
    
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    let gestureOverlayWindow = GestureOverlayWindow(contentRect: CGRect(x: 0, y: 0, width: 0, height: 0), styleMask: [NSWindow.StyleMask.borderless], backing: NSWindow.BackingStoreType.buffered, defer: true)
    let placeholderWindow = PlaceholderWindow(contentRect: CGRect(x: 0, y: 0, width: 0, height: 0), styleMask: [NSWindow.StyleMask.borderless], backing: NSWindow.BackingStoreType.buffered, defer: true)
    let placeholderWindowViewController = PlaceholderWindowViewController.freshController()
    let preferencesWindow = NSWindow(contentViewController: PreferencesViewController.freshController())
    let aboutWindow = NSWindow(contentViewController: AboutViewController.freshController())
    var focusedWindow: SIWindow? = nil
    var selectedWindow: SIWindow? = nil
    let activationHandler = ActivationHandler()
    var disabled = false
    let windowHelper = WindowHelper()
    var active = false
    var updater = SUUpdater()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        if !Env.isProduction() {
            let console = ConsoleDestination()
            console.format = "$DHH:mm:ss.SSS$d $C$L$c: $M"
            console.asynchronously = false
            log.addDestination(console)
        }
    
        let file = FileDestination()
        file.format = "$Dyyyy-MM-dd HH:mm:ss.SSS$d $C$L$c: $M"
        file.logFileURL = URL(fileURLWithPath: "/tmp/penc.log")
//        file.asynchronously = false
        log.addDestination(file)
        
        log.info("Booting...")
        
        let launcherAppId = "com.denizgurkaynak.PencLauncher"
        let runningApps = NSWorkspace.shared.runningApplications
        let isLauncherRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty
        if isLauncherRunning {
            log.debug("Launcher is running, killing it...")
            DistributedNotificationCenter.default().post(name: .killLauncher, object: Bundle.main.bundleIdentifier!)
        }
        
        if let button = self.statusItem.button {
            button.image = NSImage(named:NSImage.Name("penc-menu-icon"))
        }
        
        log.info("Checking accessibility permissions...")
        
        if checkPermissions() {
            constructMenu()
            Preferences.shared.setDelegate(self)
            self.gestureOverlayWindow.setDelegate(self)
            self.activationHandler.setDelegate(self)
            
            self.setupPlaceholderWindow()
            self.setupOverlayWindow()
            self.setupPreferencesWindow()
            self.setupAboutWindow()
            self.onPreferencesChanged(preferences: Preferences.shared)
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
            log.info("We're trusted accessibility client")
            return true
        } else {
            let options = NSDictionary(object: kCFBooleanTrue, forKey: kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString) as CFDictionary
            let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
            log.warning("We're NOT trusted accessibility client, manual check result: \(accessibilityEnabled)")
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
    }
    
    func setupOverlayWindow() {
        self.gestureOverlayWindow.level = .popUpMenu
        self.gestureOverlayWindow.isOpaque = false
        self.gestureOverlayWindow.ignoresMouseEvents = false
        self.gestureOverlayWindow.contentView!.allowedTouchTypes = [.indirect]
        self.gestureOverlayWindow.backgroundColor = NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    }
    
    func setupPreferencesWindow() {
        self.preferencesWindow.title = "Penc Preferences"
        self.preferencesWindow.styleMask.remove(.resizable)
        self.preferencesWindow.styleMask.remove(.miniaturizable)
    }
    
    @objc func openPreferencesWindow(_ sender: Any?) {
        self.preferencesWindow.makeKeyAndOrderFront(self.preferencesWindow)
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
    
    func onPreferencesChanged(preferences: Preferences) {
        self.activationHandler.activationModifierKey = preferences.activationModifierKey
        self.activationHandler.activationTimeout = Double(preferences.activationSensitivity)
        self.gestureOverlayWindow.swipeThreshold = preferences.swipeThreshold
        self.gestureOverlayWindow.reverseScroll = preferences.reverseScroll
    }
    
    func onActivated(activationHandler: ActivationHandler) {
        guard !self.disabled else {
            log.info("Not gonna activate, Penc is disabled globally")
            return
        }
        
        guard NSScreen.screens.indices.contains(0) else {
            log.info("Not gonna activate, there is no screen at all")
            return
        }
        
        self.focusedWindow = SIWindow.focused()
        self.selectedWindow = nil
        
        // If focused window is finder's desktop window, ignore
        if self.focusedWindow?.title() == nil {
            if let focusedApp = self.focusedWindow?.app() {
                if focusedApp.title() == "Finder" {
                    log.debug("Desktop is focused, ignoring")
                    self.focusedWindow = nil
                }
            }
        }
        
        switch Preferences.shared.windowSelection {
        case "focused":
            self.selectedWindow = self.focusedWindow
        case "underCursor":
            let visibleWindowsInfo = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
            guard visibleWindowsInfo != nil else {
                log.error("Not gonna activate, visible windows returned nil")
                return
            }
            
            let mouseX = NSEvent.mouseLocation.x
            let mouseY = NSEvent.mouseLocation.y
            log.debug("Looking for the window under mouse cursor -- X=\(mouseX), Y=\(mouseY)")
            
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
                let windowY = windowBounds!["Y"] as? Int
                
                guard windowWidth != nil else { continue }
                guard windowHeight != nil else { continue }
                guard windowX != nil else { continue }
                guard windowY != nil else { continue }
                
                let rect = CGRect(x: windowX!, y: windowY!, width: windowWidth!, height: windowHeight!).topLeft2bottomLeft(NSScreen.screens[0])
                let isInRange = (
                    x: mouseX >= rect.origin.x && mouseX <= (rect.origin.x + rect.size.width),
                    y: mouseY >= rect.origin.y && mouseY <= (rect.origin.y + rect.size.height)
                )

                if isInRange.x && isInRange.y {
                    log.debug("Found a window: \(windowInfo)")
                    if let runningApp = NSRunningApplication.init(processIdentifier: appPid!) {
                        let app = SIApplication.init(runningApplication: runningApp)
                        let visibleWindows = app.visibleWindows()

                        for case let win as SIWindow in visibleWindows {
                            if Int(win.windowID()) == windowNumber {
                                self.selectedWindow = win
                                break
                            }
                        }
                    }
                    break
                }
            }
        default:
            log.error("Not gonna activate, unknown window selection: \(Preferences.shared.windowSelection)")
            return
        }
        
        log.info("Activating... (Window selection: \(Preferences.shared.windowSelection) -- Focused window: \(self.focusedWindow.debugDescription) -- Selected window: \(self.selectedWindow.debugDescription))")
        
        guard self.selectedWindow != nil else {
            return
        }
        
        let selectedScreen = self.selectedWindow!.screen()
        guard selectedScreen != nil else {
            log.info("Not gonna activate, there is no selected screen")
            return
        }
        
        if let app = NSRunningApplication.init(processIdentifier: self.selectedWindow!.processIdentifier()) {
            if let appBundleId = app.bundleIdentifier {
                if Preferences.shared.disabledApps.contains(appBundleId) {
                    log.info("Not gonna activate, Penc is disabled for \(appBundleId)")
                    return
                }
            }
        }
        
        self.active = true
        
        let selectedWindowRect = self.selectedWindow!.frame().topLeft2bottomLeft(NSScreen.screens[0])
        self.placeholderWindow.setFrame(selectedWindowRect, display: true, animate: false)
        self.placeholderWindow.makeKeyAndOrderFront(self.placeholderWindow)
        
        self.gestureOverlayWindow.setFrame(selectedScreen!.frame, display: true, animate: false)
        self.gestureOverlayWindow.makeKeyAndOrderFront(self.gestureOverlayWindow)
        
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func onCompleted(activationHandler: ActivationHandler) {
        guard self.active else { return }
        
        guard NSScreen.screens.indices.contains(0) else {
            log.info("Not gonna complete activation, there is no screen -- force cancelling")
            self.onCancelled(activationHandler: activationHandler)
            return
        }
        
        let newRect = self.placeholderWindow.frame.topLeft2bottomLeft(NSScreen.screens[0])
        self.selectedWindow!.setFrame(newRect)
        self.focusedWindow?.focus()
        self.placeholderWindow.orderOut(self.placeholderWindow)
        self.gestureOverlayWindow.orderOut(self.gestureOverlayWindow)
        self.gestureOverlayWindow.clear()
        
        self.focusedWindow = nil
        self.selectedWindow = nil
        self.active = false
    }
    
    func onCancelled(activationHandler: ActivationHandler) {
        guard self.active else { return }
        
        log.info("Cancelled activation")
        
        self.focusedWindow?.focus()
        self.placeholderWindow.orderOut(self.placeholderWindow)
        self.gestureOverlayWindow.orderOut(self.gestureOverlayWindow)
        self.gestureOverlayWindow.clear()
        
        self.focusedWindow = nil
        self.selectedWindow = nil
        self.active = false
    }
    
    func onMoveGesture(gestureOverlayWindow: GestureOverlayWindow, delta: (x: CGFloat, y: CGFloat)) {
        guard self.active else { return }
        guard self.selectedWindow!.isMovable() else { return }
        
        let rect = self.windowHelper.moveWithSnappingScreenBoundaries(self.placeholderWindow, delta: delta)
        self.placeholderWindow.setFrame(rect, display: true, animate: false)
    }
    
    func onSwipeGesture(gestureOverlayWindow: GestureOverlayWindow, type: GestureType) {
        guard self.active else { return }
        guard self.selectedWindow!.isMovable() else { return }
        guard self.placeholderWindow.screen != nil else { return }
        
        var rect: CGRect? = nil
        
        if self.selectedWindow!.isResizable() {
            if [GestureType.SWIPE_TOP, GestureType.SWIPE_BOTTOM].contains(type) {
                rect = self.windowHelper.resizeToScreenWidth(self.placeholderWindow, frame: rect, factor: 1.0)
                rect = self.windowHelper.resizeToScreenHeight(self.placeholderWindow, frame: rect, factor: 0.5)
            } else if [GestureType.SWIPE_LEFT, GestureType.SWIPE_RIGHT].contains(type) {
                rect = self.windowHelper.resizeToScreenWidth(self.placeholderWindow, frame: rect, factor: 0.5)
                rect = self.windowHelper.resizeToScreenHeight(self.placeholderWindow, frame: rect, factor: 1.0)
            } else if [GestureType.SWIPE_TOP_LEFT, GestureType.SWIPE_TOP_RIGHT, GestureType.SWIPE_BOTTOM_LEFT, GestureType.SWIPE_BOTTOM_RIGHT].contains(type) {
                rect = self.windowHelper.resizeToScreenWidth(self.placeholderWindow, frame: rect, factor: 0.5)
                rect = self.windowHelper.resizeToScreenHeight(self.placeholderWindow, frame: rect, factor: 0.5)
            }
        }
        
        switch type {
        case .SWIPE_TOP, .SWIPE_LEFT, .SWIPE_TOP_LEFT:
            rect = self.windowHelper.snapToTopOfScreen(self.placeholderWindow, frame: rect)
            rect = self.windowHelper.snapToLeftOfScreen(self.placeholderWindow, frame: rect)
        case .SWIPE_BOTTOM, .SWIPE_BOTTOM_LEFT:
            rect = self.windowHelper.snapToBottomOfScreen(self.placeholderWindow, frame: rect)
            rect = self.windowHelper.snapToLeftOfScreen(self.placeholderWindow, frame: rect)
        case .SWIPE_RIGHT, .SWIPE_TOP_RIGHT:
            rect = self.windowHelper.snapToTopOfScreen(self.placeholderWindow, frame: rect)
            rect = self.windowHelper.snapToRightOfScreen(self.placeholderWindow, frame: rect)
        case .SWIPE_BOTTOM_RIGHT:
            rect = self.windowHelper.snapToBottomOfScreen(self.placeholderWindow, frame: rect)
            rect = self.windowHelper.snapToRightOfScreen(self.placeholderWindow, frame: rect)
        default:
            log.error("Unsupported swipe type: \(type)")
        }
        
        if rect != nil {
            self.placeholderWindow.setFrame(rect!, display: true, animate: false)
        }
    }
    
    func onResizeFactorGesture(gestureOverlayWindow: GestureOverlayWindow, factor: (x: CGFloat, y: CGFloat)) {
        guard self.active else { return }
        guard self.selectedWindow!.isResizable() else { return }
        guard self.placeholderWindow.screen != nil else { return }
        
        let rect = self.windowHelper.resize(self.placeholderWindow, factor: factor)
        self.placeholderWindow.setFrame(rect, display: true, animate: false)
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
        log.info(self.disabled ? "Disabled globally" : "Enabled globally")
    }
    
    @objc func toggleDisableApp(_ sender: Any?) {
        if let app = NSWorkspace.shared.frontmostApplication {
            if let appBundleId = app.bundleIdentifier {
                if Preferences.shared.disabledApps.contains(appBundleId) {
                    let i = Preferences.shared.disabledApps.index(of: appBundleId)
                    Preferences.shared.disabledApps.remove(at: i!)
                    log.info("Enabled back for \(appBundleId)")
                } else {
                    Preferences.shared.disabledApps.append(appBundleId)
                    log.info("Disabled for \(appBundleId)")
                }
                
                Preferences.shared.disabledApps = Preferences.shared.disabledApps
            }
        }
    }
    
    @objc func checkForUpdates(_ sender: Any?) {
        log.info("Checking for updates")
        self.updater.checkForUpdates(nil)
    }
    
}



