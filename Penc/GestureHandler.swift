//
//  GestureHandler.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 31.10.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa

enum GestureHandlerPhase {
    case BEGAN
    case CHANGED
    case ENDED
}

enum GestureType {
    case MOVE
    case RESIZE_ANCHOR_TOP_LEFT
    case SWIPE_TOP
    case SWIPE_TOP_RIGHT
    case SWIPE_RIGHT
    case SWIPE_BOTTOM_RIGHT
    case SWIPE_BOTTOM
    case SWIPE_BOTTOM_LEFT
    case SWIPE_LEFT
    case SWIPE_TOP_LEFT
}

protocol GestureHandlerDelegate: class {
    func onGestureBegan(gestureHandler: GestureHandler)
    func onGestureChanged(gestureHandler: GestureHandler, type: GestureType, delta: (x: CGFloat, y: CGFloat)?)
    func onGestureEnded(gestureHandler: GestureHandler)
}

class GestureHandler: ScrollHandlerDelegate {
    weak var delegate: GestureHandlerDelegate?
    private var globalModifierKeyMonitor: Any?
    private var localModifierKeyMonitor: Any?
    private let scrollHandler = ScrollHandler()
    var pressedKeys = NSEvent.ModifierFlags.init(rawValue: 0)
    var phase = GestureHandlerPhase.ENDED
    
    init() {
        self.scrollHandler.setDelegate(self)
        self.scrollHandler.pause()
        self.globalModifierKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { (event) in
            self.onModifierKeyEvent(event)
        }
        self.localModifierKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { (event) in
            self.onModifierKeyEvent(event)
            return event
        }
    }
    
    func setDelegate(_ delegate: GestureHandlerDelegate?) {
        self.delegate = delegate
    }
    
    private func onModifierKeyEvent(_ event: NSEvent) {
        self.pressedKeys = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        if self.pressedKeys.rawValue == 0 {
            self.scrollHandler.pause()
            self.end()
        } else {
            self.scrollHandler.resume()
        }
    }
    
    func onScrollBegan(scrollHandler: ScrollHandler) {
        self.begin()
    }
    
    func onScrollChanged(scrollHandler: ScrollHandler, delta: (x: CGFloat, y: CGFloat)) {
        // Determine gesture
        if self.pressedKeys == [.command] {
            self.change(GestureType.MOVE, delta: delta)
        } else if self.pressedKeys == [.command, .option] {
            self.change(GestureType.RESIZE_ANCHOR_TOP_LEFT, delta: delta)
        }
    }
    
    func onScrollCancelled(scrollHandler: ScrollHandler) {
        // Do nothing
    }
    
    func onScrollEnded(scrollHandler: ScrollHandler, delta: (x: CGFloat, y: CGFloat)?) {
        // Check its swipe?
    }
    
    private func begin() {
        if self.phase != .ENDED { return } // Can be called multiple times, but begin at just the first one
        self.phase = .BEGAN
        self.delegate?.onGestureBegan(gestureHandler: self)
    }
    
    private func change(_ gestureType: GestureType, delta: (x: CGFloat, y: CGFloat)?) {
        self.phase = .CHANGED
        self.delegate?.onGestureChanged(gestureHandler: self, type: gestureType, delta: delta)
    }
    
    private func end() {
        if self.phase == .ENDED { return }
        self.phase = .ENDED
        self.delegate?.onGestureEnded(gestureHandler: self)
    }
    
    deinit {
        NSEvent.removeMonitor(self.localModifierKeyMonitor as Any)
        NSEvent.removeMonitor(self.globalModifierKeyMonitor as Any)
    }
}
