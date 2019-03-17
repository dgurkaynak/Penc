//
//  SIWindowExtension.swift
//  Penc
//
//  Created by Lukas Stabe on 07.03.2019
//  Copyright © 2019 Deniz Gurkaynak. All rights reserved.
//

import Silica

extension SIWindow {
    func focusThisWindowOnly() {
        NSRunningApplication(processIdentifier: processIdentifier())?.activate(options: .activateIgnoringOtherApps)
        AXUIElementSetAttributeValue(axElementRef, NSAccessibilityAttributeName.main.rawValue as CFString, kCFBooleanTrue)
    }
}
