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
    
    private static let key_modifierKey1Mask = "modifierKey1Mask"
    private static let key_activationDelay = "activationDelay"
    private static let key_swipeThreshold = "swipeThreshold"
    private static let key_inferMagnificationAngle = "inferMagnificationAngle"
    
    weak var delegate: PreferencesDelegate?
    
    var modifierKey1Mask: NSEvent.ModifierFlags {
        didSet {
            UserDefaults.standard.set(self.modifierKey1Mask.rawValue, forKey: Preferences.key_modifierKey1Mask)
            self.delegate?.onPreferencesChanged(preferences: self)
        }
    }
    
    var activationDelay: Float {
        didSet {
            UserDefaults.standard.set(self.activationDelay, forKey: Preferences.key_activationDelay)
            self.delegate?.onPreferencesChanged(preferences: self)
        }
    }
    
    var swipeThreshold: CGFloat {
        didSet {
            UserDefaults.standard.set(self.swipeThreshold, forKey: Preferences.key_swipeThreshold)
            self.delegate?.onPreferencesChanged(preferences: self)
        }
    }
    
    var inferMagnificationAngle: Bool {
        didSet {
            UserDefaults.standard.set(self.inferMagnificationAngle, forKey: Preferences.key_inferMagnificationAngle)
            self.delegate?.onPreferencesChanged(preferences: self)
        }
    }
    
    @available(OSX, deprecated: 10.10)
    @objc dynamic var launchAtLogin : Bool {
        get {
            guard let jobDicts = SMCopyAllJobDictionaries( kSMDomainUserLaunchd ).takeRetainedValue() as? [[String:Any]] else { return false }
            return jobDicts.first(where: { $0["Label"] as! String == Bundle.main.bundleIdentifier! }) != nil
        }
    }
    
    private init() {
        let defaults = UserDefaults.standard
        
        let modifierKey1Mask_int = defaults.object(forKey: Preferences.key_modifierKey1Mask) as? Int
        if modifierKey1Mask_int == nil {
            self.modifierKey1Mask = [.function]
            UserDefaults.standard.set(self.modifierKey1Mask.rawValue, forKey: Preferences.key_modifierKey1Mask)
        } else {
            self.modifierKey1Mask = NSEvent.ModifierFlags.init(rawValue: UInt(modifierKey1Mask_int!))
        }
        
        let activationDelay = defaults.object(forKey: Preferences.key_activationDelay) as? Float
        if activationDelay == nil {
            self.activationDelay = 1.0
            UserDefaults.standard.set(self.activationDelay, forKey: Preferences.key_activationDelay)
        } else {
            self.activationDelay = activationDelay!
        }
        
        let swipeThreshold = defaults.object(forKey: Preferences.key_swipeThreshold) as? CGFloat
        if swipeThreshold == nil {
            self.swipeThreshold = 20.0
            UserDefaults.standard.set(self.swipeThreshold, forKey: Preferences.key_swipeThreshold)
        } else {
            self.swipeThreshold = swipeThreshold!
        }
        
        let inferMagnificationAngle = defaults.object(forKey: Preferences.key_inferMagnificationAngle) as? Bool
        if inferMagnificationAngle == nil {
            self.inferMagnificationAngle = true
            UserDefaults.standard.set(self.inferMagnificationAngle, forKey: Preferences.key_inferMagnificationAngle)
        } else {
            self.inferMagnificationAngle = inferMagnificationAngle!
        }
    }
    
    func setDelegate(_ delegate: PreferencesDelegate?) {
        self.delegate = delegate
    }
    
    func reset() {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        self.modifierKey1Mask = [.function]
        self.activationDelay = 1.0
        self.swipeThreshold = 20.0
        self.inferMagnificationAngle = true
    }
    
    func setLaunchAtLogin(_ value: Bool) -> Bool {
        return SMLoginItemSetEnabled(Bundle.main.bundleIdentifier! as CFString, value)
    }
}
