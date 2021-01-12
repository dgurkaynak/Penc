//
//  PlaceholderPool.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 11.01.2021.
//  Copyright © 2021 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa

class PlaceholderPool {
    static let shared = PlaceholderPool()
    
    private var pool = [(window: PlaceholderWindow, windowViewController: PlaceholderWindowViewController)]()
    
    private func create() -> (window: PlaceholderWindow, windowViewController: PlaceholderWindowViewController) {
        let window = PlaceholderWindow(contentRect: CGRect(x: 0, y: 0, width: 0, height: 0), styleMask: [NSWindow.StyleMask.borderless], backing: NSWindow.BackingStoreType.buffered, defer: true)
        let windowViewController = PlaceholderWindowViewController.freshController()
        
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        window.contentViewController = windowViewController
        window.delegate = windowViewController
        
        windowViewController.toggleWindowSizeTextField(Preferences.shared.showWindowSize)
        
        return (window: window, windowViewController: windowViewController)
    }
    
    func acquire() -> (window: PlaceholderWindow, windowViewController: PlaceholderWindowViewController) {
        if self.pool.isEmpty {
            return self.create()
        }
        
        return self.pool.removeLast()
    }
    
    func release(_ item: (window: PlaceholderWindow, windowViewController: PlaceholderWindowViewController)) {
        self.pool.append(item)
    }
}
