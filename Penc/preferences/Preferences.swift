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
    private static let key_trackpadScrollToSwipeDetectionVelocityThreshold = "swipeDetectionVelocityThreshold"
    private static let key_reverseScroll = "reverseScroll"
    private static let key_disabledApps = "disabledApps"
    private static let key_mouseDragToSwipeDetectionVelocityThreshold = "mouseSwipeDetectionVelocityThreshold"
    private static let key_mouseScrollWheelToResizeSensitivity = "mouseScrollWheelResizeSensitivity"
    private static let key_customActionsForScreenPrefix = "customActionsForScreen"
    private static let key_disableBackgroundBlur = "disableBackgroundBlur"
    private static let key_showWindowSize = "showWindowSize"

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
    
    var trackpadScrollToSwipeDetectionVelocityThreshold: Double {
        didSet {
            UserDefaults.standard.set(self.trackpadScrollToSwipeDetectionVelocityThreshold, forKey: Preferences.key_trackpadScrollToSwipeDetectionVelocityThreshold)
            self.delegate?.onPreferencesChanged()
        }
    }
    
    var disabledApps: [String] {
        didSet {
            UserDefaults.standard.set(self.disabledApps, forKey: Preferences.key_disabledApps)
            self.delegate?.onPreferencesChanged()
        }
    }
    
    @objc dynamic var launchAtLogin : Bool {
        get {
            // There is no way to supress this warning
            // https://github.com/sindresorhus/LaunchAtLogin/tree/0f39982b9d6993eef253b81219d3c39ba1e680f3#im-getting-a-smcopyalljobdictionaries-was-deprecated-in-os-x-1010-warning
            guard let jobDicts = SMCopyAllJobDictionaries( kSMDomainUserLaunchd ).takeRetainedValue() as? [[String:Any]] else { return false }
            return jobDicts.first(where: { $0["Label"] as! String == "com.denizgurkaynak.PencLauncher" }) != nil
        }
    }
    
    var reverseScroll: Bool {
        didSet {
            UserDefaults.standard.set(self.reverseScroll, forKey: Preferences.key_reverseScroll)
            self.delegate?.onPreferencesChanged()
        }
    }
    
    var mouseDragToSwipeDetectionVelocityThreshold: Double {
        didSet {
            UserDefaults.standard.set(self.mouseDragToSwipeDetectionVelocityThreshold, forKey: Preferences.key_mouseDragToSwipeDetectionVelocityThreshold)
            self.delegate?.onPreferencesChanged()
        }
    }
    
    var mouseScrollWheelToResizeSensitivity: Double {
        didSet {
            UserDefaults.standard.set(self.mouseScrollWheelToResizeSensitivity, forKey: Preferences.key_mouseScrollWheelToResizeSensitivity)
            self.delegate?.onPreferencesChanged()
        }
    }
    
    var disableBackgroundBlur: Bool {
        didSet {
            UserDefaults.standard.set(self.disableBackgroundBlur, forKey: Preferences.key_disableBackgroundBlur)
            self.delegate?.onPreferencesChanged()
        }
    }
    
    var showWindowSize: Bool {
        didSet {
            UserDefaults.standard.set(self.showWindowSize, forKey: Preferences.key_showWindowSize)
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
        
        let trackpadScrollToSwipeDetectionVelocityThreshold = defaults.object(forKey: Preferences.key_trackpadScrollToSwipeDetectionVelocityThreshold) as? Double
        if trackpadScrollToSwipeDetectionVelocityThreshold == nil {
            self.trackpadScrollToSwipeDetectionVelocityThreshold = 500
            UserDefaults.standard.set(self.trackpadScrollToSwipeDetectionVelocityThreshold, forKey: Preferences.key_trackpadScrollToSwipeDetectionVelocityThreshold)
        } else {
            self.trackpadScrollToSwipeDetectionVelocityThreshold = trackpadScrollToSwipeDetectionVelocityThreshold!
        }
        
        let disabledApps = defaults.object(forKey: Preferences.key_disabledApps) as? [String]
        if disabledApps == nil {
            self.disabledApps = []
            UserDefaults.standard.set(self.disabledApps, forKey: Preferences.key_disabledApps)
        } else {
            self.disabledApps = disabledApps!
        }
        
        let reverseScroll = defaults.object(forKey: Preferences.key_reverseScroll) as? Bool
        if reverseScroll == nil {
            self.reverseScroll = false
            UserDefaults.standard.set(self.reverseScroll, forKey: Preferences.key_reverseScroll)
        } else {
            self.reverseScroll = reverseScroll!
        }
        
        let mouseDragToSwipeDetectionVelocityThreshold = defaults.object(forKey: Preferences.key_mouseDragToSwipeDetectionVelocityThreshold) as? Double
        if mouseDragToSwipeDetectionVelocityThreshold == nil {
            self.mouseDragToSwipeDetectionVelocityThreshold = 1000
            UserDefaults.standard.set(self.mouseDragToSwipeDetectionVelocityThreshold, forKey: Preferences.key_mouseDragToSwipeDetectionVelocityThreshold)
        } else {
            self.mouseDragToSwipeDetectionVelocityThreshold = mouseDragToSwipeDetectionVelocityThreshold!
        }
        
        let mouseScrollWheelToResizeSensitivity = defaults.object(forKey: Preferences.key_mouseScrollWheelToResizeSensitivity) as? Double
        if mouseScrollWheelToResizeSensitivity == nil {
            self.mouseScrollWheelToResizeSensitivity = 1
            UserDefaults.standard.set(self.mouseScrollWheelToResizeSensitivity, forKey: Preferences.key_mouseScrollWheelToResizeSensitivity)
        } else {
            self.mouseScrollWheelToResizeSensitivity = mouseScrollWheelToResizeSensitivity!
        }
        
        let disableBackgroundBlur = defaults.object(forKey: Preferences.key_disableBackgroundBlur) as? Bool
        if disableBackgroundBlur == nil {
            self.disableBackgroundBlur = false
            UserDefaults.standard.set(self.disableBackgroundBlur, forKey: Preferences.key_disableBackgroundBlur)
        } else {
            self.disableBackgroundBlur = disableBackgroundBlur!
        }
        
        let showWindowSize = defaults.object(forKey: Preferences.key_showWindowSize) as? Bool
        if showWindowSize == nil {
            self.showWindowSize = false
            UserDefaults.standard.set(self.showWindowSize, forKey: Preferences.key_showWindowSize)
        } else {
            self.showWindowSize = showWindowSize!
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
        self.trackpadScrollToSwipeDetectionVelocityThreshold = 500
        self.reverseScroll = false
        self.disabledApps = []
        self.mouseDragToSwipeDetectionVelocityThreshold = 1000
        self.mouseScrollWheelToResizeSensitivity = 5
        self.disableBackgroundBlur = false
        self.showWindowSize = false
    }
    
    func setLaunchAtLogin(_ value: Bool) -> Bool {
        return SMLoginItemSetEnabled("com.denizgurkaynak.PencLauncher" as CFString, value)
    }
}
