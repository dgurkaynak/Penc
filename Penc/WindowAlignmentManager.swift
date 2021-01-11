//
//  WindowAlignmentManager.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 3.01.2021.
//  Copyright © 2021 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa

let WINDOW_ALIGNMENT_OFFSET: CGFloat = 1.0
let WINDOW_ALIGNMENT_SPEED_LIMIT: Double = 400

enum VerticalEdgeType {
    case LEFT
    case RIGHT
}

enum HorizontalEdgeType {
    case TOP
    case BOTTOM
}

struct VerticalEdgeAlignment {
    // Which vertical edge on Window A
    var edge: VerticalEdgeType
    // Vertical line segment to align (most probably an edge of window B, or screen edges)
    var alignTo: VerticalLineSegment
    // If you want to modify the edge (line segment) before alignment/collision check
    var edgeModifier: ((_ lineSegment: VerticalLineSegment) -> VerticalLineSegment)?
    // Pass it true if you want NOT to check continous collision
    var skipContinuousCollisionCheck: Bool?
}

struct HorizontalEdgeAlignment {
    var edge: HorizontalEdgeType
    var alignTo: HorizontalLineSegment
    var edgeModifier: ((_ lineSegment: HorizontalLineSegment) -> HorizontalLineSegment)?
    var skipContinuousCollisionCheck: Bool?
}

class WindowAlignmentManager {
    private var getWindowFrame: () -> CGRect // expects bottom-left originated
    private var otherWindows: [Int: WindowInfo]
    private var totalResistedX: CGFloat = 0.0
    private var totalResistedY: CGFloat = 0.0
    private var latestTimestamp: Double?
    
    private var verticalAlignments: [VerticalEdgeAlignment] = []
    private var horizontalAlignments: [HorizontalEdgeAlignment] = []
    
    init(
        getWindowFrame: @escaping () -> CGRect, // expects bottom-left originated
        otherWindows: [Int: WindowInfo]
    ) {
        self.getWindowFrame = getWindowFrame
        self.otherWindows = otherWindows
        
        self.buildAlignments()
    }
    
    private func buildAlignments() {
        // Terminology:
        // Window A: moving window
        // Window B: any other target window
        // `>|<`: means both sides of the symbol are aligned
        
        // Reset alignments
        self.verticalAlignments = []
        self.horizontalAlignments = []
        
        // Start iterating from the back-most window
        let otherWindowsSorted = self.otherWindows.values.sorted { (a, b) -> Bool in
            a.zIndex < b.zIndex
        }
        
        for otherWindow in otherWindowsSorted {
            // Increase window size by WINDOW_ALIGNMENT_OFFSET without changing it's center,
            // so our window can perfectly align to it by sepecified offset
            let enlargedRect = CGRect(
                x: otherWindow.rect.origin.x - WINDOW_ALIGNMENT_OFFSET,
                y: otherWindow.rect.origin.y - WINDOW_ALIGNMENT_OFFSET,
                width: otherWindow.rect.width + (2 * WINDOW_ALIGNMENT_OFFSET),
                height: otherWindow.rect.height + (2 * WINDOW_ALIGNMENT_OFFSET)
            )
            
            // This enlarged window may be overlapping previous line segments,
            // so let's go check and clip them
            var newVerticalAlignments: [VerticalEdgeAlignment] = []
            for verticalAlignment in self.verticalAlignments {
                let newLineSegments = verticalAlignment.alignTo.invertedClip(withRegion: otherWindow.rect)
                for newLineSegment in newLineSegments {
                    let newVerticalAlignment = VerticalEdgeAlignment(
                        edge: verticalAlignment.edge,
                        alignTo: newLineSegment,
                        edgeModifier: verticalAlignment.edgeModifier,
                        skipContinuousCollisionCheck: verticalAlignment.skipContinuousCollisionCheck
                    )
                    newVerticalAlignments.append(newVerticalAlignment)
                }
            }
            self.verticalAlignments = newVerticalAlignments
            
            // Let's do the same with horizontal alignments
            var newHorizontalAlignmets: [HorizontalEdgeAlignment] = []
            for horizontalAlignment in self.horizontalAlignments {
                let newLineSegments = horizontalAlignment.alignTo.invertedClip(withRegion: otherWindow.rect)
                for newLineSegment in newLineSegments {
                    let newHorizontalAlignment = HorizontalEdgeAlignment(
                        edge: horizontalAlignment.edge,
                        alignTo: newLineSegment,
                        edgeModifier: horizontalAlignment.edgeModifier,
                        skipContinuousCollisionCheck: horizontalAlignment.skipContinuousCollisionCheck
                    )
                    newHorizontalAlignmets.append(newHorizontalAlignment)
                }
            }
            self.horizontalAlignments = newHorizontalAlignmets
            
            // Handle the standart edge alignments
            // - leftEdge(A) >|< rightEdge(B)
            // - rightEdge(A) >|< leftEdge(B)
            // - topEdge(A) >|< bottomEdge(B)
            // - bottomEdge(A) >|< topEdge(B)
            self.verticalAlignments.append(VerticalEdgeAlignment(edge: .LEFT, alignTo: enlargedRect.getRightEdge()))
            self.verticalAlignments.append(VerticalEdgeAlignment(edge: .RIGHT, alignTo: enlargedRect.getLeftEdge()))
            self.horizontalAlignments.append(HorizontalEdgeAlignment(edge: .TOP, alignTo: enlargedRect.getBottomEdge()))
            self.horizontalAlignments.append(HorizontalEdgeAlignment(edge: .BOTTOM, alignTo: enlargedRect.getTopEdge()))
         
            // If windows' vertical edges are aligned (
            //    leftEdge(A) >|< rightEdge(B)
            //    OR
            //    rightEdge(A) >|< leftEdge(B)
            // ), we also want extra alignments:
            // - topEdge(A) >|< topEdge(B)
            // - bottomEdge(A) >|< bottomEdge(B)
            //
            // To do this, first we will get the leftest/righest point of our edge
            // or Window A as an another line segment. (Let's call it LS1)
            // Next, we will calculate little extension line segments from the
            // target edges of Window B. And let's call any of them LS2.
            //
            //  ↓                ↓  <- these extensions
            //  -+--------------+-
            //   |              |
            //   |   Window B   |
            //   |              |
            //  -+--------------+-
            //  ↑                ↑  <- these extensions
            //
            // And the length of these extension is equal to WINDOW_ALIGNMENT_OFFSET.
            // The trick is that the LS1 and LS2 only overlaps when Window A
            // and Window B are aligned to each other.
         
            // rightEdge(A) >|< leftEdge(B)
            self.horizontalAlignments.append(contentsOf: [
                // topEdge(A) >|< topEdge(B)
                HorizontalEdgeAlignment(
                    edge: .TOP,
                    alignTo: HorizontalLineSegment(
                        y: otherWindow.rect.origin.y + otherWindow.rect.size.height,
                        x1: otherWindow.rect.origin.x - WINDOW_ALIGNMENT_OFFSET,
                        x2: otherWindow.rect.origin.x
                    ),
                    edgeModifier: rightPointOf(_:),
                    skipContinuousCollisionCheck: true
                ),
                // bottomEdge(A) >|< bottomEdge(B)
                HorizontalEdgeAlignment(
                    edge: .BOTTOM,
                    alignTo: HorizontalLineSegment(
                        y: otherWindow.rect.origin.y,
                        x1: otherWindow.rect.origin.x - WINDOW_ALIGNMENT_OFFSET,
                        x2: otherWindow.rect.origin.x
                    ),
                    edgeModifier: rightPointOf(_:),
                    skipContinuousCollisionCheck: true
                )
            ])
            
            // leftEdge(A) >|< rightEdge(B)
            self.horizontalAlignments.append(contentsOf: [
                // topEdge(A) >|< topEdge(B)
                HorizontalEdgeAlignment(
                    edge: .TOP,
                    alignTo: HorizontalLineSegment(
                        y: otherWindow.rect.origin.y + otherWindow.rect.size.height,
                        x1: otherWindow.rect.origin.x + otherWindow.rect.size.width,
                        x2: otherWindow.rect.origin.x + otherWindow.rect.size.width + WINDOW_ALIGNMENT_OFFSET
                    ),
                    edgeModifier: leftPointOf(_:),
                    skipContinuousCollisionCheck: true
                ),
                // bottomEdge(A) >|< bottomEdge(B)
                HorizontalEdgeAlignment(
                    edge: .BOTTOM,
                    alignTo: HorizontalLineSegment(
                        y: otherWindow.rect.origin.y,
                        x1: otherWindow.rect.origin.x + otherWindow.rect.size.width,
                        x2: otherWindow.rect.origin.x + otherWindow.rect.size.width + WINDOW_ALIGNMENT_OFFSET
                    ),
                    edgeModifier: leftPointOf(_:),
                    skipContinuousCollisionCheck: true
                )
            ])
            
            // Similarly add the extra vertical alignments
            
            // bottomEdge(A) >|< topEdge(B)
            self.verticalAlignments.append(contentsOf: [
                // leftEdge(A) >|< leftEdge(B)
                VerticalEdgeAlignment(
                    edge: .LEFT,
                    alignTo: VerticalLineSegment(
                        x: otherWindow.rect.origin.x,
                        y1: otherWindow.rect.origin.y + otherWindow.rect.size.height,
                        y2: otherWindow.rect.origin.y + otherWindow.rect.size.height + WINDOW_ALIGNMENT_OFFSET
                    ),
                    edgeModifier: bottomPointOf(_:),
                    skipContinuousCollisionCheck: true
                ),
                // rightEdge(A) >|< rightEdge(B)
                VerticalEdgeAlignment(
                    edge: .RIGHT,
                    alignTo: VerticalLineSegment(
                        x: otherWindow.rect.origin.x + otherWindow.rect.size.width,
                        y1: otherWindow.rect.origin.y + otherWindow.rect.size.height,
                        y2: otherWindow.rect.origin.y + otherWindow.rect.size.height + WINDOW_ALIGNMENT_OFFSET
                    ),
                    edgeModifier: bottomPointOf(_:),
                    skipContinuousCollisionCheck: true
                )
            ])
            
            // topEdge(A) >|< bottomEdge(B)
            self.verticalAlignments.append(contentsOf: [
                // leftEdge(A) >|< leftEdge(B)
                VerticalEdgeAlignment(
                    edge: .LEFT,
                    alignTo: VerticalLineSegment(
                        x: otherWindow.rect.origin.x,
                        y1: otherWindow.rect.origin.y - WINDOW_ALIGNMENT_OFFSET,
                        y2: otherWindow.rect.origin.y
                    ),
                    edgeModifier: topPointOf(_:),
                    skipContinuousCollisionCheck: true
                ),
                // rightEdge(A) >|< rightEdge(B)
                VerticalEdgeAlignment(
                    edge: .RIGHT,
                    alignTo: VerticalLineSegment(
                        x: otherWindow.rect.origin.x + otherWindow.rect.size.width,
                        y1: otherWindow.rect.origin.y - WINDOW_ALIGNMENT_OFFSET,
                        y2: otherWindow.rect.origin.y
                    ),
                    edgeModifier: topPointOf(_:),
                    skipContinuousCollisionCheck: true
                )
            ])
        }
        
        // Add screen edges
        for screen in NSScreen.screens {
            self.verticalAlignments.append(contentsOf: [
                // Left edge
                VerticalEdgeAlignment(
                    edge: .LEFT,
                    alignTo: VerticalLineSegment(
                        x: screen.visibleFrame.origin.x,
                        y1: screen.visibleFrame.origin.y,
                        y2: screen.visibleFrame.origin.y + screen.visibleFrame.size.height
                    )
                ),
                // Right edge
                VerticalEdgeAlignment(
                    edge: .RIGHT,
                    alignTo: VerticalLineSegment(
                        x: screen.visibleFrame.origin.x + screen.visibleFrame.size.width,
                        y1: screen.visibleFrame.origin.y,
                        y2: screen.visibleFrame.origin.y + screen.visibleFrame.size.height
                    )
                )
            ])
            
            self.horizontalAlignments.append(contentsOf: [
                // Top edge
                HorizontalEdgeAlignment(
                    edge: .TOP,
                    alignTo: HorizontalLineSegment(
                        y: screen.visibleFrame.origin.y + screen.visibleFrame.size.height,
                        x1: screen.visibleFrame.origin.x,
                        x2: screen.visibleFrame.origin.x + screen.visibleFrame.size.width
                    )
                ),
                // Bottom edge
                HorizontalEdgeAlignment(
                    edge: .BOTTOM,
                    alignTo: HorizontalLineSegment(
                        y: screen.visibleFrame.origin.y,
                        x1: screen.visibleFrame.origin.x,
                        x2: screen.visibleFrame.origin.x + screen.visibleFrame.size.width
                    )
                )
            ])
        }
    }
    
    // This function maps a cursor movement and returns a new one
    // with respecting alignments.
    //
    // Assuming bottom-left originated movement
    // So upper direction is +y, right direction is +x
    func map(movement: (x: CGFloat, y: CGFloat), timestamp: Double) -> (x: CGFloat, y: CGFloat) {
        let currentFrame = self.getWindowFrame()
        let currentX = currentFrame.origin.x
        let currentY = currentFrame.origin.y
        var newMovement = (x: movement.x, y: movement.y)

        let currentTopEdge = currentFrame.getTopEdge()
        let currentBottomEdge = currentFrame.getBottomEdge()
        let currentLeftEdge = currentFrame.getLeftEdge()
        let currentRightEdge = currentFrame.getRightEdge()
        
        let deltaTime = self.latestTimestamp != nil ? timestamp - self.latestTimestamp! : nil
        self.latestTimestamp = timestamp
        let speedX = deltaTime != nil ? Double(movement.x) / deltaTime! : nil
        let speedY = deltaTime != nil ? Double(movement.y) / deltaTime! : nil
        
        //------------------//
        //----- X-AXIS -----//
        //------------------//
        
        // If user is not moved x-axis, do not check
        if movement.x != 0 {
            // If moving above speed limit
            if speedX != nil && abs(speedX!) >= WINDOW_ALIGNMENT_SPEED_LIMIT {
                self.totalResistedX = 0
            } else {
                // Speed limit is not exceeded
                
                // Let's check if we're already aligned to something
                let alignedTarget = self.verticalAlignments.first { (alignment) -> Bool in
                    let currentEdge = alignment.edge == .LEFT ? currentLeftEdge : currentRightEdge
                    let currentEdgeLineSegment = alignment.edgeModifier == nil ? currentEdge : alignment.edgeModifier!(currentEdge)
                    return currentEdgeLineSegment.isOverlapping(with: alignment.alignTo)
                }
                
                // If we already aligned to a target, check the current state
                if alignedTarget != nil {
                    let maxResistance = getMaximumResistance(mouseMovementInAOtherDirection: movement.y)
                    
                    if abs(self.totalResistedX) < maxResistance {
                        // Continue resisting
                        self.totalResistedX = self.totalResistedX + movement.x
                        newMovement.x = 0
                    } else {
                        // Break resistance
                        self.totalResistedX = 0
                    }
                } else {
                    // We're not already aligned to a target
                    // Let's check whether we're going to align in next step
                    let collidedTarget = self.verticalAlignments.first { (alignment) -> Bool in
                        if alignment.skipContinuousCollisionCheck != nil &&
                            alignment.skipContinuousCollisionCheck == true {
                            return false
                        }
                        
                        let currentEdge = alignment.edge == .LEFT ? currentLeftEdge : currentRightEdge
                        let currentEdgeLineSegment = alignment.edgeModifier == nil ? currentEdge : alignment.edgeModifier!(currentEdge)
                        return currentEdgeLineSegment.checkContinuousCollision(withTarget: alignment.alignTo, movement: movement)
                    }
                    
                    if collidedTarget != nil {
                        let alignedX = collidedTarget!.alignTo.x
                        let alignedOriginX = collidedTarget!.edge == .RIGHT ? alignedX - currentFrame.size.width : alignedX
                        
                        let resistedDeltaX = currentX + movement.x - alignedOriginX
                        self.totalResistedX = self.totalResistedX + resistedDeltaX
                        newMovement.x = alignedOriginX - currentX
                    }
                } // end of alignedTarget else
            } // end of speedX check
        } // end of movement.x check
        
        //------------------//
        //----- Y-AXIS -----//
        //------------------//
        
        // If user is not moved y-axis, do not check
        if movement.y != 0 {
            // If moving above speed limit
            if speedY != nil && abs(speedY!) >= WINDOW_ALIGNMENT_SPEED_LIMIT {
                self.totalResistedY = 0
            } else {
                // Speed limit is not exceeded
                
                // Let's check if we're already aligned to something
                let alignedTarget = self.horizontalAlignments.first { (alignment) -> Bool in
                    let currentEdge = alignment.edge == .TOP ? currentTopEdge : currentBottomEdge
                    let currentEdgeLineSegment = alignment.edgeModifier == nil ? currentEdge : alignment.edgeModifier!(currentEdge)
                    return currentEdgeLineSegment.isOverlapping(with: alignment.alignTo)
                }
                
                // If we already aligned to a target, check the current state
                if alignedTarget != nil {
                    let maxResistance = getMaximumResistance(mouseMovementInAOtherDirection: movement.x)
                    
                    if abs(self.totalResistedY) < maxResistance {
                        // Continue resisting
                        self.totalResistedY = self.totalResistedY + movement.y
                        newMovement.y = 0
                    } else {
                        // Break resistance
                        self.totalResistedY = 0
                    }
                } else {
                    // We're not already aligned to a target
                    // Let's check whether we're going to align in next step
                    let collidedTarget = self.horizontalAlignments.first { (alignment) -> Bool in
                        if alignment.skipContinuousCollisionCheck != nil &&
                            alignment.skipContinuousCollisionCheck == true {
                            return false
                        }
                        
                        let currentEdge = alignment.edge == .TOP ? currentTopEdge : currentBottomEdge
                        let currentEdgeLineSegment = alignment.edgeModifier == nil ? currentEdge : alignment.edgeModifier!(currentEdge)
                        return currentEdgeLineSegment.checkContinuousCollision(withTarget: alignment.alignTo, movement: movement)
                    }
                    
                    if collidedTarget != nil {
                        let alignedY = collidedTarget!.alignTo.y
                        let alignedOriginY = collidedTarget!.edge == .TOP ? alignedY - currentFrame.size.height : alignedY
                        
                        let resistedDeltaY = currentY + movement.y - alignedOriginY
                        self.totalResistedY = self.totalResistedY + resistedDeltaY
                        newMovement.y = alignedOriginY - currentY
                    }
                } // end of alignedTarget check
            } // end of speedY check
        } // end of movement.y check
        
        return newMovement
    }
}

// TODO: Maybe introduce a coefficient here as a preference?
internal func getMaximumResistance(mouseMovementInAOtherDirection: CGFloat) -> CGFloat {
    if mouseMovementInAOtherDirection == 0 { return 34.0 }
    let absValue = abs(mouseMovementInAOtherDirection)
    if (absValue == 1) { return 94.0 }
    return 139.0
}

internal func rightPointOf(_ ls: HorizontalLineSegment) -> HorizontalLineSegment {
    return HorizontalLineSegment(y: ls.y, x1: ls.x2, x2: ls.x2)
}

internal func leftPointOf(_ ls: HorizontalLineSegment) -> HorizontalLineSegment {
    return HorizontalLineSegment(y: ls.y, x1: ls.x1, x2: ls.x1)
}

internal func bottomPointOf(_ ls: VerticalLineSegment) -> VerticalLineSegment {
    return VerticalLineSegment(x: ls.x, y1: ls.y1, y2: ls.y1)
}

internal func topPointOf(_ ls: VerticalLineSegment) -> VerticalLineSegment {
    return VerticalLineSegment(x: ls.x, y1: ls.y2, y2: ls.y2)
}
