//
//  CGRectExtension.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 31.10.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa


extension CGRect {
    func topLeft2bottomLeft(_ screen: NSScreen) -> CGRect {
        return CGRect(x: self.origin.x, y: screen.frame.height - self.height - self.origin.y, width: self.width, height: self.height)
    }
}
