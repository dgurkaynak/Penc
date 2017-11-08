//
//  PreferencesViewController.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 31.10.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Cocoa

class PreferencesViewController: NSViewController {
    
    @IBOutlet var doublePressSensitivitySider: NSSlider!
    @IBOutlet var doublePressSensitivityLabel: NSTextField!
    @IBOutlet var swipeSensitivitySlider: NSSlider!
    @IBOutlet var swipeSensitivityLabel: NSTextField!
    @IBOutlet var inferPinchAngleCheckbox: NSButton!
    @IBOutlet var launchAtLoginCheckbox: NSButton!
    @IBOutlet var resetDefaultsButton: NSButton!
    @IBOutlet var modifierKeyPopUpButton: NSPopUpButton!
    @IBOutlet var showGestureInfoCheckbox: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.modifierKeyPopUpButton.removeAllItems()
        self.modifierKeyPopUpButton.addItems(withTitles: [
            "⌘ Command",
            "⌥ Option",
            "^ Control",
            "⇧ Shift"
        ])
        self.modifierKeyPopUpButton.target = self
        self.modifierKeyPopUpButton.action = #selector(onModifierKeyPopUpButtonChange)
        
        self.doublePressSensitivitySider.target = self
        self.doublePressSensitivitySider.action = #selector(onDoublePressSensitivitySliderChange)
        
        self.swipeSensitivitySlider.target = self
        self.swipeSensitivitySlider.action = #selector(onSwipeSensitivitySliderChange)
        
        self.inferPinchAngleCheckbox.target = self
        self.inferPinchAngleCheckbox.action = #selector(onInferPinchAngleCheckboxChange)
        
        self.showGestureInfoCheckbox.target = self
        self.showGestureInfoCheckbox.action = #selector(onShowGestureInfoCheckboxChange)
        
        self.launchAtLoginCheckbox.target = self
        self.launchAtLoginCheckbox.action = #selector(onLaunchAtLoginCheckboxChange)
        
        self.resetDefaultsButton.target = self
        self.resetDefaultsButton.action = #selector(onResetDefaultsButtonClick)
        
        self.update()
    }
    
    func update() {
        let activationModifierKey = Preferences.shared.activationModifierKey
        switch activationModifierKey {
        case .command:
            self.modifierKeyPopUpButton.selectItem(at: 0)
        case .option:
            self.modifierKeyPopUpButton.selectItem(at: 1)
        case .control:
            self.modifierKeyPopUpButton.selectItem(at: 2)
        case .shift:
            self.modifierKeyPopUpButton.selectItem(at: 3)
        default:
            self.modifierKeyPopUpButton.selectItem(at: 0)
        }
        
        let activationSensitivity = Int(Preferences.shared.activationSensitivity * 1000)
        self.doublePressSensitivitySider.integerValue = activationSensitivity
        self.doublePressSensitivityLabel.stringValue = "\(activationSensitivity) ms"
        
        let swipeThreshold = Float(Preferences.shared.swipeThreshold)
        let sliderValue = 55 - swipeThreshold
        self.swipeSensitivitySlider.floatValue = sliderValue
        self.swipeSensitivityLabel.stringValue = String(format: "%.2f", sliderValue)
        
        self.showGestureInfoCheckbox.state = Preferences.shared.showGestureInfo ? .on : .off
        self.showGestureInfoCheckbox.state = Preferences.shared.showGestureInfo ? .on : .off
        
        self.inferPinchAngleCheckbox.state = Preferences.shared.inferMagnificationAngle ? .on : .off
        self.launchAtLoginCheckbox.state = Preferences.shared.launchAtLogin ? .on : .off
    }
    
    @objc private func onModifierKeyPopUpButtonChange() {
        switch self.modifierKeyPopUpButton.indexOfSelectedItem {
        case 0:
            Preferences.shared.activationModifierKey = .command
        case 1:
            Preferences.shared.activationModifierKey = .option
        case 2:
            Preferences.shared.activationModifierKey = .control
        case 3:
            Preferences.shared.activationModifierKey = .shift
        default:
            Preferences.shared.activationModifierKey = .command
        }
    }
    
    @objc private func onDoublePressSensitivitySliderChange() {
        self.doublePressSensitivityLabel.stringValue = "\(self.doublePressSensitivitySider.integerValue) ms"
        Preferences.shared.activationSensitivity = self.doublePressSensitivitySider.floatValue / 1000
    }
    
    @objc private func onSwipeSensitivitySliderChange() {
        self.swipeSensitivityLabel.stringValue = String(format: "%.2f", self.swipeSensitivitySlider.floatValue)
        Preferences.shared.swipeThreshold = CGFloat(55 - self.swipeSensitivitySlider.floatValue)
    }
    
    @objc private func onInferPinchAngleCheckboxChange() {
        Preferences.shared.inferMagnificationAngle = self.inferPinchAngleCheckbox.state == .on
    }
    
    @objc private func onShowGestureInfoCheckboxChange() {
        Preferences.shared.showGestureInfo = self.showGestureInfoCheckbox.state == .on
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
