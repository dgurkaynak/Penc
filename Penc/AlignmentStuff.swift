//
//  AlignmentStuff.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 5.02.2021.
//  Copyright © 2021 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa

// Terminology:
// Window A: moving window
// Window B: any other window
// `>|<`: means both sides of the symbol are aligned

let WINDOW_ALIGNMENT_OFFSET: CGFloat = 1.0
let WINDOW_ALIGNMENT_SPEED_LIMIT: Double = 400

enum WindowVerticalEdgeType {
    case LEFT
    case RIGHT
}

enum WindowHorizontalEdgeType {
    case TOP
    case BOTTOM
}

struct WindowVerticalEdgeAlignment {
    // Which vertical edge on Window A
    var edge: WindowVerticalEdgeType
    // Vertical line segment to align (most probably an edge of window B, or screen edges)
    var alignTo: VerticalLineSegment
    // If you want to modify the edge (line segment) before alignment/collision check
    var edgeModifier: ((_ lineSegment: VerticalLineSegment) -> VerticalLineSegment)?
}

struct WindowHorizontalEdgeAlignment {
    // Which horizontal edge on Window A
    var edge: WindowHorizontalEdgeType
    // Horizontal line segment to align (most probably an edge of window B, or screen edges)
    var alignTo: HorizontalLineSegment
    // If you want to modify the edge (line segment) before alignment/collision check
    var edgeModifier: ((_ lineSegment: HorizontalLineSegment) -> HorizontalLineSegment)?
}

typealias WindowAlignmentGuides = (
    horizontal: [WindowHorizontalEdgeAlignment],
    vertical: [WindowVerticalEdgeAlignment]
)

// This function builds alignment guides OF A SINGLE WINDOW.
// These alignment guides are FOR OTHER WINDOWS. And they're
// in raw form. In order to calculate final guides, we must
// take other windows into account and clip some guides because of
// overlapping windows.
func buildRawAlignmentGuides(ofWindow rect: CGRect) -> WindowAlignmentGuides {
    var verticalAlignments = [WindowVerticalEdgeAlignment]()
    var horizontalAlignments = [WindowHorizontalEdgeAlignment]()
    
    // Increase window size by WINDOW_ALIGNMENT_OFFSET without changing it's center,
    // so our window can perfectly align to it by sepecified offset
    let enlargedRect = CGRect(
        x: rect.origin.x - WINDOW_ALIGNMENT_OFFSET,
        y: rect.origin.y - WINDOW_ALIGNMENT_OFFSET,
        width: rect.width + (2 * WINDOW_ALIGNMENT_OFFSET),
        height: rect.height + (2 * WINDOW_ALIGNMENT_OFFSET)
    )
    
    // Handle the standart edge alignments
    // - leftEdge(A) >|< rightEdge(B)
    // - rightEdge(A) >|< leftEdge(B)
    // - topEdge(A) >|< bottomEdge(B)
    // - bottomEdge(A) >|< topEdge(B)
    verticalAlignments.append(WindowVerticalEdgeAlignment(edge: .LEFT, alignTo: enlargedRect.getRightEdge()))
    verticalAlignments.append(WindowVerticalEdgeAlignment(edge: .RIGHT, alignTo: enlargedRect.getLeftEdge()))
    horizontalAlignments.append(WindowHorizontalEdgeAlignment(edge: .TOP, alignTo: enlargedRect.getBottomEdge()))
    horizontalAlignments.append(WindowHorizontalEdgeAlignment(edge: .BOTTOM, alignTo: enlargedRect.getTopEdge()))
 
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
    horizontalAlignments.append(contentsOf: [
        // topEdge(A) >|< topEdge(B)
        WindowHorizontalEdgeAlignment(
            edge: .TOP,
            alignTo: HorizontalLineSegment(
                y: rect.origin.y + rect.size.height,
                x1: rect.origin.x - WINDOW_ALIGNMENT_OFFSET,
                x2: rect.origin.x
            ),
            edgeModifier: rightPointOf(_:)
        ),
        // bottomEdge(A) >|< bottomEdge(B)
        WindowHorizontalEdgeAlignment(
            edge: .BOTTOM,
            alignTo: HorizontalLineSegment(
                y: rect.origin.y,
                x1: rect.origin.x - WINDOW_ALIGNMENT_OFFSET,
                x2: rect.origin.x
            ),
            edgeModifier: rightPointOf(_:)
        )
    ])
    
    // leftEdge(A) >|< rightEdge(B)
    horizontalAlignments.append(contentsOf: [
        // topEdge(A) >|< topEdge(B)
        WindowHorizontalEdgeAlignment(
            edge: .TOP,
            alignTo: HorizontalLineSegment(
                y: rect.origin.y + rect.size.height,
                x1: rect.origin.x + rect.size.width,
                x2: rect.origin.x + rect.size.width + WINDOW_ALIGNMENT_OFFSET
            ),
            edgeModifier: leftPointOf(_:)
        ),
        // bottomEdge(A) >|< bottomEdge(B)
        WindowHorizontalEdgeAlignment(
            edge: .BOTTOM,
            alignTo: HorizontalLineSegment(
                y: rect.origin.y,
                x1: rect.origin.x + rect.size.width,
                x2: rect.origin.x + rect.size.width + WINDOW_ALIGNMENT_OFFSET
            ),
            edgeModifier: leftPointOf(_:)
        )
    ])
    
    // Similarly add the extra vertical alignments
    
    // bottomEdge(A) >|< topEdge(B)
    verticalAlignments.append(contentsOf: [
        // leftEdge(A) >|< leftEdge(B)
        WindowVerticalEdgeAlignment(
            edge: .LEFT,
            alignTo: VerticalLineSegment(
                x: rect.origin.x,
                y1: rect.origin.y + rect.size.height,
                y2: rect.origin.y + rect.size.height + WINDOW_ALIGNMENT_OFFSET
            ),
            edgeModifier: bottomPointOf(_:)
        ),
        // rightEdge(A) >|< rightEdge(B)
        WindowVerticalEdgeAlignment(
            edge: .RIGHT,
            alignTo: VerticalLineSegment(
                x: rect.origin.x + rect.size.width,
                y1: rect.origin.y + rect.size.height,
                y2: rect.origin.y + rect.size.height + WINDOW_ALIGNMENT_OFFSET
            ),
            edgeModifier: bottomPointOf(_:)
        )
    ])
    
    // topEdge(A) >|< bottomEdge(B)
    verticalAlignments.append(contentsOf: [
        // leftEdge(A) >|< leftEdge(B)
        WindowVerticalEdgeAlignment(
            edge: .LEFT,
            alignTo: VerticalLineSegment(
                x: rect.origin.x,
                y1: rect.origin.y - WINDOW_ALIGNMENT_OFFSET,
                y2: rect.origin.y
            ),
            edgeModifier: topPointOf(_:)
        ),
        // rightEdge(A) >|< rightEdge(B)
        WindowVerticalEdgeAlignment(
            edge: .RIGHT,
            alignTo: VerticalLineSegment(
                x: rect.origin.x + rect.size.width,
                y1: rect.origin.y - WINDOW_ALIGNMENT_OFFSET,
                y2: rect.origin.y
            ),
            edgeModifier: topPointOf(_:)
        )
    ])
    
    return (
        horizontal: horizontalAlignments,
        vertical: verticalAlignments
    )
}

// This function builds the actual alignment guides considering
// other windows' position/zIndex and screen edges. When a window
// is selected, pass the other windows into this function in order to
// calculate alignment guides.
func buildActualAlignmentGuides(
    otherWindows: [ActivationWindow],
    addScreenEdges: Bool = true
) -> WindowAlignmentGuides {
    var verticalAlignments = [WindowVerticalEdgeAlignment]()
    var horizontalAlignments = [WindowHorizontalEdgeAlignment]()
    
    // Start iterating from the back-most window
    let windowsSorted = otherWindows.sorted { (a, b) -> Bool in
        a.zIndex < b.zIndex
    }
    
    for window in windowsSorted {
        // This window may be overlapping previous line segments,
        // so let's go check and clip them
        var newVerticalAlignments: [WindowVerticalEdgeAlignment] = []
        for verticalAlignment in verticalAlignments {
            let newLineSegments = verticalAlignment.alignTo.invertedClip(withRegion: window.newRect)
            for newLineSegment in newLineSegments {
                let newVerticalAlignment = WindowVerticalEdgeAlignment(
                    edge: verticalAlignment.edge,
                    alignTo: newLineSegment,
                    edgeModifier: verticalAlignment.edgeModifier
                )
                newVerticalAlignments.append(newVerticalAlignment)
            }
        }
        verticalAlignments = newVerticalAlignments
        
        // Let's do the same with horizontal alignments
        var newHorizontalAlignmets: [WindowHorizontalEdgeAlignment] = []
        for horizontalAlignment in horizontalAlignments {
            let newLineSegments = horizontalAlignment.alignTo.invertedClip(withRegion: window.newRect)
            for newLineSegment in newLineSegments {
                let newHorizontalAlignment = WindowHorizontalEdgeAlignment(
                    edge: horizontalAlignment.edge,
                    alignTo: newLineSegment,
                    edgeModifier: horizontalAlignment.edgeModifier
                )
                newHorizontalAlignmets.append(newHorizontalAlignment)
            }
        }
        horizontalAlignments = newHorizontalAlignmets
        
        // Now add the raw alignments
        verticalAlignments.append(contentsOf: window.rawAlignmentGuides.vertical)
        horizontalAlignments.append(contentsOf: window.rawAlignmentGuides.horizontal)
    }
    
    // Add screen edges
    if addScreenEdges {
        for screen in NSScreen.screens {
            verticalAlignments.append(contentsOf: [
                // Left edge
                WindowVerticalEdgeAlignment(
                    edge: .LEFT,
                    alignTo: VerticalLineSegment(
                        x: screen.visibleFrame.origin.x,
                        y1: screen.visibleFrame.origin.y,
                        y2: screen.visibleFrame.origin.y + screen.visibleFrame.size.height
                    )
                ),
                // Right edge
                WindowVerticalEdgeAlignment(
                    edge: .RIGHT,
                    alignTo: VerticalLineSegment(
                        x: screen.visibleFrame.origin.x + screen.visibleFrame.size.width,
                        y1: screen.visibleFrame.origin.y,
                        y2: screen.visibleFrame.origin.y + screen.visibleFrame.size.height
                    )
                )
            ])
            
            horizontalAlignments.append(contentsOf: [
                // Top edge
                WindowHorizontalEdgeAlignment(
                    edge: .TOP,
                    alignTo: HorizontalLineSegment(
                        y: screen.visibleFrame.origin.y + screen.visibleFrame.size.height,
                        x1: screen.visibleFrame.origin.x,
                        x2: screen.visibleFrame.origin.x + screen.visibleFrame.size.width
                    )
                ),
                // Bottom edge
                WindowHorizontalEdgeAlignment(
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
    
    return (
        horizontal: horizontalAlignments,
        vertical: verticalAlignments
    )
}

class WindowMovementProcessingState {
    var resistedWindowMovement: (x: CGFloat, y: CGFloat) = (x: 0, y: 0)
    var latestWindowMovementTimestamp: Double?
    
    func reset() {
        self.resistedWindowMovement = (x: 0, y: 0)
        self.latestWindowMovementTimestamp = nil
    }
}

// This function process a window movement and returns a new one
// with respecting alignment guides.
//
// !!! Paramater `state` WILL BE MUTATED !!!
//
// Assuming bottom-left originated movement
// So upper direction is +y, right direction is +x
func processWindowMovementConsideringAlignment(
    windowRect: CGRect,
    alignmentGuides: WindowAlignmentGuides,
    state: WindowMovementProcessingState, // !!! WILL BE MUTATED !!!
    movement: (x: CGFloat, y: CGFloat), // window movement request
    timestamp: Double
) -> (x: CGFloat, y: CGFloat) {
    let currentFrame = windowRect
    let currentX = currentFrame.origin.x
    let currentY = currentFrame.origin.y
    var newMovement = (x: movement.x, y: movement.y)

    let currentTopEdge = currentFrame.getTopEdge()
    let currentBottomEdge = currentFrame.getBottomEdge()
    let currentLeftEdge = currentFrame.getLeftEdge()
    let currentRightEdge = currentFrame.getRightEdge()

    let deltaTime = state.latestWindowMovementTimestamp != nil ? timestamp - state.latestWindowMovementTimestamp! : nil
    state.latestWindowMovementTimestamp = timestamp
    let speedX = deltaTime != nil ? Double(movement.x) / deltaTime! : nil
    let speedY = deltaTime != nil ? Double(movement.y) / deltaTime! : nil

    //------------------//
    //----- X-AXIS -----//
    //------------------//

    // If user is not moved x-axis, do not check
    if movement.x != 0 {
        // If moving above speed limit
        if speedX != nil && abs(speedX!) >= WINDOW_ALIGNMENT_SPEED_LIMIT {
            state.resistedWindowMovement.x = 0
        } else {
            // Speed limit is not exceeded

            // Let's check if we're already aligned to something
            let alignedGuide = alignmentGuides.vertical.first { (alignment) -> Bool in
                let currentEdge = alignment.edge == .LEFT ? currentLeftEdge : currentRightEdge
                let currentEdgeLineSegment = alignment.edgeModifier == nil ? currentEdge : alignment.edgeModifier!(currentEdge)
                return currentEdgeLineSegment.isOverlapping(with: alignment.alignTo)
            }

            // If we already aligned to a guide, check the current state
            if alignedGuide != nil {
                let maxResistance = getMaximumResistance(mouseMovementInAOtherDirection: movement.y)

                if abs(state.resistedWindowMovement.x) < maxResistance {
                    // Continue resisting
                    state.resistedWindowMovement.x = state.resistedWindowMovement.x + movement.x
                    newMovement.x = 0
                } else {
                    // Break resistance
                    state.resistedWindowMovement.x = 0
                }
            } else {
                // We're not already aligned to a guide
                // Let's check whether we're going to align in next step
                let collidedGuide = alignmentGuides.vertical.first { (alignment) -> Bool in
                    let currentEdge = alignment.edge == .LEFT ? currentLeftEdge : currentRightEdge
                    let currentEdgeLineSegment = alignment.edgeModifier == nil ? currentEdge : alignment.edgeModifier!(currentEdge)
                    return currentEdgeLineSegment.checkContinuousCollision(withTarget: alignment.alignTo, movement: movement)
                }

                if collidedGuide != nil {
                    let alignedX = collidedGuide!.alignTo.x
                    let alignedOriginX = collidedGuide!.edge == .RIGHT ? alignedX - currentFrame.size.width : alignedX

                    let resistedDeltaX = currentX + movement.x - alignedOriginX
                    state.resistedWindowMovement.x = state.resistedWindowMovement.x + resistedDeltaX
                    newMovement.x = alignedOriginX - currentX
                }
            } // end of alignedGuide else
        } // end of speedX check
    } // end of movement.x check

    //------------------//
    //----- Y-AXIS -----//
    //------------------//

    // If user is not moved y-axis, do not check
    if movement.y != 0 {
        // If moving above speed limit
        if speedY != nil && abs(speedY!) >= WINDOW_ALIGNMENT_SPEED_LIMIT {
            state.resistedWindowMovement.y = 0
        } else {
            // Speed limit is not exceeded

            // Let's check if we're already aligned to something
            let alignedGuide = alignmentGuides.horizontal.first { (alignment) -> Bool in
                let currentEdge = alignment.edge == .TOP ? currentTopEdge : currentBottomEdge
                let currentEdgeLineSegment = alignment.edgeModifier == nil ? currentEdge : alignment.edgeModifier!(currentEdge)
                return currentEdgeLineSegment.isOverlapping(with: alignment.alignTo)
            }

            // If we already aligned to a guide, check the current state
            if alignedGuide != nil {
                let maxResistance = getMaximumResistance(mouseMovementInAOtherDirection: movement.x)

                if abs(state.resistedWindowMovement.y) < maxResistance {
                    // Continue resisting
                    state.resistedWindowMovement.y = state.resistedWindowMovement.y + movement.y
                    newMovement.y = 0
                } else {
                    // Break resistance
                    state.resistedWindowMovement.y = 0
                }
            } else {
                // We're not already aligned to a guide
                // Let's check whether we're going to align in next step
                let collidedGuide = alignmentGuides.horizontal.first { (alignment) -> Bool in
                    let currentEdge = alignment.edge == .TOP ? currentTopEdge : currentBottomEdge
                    let currentEdgeLineSegment = alignment.edgeModifier == nil ? currentEdge : alignment.edgeModifier!(currentEdge)
                    return currentEdgeLineSegment.checkContinuousCollision(withTarget: alignment.alignTo, movement: movement)
                }

                if collidedGuide != nil {
                    let alignedY = collidedGuide!.alignTo.y
                    let alignedOriginY = collidedGuide!.edge == .TOP ? alignedY - currentFrame.size.height : alignedY

                    let resistedDeltaY = currentY + movement.y - alignedOriginY
                    state.resistedWindowMovement.y = state.resistedWindowMovement.y + resistedDeltaY
                    newMovement.y = alignedOriginY - currentY
                }
            } // end of alignedGuide check
        } // end of speedY check
    } // end of movement.y check

    return newMovement
}

// TODO: Maybe introduce a coefficient here as a preference?
fileprivate func getMaximumResistance(mouseMovementInAOtherDirection: CGFloat) -> CGFloat {
    if mouseMovementInAOtherDirection == 0 { return 34.0 }
    let absValue = abs(mouseMovementInAOtherDirection)
    if (absValue == 1) { return 94.0 }
    return 139.0
}

fileprivate func rightPointOf(_ ls: HorizontalLineSegment) -> HorizontalLineSegment {
    return HorizontalLineSegment(y: ls.y, x1: ls.x2, x2: ls.x2)
}

fileprivate func leftPointOf(_ ls: HorizontalLineSegment) -> HorizontalLineSegment {
    return HorizontalLineSegment(y: ls.y, x1: ls.x1, x2: ls.x1)
}

fileprivate func bottomPointOf(_ ls: VerticalLineSegment) -> VerticalLineSegment {
    return VerticalLineSegment(x: ls.x, y1: ls.y1, y2: ls.y1)
}

fileprivate func topPointOf(_ ls: VerticalLineSegment) -> VerticalLineSegment {
    return VerticalLineSegment(x: ls.x, y1: ls.y2, y2: ls.y2)
}
