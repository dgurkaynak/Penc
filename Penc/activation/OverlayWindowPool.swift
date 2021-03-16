//
//  OverlayWindowPool.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 31.01.2021.
//  Copyright © 2021 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa

internal typealias OverlayWindowPoolItem = (
    bg: NSWindow,
    gesture: GestureOverlayWindow
)

class OverlayWindowPool {
    static let shared = OverlayWindowPool()
    
    private var all = [OverlayWindowPoolItem]()
    private var avaliable = [OverlayWindowPoolItem]()
    
    func forEach(_ predicate: (OverlayWindowPoolItem) -> ()) {
        self.all.forEach { (item) in
            predicate(item)
        }
    }
    
    private func create() -> OverlayWindowPoolItem {
        // Create background overlay window
        let bgOverlayWindow = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 0, height: 0), styleMask: [NSWindow.StyleMask.borderless], backing: NSWindow.BackingStoreType.buffered, defer: true)
        
        bgOverlayWindow.level = .popUpMenu
        bgOverlayWindow.isOpaque = false
        self.updateBackgroundOverlayWindowStyle(bgOverlayWindow)
        
        // Create gesture overlay window
        let gestureOverlayWindow = GestureOverlayWindow(contentRect: CGRect(x: 0, y: 0, width: 0, height: 0), styleMask: [NSWindow.StyleMask.borderless], backing: NSWindow.BackingStoreType.buffered, defer: true)
        
        gestureOverlayWindow.scrollSwipeDetectionVelocityThreshold = Preferences.shared.swipeDetectionVelocityThreshold
        
        gestureOverlayWindow.level = .popUpMenu
        gestureOverlayWindow.isOpaque = false
        gestureOverlayWindow.ignoresMouseEvents = false
        gestureOverlayWindow.acceptsMouseMovedEvents = true
        gestureOverlayWindow.contentView!.allowedTouchTypes = [.indirect]
        gestureOverlayWindow.backgroundColor = NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        
        // Save the item
        let item = (bg: bgOverlayWindow, gesture: gestureOverlayWindow)
        self.all.append(item)
        
        return item
    }
    
    func updateAllBackgroundOverlayWindowStyles() {
        self.all.forEach { (item) in
            self.updateBackgroundOverlayWindowStyle(item.bg)
        }
    }
    
    private func updateBackgroundOverlayWindowStyle(_ bgOverlayWindow: NSWindow) {
        bgOverlayWindow.contentView?.subviews = []
        
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency && !Preferences.shared.disableBackgroundBlur {
            let blurView = NSVisualEffectView(frame: bgOverlayWindow.frame)
            blurView.blendingMode = .behindWindow
            blurView.material = .dark
            blurView.state = .active
            blurView.autoresizingMask = [.width, .height]
            bgOverlayWindow.contentView?.addSubview(blurView)
        } else {
            bgOverlayWindow.backgroundColor = NSColor(white: 0.15, alpha: 0.8)
        }
    }
    
    func acquire() -> OverlayWindowPoolItem {
        if self.avaliable.isEmpty {
            return self.create()
        }
        
        return self.avaliable.removeLast()
    }
    
    func release(_ item: OverlayWindowPoolItem) {
        // Remove gestureWindow's delegate, just in case
        item.gesture.setDelegate(nil)
        
        self.avaliable.append(item)
    }
}
