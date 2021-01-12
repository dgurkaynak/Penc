//
//  WindowHandle.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 11.01.2021.
//  Copyright © 2021 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa
import Silica

class PWindowHandle {
    var appPid: pid_t
    var windowNumber: Int
    var zIndex: Int
    var oldRect: CGRect // bottom-left originated
    var newRect: CGRect // bottom-left originated
    
    var placeholderWindow: PlaceholderWindow
    var placeholderWindowViewController: PlaceholderWindowViewController
    
    var siWindow: SIWindow
}
