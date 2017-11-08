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
}

class GestureOverlayWindow: NSWindow {
    weak var delegate_: GestureOverlayWindowDelegate?
    
    var shouldInferMagnificationAngle = false
    private var magnifying = false
    private var magnificationAngle = CGFloat.pi / 4
    
    var swipeThreshold: CGFloat = 20
    private var latestScrollingDelta: (x: CGFloat, y: CGFloat)?
    
    
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
            let angle = self.shouldInferMagnificationAngle ? self.magnificationAngle : nil
            let magnification = event.magnification
            let xFactor = angle == nil ? (-1 * magnification) : (-1 * magnification * cos(angle!))
            let yFactor = angle == nil ? (-1 * magnification) : (-1 * magnification * sin(angle!))
        
            self.delegate_?.onResizeFactorGesture(gestureOverlayWindow: self, factor: (x: xFactor, y: yFactor))
        } else if event.phase == NSEvent.Phase.ended {
            self.magnifying = false
        }
    }
    
    override func touchesMoved(with event: NSEvent) {
        // Infer pinch angle
        guard self.magnifying == true else { return }
        guard self.shouldInferMagnificationAngle == true else { return }
        let touches = event.allTouches()
        guard touches.count == 2 else { return }
        
        let touch1 = touches[touches.index(touches.startIndex, offsetBy: 0)]
        let touch2 = touches[touches.index(touches.startIndex, offsetBy: 1)]
        var angle = atan2(touch1.normalizedPosition.y - touch2.normalizedPosition.y, touch1.normalizedPosition.x - touch2.normalizedPosition.x)
        if angle < 0 { angle += CGFloat.pi }
        if angle > CGFloat.pi / 2 { angle = CGFloat.pi - angle }
        self.magnificationAngle = angle
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override func mouseDragged(with event: NSEvent) {
        // Moving the window
        let delta = (x: -1 * event.deltaX, y: -1 * event.deltaY)
        self.delegate_?.onMoveGesture(gestureOverlayWindow: self, delta: delta)
    }
    
    override func scrollWheel(with event: NSEvent) {
        if event.phase == NSEvent.Phase.began {
            self.latestScrollingDelta = nil
        } else if event.phase == NSEvent.Phase.cancelled {
            self.latestScrollingDelta = nil
        } else if event.phase == NSEvent.Phase.changed {
            // Moving the window
            let factor: CGFloat = event.isDirectionInvertedFromDevice ? -1 : 1;
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
}
