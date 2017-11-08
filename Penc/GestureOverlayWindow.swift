//
//  OverlayWindow.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 3.11.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Cocoa


protocol GestureOverlayWindowDelegate: class {
    func onMagnifyBegan(overlayWindow: GestureOverlayWindow)
    func onMagnifyChanged(overlayWindow: GestureOverlayWindow, magnification: CGFloat, angle: CGFloat?)
    func onMagnifyCancelled(overlayWindow: GestureOverlayWindow)
    func onMagnifyEnded(overlayWindow: GestureOverlayWindow)
    func onMouseDragged(overlayWindow: GestureOverlayWindow, delta: (x: CGFloat, y: CGFloat))
}

class GestureOverlayWindow: NSWindow {
    weak var delegate_: GestureOverlayWindowDelegate?
    var magnifying = false
    var shouldInferMagnificationAngle = false
    var magnificationAngle = CGFloat.pi / 4
    
    func setDelegate(_ delegate: GestureOverlayWindowDelegate?) {
        self.delegate_ = delegate
    }
    
    override func magnify(with event: NSEvent) {
        if event.phase == NSEvent.Phase.began {
            self.magnifying = true
            self.delegate_?.onMagnifyBegan(overlayWindow: self)
        } else if event.phase == NSEvent.Phase.cancelled {
            self.magnifying = false
            self.delegate_?.onMagnifyCancelled(overlayWindow: self)
        } else if event.phase == NSEvent.Phase.changed {
            let angle = self.shouldInferMagnificationAngle ? self.magnificationAngle : nil
            self.delegate_?.onMagnifyChanged(overlayWindow: self, magnification: event.magnification, angle: angle)
        } else if event.phase == NSEvent.Phase.ended {
            self.magnifying = false
            self.delegate_?.onMagnifyEnded(overlayWindow: self)
        }
    }
    
    override func touchesMoved(with event: NSEvent) {
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
        self.delegate_?.onMouseDragged(overlayWindow: self, delta: (x: event.deltaX, y: event.deltaY))
    }
}
