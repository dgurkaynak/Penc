//
//  WindowAlignmentManager.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 3.01.2021.
//  Copyright © 2021 Deniz Gurkaynak. All rights reserved.
//

import Foundation

let WINDOW_ALIGNMENT_OFFSET: CGFloat = 1.0

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
    private var otherWindows: [WindowInfo] // assuming array starts from frontmost window
    private var totalResistedX: CGFloat = 0.0
    private var totalResistedY: CGFloat = 0.0
    
    private var verticalAlignments: [VerticalEdgeAlignment] = []
    private var horizontalAlignments: [HorizontalEdgeAlignment] = []
    
    init(
        getWindowFrame: @escaping () -> CGRect, // expects bottom-left originated
        otherWindows: [WindowInfo] // assuming array starts from frontmost window
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
        for otherWindow in self.otherWindows.reversed() {
            // Increase window size by WINDOW_ALIGNMENT_OFFSET without changing it's center,
            // so our window can perfectly align to it by sepecified offset
            let enlargedRect = CGRect(
                x: otherWindow.rect.origin.x + WINDOW_ALIGNMENT_OFFSET,
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
         
            // TODO: Devam edeceksin kanki
        }
    }
    
    // This function maps a cursor movement and returns a new one
    // with respecting alignments.
    //
    // Assuming bottom-left originated movement
    // So upper direction is +y, right direction is +x
    func map(movement: (x: CGFloat, y: CGFloat)) -> (x: CGFloat, y: CGFloat) {
        let currentFrame = self.getWindowFrame()
        let currentX = currentFrame.origin.x
        let currentY = currentFrame.origin.y
        var newMovement = (x: movement.x, y: movement.y)

        let currentTopEdge = currentFrame.getTopEdge()
        let currentBottomEdge = currentFrame.getBottomEdge()
        let currentLeftEdge = currentFrame.getLeftEdge()
        let currentRightEdge = currentFrame.getRightEdge()
        
        //------------------//
        //----- X-AXIS -----//
        //------------------//
        
        // If user is not moved x-axis, do not check
        if movement.x != 0 {
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
            }
        }
        
        //------------------//
        //----- Y-AXIS -----//
        //------------------//
        
        // If user is not moved y-axis, do not check
        if movement.y != 0 {
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
            }
            
        }
        
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
