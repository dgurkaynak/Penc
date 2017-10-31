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
class AppDelegate: NSObject, NSApplicationDelegate, GestureHandlerDelegate {
    
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    let gestureHandler = GestureHandler()
    let placeholderWindow = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 0, height: 0), styleMask: [NSWindow.StyleMask.borderless], backing: NSWindow.BackingStoreType.buffered, defer: true)
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
        } else {
            let warnAlert = NSAlert();
            warnAlert.messageText = "Resizr relies upon having permission to 'control your computer'. If the permission prompt did not appear automatically, go to System Preferences, Security & Privacy, Privacy, Accessibility, and add Resizr to the list of allowed apps. Then relaunch Resizr.";
            warnAlert.layout()
            warnAlert.runModal()
            NSApplication.shared.terminate(self)
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    @objc func printQuote(_ sender: Any?) {
        let quoteText = "Never put off until tomorrow what you can do the day after tomorrow."
        let quoteAuthor = "Mark Twain"
        
        print("\(quoteText) — \(quoteAuthor)")
    }
    
    func constructMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Print Quote", action: #selector(AppDelegate.printQuote(_:)), keyEquivalent: "P"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
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
        placeholderWindow.level = .floating
        placeholderWindow.isOpaque = false
        placeholderWindow.backgroundColor = NSColor(calibratedRed: 0.0, green: 1.0, blue: 0.0, alpha: 0.25)
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
        
        if type == .RESIZE_ANCHOR_TOP_LEFT && self.focusedWindow!.isResizable() && delta != nil {
            let rect = self.placeholderWindow.frame
            let newRect = CGRect(x: rect.origin.x, y: rect.origin.y + delta!.y, width: rect.size.width - delta!.x, height: rect.size.height - delta!.y)
            self.placeholderWindow.setFrame(newRect, display: true, animate: false)
            self.placeholderWindow.makeKeyAndOrderFront(self.placeholderWindow)
        }
        
        if type == .MOVE && self.focusedWindow!.isMovable() && delta != nil {
            let rect = self.placeholderWindow.frame
            let newRect = CGRect(x: rect.origin.x - delta!.x, y: rect.origin.y + delta!.y, width: rect.size.width, height: rect.size.height)
            self.placeholderWindow.setFrame(newRect, display: true, animate: false)
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



