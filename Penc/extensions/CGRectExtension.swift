//
//  CGRectExtension.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 31.10.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa

enum RectAnchorPoint {
    case TOP_CENTER
    case TOP_RIGHT
    case RIGHT_CENTER
    case BOTTOM_RIGHT
    case BOTTOM_CENTER
    case BOTTOM_LEFT
    case LEFT_CENTER
    case TOP_LEFT
    case CENTER
}

extension CGRect {
    // NSRect or CGRect's signiture is => { x, y, width, height }
    // Silica uses top-left corner of the main screen as origin and
    // (x, y) refers to top-left corner of a window.
    // However Cocoa uses bottom-left corner of the main screen
    // as origin (increasing bottom to top) and bottom-left corner
    // of a window as (x, y).
    //
    // This method converts between top-left <=> bottom-left (in both ways)
    //
    // Primary screen is the screen at index 0, that contains
    // the menu bar and whose origin is at the point (0, 0).
    func topLeft2bottomLeft(_ primaryScreen: NSScreen) -> CGRect {
        return CGRect(x: self.origin.x, y: primaryScreen.frame.height - self.height - self.origin.y, width: self.width, height: self.height)
    }
    
    // This method fits a rect into specified screen's visible frame.
    // - If (width|height) larger than visible frame => set (width|height) 100% and position it (0, 0)
    // - Else, set its position as all of the window frame is visible.
    //
    // Works only for bottom-left rects
    func fitInVisibleFrame(ofScreen: NSScreen) -> CGRect {
        let visibleFrame = ofScreen.visibleFrame
        var rectData = (x: self.origin.x, y: self.origin.y, width: self.width, height: self.height)
        
        if self.height >= visibleFrame.height {
            rectData.height = visibleFrame.height
            rectData.y = visibleFrame.origin.y
        } else if self.origin.y < visibleFrame.origin.y {
            rectData.y = visibleFrame.origin.y
        } else if self.origin.y + self.height > visibleFrame.origin.y + visibleFrame.height {
            rectData.y = visibleFrame.origin.y + visibleFrame.height - self.height
        }
        
        if self.width >= visibleFrame.width {
            rectData.width = visibleFrame.width
            rectData.x = visibleFrame.origin.x
        } else if self.origin.x < visibleFrame.origin.x {
            rectData.x = visibleFrame.origin.x
        } else if self.origin.x + self.width > visibleFrame.origin.x + visibleFrame.width {
            rectData.x = visibleFrame.origin.x + visibleFrame.width - self.width
        }
        
        return CGRect(x: rectData.x, y: rectData.y, width: rectData.width, height: rectData.height)
    }
    
    // This method gets the position of some specified points
    // (like edges centers & corners) of a rectangle.
    //
    // Works only for bottom-left rects
    func getPointOf(anchorPoint: RectAnchorPoint) -> CGPoint {
        var x = self.origin.x
        var y = self.origin.y
        
        switch anchorPoint {
        case .TOP_CENTER:
            x = x + (width / 2)
            y = y + height
        case .TOP_RIGHT:
            x = x + width
            y = y + height
        case .RIGHT_CENTER:
            x = x + width
            y = y + (height / 2)
        case .BOTTOM_RIGHT:
            x = x + width
            y = y + 0
        case .BOTTOM_CENTER:
            x = x + (width / 2)
            y = y + 0
        case .BOTTOM_LEFT:
            // NOOP
            x = x + 0
            y = y + 0
        case .LEFT_CENTER:
            x = x + 0
            y = y + (height / 2)
        case .TOP_LEFT:
            x = x + 0
            y = y + height
        case .CENTER:
            x = x + (width / 2)
            y = y + (height / 2)
        }
        
        return CGPoint(x: x, y: y)
    }
    
    // Works for bottom-left originated rects
    func getTopEdge() -> HorizontalLineSegment {
        return HorizontalLineSegment(
            y: self.origin.y + self.size.height,
            x1: self.origin.x,
            x2: self.origin.x + self.size.width
        )
    }
    
    // Works for bottom-left originated rects
    func getBottomEdge() -> HorizontalLineSegment {
        return HorizontalLineSegment(
            y: self.origin.y,
            x1: self.origin.x,
            x2: self.origin.x + self.size.width
        )
    }
    
    // Works for bottom-left originated rects
    func getLeftEdge() -> VerticalLineSegment {
        return VerticalLineSegment(
            x: self.origin.x,
            y1: self.origin.y,
            y2: self.origin.y + self.size.height
        )
    }
    
    // Works for bottom-left originated rects
    func getRightEdge() -> VerticalLineSegment {
        return VerticalLineSegment(
            x: self.origin.x + self.size.width,
            y1: self.origin.y,
            y2: self.origin.y + self.size.height
        )
    }
    
    // This method set positions of window by specific anchor point
    // Works for bottom-left originated rects
    func setPositionOf(anchorPoint: RectAnchorPoint, toPosition: CGPoint) -> CGRect {
        let width = self.width
        let height = self.height
        var x = toPosition.x
        var y = toPosition.y
        
        switch anchorPoint {
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
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    // This method resizes the window relative to screen size
    // (visibleFrame actually), when ratio is 1.0, the window
    // will be full-width etc.
    //
    // This does not change the origin (position) of the window.
    func resizeBy(screen: NSScreen, ratio: (width: CGFloat, height: CGFloat)) -> CGRect {
        return CGRect(
            x: self.origin.x,
            y: self.origin.y,
            width: screen.visibleFrame.size.width * ratio.width,
            height: screen.visibleFrame.size.height * ratio.height
        )
    }
    
    // This method resizes by multiplying its width and height
    // with a constant number. Anchor of the resize is the center.
    func resizeBy(factor: (width: CGFloat, height: CGFloat)) -> CGRect {
        let delta = (
            width: self.size.width * (factor.width - 1),
            height: self.size.height * (factor.height - 1)
        )
        
        return CGRect(
            x: self.origin.x - delta.width,
            y: self.origin.y - delta.height,
            width: self.size.width + (delta.width * 2),
            height: self.size.height + (delta.height * 2)
        )
    }
    
    func resizeBy(handle: PWindowResizeHandle, delta: (x: CGFloat, y: CGFloat)) -> CGRect {
        switch handle {
        case .TOP:
            return CGRect(
                x: self.origin.x,
                y: self.origin.y,
                width: self.size.width,
                height: self.size.height + delta.y
            )
        case .TOP_LEFT:
            return CGRect(
                x: self.origin.x + delta.x,
                y: self.origin.y,
                width: self.size.width - delta.x,
                height: self.size.height + delta.y
            )
        case .LEFT:
            return CGRect(
                x: self.origin.x + delta.x,
                y: self.origin.y,
                width: self.size.width - delta.x,
                height: self.size.height
            )
        case .BOTTOM_LEFT:
            return CGRect(
                x: self.origin.x + delta.x,
                y: self.origin.y + delta.y,
                width: self.size.width - delta.x,
                height: self.size.height - delta.y
            )
        case .BOTTOM:
            return CGRect(
                x: self.origin.x,
                y: self.origin.y + delta.y,
                width: self.size.width,
                height: self.size.height - delta.y
            )
        case .BOTTOM_RIGHT:
            return CGRect(
                x: self.origin.x,
                y: self.origin.y + delta.y,
                width: self.size.width + delta.x,
                height: self.size.height - delta.y
            )
        case .RIGHT:
            return CGRect(
                x: self.origin.x,
                y: self.origin.y,
                width: self.size.width + delta.x,
                height: self.size.height
            )
        case .TOP_RIGHT:
            return CGRect(
                x: self.origin.x,
                y: self.origin.y,
                width: self.size.width + delta.x,
                height: self.size.height + delta.y
            )
        }
    }
}
