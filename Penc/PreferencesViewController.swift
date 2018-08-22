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
    @IBOutlet var launchAtLoginCheckbox: NSButton!
    @IBOutlet var resetDefaultsButton: NSButton!
    @IBOutlet var modifierKeyPopUpButton: NSPopUpButton!
    @IBOutlet var reverseScrollCheckbox: NSButton!
    @IBOutlet var windowSelectionPopUpButton: NSPopUpButton!
    
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
        
        self.windowSelectionPopUpButton.removeAllItems()
        self.windowSelectionPopUpButton.addItems(withTitles: [
            "Focused window",
            "Under mouse cursor"
        ])
        self.windowSelectionPopUpButton.target = self
        self.windowSelectionPopUpButton.action = #selector(onWindowSelectionPopUpButtonChange)
        
        self.reverseScrollCheckbox.target = self
        self.reverseScrollCheckbox.action = #selector(onReverseScrollCheckboxChange)
        
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
        
        let windowSelection = Preferences.shared.windowSelection
        switch windowSelection {
        case "focused":
            self.windowSelectionPopUpButton.selectItem(at: 0)
        case "underCursor":
            self.windowSelectionPopUpButton.selectItem(at: 1)
        default:
            self.windowSelectionPopUpButton.selectItem(at: 0)
        }
        
        self.reverseScrollCheckbox.state = Preferences.shared.reverseScroll ? .on : .off
        
        self.launchAtLoginCheckbox.state = Preferences.shared.launchAtLogin ? .on : .off
    }
    
    @objc private func onModifierKeyPopUpButtonChange() {
        switch self.modifierKeyPopUpButton.indexOfSelectedItem {
        case 0:
            Preferences.shared.activationModifierKey = .command
            log.info("Set activation modifier key as Command")
        case 1:
            Preferences.shared.activationModifierKey = .option
            log.info("Set activation modifier key as Option")
        case 2:
            Preferences.shared.activationModifierKey = .control
            log.info("Set activation modifier key as Control")
        case 3:
            Preferences.shared.activationModifierKey = .shift
            log.info("Set activation modifier key as Shift")
        default:
            Preferences.shared.activationModifierKey = .command
            log.warning("Unknown activation modifier key index, set activation modifier key as Command anyway")
        }
    }
    
    @objc private func onDoublePressSensitivitySliderChange() {
        self.doublePressSensitivityLabel.stringValue = "\(self.doublePressSensitivitySider.integerValue) ms"
        Preferences.shared.activationSensitivity = self.doublePressSensitivitySider.floatValue / 1000
        log.info("Set activation double press sensitivity \(Preferences.shared.activationSensitivity)")
    }
    
    @objc private func onSwipeSensitivitySliderChange() {
        self.swipeSensitivityLabel.stringValue = String(format: "%.2f", self.swipeSensitivitySlider.floatValue)
        Preferences.shared.swipeThreshold = CGFloat(55 - self.swipeSensitivitySlider.floatValue)
        log.info("Set swipe threshold \(Preferences.shared.swipeThreshold)")
    }
    
    @objc private func onWindowSelectionPopUpButtonChange() {
        switch self.windowSelectionPopUpButton.indexOfSelectedItem {
        case 0:
            Preferences.shared.windowSelection = "focused"
            log.info("Set window selection as focused")
        case 1:
            Preferences.shared.windowSelection = "underCursor"
            log.info("Set window selection as under cursor")
        default:
            Preferences.shared.windowSelection = "focused"
            log.warning("Unknown window selection index, set window selection as focused anyway")
        }
    }
    
    @objc private func onReverseScrollCheckboxChange() {
        Preferences.shared.reverseScroll = self.reverseScrollCheckbox.state == .on
        log.info("Set reverse scroll to \(self.reverseScrollCheckbox.state == .on)")
    }
    
    @objc private func onLaunchAtLoginCheckboxChange() {
        log.info("Setting launch at login to \(self.launchAtLoginCheckbox.state == .on)")
        if !Preferences.shared.setLaunchAtLogin(self.launchAtLoginCheckbox.state == .on) {
            log.error("Could not add Penc to login items")
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
            log.info("Reset all preferences to default")
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
