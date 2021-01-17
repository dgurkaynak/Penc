//
//  Preferences.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 6.11.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa
import ServiceManagement

protocol PreferencesDelegate: class {
    func onPreferencesChanged()
}

final class Preferences {
    static let shared = Preferences()
    
    private static let key_activationModifierKey = "activationModifierKey"
    private static let key_activationSensitivity = "activationSensitivity"
    private static let key_holdDuration = "holdDuration"
    private static let key_swipeThreshold = "swipeThreshold"
    private static let key_disabledApps = "disabledApps"
    private static let key_reverseScroll = "reverseScroll"
    private static let key_windowSelection = "windowSelection"
    private static let key_customActionsForScreenPrefix = "customActionsForScreen"

    weak var delegate: PreferencesDelegate?
    
    var activationModifierKey: NSEvent.ModifierFlags {
        didSet {
            UserDefaults.standard.set(self.activationModifierKey.rawValue, forKey: Preferences.key_activationModifierKey)
            self.delegate?.onPreferencesChanged()
        }
    }
    
    var activationSensitivity: Float {
        didSet {
            UserDefaults.standard.set(self.activationSensitivity, forKey: Preferences.key_activationSensitivity)
            self.delegate?.onPreferencesChanged()
        }
    }
    
    var holdDuration: Float {
        didSet {
            UserDefaults.standard.set(self.holdDuration, forKey: Preferences.key_holdDuration)
            self.delegate?.onPreferencesChanged()
        }
    }
    
    var swipeThreshold: CGFloat {
        didSet {
            UserDefaults.standard.set(self.swipeThreshold, forKey: Preferences.key_swipeThreshold)
            self.delegate?.onPreferencesChanged()
        }
    }
    
    var disabledApps: [String] {
        didSet {
            UserDefaults.standard.set(self.disabledApps, forKey: Preferences.key_disabledApps)
            self.delegate?.onPreferencesChanged()
        }
    }
    
    @available(OSX, deprecated: 10.10)
    @objc dynamic var launchAtLogin : Bool {
        get {
            guard let jobDicts = SMCopyAllJobDictionaries( kSMDomainUserLaunchd ).takeRetainedValue() as? [[String:Any]] else { return false }
            return jobDicts.first(where: { $0["Label"] as! String == "com.denizgurkaynak.PencLauncher" }) != nil
        }
    }
    
    var windowSelection: String {
        didSet {
            UserDefaults.standard.set(self.windowSelection, forKey: Preferences.key_windowSelection)
            self.delegate?.onPreferencesChanged()
        }
    }
    
    var reverseScroll: Bool {
        didSet {
            UserDefaults.standard.set(self.reverseScroll, forKey: Preferences.key_reverseScroll)
            self.delegate?.onPreferencesChanged()
        }
    }
    
    private init() {
        let defaults = UserDefaults.standard
        
        let activationModifierKey_int = defaults.object(forKey: Preferences.key_activationModifierKey) as? Int
        if activationModifierKey_int == nil {
            self.activationModifierKey = .command
            UserDefaults.standard.set(self.activationModifierKey.rawValue, forKey: Preferences.key_activationModifierKey)
        } else {
            self.activationModifierKey = NSEvent.ModifierFlags.init(rawValue: UInt(activationModifierKey_int!))
        }
        
        let activationSensitivity = defaults.object(forKey: Preferences.key_activationSensitivity) as? Float
        if activationSensitivity == nil {
            self.activationSensitivity = 0.3
            UserDefaults.standard.set(self.activationSensitivity, forKey: Preferences.key_activationSensitivity)
        } else {
            self.activationSensitivity = activationSensitivity!
        }
        
        let holdDuration = defaults.object(forKey: Preferences.key_holdDuration) as? Float
        if holdDuration == nil {
            self.holdDuration = 0.1
            UserDefaults.standard.set(self.holdDuration, forKey: Preferences.key_holdDuration)
        } else {
            self.holdDuration = holdDuration!
        }
        
        let swipeThreshold = defaults.object(forKey: Preferences.key_swipeThreshold) as? CGFloat
        if swipeThreshold == nil {
            self.swipeThreshold = 25.0
            UserDefaults.standard.set(self.swipeThreshold, forKey: Preferences.key_swipeThreshold)
        } else {
            self.swipeThreshold = swipeThreshold!
        }
        
        let disabledApps = defaults.object(forKey: Preferences.key_disabledApps) as? [String]
        if disabledApps == nil {
            self.disabledApps = []
            UserDefaults.standard.set(self.disabledApps, forKey: Preferences.key_disabledApps)
        } else {
            self.disabledApps = disabledApps!
        }
        
        let windowSelection = defaults.object(forKey: Preferences.key_windowSelection) as? String
        if windowSelection == nil {
            self.windowSelection = "focused"
            UserDefaults.standard.set(self.windowSelection, forKey: Preferences.key_windowSelection)
        } else {
            self.windowSelection = windowSelection!
        }
        
        let reverseScroll = defaults.object(forKey: Preferences.key_reverseScroll) as? Bool
        if reverseScroll == nil {
            self.reverseScroll = false
            UserDefaults.standard.set(self.reverseScroll, forKey: Preferences.key_reverseScroll)
        } else {
            self.reverseScroll = reverseScroll!
        }
    }
    
    func setDelegate(_ delegate: PreferencesDelegate?) {
        self.delegate = delegate
    }
    

    // [width, height]
    func getCustomActions(forScreenNumber: NSNumber) -> [String: [Double]] {
        let preferenceKey = "\(Preferences.key_customActionsForScreenPrefix)_\(forScreenNumber.intValue)"
        let customActions = UserDefaults.standard.object(forKey: preferenceKey) as? [String: [Double]] ?? [
            "top": [1, 0.5],
            "topRight": [0.5, 0.5],
            "right": [0.5, 1],
            "bottomRight": [0.5, 0.5],
            "bottom": [1, 0.5],
            "bottomLeft": [0.5, 0.5],
            "left": [0.5, 1],
            "topLeft": [0.5, 0.5],
            "dblClick": [1, 1]
        ]
        return customActions
    }

    func setCustomActions(_ customActions: [String: [Double]], forScreenNumber: NSNumber) {
        let preferenceKey = "\(Preferences.key_customActionsForScreenPrefix)_\(forScreenNumber.intValue)"
        UserDefaults.standard.set(customActions, forKey: preferenceKey)
    }

    func reset() {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        self.activationModifierKey = .command
        self.activationSensitivity = 0.3
        self.holdDuration = 0.1
        self.swipeThreshold = 25.0
        self.disabledApps = []
        self.windowSelection = "focused"
        self.reverseScroll = false
    }
    
    func setLaunchAtLogin(_ value: Bool) -> Bool {
        return SMLoginItemSetEnabled("com.denizgurkaynak.PencLauncher" as CFString, value)
    }
}
