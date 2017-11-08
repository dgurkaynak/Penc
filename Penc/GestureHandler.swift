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
    case RESIZE_DELTA
    case RESIZE_FACTOR
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
    func onMoveGesture(gestureHandler: GestureHandler, delta: (x: CGFloat, y: CGFloat))
    func onSwipeGesture(gestureHandler: GestureHandler, type: GestureType)
    func onResizeDeltaGesture(gestureHandler: GestureHandler, delta: (x: CGFloat, y: CGFloat))
    func onResizeFactorGesture(gestureHandler: GestureHandler, factor: (x: CGFloat, y: CGFloat))
    func onGestureEnded(gestureHandler: GestureHandler)
}

class GestureHandler: ScrollHandlerDelegate, GestureOverlayWindowDelegate {
    weak var delegate: GestureHandlerDelegate?
    private var globalModifierKeyMonitor: Any?
    private var localModifierKeyMonitor: Any?
    private let scrollHandler = ScrollHandler()
    var modifierFlags = NSEvent.ModifierFlags.init(rawValue: 0)
    var moveModifierFlags: NSEvent.ModifierFlags = [.function]
    var resizeDeltaModifierFlags: NSEvent.ModifierFlags = []
    var resizeFactorModifierFlags: NSEvent.ModifierFlags = [.function]
    var swipeModifierFlags: NSEvent.ModifierFlags = [.function]
    var phase = GestureHandlerPhase.ENDED
    var shouldBeginEarly = true
    var earlyBeginDelay = 0.5
    var earlyBeginTimer: Timer? = nil
    var swipeThreshold: CGFloat = 20
    
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
        self.modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        if self.modifierFlags.rawValue == 0 {
            self.scrollHandler.pause()
            self.earlyBeginTimer?.invalidate()
            self.end()
        } else if self.modifierFlags == self.moveModifierFlags ||
            self.modifierFlags == self.resizeDeltaModifierFlags ||
            self.modifierFlags == self.resizeFactorModifierFlags ||
            self.modifierFlags == self.swipeModifierFlags {
            if self.shouldBeginEarly && (self.earlyBeginTimer == nil || !self.earlyBeginTimer!.isValid) {
                self.earlyBeginTimer = Timer.scheduledTimer(timeInterval: self.earlyBeginDelay, target: self, selector: #selector(begin), userInfo: nil, repeats: false)
            }
            self.scrollHandler.resume()
        } else {
            self.scrollHandler.pause()
            self.earlyBeginTimer?.invalidate()
            self.end()
        }
    }
    
    func onScrollBegan(scrollHandler: ScrollHandler) {
        guard self.modifierFlags.rawValue != 0 else { return }
        self.begin()
    }
    
    func onScrollChanged(scrollHandler: ScrollHandler, delta: (x: CGFloat, y: CGFloat)) {
        guard self.modifierFlags.rawValue != 0 else { return }
        
        if self.modifierFlags == self.moveModifierFlags {
            self.phase = .CHANGED
            self.delegate?.onMoveGesture(gestureHandler: self, delta: delta)
        } else if self.modifierFlags == self.resizeDeltaModifierFlags {
            self.phase = .CHANGED
            self.delegate?.onResizeDeltaGesture(gestureHandler: self, delta: delta)
        }
    }
    
    func onScrollCancelled(scrollHandler: ScrollHandler) {
        // Do nothing
    }
    
    func onScrollEnded(scrollHandler: ScrollHandler, delta: (x: CGFloat, y: CGFloat)?) {
        guard self.modifierFlags.rawValue != 0 else { return }
        
        if self.modifierFlags == self.swipeModifierFlags && delta != nil {
            var swipe = (x: 0, y: 0)
            
            if abs(delta!.x) > self.swipeThreshold {
                swipe.x = delta!.x > 0 ? 1 : -1
            }
            
            if abs(delta!.y) > self.swipeThreshold {
                swipe.y = delta!.y > 0 ? 1 : -1
            }
            
            var swipeType: GestureType? = nil
            
            switch swipe {
            case (x: -1, y: -1):
                swipeType = GestureType.SWIPE_BOTTOM_RIGHT
                break
            case (x: -1, y: 0):
                swipeType = GestureType.SWIPE_RIGHT
                break
            case (x: -1, y: 1):
                swipeType = GestureType.SWIPE_TOP_RIGHT
                break
            case (x: 0, y: -1):
                swipeType = GestureType.SWIPE_BOTTOM
                break
            case (x: 0, y: 0):
                swipeType = nil
                break
            case (x: 0, y: 1):
                swipeType = GestureType.SWIPE_TOP
                break
            case (x: 1, y: -1):
                swipeType = GestureType.SWIPE_BOTTOM_LEFT
                break
            case (x: 1, y: 0):
                swipeType = GestureType.SWIPE_LEFT
                break
            case (x: 1, y: 1):
                swipeType = GestureType.SWIPE_TOP_LEFT
                break
            default:
                swipeType = nil
                break
            }
            
            if swipeType != nil {
                self.phase = .CHANGED
                self.delegate?.onSwipeGesture(gestureHandler: self, type: swipeType!)
            }
        }
    }
    
    func onMagnifyBegan(overlayWindow: GestureOverlayWindow) {
        guard self.modifierFlags.rawValue != 0 else { return }
        self.begin()
    }
    
    func onMagnifyChanged(overlayWindow: GestureOverlayWindow, magnification: CGFloat, angle: CGFloat?) {
        guard self.modifierFlags.rawValue != 0 else { return }
        guard self.modifierFlags == self.resizeFactorModifierFlags else { return }
        self.phase = .CHANGED
        
        let xFactor = angle == nil ? (-1 * magnification) : (-1 * magnification * cos(angle!))
        let yFactor = angle == nil ? (-1 * magnification) : (-1 * magnification * sin(angle!))
        
        self.delegate?.onResizeFactorGesture(gestureHandler: self, factor: (x: xFactor, y: yFactor))
    }
    
    func onMagnifyCancelled(overlayWindow: GestureOverlayWindow) {
        // Do nothing
    }
    
    func onMagnifyEnded(overlayWindow: GestureOverlayWindow) {
        // Do nothing
    }
    
    func onMouseDragged(overlayWindow: GestureOverlayWindow, delta: (x: CGFloat, y: CGFloat)) {
        guard self.modifierFlags.rawValue != 0 else { return }
        guard self.modifierFlags == self.moveModifierFlags else { return }
        
        self.phase = .CHANGED
        let invertDelta = (x: delta.x * -1, y: delta.y * -1)
        self.delegate?.onMoveGesture(gestureHandler: self, delta: invertDelta)
    }
    
    @objc private func begin() {
        guard self.phase == .ENDED else { return } // Can be called multiple times, but begin at just the first one
        self.phase = .BEGAN
        self.delegate?.onGestureBegan(gestureHandler: self)
    }
    
    private func end() {
        guard self.phase != .ENDED else { return }
        self.phase = .ENDED
        self.delegate?.onGestureEnded(gestureHandler: self)
    }
    
    deinit {
        NSEvent.removeMonitor(self.localModifierKeyMonitor as Any)
        NSEvent.removeMonitor(self.globalModifierKeyMonitor as Any)
    }
}
