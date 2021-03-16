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
    func onActivationAborted()
    func onKeyDownWhileActivated(pressedKeys: Set<UInt16>)
}

private enum ActivationState: String {
    case idle
    case waitingForSecondActivationModifierKeyPress
    case holdActivationModifierKeyToActivate
    case active
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
    private var pressedKeys = Set<UInt16>()
    
    private var state = ActivationState.idle
    
    private var secondActivationModifierKeyPressTimeoutTask: DispatchWorkItem?
    var secondActivationModifierKeyPress = 0.3
    
    private var holdActivationModifierKeyTimeoutTask: DispatchWorkItem?
    var holdActivationModifierKeyTimeout = 0.10
    
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
        Logger.shared.log("Modifier key event", [
            "state": self.state.rawValue,
            "flags": humanReadableModifierFlags(flags),
        ])
        
        // Allow working while caps lock is on
        if flags == [] || flags == [NSEvent.ModifierFlags.capsLock] {
            self.handleEmptyModifierKey()
        } else if flags == [self.activationModifierKey] || flags == [self.activationModifierKey, NSEvent.ModifierFlags.capsLock] {
            self.handleActivationModifierKey()
        } else {
            self.handleOtherModifierKeyCombinations()
        }
    }
    
    private func onKeyDown(_ event: NSEvent) {
        guard !event.isARepeat else { return }
        
        Logger.shared.log("Key down event", [
            "state": self.state.rawValue,
            "alreadPressedKeys": self.pressedKeys,
            "keyCode": event.keyCode // Keycode list: https://boredzo.org/blog/archives/2007-05-22/virtual-key-codes
        ])
        
        switch self.state {
        case .idle:
            // NOOP
            break
        case .waitingForSecondActivationModifierKeyPress:
            // Go back to idle state
            self.secondActivationModifierKeyPressTimeoutTask?.cancel()
            self.secondActivationModifierKeyPressTimeoutTask = nil
            
            self.state = .idle
        case .holdActivationModifierKeyToActivate:
            // Go back to idle state
            self.holdActivationModifierKeyTimeoutTask?.cancel()
            self.holdActivationModifierKeyTimeoutTask = nil
            
            self.state = .idle
        case .active:
            switch event.keyCode {
            case 123: // left
                if self.pressedKeys.contains(124) {
                    // NOOP, right key is already down
                    return
                }
                
                self.pressedKeys.insert(event.keyCode)
                self.delegate?.onKeyDownWhileActivated(pressedKeys: self.pressedKeys)
            case 124: // right
                if self.pressedKeys.contains(123) {
                    // NOOP, left key is already down
                    return
                }
                
                self.pressedKeys.insert(event.keyCode)
                self.delegate?.onKeyDownWhileActivated(pressedKeys: self.pressedKeys)
            case 125: // down
                if self.pressedKeys.contains(126) {
                    // NOOP, up key is already down
                    return
                }
                
                self.pressedKeys.insert(event.keyCode)
                self.delegate?.onKeyDownWhileActivated(pressedKeys: self.pressedKeys)
            case 126: // up
                if self.pressedKeys.contains(125) {
                    // NOOP, down is already down
                    return
                }
                
                self.pressedKeys.insert(event.keyCode)
                self.delegate?.onKeyDownWhileActivated(pressedKeys: self.pressedKeys)
            case 36: // enter
                self.pressedKeys.insert(event.keyCode)
                self.delegate?.onKeyDownWhileActivated(pressedKeys: self.pressedKeys)
            default: // unknown key
                self.state = .idle
                self.delegate?.onActivationAborted()
            }
        }
    }

    private func onKeyUp(_ event: NSEvent) {
        guard self.state == .active else { return }
        
        Logger.shared.log("Key up event", [
            "state": self.state.rawValue,
            "alreadPressedKeys": self.pressedKeys,
            "keyCode": event.keyCode // Keycode list: https://boredzo.org/blog/archives/2007-05-22/virtual-key-codes
        ])
        
        self.pressedKeys.remove(event.keyCode)
    }
    
    private func handleEmptyModifierKey() {
        switch self.state {
        case .idle:
            // NOOP
            break
        case .waitingForSecondActivationModifierKeyPress:
            // NOOP
            // First activation modKey is released
            break
        case .holdActivationModifierKeyToActivate:
            // Go back to idle state
            self.holdActivationModifierKeyTimeoutTask?.cancel()
            self.holdActivationModifierKeyTimeoutTask = nil
            
            self.state = .idle
        case .active:
            // Go back to idle state w/ completed event
            self.state = .idle
            self.delegate?.onActivationCompleted()
        }
    }
    
    private func handleActivationModifierKey() {
        switch self.state {
        case .idle:
            // Switch to waiting state
            self.secondActivationModifierKeyPressTimeoutTask?.cancel()
            self.secondActivationModifierKeyPressTimeoutTask = DispatchWorkItem {
                self.handleSecondActivationModifierKeyPressTimeout()
            }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + self.secondActivationModifierKeyPress, execute: self.secondActivationModifierKeyPressTimeoutTask!)
            
            self.state = .waitingForSecondActivationModifierKeyPress
        case .waitingForSecondActivationModifierKeyPress:
            // Switch to hold state
            self.secondActivationModifierKeyPressTimeoutTask?.cancel()
            self.secondActivationModifierKeyPressTimeoutTask = nil
            
            self.holdActivationModifierKeyTimeoutTask?.cancel()
            self.holdActivationModifierKeyTimeoutTask = DispatchWorkItem {
                self.handleHoldActivationModifierKeyTimeout()
            }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + self.holdActivationModifierKeyTimeout, execute: self.holdActivationModifierKeyTimeoutTask!)
            
            self.state = .holdActivationModifierKeyToActivate
        case .holdActivationModifierKeyToActivate:
            // NOOP
            break
        case .active:
            // NOOP
            break
        }
    }
    
    private func handleOtherModifierKeyCombinations() {
        switch self.state {
        case .idle:
            // NOOP
            break
        case .waitingForSecondActivationModifierKeyPress:
            // Go back to idle state
            self.secondActivationModifierKeyPressTimeoutTask?.cancel()
            self.secondActivationModifierKeyPressTimeoutTask = nil
            
            self.state = .idle
        case .holdActivationModifierKeyToActivate:
            // Go back to idle state
            self.holdActivationModifierKeyTimeoutTask?.cancel()
            self.holdActivationModifierKeyTimeoutTask = nil
            
            self.state = .idle
        case .active:
            // Go back to idle state w/ aborted event
            self.state = .idle
            self.delegate?.onActivationAborted()
        }
    }
    
    private func handleSecondActivationModifierKeyPressTimeout() {
        Logger.shared.log("Timeout for second activation modifier key press", [
            "state": self.state.rawValue,
            "timeoutDuration": self.secondActivationModifierKeyPress
        ])
        
        switch self.state {
        case .idle:
            // Not expected
            break
        case .waitingForSecondActivationModifierKeyPress:
            // Go back to idle state
            self.secondActivationModifierKeyPressTimeoutTask?.cancel()
            self.secondActivationModifierKeyPressTimeoutTask = nil
            
            self.state = .idle
        case .holdActivationModifierKeyToActivate:
            // Not expected
            break
        case .active:
            // Not expected
            break
        }
    }
    
    private func handleHoldActivationModifierKeyTimeout() {
        Logger.shared.log("Timeout for holding activation modifier key", [
            "state": self.state.rawValue,
            "timeoutDuration": self.holdActivationModifierKeyTimeout
        ])
        
        switch self.state {
        case .idle:
            // Not expected
            break
        case .waitingForSecondActivationModifierKeyPress:
            // Not expected
            break
        case .holdActivationModifierKeyToActivate:
            // Go to activate state w/ activated event
            self.holdActivationModifierKeyTimeoutTask?.cancel()
            self.holdActivationModifierKeyTimeoutTask = nil
            self.pressedKeys.removeAll()
            self.state = .active
            self.delegate?.onActivationStarted()
        case .active:
            // Not expected
            break
        }
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

fileprivate func humanReadableModifierFlags(_ flags: NSEvent.ModifierFlags) -> String {
    var keys: [String] = []
    if flags.contains(.capsLock) { keys.append("capsLock") }
    if flags.contains(.shift) { keys.append("shift") }
    if flags.contains(.control) { keys.append("control") }
    if flags.contains(.option) { keys.append("option") }
    if flags.contains(.command) { keys.append("command") }
    if flags.contains(.numericPad) { keys.append("numericPad") }
    if flags.contains(.help) { keys.append("help") }
    return keys.joined(separator: " ")
}
