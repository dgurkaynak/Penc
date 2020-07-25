//
//  ActivationHandler.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 7.11.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa


protocol KeyboardListenerDelegate: class {
    func onActivationStarted(activationHandler: KeyboardListener)
    func onActivationCompleted(activationHandler: KeyboardListener)
    func onActivationCancelled(activationHandler: KeyboardListener)
}

class KeyboardListener {
    
    weak var delegate: KeyboardListenerDelegate?
    private var globalModifierKeyMonitor: Any?
    private var localModifierKeyMonitor: Any?
    private var globalKeyDownMonitor: Any?
    private var localKeyDownMonitor: Any?
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
        self.globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { (event) in
            self.onKeyDown(event)
        }
        self.localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (event) in
            self.onKeyDown(event)
            return event
        }
    }
    
    func setDelegate(_ delegate: KeyboardListenerDelegate) {
        self.delegate = delegate
    }
    
    private func onModifierKeyEvent(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        if flags == [] || flags == [NSEvent.ModifierFlags.capsLock] {
            // Modifier key released, it could be completion or gap between double press
            self.complete()
        } else if flags == [self.activationModifierKey] || flags == [self.activationModifierKey, NSEvent.ModifierFlags.capsLock] {
            if self.activationTimer == nil {
                // Start timer
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
            self.cancel()
        }
    }
    
    private func onKeyDown(_ event: NSEvent) {
        self.cancel()
    }
    
    private func activate() {
        guard !self.active else { return }
        self.active = true
        self.activationTimer = nil
        self.delegate?.onActivationStarted(activationHandler: self)
    }
    
    private func complete() {
        guard self.active else { return }
        self.active = false
        self.activationTimer = nil
        self.delegate?.onActivationCompleted(activationHandler: self)
    }
    
    private func cancel() {
        self.activationTimer = nil
        guard self.active else { return }
        self.active = false
        self.delegate?.onActivationCancelled(activationHandler: self)
    }
    
    deinit {
        NSEvent.removeMonitor(self.localModifierKeyMonitor as Any)
        NSEvent.removeMonitor(self.globalModifierKeyMonitor as Any)
        NSEvent.removeMonitor(self.localKeyDownMonitor as Any)
        NSEvent.removeMonitor(self.globalKeyDownMonitor as Any)
    }
    
}
