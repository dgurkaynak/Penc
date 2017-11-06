//
//  PreferencesViewController.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 31.10.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Cocoa

class PreferencesViewController: NSViewController {
    @IBOutlet var modifierKey1CommandCheckbox: NSButton!
    @IBOutlet var modifierKey1OptionCheckbox: NSButton!
    @IBOutlet var modifierKey1ControlCheckbox: NSButton!
    @IBOutlet var modifierKey1ShiftCheckbox: NSButton!
    @IBOutlet var modifierKey1FunctionCheckbox: NSButton!
    @IBOutlet var activationDelaySlider: NSSlider!
    @IBOutlet var activationDelayLabel: NSTextField!
    @IBOutlet var swipeSensitivitySlider: NSSlider!
    @IBOutlet var swipeSensitivityLabel: NSTextField!
    @IBOutlet var inferPinchAngleCheckbox: NSButton!
    @IBOutlet var launchAtLoginCheckbox: NSButton!
    @IBOutlet var resetDefaultsButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.modifierKey1CommandCheckbox.target = self
        self.modifierKey1CommandCheckbox.action = #selector(onModifierKey1CommandCheckboxChange)
        self.modifierKey1OptionCheckbox.target = self
        self.modifierKey1OptionCheckbox.action = #selector(onModifierKey1OptionCheckboxChange)
        self.modifierKey1ControlCheckbox.target = self
        self.modifierKey1ControlCheckbox.action = #selector(onModifierKey1ControlCheckboxChange)
        self.modifierKey1ShiftCheckbox.target = self
        self.modifierKey1ShiftCheckbox.action = #selector(onModifierKey1ShiftCheckboxChange)
        self.modifierKey1FunctionCheckbox.target = self
        self.modifierKey1FunctionCheckbox.action = #selector(onModifierKey1FunctionCheckboxChange)
        
        self.activationDelaySlider.target = self
        self.activationDelaySlider.action = #selector(onActivationDelaySliderChange)
        
        self.swipeSensitivitySlider.target = self
        self.swipeSensitivitySlider.action = #selector(onSwipeSensitivitySliderChange)
        
        self.inferPinchAngleCheckbox.target = self
        self.inferPinchAngleCheckbox.action = #selector(onInferPinchAngleCheckboxChange)
        
        self.launchAtLoginCheckbox.target = self
        self.launchAtLoginCheckbox.action = #selector(onLaunchAtLoginCheckboxChange)
        
        self.resetDefaultsButton.target = self
        self.resetDefaultsButton.action = #selector(onResetDefaultsButtonClick)
        
        self.update()
    }
    
    func update() {
        let modifierKey1Mask = Preferences.shared.modifierKey1Mask
        self.modifierKey1CommandCheckbox.state = modifierKey1Mask.contains(.command) ? .on : .off
        self.modifierKey1OptionCheckbox.state = modifierKey1Mask.contains(.option) ? .on : .off
        self.modifierKey1ControlCheckbox.state = modifierKey1Mask.contains(.control) ? .on : .off
        self.modifierKey1ShiftCheckbox.state = modifierKey1Mask.contains(.shift) ? .on : .off
        self.modifierKey1FunctionCheckbox.state = modifierKey1Mask.contains(.function) ? .on : .off
        
        let activationDelay = Int(Preferences.shared.activationDelay * 1000)
        self.activationDelaySlider.integerValue = activationDelay
        self.activationDelayLabel.stringValue = "\(activationDelay) ms"
        
        let swipeThreshold = Float(Preferences.shared.swipeThreshold)
        let sliderValue = 55 - swipeThreshold
        self.swipeSensitivitySlider.floatValue = sliderValue
        self.swipeSensitivityLabel.stringValue = String(format: "%.2f", sliderValue)
        
        self.inferPinchAngleCheckbox.state = Preferences.shared.inferMagnificationAngle ? .on : .off
        self.launchAtLoginCheckbox.state = Preferences.shared.launchAtLogin ? .on : .off
    }
    
    @objc private func onModifierKey1CommandCheckboxChange() {
        if self.modifierKey1CommandCheckbox.state == .on {
            Preferences.shared.modifierKey1Mask.insert(.command)
            Preferences.shared.modifierKey1Mask = Preferences.shared.modifierKey1Mask // triggering didSet observer
        } else if self.modifierKey1CommandCheckbox.state == .off {
            Preferences.shared.modifierKey1Mask.remove(.command)
            Preferences.shared.modifierKey1Mask = Preferences.shared.modifierKey1Mask
        }
    }
    
    @objc private func onModifierKey1OptionCheckboxChange() {
        if self.modifierKey1OptionCheckbox.state == .on {
            Preferences.shared.modifierKey1Mask.insert(.option)
            Preferences.shared.modifierKey1Mask = Preferences.shared.modifierKey1Mask // triggering didSet observer
        } else if self.modifierKey1OptionCheckbox.state == .off {
            Preferences.shared.modifierKey1Mask.remove(.option)
            Preferences.shared.modifierKey1Mask = Preferences.shared.modifierKey1Mask
        }
    }
    
    @objc private func onModifierKey1ControlCheckboxChange() {
        if self.modifierKey1ControlCheckbox.state == .on {
            Preferences.shared.modifierKey1Mask.insert(.control)
            Preferences.shared.modifierKey1Mask = Preferences.shared.modifierKey1Mask // triggering didSet observer
        } else if self.modifierKey1ControlCheckbox.state == .off {
            Preferences.shared.modifierKey1Mask.remove(.control)
            Preferences.shared.modifierKey1Mask = Preferences.shared.modifierKey1Mask
        }
    }
    
    @objc private func onModifierKey1ShiftCheckboxChange() {
        if self.modifierKey1ShiftCheckbox.state == .on {
            Preferences.shared.modifierKey1Mask.insert(.shift)
            Preferences.shared.modifierKey1Mask = Preferences.shared.modifierKey1Mask // triggering didSet observer
        } else if self.modifierKey1ShiftCheckbox.state == .off {
            Preferences.shared.modifierKey1Mask.remove(.shift)
            Preferences.shared.modifierKey1Mask = Preferences.shared.modifierKey1Mask
        }
    }
    
    @objc private func onModifierKey1FunctionCheckboxChange() {
        if self.modifierKey1FunctionCheckbox.state == .on {
            Preferences.shared.modifierKey1Mask.insert(.function)
            Preferences.shared.modifierKey1Mask = Preferences.shared.modifierKey1Mask // triggering didSet observer
        } else if self.modifierKey1FunctionCheckbox.state == .off {
            Preferences.shared.modifierKey1Mask.remove(.function)
            Preferences.shared.modifierKey1Mask = Preferences.shared.modifierKey1Mask
        }
    }
    
    @objc private func onActivationDelaySliderChange() {
        self.activationDelayLabel.stringValue = "\(self.activationDelaySlider.integerValue) ms"
        Preferences.shared.activationDelay = self.activationDelaySlider.floatValue / 1000
    }
    
    @objc private func onSwipeSensitivitySliderChange() {
        self.swipeSensitivityLabel.stringValue = String(format: "%.2f", self.swipeSensitivitySlider.floatValue)
        Preferences.shared.swipeThreshold = CGFloat(55 - self.swipeSensitivitySlider.floatValue)
    }
    
    @objc private func onInferPinchAngleCheckboxChange() {
        Preferences.shared.inferMagnificationAngle = self.inferPinchAngleCheckbox.state == .on
    }
    
    @objc private func onLaunchAtLoginCheckboxChange() {
        if !Preferences.shared.setLaunchAtLogin(self.launchAtLoginCheckbox.state == .on) {
            let warnAlert = NSAlert();
            warnAlert.messageText = "Could not add Penc to login items";
            warnAlert.informativeText = "Please move Penc app into Applications folder and relaunch."
            warnAlert.layout()
            warnAlert.runModal()
        }
        
        self.launchAtLoginCheckbox.state = Preferences.shared.launchAtLogin ? .on : .off
    }
    
    @objc private func onResetDefaultsButtonClick() {
        let alert = NSAlert()
        alert.messageText = "This will restore Penc's default settings"
        alert.informativeText = "Would you like to restore the default settings? Any customization whill be lost."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            Preferences.shared.reset()
            self.update()
        }
    }
}

extension PreferencesViewController {
    // MARK: Storyboard instantiation
    static func freshController() -> PreferencesViewController {
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier(rawValue: "PreferencesViewController")
        guard let viewController = storyboard.instantiateController(withIdentifier: identifier) as? PreferencesViewController else {
            fatalError("Not found PreferencesViewController in Main.storyboard")
        }
        return viewController
    }
}
