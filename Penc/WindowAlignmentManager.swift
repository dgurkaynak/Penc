//
//  WindowAlignmentManager.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 3.01.2021.
//  Copyright © 2021 Deniz Gurkaynak. All rights reserved.
//

import Foundation

class WindowAlignmentManager {
    private var getWindowFrame: () -> CGRect // expects bottom-left originated
    private var otherWindows: [WindowInfo] // assuming array starts from frontmost window
    
    init(
        getWindowFrame: @escaping () -> CGRect, // expects bottom-left originated
        otherWindows: [WindowInfo] // assuming array starts from frontmost window
    ) {
        self.getWindowFrame = getWindowFrame
        self.otherWindows = otherWindows
    }
    
    // This function maps a cursor movement and returns a new one
    // with respecting alignments.
    //
    // Assuming bottom-left originated movement
    // So upper direction is +y, right direction is +x
    func map(movement: (x: CGFloat, y: CGFloat)) -> (x: CGFloat, y: CGFloat) {
        return movement
    }
}
