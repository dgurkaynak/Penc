//
//  LineSegment.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 3.01.2021.
//  Copyright © 2021 Deniz Gurkaynak. All rights reserved.
//

import Foundation

// This whole file is written with bottom-left originated space coordinates in mind
// I don't know if it works with top-left coordinates

struct HorizontalLineSegment {
    var y: CGFloat
    var x1: CGFloat
    var x2: CGFloat
        
    // x2 must be => x1
    init(y: CGFloat, x1: CGFloat, x2: CGFloat) {
        self.y = y
        self.x1 = min(x1, x2)
        self.x2 = max(x1, x2)
    }
    
    func isOverlapping(with lineSegment: HorizontalLineSegment) -> Bool {
        if self.y != lineSegment.y { return false }
        return checkOverlapping1DLineSegments(
            a: (min: self.x1, max: self.x2),
            b: (min: lineSegment.x1, max: lineSegment.x2)
        )
    }
    
    func checkContinuousCollision(
        withTarget lineSegment: HorizontalLineSegment,
        movement: (x: CGFloat, y: CGFloat)
    ) -> Bool {
        // Quick check to early terminate
        if movement.y == 0 {
            if self.y != lineSegment.y { return false }
        } else if movement.y > 0 {
            if self.y >= lineSegment.y { return false }
            if self.y + movement.y < lineSegment.y { return false }
        } else if movement.y < 0 {
            if self.y <= lineSegment.y { return false }
            if self.y + movement.y > lineSegment.y { return false }
        }
        
        // Calculate collision
        let deltaY = lineSegment.y - self.y
        let deltaX = (deltaY / movement.y) * movement.x
        return checkOverlapping1DLineSegments(
            a: (min: self.x1 + deltaX, max: self.x2 + deltaX),
            b: (min: lineSegment.x1, max: lineSegment.x2)
        )
    }
    
    func invertedClip(withRegion rect: CGRect) -> [HorizontalLineSegment] {
        let rectTopY = rect.origin.y + rect.size.height
        let rectRightX = rect.origin.x + rect.size.width
        
        // Handle not intersecting cases
        if self.y < rect.origin.y { return [self] }
        if self.y > rectTopY { return [self] }
        if self.x2 <= rect.origin.x { return [self] }
        if self.x1 >= rectRightX { return [self] }
        
        // Handle cases with no resulting line segments at all
        if self.x1 >= rect.origin.x &&
            self.x1 <= rectRightX &&
            self.x2 >= rect.origin.x &&
            self.x2 <= rectRightX {
            return []
        }
        
        // Handle the case that line segment starts from left of the rect
        if self.x1 < rect.origin.x {
            return [HorizontalLineSegment(y: self.y, x1: self.x1, x2: rect.origin.x)]
        }
        
        // Handle the case that line segment ends at the right of the rect
        if self.x1 >= rect.origin.x {
            return [HorizontalLineSegment(y: self.y, x1: rectRightX, x2: self.x2)]
        }
        
        print("Impossible case ?!?")
        return []
    }
}

struct VerticalLineSegment {
    var x: CGFloat
    var y1: CGFloat
    var y2: CGFloat
    
    // y2 must be => y1
    init(x: CGFloat, y1: CGFloat, y2: CGFloat) {
        self.x = x
        self.y1 = min(y1, y2)
        self.y2 = max(y1, y2)
    }
    
    func isOverlapping(with lineSegment: VerticalLineSegment) -> Bool {
        if (self.x != lineSegment.x) { return false }
        return checkOverlapping1DLineSegments(
            a: (min: self.y1, max: self.y2),
            b: (min: lineSegment.y1, max: lineSegment.y2)
        )
    }
    
    func checkContinuousCollision(
        withTarget lineSegment: VerticalLineSegment,
        movement: (x: CGFloat, y: CGFloat)
    ) -> Bool {
        // Quick check to early terminate
        if movement.x == 0 {
            if self.x != lineSegment.x { return false }
        } else if movement.x > 0 {
            if self.x >= lineSegment.x { return false }
            if self.x + movement.x < lineSegment.x { return false }
        } else if movement.x < 0 {
            if self.x <= lineSegment.x { return false }
            if self.x + movement.x > lineSegment.x { return false }
        }
        
        // Calculate collision
        let deltaX = lineSegment.x - self.x
        let deltaY = (deltaX / movement.x) * movement.y
        return checkOverlapping1DLineSegments(
            a: (min: self.y1 + deltaY, max: self.y2 + deltaY),
            b: (min: lineSegment.y1, max: lineSegment.y2)
        )
    }
    
    func invertedClip(withRegion rect: CGRect) -> [VerticalLineSegment] {
        let rectTopY = rect.origin.y + rect.size.height
        let rectRightX = rect.origin.x + rect.size.width
        
        // Handle not intersecting case
        if self.x < rect.origin.x { return [self] }
        if self.x > rectRightX { return [self] }
        if self.y2 <= rect.origin.y { return [self] }
        if self.y1 >= rectTopY { return [self] }
        
        // Handle the case with 2 resulting line segments
        if self.y1 < rect.origin.y && self.y2 > rectTopY {
            return [
                VerticalLineSegment(x: self.x, y1: self.y1, y2: rect.origin.y),
                VerticalLineSegment(x: self.x, y1: rectTopY, y2: self.y2)
            ]
        }
        
        // Handle the case with no resulting line segment at all
        if self.y1 >= rect.origin.y &&
            self.y1 <= rectTopY &&
            self.y2 >= rect.origin.y &&
            self.y2 <= rectTopY {
            return []
        }
        
        // Handle the case that line segment starts below the rect
        if self.y1 < rect.origin.y {
            return [VerticalLineSegment(x: self.x, y1: self.y1, y2: rect.origin.y)]
        }
        
        // Handle the case with line segments ends above the rect
        if self.y1 >= rect.origin.y {
            return [VerticalLineSegment(x: self.x, y1: rectTopY, y2: self.y2)]
        }
        
        print("Impossible case ?!?")
        return []
    }
}

func checkOverlapping1DLineSegments(
    a: (min: CGFloat, max: CGFloat),
    b: (min: CGFloat, max: CGFloat)
) -> Bool {
    if a.max < b.min { return false }
    if a.min > b.max { return false }
    return true
}
