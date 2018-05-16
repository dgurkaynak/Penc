//
//  WindowHelper.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 16.05.2018.
//  Copyright © 2018 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa


class WindowHelper {
    // Move+Snap properties
    private var ignoredDeltaXs: [CGFloat] = []
    private var ignoredDeltaYs: [CGFloat] = []
    var maxIgnoredX: CGFloat = 60
    var maxSnapDeltaX: CGFloat = 10
    var maxIgnoredY: CGFloat = 60
    var maxSnapDeltaY: CGFloat = 10
    
    
    func snapToLeftOfScreen(_ window: NSWindow, frame: NSRect?) -> CGRect {
        var frame_ = window.frame
        if frame != nil { frame_ = frame! }
        
        return CGRect(
            x: window.screen!.visibleFrame.origin.x,
            y: frame_.origin.y,
            width: frame_.size.width,
            height: frame_.size.height
        )
    }
    
    func snapToRightOfScreen(_ window: NSWindow, frame: NSRect?) -> CGRect {
        var frame_ = window.frame
        if frame != nil { frame_ = frame! }
        
        return CGRect(
            x: window.screen!.visibleFrame.origin.x + window.screen!.visibleFrame.size.width - frame_.size.width,
            y: frame_.origin.y,
            width: frame_.size.width,
            height: frame_.size.height
        )
    }
    
    func snapToBottomOfScreen(_ window: NSWindow, frame: NSRect?) -> CGRect {
        var frame_ = window.frame
        if frame != nil { frame_ = frame! }
        
        return CGRect(
            x: frame_.origin.x,
            y: window.screen!.visibleFrame.origin.y,
            width: frame_.size.width,
            height: frame_.size.height
        )
    }
    
    func snapToTopOfScreen(_ window: NSWindow, frame: NSRect?) -> CGRect {
        var frame_ = window.frame
        if frame != nil { frame_ = frame! }
        
        return CGRect(
            x: frame_.origin.x,
            y: window.screen!.visibleFrame.origin.y + window.screen!.visibleFrame.size.height - frame_.size.height,
            width: frame_.size.width,
            height: frame_.size.height
        )
    }
    
    func resizeToScreenWidth(_ window: NSWindow, frame: NSRect?, factor: CGFloat = 1) -> CGRect {
        var frame_ = window.frame
        if frame != nil { frame_ = frame! }
        
        return CGRect(
            x: frame_.origin.x,
            y: frame_.origin.y,
            width: window.screen!.visibleFrame.size.width * factor,
            height: frame_.size.height
        )
    }
    
    func resizeToScreenHeight(_ window: NSWindow, frame: NSRect?, factor: CGFloat = 1) -> CGRect {
        var frame_ = window.frame
        if frame != nil { frame_ = frame! }
        
        return CGRect(
            x: frame_.origin.x,
            y: frame_.origin.y,
            width: frame_.size.width,
            height: window.screen!.visibleFrame.size.height * factor
        )
    }
    
    func moveWithSnappingScreenBoundaries(_ window: NSWindow, delta: (x: CGFloat, y: CGFloat)) -> CGRect {
        var deltaX: CGFloat = delta.x
        var deltaY: CGFloat = delta.y
        
        if window.screen != nil {
            ///////
            // X //
            ///////
            var ignoredX = false
            let xCurrent = window.frame.origin.x
            let xCandidate = window.frame.origin.x - delta.x
            let xScreenLeftBoundry = window.screen!.visibleFrame.origin.x
            let xScreenRightBoundry = window.screen!.visibleFrame.origin.x + window.screen!.visibleFrame.size.width - window.frame.size.width
            
            if xCurrent >= xScreenLeftBoundry && xCandidate < xScreenLeftBoundry {
                ignoredX = true
            } else if xCurrent <= xScreenRightBoundry && xCandidate > xScreenRightBoundry {
                ignoredX = true
            }
            
            // If max ignored reached
            let totalIgnoredX = self.ignoredDeltaXs.reduce(0, +)
            if abs(totalIgnoredX) > self.maxIgnoredX {
                ignoredX = false
            }
            
            // If max delta
            if abs(delta.x) >= self.maxSnapDeltaX {
                ignoredX = false
            }
            
            if ignoredX {
                deltaX = 0
                self.ignoredDeltaXs.append(delta.x)
            } else {
                self.ignoredDeltaXs = []
            }
            
            ///////
            // Y //
            ///////
            var ignoredY = false
            let yCurrent = window.frame.origin.y
            let yCandidate = window.frame.origin.y + delta.y
            let yScreenBottomBoundry = window.screen!.visibleFrame.origin.y
            let yScreenTopBoundry = window.screen!.visibleFrame.origin.y + window.screen!.visibleFrame.size.height - window.frame.size.height
            
            if yCurrent <= yScreenTopBoundry && yCandidate > yScreenTopBoundry {
                ignoredY = true
            } else if yCurrent >= yScreenBottomBoundry && yCandidate < yScreenBottomBoundry {
                ignoredY = true
            }
            
            // If max ignored reached
            let totalIgnoredY = self.ignoredDeltaYs.reduce(0, +)
            if abs(totalIgnoredY) > self.maxIgnoredY {
                ignoredY = false
            }
            
            // If max delta
            if abs(delta.y) >= self.maxSnapDeltaY {
                ignoredY = false
            }
            
            if ignoredY {
                deltaY = 0
                self.ignoredDeltaYs.append(delta.y)
            } else {
                self.ignoredDeltaYs = []
            }
        }
        
        return CGRect(
            x: window.frame.origin.x - deltaX,
            y: window.frame.origin.y + deltaY,
            width: window.frame.size.width,
            height: window.frame.size.height
        )
    }
}
