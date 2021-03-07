//
//  PlaceholderPool.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 11.01.2021.
//  Copyright © 2021 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa

internal typealias PlaceholderPoolItem = (
    window: PlaceholderWindow,
    windowViewController: PlaceholderWindowViewController
)

class PlaceholderPool {
    static let shared = PlaceholderPool()
    
    private var all = [PlaceholderPoolItem]()
    private var avaliable = [PlaceholderPoolItem]()
    
    func forEach(_ predicate: (PlaceholderPoolItem) -> ()) {
        self.all.forEach { (item) in
            predicate(item)
        }
    }
    
    private func create() -> PlaceholderPoolItem {
        let window = PlaceholderWindow(contentRect: CGRect(x: 0, y: 0, width: 0, height: 0), styleMask: [NSWindow.StyleMask.borderless], backing: NSWindow.BackingStoreType.buffered, defer: true)
        let windowViewController = PlaceholderWindowViewController.freshController()
        
        window.level = .popUpMenu
        window.isOpaque = true
        window.backgroundColor = NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        window.contentViewController = windowViewController
        window.delegate = windowViewController
        
        let item = (window: window, windowViewController: windowViewController)
        self.all.append(item)
        
        return item
    }
    
    func acquire() -> PlaceholderPoolItem {
        if self.avaliable.isEmpty {
            return self.create()
        }
        
        return self.avaliable.removeLast()
    }
    
    func release(_ item: PlaceholderPoolItem) {
        self.avaliable.append(item)
    }
}
