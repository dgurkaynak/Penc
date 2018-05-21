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
    func onPreferencesChanged(preferences: Preferences)
}

final class Preferences {
    static let shared = Preferences()
    
    private static let key_activationModifierKey = "activationModifierKey"
    private static let key_activationSensitivity = "activationSensitivity"
    private static let key_swipeThreshold = "swipeThreshold"
    private static let key_disabledApps = "disabledApps"
    
    weak var delegate: PreferencesDelegate?
    
    var activationModifierKey: NSEvent.ModifierFlags {
        didSet {
            UserDefaults.standard.set(self.activationModifierKey.rawValue, forKey: Preferences.key_activationModifierKey)
            self.delegate?.onPreferencesChanged(preferences: self)
        }
    }
    
    var activationSensitivity: Float {
        didSet {
            UserDefaults.standard.set(self.activationSensitivity, forKey: Preferences.key_activationSensitivity)
            self.delegate?.onPreferencesChanged(preferences: self)
        }
    }
    
    var swipeThreshold: CGFloat {
        didSet {
            UserDefaults.standard.set(self.swipeThreshold, forKey: Preferences.key_swipeThreshold)
            self.delegate?.onPreferencesChanged(preferences: self)
        }
    }
    
    var disabledApps: [String] {
        didSet {
            UserDefaults.standard.set(self.disabledApps, forKey: Preferences.key_disabledApps)
            self.delegate?.onPreferencesChanged(preferences: self)
        }
    }
    
    @available(OSX, deprecated: 10.10)
    @objc dynamic var launchAtLogin : Bool {
        get {
            guard let jobDicts = SMCopyAllJobDictionaries( kSMDomainUserLaunchd ).takeRetainedValue() as? [[String:Any]] else { return false }
            return jobDicts.first(where: { $0["Label"] as! String == "com.denizgurkaynak.PencLauncher" }) != nil
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
    }
    
    func setDelegate(_ delegate: PreferencesDelegate?) {
        self.delegate = delegate
    }
    
    func reset() {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        self.activationModifierKey = .command
        self.activationSensitivity = 0.3
        self.swipeThreshold = 25.0
        self.disabledApps = []
    }
    
    func setLaunchAtLogin(_ value: Bool) -> Bool {
        return SMLoginItemSetEnabled("com.denizgurkaynak.PencLauncher" as CFString, value)
    }
}
