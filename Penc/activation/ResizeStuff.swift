//
//  ResizeStuff.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 5.02.2021.
//  Copyright © 2021 Deniz Gurkaynak. All rights reserved.
//

import Foundation


let WINDOW_RESIZE_HANDLE_SIZE: CGFloat = 20
let RESIZE_ADJECENT_WINDOW_DETECTION_SIZE: CGFloat = 10

enum WindowResizeHandleType {
    case TOP
    case TOP_LEFT
    case LEFT
    case BOTTOM_LEFT
    case BOTTOM
    case BOTTOM_RIGHT
    case RIGHT
    case TOP_RIGHT
}

typealias WindowResizeHandleRect = (
    type: WindowResizeHandleType,
    rect: CGRect
)

func getWindowResizeHandleRects(_ windowRect: CGRect) -> [WindowResizeHandleRect] {
    return [
        (
            type: .TOP,
            rect: CGRect(
                x: windowRect.origin.x + WINDOW_RESIZE_HANDLE_SIZE,
                y: windowRect.origin.y + windowRect.size.height - WINDOW_RESIZE_HANDLE_SIZE,
                width: windowRect.size.width - (2 * WINDOW_RESIZE_HANDLE_SIZE),
                height: WINDOW_RESIZE_HANDLE_SIZE
            )
        ),
        (
            type: .TOP_LEFT,
            rect: CGRect(
                x: windowRect.origin.x,
                y: windowRect.origin.y + windowRect.size.height - WINDOW_RESIZE_HANDLE_SIZE,
                width: WINDOW_RESIZE_HANDLE_SIZE,
                height: WINDOW_RESIZE_HANDLE_SIZE
            )
        ),
        (
            type: .LEFT,
            rect: CGRect(
                x: windowRect.origin.x,
                y: windowRect.origin.y + WINDOW_RESIZE_HANDLE_SIZE,
                width: WINDOW_RESIZE_HANDLE_SIZE,
                height: windowRect.size.height - (2 * WINDOW_RESIZE_HANDLE_SIZE)
            )
        ),
        (
            type: .BOTTOM_LEFT,
            rect: CGRect(
                x: windowRect.origin.x,
                y: windowRect.origin.y,
                width: WINDOW_RESIZE_HANDLE_SIZE,
                height: WINDOW_RESIZE_HANDLE_SIZE
            )
        ),
        (
            type: .BOTTOM,
            rect: CGRect(
                x: windowRect.origin.x + WINDOW_RESIZE_HANDLE_SIZE,
                y: windowRect.origin.y,
                width: windowRect.size.width - (2 * WINDOW_RESIZE_HANDLE_SIZE),
                height: WINDOW_RESIZE_HANDLE_SIZE
            )
        ),
        (
            type: .BOTTOM_RIGHT,
            rect: CGRect(
                x: windowRect.origin.x + windowRect.size.width - WINDOW_RESIZE_HANDLE_SIZE,
                y: windowRect.origin.y,
                width: WINDOW_RESIZE_HANDLE_SIZE,
                height: WINDOW_RESIZE_HANDLE_SIZE
            )
        ),
        (
            type: .RIGHT,
            rect: CGRect(
                x: windowRect.origin.x + windowRect.size.width - WINDOW_RESIZE_HANDLE_SIZE,
                y: windowRect.origin.y + WINDOW_RESIZE_HANDLE_SIZE,
                width: WINDOW_RESIZE_HANDLE_SIZE,
                height: windowRect.size.height - (2 * WINDOW_RESIZE_HANDLE_SIZE)
            )
        ),
        (
            type: .TOP_RIGHT,
            rect: CGRect(
                x: windowRect.origin.x + windowRect.size.width - WINDOW_RESIZE_HANDLE_SIZE,
                y: windowRect.origin.y + windowRect.size.height - WINDOW_RESIZE_HANDLE_SIZE,
                width: WINDOW_RESIZE_HANDLE_SIZE,
                height: WINDOW_RESIZE_HANDLE_SIZE
            )
        )
    ]
}

func getAlignedWindowsToResizeSimultaneously(
    window: ActivationWindow, // current window
    resizeHandle: WindowResizeHandleType, // current resize handle
    otherWindows: [ActivationWindow]
) -> [ActivationWindow] {
    var alignedWindows = [ActivationWindow]()
    
    switch resizeHandle {
    case .TOP:
        let targetRect = CGRect(
            x: window.newRect.origin.x,
            y: window.newRect.origin.y + window.newRect.size.height - (RESIZE_ADJECENT_WINDOW_DETECTION_SIZE / 2),
            width: window.newRect.size.width,
            height: RESIZE_ADJECENT_WINDOW_DETECTION_SIZE
        )
        alignedWindows = otherWindows.filter({ (windowHandle) -> Bool in
            let edge = windowHandle.newRect.getBottomEdge()
            let edgeRect = CGRect(x: edge.x1, y: edge.y, width: edge.x2 - edge.x1, height: 0)
            return targetRect.intersects(edgeRect)
        })
    case .TOP_LEFT:
        return []
    case .LEFT:
        let targetRect = CGRect(
            x: window.newRect.origin.x - (RESIZE_ADJECENT_WINDOW_DETECTION_SIZE / 2),
            y: window.newRect.origin.y,
            width: RESIZE_ADJECENT_WINDOW_DETECTION_SIZE,
            height: window.newRect.size.height
        )
        alignedWindows = otherWindows.filter({ (windowHandle) -> Bool in
            let edge = windowHandle.newRect.getRightEdge()
            let edgeRect = CGRect(x: edge.x, y: edge.y1, width: 0, height: edge.y2 - edge.y1)
            return targetRect.intersects(edgeRect)
        })
    case .BOTTOM_LEFT:
        return []
    case .BOTTOM:
        let targetRect = CGRect(
            x: window.newRect.origin.x,
            y: window.newRect.origin.y - (RESIZE_ADJECENT_WINDOW_DETECTION_SIZE / 2),
            width: window.newRect.size.width,
            height: RESIZE_ADJECENT_WINDOW_DETECTION_SIZE
        )
        alignedWindows = otherWindows.filter({ (windowHandle) -> Bool in
            let edge = windowHandle.newRect.getTopEdge()
            let edgeRect = CGRect(x: edge.x1, y: edge.y, width: edge.x2 - edge.x1, height: 0)
            return targetRect.intersects(edgeRect)
        })
    case .BOTTOM_RIGHT:
        return []
    case .RIGHT:
        let targetRect = CGRect(
            x: window.newRect.origin.x + window.newRect.size.width - (RESIZE_ADJECENT_WINDOW_DETECTION_SIZE / 2),
            y: window.newRect.origin.y,
            width: RESIZE_ADJECENT_WINDOW_DETECTION_SIZE,
            height: window.newRect.size.height
        )
        alignedWindows = otherWindows.filter({ (windowHandle) -> Bool in
            let edge = windowHandle.newRect.getLeftEdge()
            let edgeRect = CGRect(x: edge.x, y: edge.y1, width: 0, height: edge.y2 - edge.y1)
            return targetRect.intersects(edgeRect)
        })
    case .TOP_RIGHT:
        return []
    }
    
    return alignedWindows
}
