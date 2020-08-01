//
//  NSWindowExtension.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 31.07.2020.
//  Copyright © 2020 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa

extension NSWindow {
    // This method resizes the window relative to screen size
    // (visibleFrame actually), when ratio is 1.0, the window
    // will be full-width etc.
    //
    // This does not change the origin (position) of the window.
    //
    // ENSURE THAT self.screen EXISTS BEFORE USAGE
    func resizeBy(screenRatio: (width: CGFloat, height: CGFloat)) {
        let newRect = CGRect(
            x: self.frame.origin.x,
            y: self.frame.origin.y,
            width: self.screen!.visibleFrame.size.width * screenRatio.width,
            height: self.screen!.visibleFrame.size.height * screenRatio.height
        )
        
        self.setFrame(newRect, display: true, animate: false)
    }
    
    // This method resizes by multiplying its width and height
    // with a constant number. Anchor of the resize is the center.
    // A window cannot be resized bigger than its containing screen.
    //
    // ENSURE THAT self.screen EXISTS BEFORE USAGE
    func resizeBy(factor: (width: CGFloat, height: CGFloat)) {
        let delta = (
            width: self.frame.size.width * (factor.width - 1),
            height: self.frame.size.height * (factor.height - 1)
        )
        
        let wCandidate = self.frame.size.width + (delta.width * 2)
        let hCandidate = self.frame.size.height + (delta.height * 2)
        
        let newRect = CGRect(
            x: self.frame.origin.x - delta.width,
            y: self.frame.origin.y - delta.height,
            width: min(max(wCandidate, self.minSize.width), self.maxSize.width),
            height: min(max(hCandidate, self.minSize.height), self.maxSize.height)
        ).fitInVisibleFrame(self.screen!)
        
        self.setFrame(newRect, display: true, animate: false)
    }
    
    // This method set positions of window by specific anchor point
    func setPosition(_ position: CGPoint, byAnchorPoint: RectAnchorPoint) {
        let width = self.frame.width
        let height = self.frame.height
        var x = position.x
        var y = position.y
        
        switch byAnchorPoint {
        case .TOP_CENTER:
            x = x - (width / 2)
            y = y - height
        case .TOP_RIGHT:
            x = x - width
            y = y - height
        case .RIGHT_CENTER:
            x = x - width
            y = y - (height / 2)
        case .BOTTOM_RIGHT:
            x = x - width
            y = y - 0
        case .BOTTOM_CENTER:
            x = x - (width / 2)
            y = y - 0
        case .BOTTOM_LEFT:
            // NOOP
            x = x - 0
            y = y - 0
        case .LEFT_CENTER:
            x = x - 0
            y = y - (height / 2)
        case .TOP_LEFT:
            x = x - 0
            y = y - height
        case .CENTER:
            x = x - (width / 2)
            y = y - (height / 2)
        }
        
        self.setFrameOrigin(CGPoint(x: x, y: y))
    }
}
