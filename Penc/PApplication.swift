//
//  PApplication.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 8.11.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa


@objc(PApplication)
class PApplication: NSApplication {
    // https://stackoverflow.com/questions/4001565/missing-keyup-events-on-meaningful-key-combinations-e-g-select-till-beginning
    override func sendEvent(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        if event.type == .keyUp && flags == [.command] {
            self.keyWindow?.sendEvent(event)
        } else {
            super.sendEvent(event)
        }
    }
}
