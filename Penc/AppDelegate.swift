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
import MASShortcut


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, GestureHandlerDelegate {
    
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    let gestureHandler = GestureHandler()
    let placeholderWindow = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 0, height: 0), styleMask: [NSWindow.StyleMask.borderless], backing: NSWindow.BackingStoreType.buffered, defer: true)
    let preferencesWindow = NSWindow(contentViewController: PreferencesViewController.freshController())
    var focusedWindow: SIWindow? = nil
    var focusedScreen: NSScreen? = nil
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        if let button = statusItem.button {
            button.image = NSImage(named:NSImage.Name("StatusBarButtonImage"))
        }
        
        if checkPermissions() {
            constructMenu()
            self.gestureHandler.setDelegate(self)
            self.setupPlaceholderWindow()
            self.setupPreferencesWindow()
        } else {
            let warnAlert = NSAlert();
            warnAlert.messageText = "Penc relies upon having permission to 'control your computer'. If the permission prompt did not appear automatically, go to System Preferences, Security & Privacy, Privacy, Accessibility, and add Penc to the list of allowed apps. Then relaunch Penc.";
            warnAlert.layout()
            warnAlert.runModal()
            NSApplication.shared.terminate(self)
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func constructMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Preferences", action: #selector(AppDelegate.openPreferencesWindow(_:)), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        self.statusItem.menu = menu
    }
    
    @objc func openPreferencesWindow(_ sender: Any?) {
        self.preferencesWindow.makeKeyAndOrderFront(self.preferencesWindow)
        NSApplication.shared.activate(ignoringOtherApps: true)
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
    
    func setupPlaceholderWindow() {
        self.placeholderWindow.level = .floating
        self.placeholderWindow.isOpaque = false
        self.placeholderWindow.backgroundColor = NSColor(calibratedRed: 0.0, green: 1.0, blue: 0.0, alpha: 0.25)
    }
    
    func setupPreferencesWindow() {
        self.preferencesWindow.title = "Penc Preferences"
        self.preferencesWindow.styleMask.remove(.resizable)
        self.preferencesWindow.styleMask.remove(.miniaturizable)

    }
    
    func onGestureBegan(gestureHandler: GestureHandler) {
        self.focusedWindow = SIWindow.focused()
        if self.focusedWindow == nil { return }
        self.focusedScreen = self.focusedWindow!.screen()
        if self.focusedScreen == nil { return }
        let rect = self.focusedWindow!.frame()
        let newRect = rect.topLeft2bottomLeft(self.focusedScreen!)
        placeholderWindow.setFrame(newRect, display: true, animate: false)
    }
    
    func onGestureChanged(gestureHandler: GestureHandler, type: GestureType, delta: (x: CGFloat, y: CGFloat)?) {
        if self.focusedWindow == nil { return }
        if self.focusedScreen == nil { return }
        
        var rect: CGRect? = nil
        
        if type == .RESIZE && self.focusedWindow!.isResizable() && delta != nil {
            rect = CGRect(
                x: self.placeholderWindow.frame.origin.x + delta!.x,
                y: self.placeholderWindow.frame.origin.y + delta!.y,
                width: self.placeholderWindow.frame.size.width - (delta!.x * 2),
                height: self.placeholderWindow.frame.size.height - (delta!.y * 2)
            ).fitInVisibleFrame(self.focusedScreen!)
        } else if type == .MOVE && self.focusedWindow!.isMovable() && delta != nil {
            rect = CGRect(
                x: self.placeholderWindow.frame.origin.x - delta!.x,
                y: self.placeholderWindow.frame.origin.y + delta!.y,
                width: self.placeholderWindow.frame.size.width,
                height: self.placeholderWindow.frame.size.height
            ).fitInVisibleFrame(self.focusedScreen!)
        } else if self.focusedWindow!.isMovable() && [GestureType.SWIPE_TOP, GestureType.SWIPE_BOTTOM].contains(type) {
            let newHeight = self.focusedScreen!.visibleFrame.height / 2
            rect = CGRect(
                x: self.focusedScreen!.visibleFrame.origin.x,
                y: self.focusedScreen!.visibleFrame.origin.y + (type == .SWIPE_TOP ? newHeight : 0),
                width: self.focusedScreen!.visibleFrame.width,
                height: newHeight
            )
        } else if self.focusedWindow!.isMovable() && [GestureType.SWIPE_LEFT, GestureType.SWIPE_RIGHT].contains(type) {
            let newWidth = self.focusedScreen!.visibleFrame.width / 2
            rect = CGRect(
                x: self.focusedScreen!.visibleFrame.origin.x + (type == .SWIPE_RIGHT ? newWidth : 0),
                y: self.focusedScreen!.visibleFrame.origin.y,
                width: newWidth,
                height: self.focusedScreen!.visibleFrame.height
            )
        } else if self.focusedWindow!.isMovable() && [GestureType.SWIPE_TOP_LEFT, GestureType.SWIPE_TOP_RIGHT, GestureType.SWIPE_BOTTOM_LEFT, GestureType.SWIPE_BOTTOM_RIGHT].contains(type) {
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
            self.placeholderWindow.makeKeyAndOrderFront(self.placeholderWindow)
        }
    }
    
    func onGestureEnded(gestureHandler: GestureHandler) {
        if self.focusedWindow == nil { return }
        if self.focusedScreen == nil { return }
        
        let newRect = self.placeholderWindow.frame.topLeft2bottomLeft(self.focusedScreen!)
        self.focusedWindow!.setFrame(newRect)
        self.placeholderWindow.orderOut(self.placeholderWindow)
    }
    
    
}



