//
//  OverlayWindow.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 3.11.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Cocoa

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

protocol GestureOverlayWindowDelegate: class {
    func onMoveGesture(gestureOverlayWindow: GestureOverlayWindow, delta: (x: CGFloat, y: CGFloat))
    func onSwipeGesture(gestureOverlayWindow: GestureOverlayWindow, type: GestureType)
    func onResizeFactorGesture(gestureOverlayWindow: GestureOverlayWindow, factor: (x: CGFloat, y: CGFloat))
    func onDoubleClickGesture(gestureOverlayWindow: GestureOverlayWindow)
}

class GestureOverlayWindow: NSWindow {
    weak var delegate_: GestureOverlayWindowDelegate?
    
    private var magnifying = false
    private var magnificationAngle = CGFloat.pi / 4

    var swipeThreshold: CGFloat = 20
    private var latestScrollingDelta: (x: CGFloat, y: CGFloat)?
    
    var reverseScroll = false
    
    private var doubleClickTimer: PTimer? = nil
    var doubleClickTimeout = 0.3
    
    func setDelegate(_ delegate: GestureOverlayWindowDelegate?) {
        self.delegate_ = delegate
    }
    
    override func magnify(with event: NSEvent) {
        if event.phase == NSEvent.Phase.began {
            self.magnifying = true
        } else if event.phase == NSEvent.Phase.cancelled {
            self.magnifying = false
        } else if event.phase == NSEvent.Phase.changed {
            // Resizing with factor
            let magnification = event.magnification
            let xFactor = -1 * magnification * cos(self.magnificationAngle)
            let yFactor = -1 * magnification * sin(self.magnificationAngle)
        
            self.delegate_?.onResizeFactorGesture(gestureOverlayWindow: self, factor: (x: xFactor, y: yFactor))
        } else if event.phase == NSEvent.Phase.ended {
            self.magnifying = false
        }
    }
    
    override func touchesMoved(with event: NSEvent) {
        // Infer pinch angle
        guard self.magnifying == true else { return }
        let touches = event.allTouches()
        guard touches.count == 2 else { return }
        
        let touch1 = touches[touches.index(touches.startIndex, offsetBy: 0)]
        let touch2 = touches[touches.index(touches.startIndex, offsetBy: 1)]
        var angle = atan2(touch1.normalizedPosition.y - touch2.normalizedPosition.y, touch1.normalizedPosition.x - touch2.normalizedPosition.x)
        if angle < 0 { angle += CGFloat.pi }
        if angle > CGFloat.pi / 2 { angle = CGFloat.pi - angle }
        
        if angle <= CGFloat.pi / 8 {
            angle = 0
        } else if angle >= 3 * CGFloat.pi / 8 {
            angle = CGFloat.pi / 2
        } else {
            angle = CGFloat.pi / 4
        }
        
        self.magnificationAngle = angle
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override func mouseDragged(with event: NSEvent) {
//        let delta = (x: -1 * event.deltaX, y: -1 * event.deltaY)
//        self.delegate_?.onMoveGesture(gestureOverlayWindow: self, delta: delta)
    }
    
    override func mouseDown(with event: NSEvent) {
        if self.doubleClickTimer == nil {
            // Start timer
            self.doubleClickTimer = PTimer()
        } else {
            let elapsed = self.doubleClickTimer!.end()
            let timeoutInNs = self.doubleClickTimeout * 1000000000
            
            if elapsed <= UInt64(timeoutInNs) {
                self.doubleClickTimer = nil
                self.delegate_?.onDoubleClickGesture(gestureOverlayWindow: self)
            } else {
                // Too late, start over
                self.doubleClickTimer = PTimer()
            }
        }
    }
    
    override func scrollWheel(with event: NSEvent) {
        if event.phase == NSEvent.Phase.began {
            self.latestScrollingDelta = nil
        } else if event.phase == NSEvent.Phase.cancelled {
            self.latestScrollingDelta = nil
        } else if event.phase == NSEvent.Phase.changed {
            // Moving or resizing (delta) window
            var factor: CGFloat = event.isDirectionInvertedFromDevice ? -1 : 1;
            if self.reverseScroll { factor *= -1 }
            let delta = (x: factor * event.scrollingDeltaX, y: factor * event.scrollingDeltaY)
            self.latestScrollingDelta = delta
            self.delegate_?.onMoveGesture(gestureOverlayWindow: self, delta: delta)
        } else if event.phase == NSEvent.Phase.ended {
            // Maybe swiping?
            if self.latestScrollingDelta == nil { return }
            let delta = self.latestScrollingDelta!
            var swipe = (x: 0, y: 0)
            
            if abs(delta.x) > self.swipeThreshold {
                swipe.x = delta.x > 0 ? 1 : -1
            }
            
            if abs(delta.y) > self.swipeThreshold {
                swipe.y = delta.y > 0 ? 1 : -1
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
                self.delegate_?.onSwipeGesture(gestureOverlayWindow: self, type: swipeType!)
            }
            
            self.latestScrollingDelta = nil
        }
    }
    
    func clear() {
        self.magnifying = false
        self.latestScrollingDelta = nil
    }
}
