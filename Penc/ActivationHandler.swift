//
//  ActivationHandler.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 7.11.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa


protocol ActivationHandlerDelegate: class {
    func onActivated(activationHandler: ActivationHandler)
    func onDeactivated(activationHandler: ActivationHandler)
}

class ActivationHandler {
    weak var delegate: ActivationHandlerDelegate?
    private var globalModifierKeyMonitor: Any?
    private var localModifierKeyMonitor: Any?
    var activationModifierKey = NSEvent.ModifierFlags.command
    var activationTimeout = 0.3
    private var activationTimer: PTimer? = nil
    private var active = false
    
    
    init() {
        self.globalModifierKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { (event) in
            self.onModifierKeyEvent(event)
        }
        self.localModifierKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { (event) in
            self.onModifierKeyEvent(event)
            return event
        }
    }
    
    func setDelegate(_ delegate: ActivationHandlerDelegate) {
        self.delegate = delegate
    }
    
    private func onModifierKeyEvent(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        if flags == [] {
            self.deactivate()
        } else if flags == [self.activationModifierKey] {
            if self.activationTimer == nil {
                self.activationTimer = PTimer()
            } else {
                let elapsed = self.activationTimer!.end()
                let timeoutInNs = self.activationTimeout * 1000000000
                
                if elapsed <= UInt64(timeoutInNs) {
                    self.activate()
                } else {
                    // Too late, start over
                    self.activationTimer = PTimer()
                }
            }
        } else {
            self.activationTimer = nil
            self.deactivate()
        }
    }
    
    private func activate() {
        guard !self.active else { return }
        self.active = true
        self.activationTimer = nil
        self.delegate?.onActivated(activationHandler: self)
    }
    
    private func deactivate() {
        guard self.active else { return }
        self.active = false
        self.activationTimer = nil
        self.delegate?.onDeactivated(activationHandler: self)
    }
    
    deinit {
        NSEvent.removeMonitor(self.localModifierKeyMonitor as Any)
        NSEvent.removeMonitor(self.globalModifierKeyMonitor as Any)
    }
}
