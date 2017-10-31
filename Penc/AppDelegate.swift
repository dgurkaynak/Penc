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
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        if let button = statusItem.button {
            button.image = NSImage(named:NSImage.Name("StatusBarButtonImage"))
        }
        
        if checkPermissions() {
            constructMenu()
            listenEvents()
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
    
    func listenEvents() {
        var deltaX: CGFloat = 0
        var deltaY: CGFloat = 0
        var pressedModifierKeys = NSEvent.ModifierFlags.init(rawValue: 0)
        var active = false
        
        var placeholderWindow = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 0, height: 0), styleMask: [NSWindow.StyleMask.borderless], backing: NSWindow.BackingStoreType.buffered, defer: true)
        placeholderWindow.level = .floating
        placeholderWindow.isOpaque = false
        placeholderWindow.backgroundColor = NSColor(calibratedRed: 0.0, green: 1.0, blue: 0.0, alpha: 0.25)
        
        // [.shift] [.control] [.option] [.command]
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { (event) in
            pressedModifierKeys = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            if pressedModifierKeys.rawValue == 0 {
                placeholderWindow.orderOut(placeholderWindow)
                
                if active, let focusedWindow = SIWindow.focused() {
                    let screen = focusedWindow.screen()!
                    focusedWindow.setFrame(CGRect(x: placeholderWindow.frame.origin.x, y: screen.frame.height - placeholderWindow.frame.height - placeholderWindow.frame.origin.y, width: placeholderWindow.frame.width, height: placeholderWindow.frame.height))
                    placeholderWindow.orderOut(placeholderWindow)
                    
                    active = false
                }
            }
        }
        
        NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { (event) in
            guard let focusedWindow = SIWindow.focused() else {
                return
            }
            
            if pressedModifierKeys != [.command] && pressedModifierKeys != [.command, .option] {
                return
            }
            
            if event.phase == NSEvent.Phase.began {
                deltaX = 0
                deltaY = 0
                active = true
                
                let screen = focusedWindow.screen()!
                let rect = focusedWindow.frame()
                placeholderWindow.setFrame(CGRect(x: rect.origin.x, y: screen.frame.height - rect.height - rect.origin.y, width: rect.width, height: rect.height), display: true, animate: false)
                
            } else if event.phase == NSEvent.Phase.cancelled {
                deltaX = 0
                deltaY = 0
                active = false
                
                placeholderWindow.orderOut(placeholderWindow)
            } else if event.phase == NSEvent.Phase.changed {
                if !active {
                    return
                }
                
                deltaX = deltaX + event.scrollingDeltaX
                deltaY = deltaY + event.scrollingDeltaY
                
                if pressedModifierKeys == [.command, .option] && focusedWindow.isResizable() {
                    let rect = placeholderWindow.frame
                    placeholderWindow.setFrame(CGRect(x: rect.origin.x, y: rect.origin.y + event.scrollingDeltaY, width: rect.size.width - event.scrollingDeltaX, height: rect.size.height - event.scrollingDeltaY), display: true, animate: false)
                    placeholderWindow.makeKeyAndOrderFront(placeholderWindow)
                }
                
                if pressedModifierKeys == [.command] && focusedWindow.isMovable() {
                    let rect = placeholderWindow.frame
                    placeholderWindow.setFrame(CGRect(x: rect.origin.x - event.scrollingDeltaX, y: rect.origin.y + event.scrollingDeltaY, width: rect.size.width, height: rect.size.height), display: true, animate: false)
                    placeholderWindow.makeKeyAndOrderFront(placeholderWindow)
                }
            } else if event.phase == NSEvent.Phase.ended {
                deltaX = 0
                deltaY = 0
                active = false
                
                let screen = focusedWindow.screen()!
                focusedWindow.setFrame(CGRect(x: placeholderWindow.frame.origin.x, y: screen.frame.height - placeholderWindow.frame.height - placeholderWindow.frame.origin.y, width: placeholderWindow.frame.width, height: placeholderWindow.frame.height))
                placeholderWindow.orderOut(placeholderWindow)
            }
            
            //            print(deltaX, deltaY)
            
        }
    }
    
    
}



