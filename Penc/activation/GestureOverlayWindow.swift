//
//  OverlayWindow.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 3.11.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Cocoa

enum SwipeGestureType {
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
    func onScrollGesture(delta: (x: CGFloat, y: CGFloat, timestamp: Double))
    func onSwipeGesture(type: SwipeGestureType)
    func onMagnifyGesture(factor: (width: CGFloat, height: CGFloat))
    func onMouseMoveGesture(position: (x: CGFloat, y: CGFloat))
    func onDoubleClickGesture()
    func onMouseDragGesture(
        position: (x: CGFloat, y: CGFloat),
        delta: (x: CGFloat, y: CGFloat),
        timestamp: Double
    )
}

class GestureOverlayWindow: NSWindow {
    weak var delegate_: GestureOverlayWindowDelegate?
    
    private var magnifying = false
    private var magnificationAngle = CGFloat.pi / 4

    var swipeDetectionVelocityThreshold: Double = 500
    private var scrollingDeltas = [(x: CGFloat, y: CGFloat, timestamp: TimeInterval)]()
    
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
            let wFactor = 1 + (magnification * cos(self.magnificationAngle))
            let hFactor = 1 + (magnification * sin(self.magnificationAngle))
        
            self.delegate_?.onMagnifyGesture(factor: (width: wFactor, height: hFactor))
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
    
    override func mouseMoved(with event: NSEvent) {
        let mouseX = NSEvent.mouseLocation.x
        let mouseY = NSEvent.mouseLocation.y // bottom-left origined
        self.delegate_?.onMouseMoveGesture(position: (x: mouseX, y: mouseY))
    }
    
    override func mouseDragged(with event: NSEvent) {
        let position = (
            x: NSEvent.mouseLocation.x,
            y: NSEvent.mouseLocation.y // bottom-left origined
        )
        let delta = (x: -1 * event.deltaX, y: -1 * event.deltaY)
        self.delegate_?.onMouseDragGesture(
            position: position,
            delta: delta,
            timestamp: event.timestamp
        )
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
                self.delegate_?.onDoubleClickGesture()
            } else {
                // Too late, start over
                self.doubleClickTimer = PTimer()
            }
        }
    }
    
    override func scrollWheel(with event: NSEvent) {
        if event.phase == NSEvent.Phase.began {
            self.scrollingDeltas = []
        } else if event.phase == NSEvent.Phase.cancelled {
            self.scrollingDeltas = []
        } else if event.phase == NSEvent.Phase.changed {
            // Moving or resizing (delta) window
            var factor: CGFloat = event.isDirectionInvertedFromDevice ? -1 : 1;
            if self.reverseScroll { factor *= -1 }
            let delta = (
                x: factor * event.scrollingDeltaX,
                y: factor * event.scrollingDeltaY,
                timestamp: event.timestamp
            )
            self.scrollingDeltas.append(delta)
            self.scrollingDeltas = Array(self.scrollingDeltas.suffix(5))
            self.delegate_?.onScrollGesture(delta: delta)
        } else if event.phase == NSEvent.Phase.ended {
            // Maybe swiping?
            if self.scrollingDeltas.isEmpty { return }
            
            // Include only that movements happen in 500ms before ended
            let latestScrollingDeltas = self.scrollingDeltas.filter { (delta) -> Bool in
                return event.timestamp - delta.timestamp <= 0.5
            }
            if latestScrollingDeltas.isEmpty { return }
            
            let deltaTime = event.timestamp - latestScrollingDeltas.first!.timestamp
            let totalDeltaX = latestScrollingDeltas.reduce(0) { $0 + $1.x }
            let totalDeltaY = latestScrollingDeltas.reduce(0) { $0 + $1.y }
            let speedX = Double(totalDeltaX) / deltaTime // px/s
            let speedY = Double(totalDeltaY) / deltaTime // px/s
            
            var swipe = (x: 0, y: 0)
            
            if abs(speedX) > self.swipeDetectionVelocityThreshold {
                swipe.x = speedX > 0 ? 1 : -1
            }
            
            if abs(speedY) > self.swipeDetectionVelocityThreshold {
                swipe.y = speedY > 0 ? 1 : -1
            }
            
            var swipeType: SwipeGestureType? = nil
            
            switch swipe {
            case (x: -1, y: -1):
                swipeType = SwipeGestureType.SWIPE_BOTTOM_RIGHT
                break
            case (x: -1, y: 0):
                swipeType = SwipeGestureType.SWIPE_RIGHT
                break
            case (x: -1, y: 1):
                swipeType = SwipeGestureType.SWIPE_TOP_RIGHT
                break
            case (x: 0, y: -1):
                swipeType = SwipeGestureType.SWIPE_BOTTOM
                break
            case (x: 0, y: 0):
                swipeType = nil
                break
            case (x: 0, y: 1):
                swipeType = SwipeGestureType.SWIPE_TOP
                break
            case (x: 1, y: -1):
                swipeType = SwipeGestureType.SWIPE_BOTTOM_LEFT
                break
            case (x: 1, y: 0):
                swipeType = SwipeGestureType.SWIPE_LEFT
                break
            case (x: 1, y: 1):
                swipeType = SwipeGestureType.SWIPE_TOP_LEFT
                break
            default:
                swipeType = nil
                break
            }
            
            if swipeType != nil {
                self.delegate_?.onSwipeGesture(type: swipeType!)
            }
            
            self.scrollingDeltas = []
        }
    }
    
    override func keyDown(with event: NSEvent) {
        // NOOP
        // This prevents macOS to play dang or error sound (its proper name is `funk`)
        // When (penc is activated and-) pressed arrow keys
    }
    
    func clear() {
        self.magnifying = false
        self.scrollingDeltas = []
    }
}
