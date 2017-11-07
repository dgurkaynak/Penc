//
//  OverlayWindow.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 3.11.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Cocoa


protocol OverlayWindowMagnifyDelegate: class {
    func onMagnifyBegan(overlayWindow: OverlayWindow)
    func onMagnifyChanged(overlayWindow: OverlayWindow, magnification: CGFloat, angle: CGFloat?)
    func onMagnifyCancelled(overlayWindow: OverlayWindow)
    func onMagnifyEnded(overlayWindow: OverlayWindow)
}

class OverlayWindow: NSWindow {
    weak var magnificationDelegate: OverlayWindowMagnifyDelegate?
    var magnifying = false
    var shouldInferMagnificationAngle = true
    var magnificationAngle = CGFloat.pi / 4
    
    func setMagnificationDelegate(_ delegate: OverlayWindowMagnifyDelegate?) {
        self.magnificationDelegate = delegate
    }
    
    override func magnify(with event: NSEvent) {
        if event.phase == NSEvent.Phase.began {
            self.magnifying = true
            self.magnificationDelegate?.onMagnifyBegan(overlayWindow: self)
        } else if event.phase == NSEvent.Phase.cancelled {
            self.magnifying = false
            self.magnificationDelegate?.onMagnifyCancelled(overlayWindow: self)
        } else if event.phase == NSEvent.Phase.changed {
            let angle = self.shouldInferMagnificationAngle ? self.magnificationAngle : nil
            self.magnificationDelegate?.onMagnifyChanged(overlayWindow: self, magnification: event.magnification, angle: angle)
        } else if event.phase == NSEvent.Phase.ended {
            self.magnifying = false
            self.magnificationDelegate?.onMagnifyEnded(overlayWindow: self)
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
}
