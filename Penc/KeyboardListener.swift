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
    func onActivationStarted()
    func onActivationCompleted()
    func onActivationCancelled()
    func onKeyDown(pressedKeys: Set<UInt16>)
}

class KeyboardListener {
    
    weak var delegate: KeyboardListenerDelegate?
    private var globalModifierKeyMonitor: Any?
    private var localModifierKeyMonitor: Any?
    private var globalKeyDownMonitor: Any?
    private var localKeyDownMonitor: Any?
    private var globalKeyUpMonitor: Any?
    private var localKeyUpMonitor: Any?
    var activationModifierKey = NSEvent.ModifierFlags.command
    var activationTimeout = 0.3
    private var activationTimer: PTimer? = nil
    private var active = false
    private var pressedKeys = Set<UInt16>()
    private var cancelSound = NSSound(named: "Funk")
    
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
        self.globalKeyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { (event) in
            self.onKeyUp(event)
        }
        self.localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (event) in
            self.onKeyDown(event)
            return event
        }
        self.localKeyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { (event) in
            self.onKeyUp(event)
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
        guard self.active else { return }
        guard !event.isARepeat else { return }
        
        switch event.keyCode {
        case 123: // left
            if self.pressedKeys.contains(124) {
                self.cancel()
                return
            }
            self.pressedKeys.insert(event.keyCode)
            self.delegate?.onKeyDown(pressedKeys: self.pressedKeys)
        case 124: // right
            if self.pressedKeys.contains(123) {
                self.cancel()
                return
            }
            self.pressedKeys.insert(event.keyCode)
            self.delegate?.onKeyDown(pressedKeys: self.pressedKeys)
        case 125: // down
            if self.pressedKeys.contains(126) {
                self.cancel()
                return
            }
            self.pressedKeys.insert(event.keyCode)
            self.delegate?.onKeyDown(pressedKeys: self.pressedKeys)
        case 126: // up
            if self.pressedKeys.contains(125) {
                self.cancel()
                return
            }
            self.pressedKeys.insert(event.keyCode)
            self.delegate?.onKeyDown(pressedKeys: self.pressedKeys)
        case 36: // enter
            self.pressedKeys.insert(event.keyCode)
            self.delegate?.onKeyDown(pressedKeys: self.pressedKeys)
        default:
            self.cancel()
        }
    }

    private func onKeyUp(_ event: NSEvent) {
        guard self.active else { return }
        guard !event.isARepeat else { return }
        
        self.pressedKeys.remove(event.keyCode)
    }
    
    private func activate() {
        guard !self.active else { return }
        self.active = true
        self.activationTimer = nil
        self.delegate?.onActivationStarted()
    }
    
    private func complete() {
        guard self.active else { return }
        self.active = false
        self.activationTimer = nil
        self.pressedKeys.removeAll()
        self.delegate?.onActivationCompleted()
    }
    
    private func cancel() {
        self.activationTimer = nil
        guard self.active else { return }
        self.active = false
        self.pressedKeys.removeAll()
        self.delegate?.onActivationCancelled()
        
        // Manually play `dang` or `error` sound
        self.cancelSound?.play()
    }
    
    deinit {
        NSEvent.removeMonitor(self.localModifierKeyMonitor as Any)
        NSEvent.removeMonitor(self.globalModifierKeyMonitor as Any)
        NSEvent.removeMonitor(self.localKeyDownMonitor as Any)
        NSEvent.removeMonitor(self.globalKeyDownMonitor as Any)
        NSEvent.removeMonitor(self.localKeyUpMonitor as Any)
        NSEvent.removeMonitor(self.globalKeyUpMonitor as Any)
    }
    
}
