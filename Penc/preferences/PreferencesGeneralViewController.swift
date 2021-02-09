//
//  PreferencesViewController.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 31.10.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Cocoa

class PreferencesGeneralViewController: NSViewController {
    
    @IBOutlet var doublePressSensitivitySider: NSSlider!
    @IBOutlet var doublePressSensitivityLabel: NSTextField!
    @IBOutlet var holdDurationSlider: NSSlider!
    @IBOutlet var holdDurationLabel: NSTextField!
    @IBOutlet var swipeDetectionThresholdSlider: NSSlider!
    @IBOutlet var swipeDetectionThresholdLabel: NSTextField!
    @IBOutlet var launchAtLoginCheckbox: NSButton!
    @IBOutlet var resetDefaultsButton: NSButton!
    @IBOutlet var modifierKeyPopUpButton: NSPopUpButton!
    @IBOutlet var reverseScrollCheckbox: NSButton!
    @IBOutlet var disableBackgroundBlurCheckbox: NSButton!
    @IBOutlet var showWindowSizeCheckbox: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // This forces toolbar controller to adjust its size
        self.preferredContentSize = NSSize(width: self.view.frame.width, height: self.view.frame.height)
        
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
        
        self.holdDurationSlider.target = self
        self.holdDurationSlider.action = #selector(onHoldDurationSliderChange)
        
        self.swipeDetectionThresholdSlider.target = self
        self.swipeDetectionThresholdSlider.action = #selector(onSwipeSensitivitySliderChange)
        
        self.reverseScrollCheckbox.target = self
        self.reverseScrollCheckbox.action = #selector(onReverseScrollCheckboxChange)
        
        self.disableBackgroundBlurCheckbox.target = self
        self.disableBackgroundBlurCheckbox.action = #selector(onDisableBackgroundBlurCheckboxChange)
        
        self.showWindowSizeCheckbox.target = self
        self.showWindowSizeCheckbox.action = #selector(onShowWindowSizeCheckboxChange)
        
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
        
        let holdDuration = Int(Preferences.shared.holdDuration * 1000)
        self.holdDurationSlider.integerValue = holdDuration
        self.holdDurationLabel.stringValue = "\(holdDuration) ms"
        
        let swipeDetectionThreshold = Preferences.shared.swipeDetectionVelocityThreshold
        self.swipeDetectionThresholdSlider.doubleValue = swipeDetectionThreshold
        self.swipeDetectionThresholdLabel.stringValue = String(format: "%.0f px/s", swipeDetectionThreshold)
        
        self.reverseScrollCheckbox.state = Preferences.shared.reverseScroll ? .on : .off
        
        self.disableBackgroundBlurCheckbox.state = Preferences.shared.disableBackgroundBlur ? .on : .off
        
        self.showWindowSizeCheckbox.state = Preferences.shared.showWindowSize ? .on : .off
        
        self.launchAtLoginCheckbox.state = Preferences.shared.launchAtLogin ? .on : .off
    }
    
    @objc private func onModifierKeyPopUpButtonChange() {
        switch self.modifierKeyPopUpButton.indexOfSelectedItem {
        case 0:
            Preferences.shared.activationModifierKey = .command
            Logger.shared.info("Set activation modifier key as Command")
        case 1:
            Preferences.shared.activationModifierKey = .option
            Logger.shared.info("Set activation modifier key as Option")
        case 2:
            Preferences.shared.activationModifierKey = .control
            Logger.shared.info("Set activation modifier key as Control")
        case 3:
            Preferences.shared.activationModifierKey = .shift
            Logger.shared.info("Set activation modifier key as Shift")
        default:
            Preferences.shared.activationModifierKey = .command
            Logger.shared.warn("Unknown activation modifier key index, set activation modifier key as Command anyway")
        }
    }
    
    @objc private func onDoublePressSensitivitySliderChange() {
        self.doublePressSensitivityLabel.stringValue = "\(self.doublePressSensitivitySider.integerValue) ms"
        Preferences.shared.activationSensitivity = self.doublePressSensitivitySider.floatValue / 1000
        Logger.shared.info("Set activation double press sensitivity \(Preferences.shared.activationSensitivity)")
    }
    
    @objc private func onHoldDurationSliderChange() {
        self.holdDurationLabel.stringValue = "\(self.holdDurationSlider.integerValue) ms"
        Preferences.shared.holdDuration = self.holdDurationSlider.floatValue / 1000
        Logger.shared.info("Set hold duration \(Preferences.shared.holdDuration)")
    }
    
    @objc private func onSwipeSensitivitySliderChange() {
        self.swipeDetectionThresholdLabel.stringValue = String(format: "%.0f px/s", self.swipeDetectionThresholdSlider.doubleValue)
        Preferences.shared.swipeDetectionVelocityThreshold = self.swipeDetectionThresholdSlider.doubleValue
        Logger.shared.info("Set swipe detection threshold \(Preferences.shared.swipeDetectionVelocityThreshold) px/s")
    }
    
    @objc private func onReverseScrollCheckboxChange() {
        Preferences.shared.reverseScroll = self.reverseScrollCheckbox.state == .on
        Logger.shared.info("Set reverse scroll to \(self.reverseScrollCheckbox.state == .on)")
    }
    
    @objc private func onDisableBackgroundBlurCheckboxChange() {
        Preferences.shared.disableBackgroundBlur = self.disableBackgroundBlurCheckbox.state == .on
        Logger.shared.info("Set disableBackgroundBlur to \(Preferences.shared.disableBackgroundBlur)")
    }
    
    @objc private func onShowWindowSizeCheckboxChange() {
        Preferences.shared.showWindowSize = self.showWindowSizeCheckbox.state == .on
        Logger.shared.info("Set showWindowSize to \(Preferences.shared.showWindowSize)")
    }
    
    @objc private func onLaunchAtLoginCheckboxChange() {
        Logger.shared.info("Setting launch at login to \(self.launchAtLoginCheckbox.state == .on)")
        if !Preferences.shared.setLaunchAtLogin(self.launchAtLoginCheckbox.state == .on) {
            Logger.shared.error("Could not add Penc to login items")
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
            Logger.shared.info("Reset all preferences to default")
        }
    }
}

extension PreferencesGeneralViewController {
    // MARK: Storyboard instantiation
    static func freshController() -> PreferencesGeneralViewController {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let identifier = "PreferencesGeneralViewController"
        guard let viewController = storyboard.instantiateController(withIdentifier: identifier) as? PreferencesGeneralViewController else {
            fatalError("Not found PreferencesGeneralViewController in Main.storyboard")
        }
        return viewController
    }
}
