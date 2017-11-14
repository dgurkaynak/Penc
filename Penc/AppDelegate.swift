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


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, GestureOverlayWindowDelegate, ActivationHandlerDelegate, PreferencesDelegate, NSMenuDelegate {
    
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    let gestureOverlayWindow = GestureOverlayWindow(contentRect: CGRect(x: 0, y: 0, width: 0, height: 0), styleMask: [NSWindow.StyleMask.borderless], backing: NSWindow.BackingStoreType.buffered, defer: true)
    let placeholderWindow = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 0, height: 0), styleMask: [NSWindow.StyleMask.borderless], backing: NSWindow.BackingStoreType.buffered, defer: true)
    let placeholderWindowViewController = PlaceholderWindowViewController.freshController()
    let preferencesWindow = NSWindow(contentViewController: PreferencesViewController.freshController())
    let aboutWindow = NSWindow(contentViewController: AboutViewController.freshController())
    var focusedWindow: SIWindow? = nil
    var focusedScreen: NSScreen? = nil
    let activationHandler = ActivationHandler()
    var disabled = false
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        if let button = self.statusItem.button {
            button.image = NSImage(named:NSImage.Name("penc-menu-icon"))
        }
        
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
            return true
        } else {
            let options = NSDictionary(object: kCFBooleanTrue, forKey: kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString) as CFDictionary
            
            let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
            return accessibilityEnabled
        }
    }
    
    func constructMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        let aboutMenuItem = NSMenuItem(title: "About Penc", action: #selector(AppDelegate.openAboutWindow(_:)), keyEquivalent: "")
        menu.addItem(aboutMenuItem)
        
        let checkForUpdatesMenuItem = NSMenuItem(title: "Check for updates", action: #selector(AppDelegate.openAboutWindow(_:)), keyEquivalent: "")
        checkForUpdatesMenuItem.isEnabled = false
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
        self.gestureOverlayWindow.shouldInferMagnificationAngle = preferences.inferMagnificationAngle
        self.gestureOverlayWindow.swipeThreshold = preferences.swipeThreshold
        self.placeholderWindowViewController.changeMode(preferences.showGestureInfo ? .MOVE : .NONE)
    }
    
    func onActivated(activationHandler: ActivationHandler) {
        guard !self.disabled else { return }
        self.focusedWindow = SIWindow.focused()
        guard self.focusedWindow != nil else { return }
        self.focusedScreen = self.focusedWindow!.screen()
        guard self.focusedScreen != nil else { return }
        guard self.focusedWindow!.frame() != self.focusedScreen!.frame else { return } // fullscreen
        if let app = NSWorkspace.shared.frontmostApplication {
            if let appBundleId = app.bundleIdentifier {
                if Preferences.shared.disabledApps.contains(appBundleId) { return }
            }
        }
        
        let focusedWindowRect = self.focusedWindow!.frame().topLeft2bottomLeft(self.focusedScreen!)
        self.placeholderWindow.setFrame(focusedWindowRect, display: true, animate: false)
        self.placeholderWindow.makeKeyAndOrderFront(self.placeholderWindow)
        
        let focusedScreenRect = self.focusedScreen!.frame.topLeft2bottomLeft(self.focusedScreen!)
        self.gestureOverlayWindow.setFrame(focusedScreenRect, display: true, animate: false)
        self.gestureOverlayWindow.makeKeyAndOrderFront(self.gestureOverlayWindow)
        
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func onDeactivated(activationHandler: ActivationHandler) {
        guard !self.disabled else { return }
        guard self.focusedWindow != nil else { return }
        guard self.focusedScreen != nil else { return }
        if let app = NSWorkspace.shared.frontmostApplication {
            if let appBundleId = app.bundleIdentifier {
                if Preferences.shared.disabledApps.contains(appBundleId) { return }
            }
        }
        
        let newRect = self.placeholderWindow.frame.topLeft2bottomLeft(self.focusedScreen!)
        self.focusedWindow!.setFrame(newRect)
        self.focusedWindow!.focus()
        self.placeholderWindow.orderOut(self.placeholderWindow)
        self.gestureOverlayWindow.orderOut(self.gestureOverlayWindow)
        self.gestureOverlayWindow.clear()
        
        self.focusedWindow = nil
        self.focusedScreen = nil
    }
    
    func onMoveGesture(gestureOverlayWindow: GestureOverlayWindow, delta: (x: CGFloat, y: CGFloat)) {
        guard self.focusedWindow != nil else { return }
        guard self.focusedScreen != nil else { return }
        guard self.focusedWindow!.isMovable() else { return }
        guard self.focusedWindow!.frame() != self.focusedScreen!.frame else { return } // fullscreen
        
        let rect = CGRect(
            x: self.placeholderWindow.frame.origin.x - delta.x,
            y: self.placeholderWindow.frame.origin.y + delta.y,
            width: self.placeholderWindow.frame.size.width,
            height: self.placeholderWindow.frame.size.height
        ).fitInVisibleFrame(self.focusedScreen!)
        
        self.placeholderWindow.setFrame(rect, display: true, animate: false)
    }
    
    func onSwipeGesture(gestureOverlayWindow: GestureOverlayWindow, type: GestureType) {
        guard self.focusedWindow != nil else { return }
        guard self.focusedScreen != nil else { return }
        guard self.focusedWindow!.isMovable() else { return } // TODO: Check resizeable also
        guard self.focusedWindow!.frame() != self.focusedScreen!.frame else { return } // fullscreen
        
        var rect: CGRect? = nil
        
        if [GestureType.SWIPE_TOP, GestureType.SWIPE_BOTTOM].contains(type) {
            let newHeight = self.focusedScreen!.visibleFrame.height / 2
            rect = CGRect(
                x: self.focusedScreen!.visibleFrame.origin.x,
                y: self.focusedScreen!.visibleFrame.origin.y + (type == .SWIPE_TOP ? newHeight : 0),
                width: self.focusedScreen!.visibleFrame.width,
                height: newHeight
            )
        } else if [GestureType.SWIPE_LEFT, GestureType.SWIPE_RIGHT].contains(type) {
            let newWidth = self.focusedScreen!.visibleFrame.width / 2
            rect = CGRect(
                x: self.focusedScreen!.visibleFrame.origin.x + (type == .SWIPE_RIGHT ? newWidth : 0),
                y: self.focusedScreen!.visibleFrame.origin.y,
                width: newWidth,
                height: self.focusedScreen!.visibleFrame.height
            )
        } else if [GestureType.SWIPE_TOP_LEFT, GestureType.SWIPE_TOP_RIGHT, GestureType.SWIPE_BOTTOM_LEFT, GestureType.SWIPE_BOTTOM_RIGHT].contains(type) {
            let newHeight = self.focusedScreen!.visibleFrame.height / 2
            let newWidth = self.focusedScreen!.visibleFrame.width / 2
            rect = CGRect(
                x: self.focusedScreen!.visibleFrame.origin.x + (type == .SWIPE_TOP_RIGHT || type == .SWIPE_BOTTOM_RIGHT ? newWidth : 0),
                y: self.focusedScreen!.visibleFrame.origin.y + (type == .SWIPE_TOP_LEFT || type == .SWIPE_TOP_RIGHT ? newHeight : 0),
                width: newWidth,
                height: newHeight
            )
        }
        
        if rect != nil {
            self.placeholderWindow.setFrame(rect!, display: true, animate: false)
        }
    }
    
    func onResizeDeltaGesture(gestureOverlayWindow: GestureOverlayWindow, delta: (x: CGFloat, y: CGFloat)) {
        guard self.focusedWindow != nil else { return }
        guard self.focusedScreen != nil else { return }
        guard self.focusedWindow!.isResizable() else { return }
        guard self.focusedWindow!.frame() != self.focusedScreen!.frame else { return } // fullscreen
        
        let rect = CGRect(
            x: self.placeholderWindow.frame.origin.x + delta.x,
            y: self.placeholderWindow.frame.origin.y + delta.y,
            width: self.placeholderWindow.frame.size.width - (delta.x * 2),
            height: self.placeholderWindow.frame.size.height - (delta.y * 2)
        ).fitInVisibleFrame(self.focusedScreen!)
        
        self.placeholderWindow.setFrame(rect, display: true, animate: false)
    }
    
    func onResizeFactorGesture(gestureOverlayWindow: GestureOverlayWindow, factor: (x: CGFloat, y: CGFloat)) {
        guard self.focusedWindow != nil else { return }
        guard self.focusedScreen != nil else { return }
        guard self.focusedWindow!.isResizable() else { return }
        guard self.focusedWindow!.frame() != self.focusedScreen!.frame else { return } // fullscreen
        
        let delta = (
            x: self.placeholderWindow.frame.size.width * factor.x,
            y: self.placeholderWindow.frame.size.height * factor.y
        )
        let rect = CGRect(
            x: self.placeholderWindow.frame.origin.x + delta.x,
            y: self.placeholderWindow.frame.origin.y + delta.y,
            width: self.placeholderWindow.frame.size.width - (delta.x * 2),
            height: self.placeholderWindow.frame.size.height - (delta.y * 2)
            ).fitInVisibleFrame(self.focusedScreen!)
        
        self.placeholderWindow.setFrame(rect, display: true, animate: false)
    }
    
    func onModeChange(gestureOverlayWindow: GestureOverlayWindow, mode: GestureMode) {
        guard self.placeholderWindowViewController.mode != .NONE else { return }
        
        if mode == .MOVE {
            self.placeholderWindowViewController.changeMode(.MOVE)
        } else if mode == .RESIZE {
            self.placeholderWindowViewController.changeMode(.RESIZE)
        }
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
    }
    
    @objc func toggleDisableApp(_ sender: Any?) {
        if let app = NSWorkspace.shared.frontmostApplication {
            if let appBundleId = app.bundleIdentifier {
                if Preferences.shared.disabledApps.contains(appBundleId) {
                    let i = Preferences.shared.disabledApps.index(of: appBundleId)
                    Preferences.shared.disabledApps.remove(at: i!)
                } else {
                    Preferences.shared.disabledApps.append(appBundleId)
                }
                
                Preferences.shared.disabledApps = Preferences.shared.disabledApps
            }
        }
    }
    
    
}



