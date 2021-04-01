//
//  PreferencesCustomizeActionsViewController.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 26.07.2020.
//  Copyright © 2020 Deniz Gurkaynak. All rights reserved.
//

import Cocoa

enum PreferencesCustomizeActionsError: Error {
    case unexpectedSliderIntValue
    case unexpectedSliderRatioValue
}

enum ActionType: String {
    case top = "top"
    case topRight = "topRight"
    case right = "right"
    case bottomRight = "bottomRight"
    case bottom = "bottom"
    case bottomLeft = "bottomLeft"
    case left = "left"
    case topLeft = "topLeft"
    case dblClick = "dblClick"
}

class PreferencesCustomizeActionsViewController: NSViewController {

    @IBOutlet var screenPopUpButton: NSPopUpButton!
    @IBOutlet var screenRefreshButton: NSButton!
    @IBOutlet var actionTopLeftButton: NSButton!
    @IBOutlet var actionTopButton: NSButton!
    @IBOutlet var actionTopRightButton: NSButton!
    @IBOutlet var actionRightButton: NSButton!
    @IBOutlet var actionBottomRightButton: NSButton!
    @IBOutlet var actionBottomButton: NSButton!
    @IBOutlet var actionBottomLeftButton: NSButton!
    @IBOutlet var actionLeftButton: NSButton!
    @IBOutlet var actionDblClickButton: NSButton!
    @IBOutlet var actionDescription: NSTextField!
    @IBOutlet var widthSlider: NSSlider!
    @IBOutlet var heightSlider: NSSlider!
    
    private var selectedScreen: NSScreen?
    private var selectedAction = ActionType.topLeft
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        // This forces toolbar controller to adjust its size
        self.preferredContentSize = NSSize(width: self.view.frame.width, height: self.view.frame.height)
        
        self.screenPopUpButton.removeAllItems()
        self.screenPopUpButton.target = self
        self.screenPopUpButton.action = #selector(onScreenPopUpButtonChange)
        self.updateScreens()
        
        self.screenRefreshButton.target = self
        self.screenRefreshButton.action = #selector(onScreenRefreshButtonClicked)
        
        self.actionTopButton.target = self
        self.actionTopButton.action = #selector(onActionTopClicked)
        self.actionTopRightButton.target = self
        self.actionTopRightButton.action = #selector(onActionTopRightClicked)
        self.actionRightButton.target = self
        self.actionRightButton.action = #selector(onActionRightClicked)
        self.actionBottomRightButton.target = self
        self.actionBottomRightButton.action = #selector(onActionBottomRightClicked)
        self.actionBottomButton.target = self
        self.actionBottomButton.action = #selector(onActionBottomClicked)
        self.actionBottomLeftButton.target = self
        self.actionBottomLeftButton.action = #selector(onActionBottomLeftClicked)
        self.actionLeftButton.target = self
        self.actionLeftButton.action = #selector(onActionLeftClicked)
        self.actionTopLeftButton.target = self
        self.actionTopLeftButton.action = #selector(onActionTopLeftClicked)
        self.actionDblClickButton.target = self
        self.actionDblClickButton.action = #selector(onActionDblClickClicked)
        self.updateActionButtonStates()
        self.updateActionDescription()
        
        self.widthSlider.target = self
        self.widthSlider.action = #selector(onWidthSliderChange)
        
        self.heightSlider.target = self
        self.heightSlider.action = #selector(onHeightSliderChange)
    }
    
    func update() {
        self.updateScreens()
        self.updateActionButtonStates()
        self.updateActionDescription()
        self.updateSliders()
    }
    
    @objc private func onScreenPopUpButtonChange() {
        self.selectedScreen = NSScreen.screens[self.screenPopUpButton.indexOfSelectedItem]
        self.updateSliders()
    }
    
    @objc private func onScreenRefreshButtonClicked() {
        self.updateScreens()
    }
    
    private func updateScreens() {
        self.screenPopUpButton.removeAllItems()
        
        var selectedScreenStillExists = false
        var selectedScreenNumber: NSNumber?
        
        if self.selectedScreen != nil {
            selectedScreenNumber = self.selectedScreen!.getScreenNumber()
        }
        
        for (index, screen) in NSScreen.screens.enumerated() {
            let screenNumber = screen.getScreenNumber()
            
            let screenName = screen.getDeviceName() ?? "Unnamed Screen"
            let resolution = "\(Int(screen.frame.width))x\(Int(screen.frame.height))"
            self.screenPopUpButton.addItem(withTitle: "\(screenName) (\(resolution))")
            
            if screenNumber == selectedScreenNumber {
                self.screenPopUpButton.selectItem(at: index)
                selectedScreenStillExists = true
            }
        }
        
        // If selected screen is not exists, select the first one
        if !selectedScreenStillExists && !NSScreen.screens.isEmpty {
            self.selectedScreen = NSScreen.screens[0]
            self.screenPopUpButton.selectItem(at: 0)
            self.updateSliders()
        }
    }
    
    @objc private func onActionTopClicked() {
        self.selectedAction = .top
        self.updateActionButtonStates()
        self.updateSliders()
        self.updateActionDescription()
    }
    
    @objc private func onActionTopRightClicked() {
        self.selectedAction = .topRight
        self.updateActionButtonStates()
        self.updateSliders()
        self.updateActionDescription()
    }
    
    @objc private func onActionRightClicked() {
        self.selectedAction = .right
        self.updateActionButtonStates()
        self.updateSliders()
        self.updateActionDescription()
    }
    
    @objc private func onActionBottomRightClicked() {
        self.selectedAction = .bottomRight
        self.updateActionButtonStates()
        self.updateSliders()
        self.updateActionDescription()
    }
    
    @objc private func onActionBottomClicked() {
        self.selectedAction = .bottom
        self.updateActionButtonStates()
        self.updateSliders()
        self.updateActionDescription()
    }
    
    @objc private func onActionBottomLeftClicked() {
        self.selectedAction = .bottomLeft
        self.updateActionButtonStates()
        self.updateSliders()
        self.updateActionDescription()
    }
    
    @objc private func onActionLeftClicked() {
        self.selectedAction = .left
        self.updateActionButtonStates()
        self.updateSliders()
        self.updateActionDescription()
    }
    
    @objc private func onActionTopLeftClicked() {
        self.selectedAction = .topLeft
        self.updateActionButtonStates()
        self.updateSliders()
        self.updateActionDescription()
    }
    
    @objc private func onActionDblClickClicked() {
        self.selectedAction = .dblClick
        self.updateActionButtonStates()
        self.updateSliders()
        self.updateActionDescription()
    }
    
    private func updateActionButtonStates() {
        self.actionTopButton.state = self.selectedAction == .top ? .on : .off
        self.actionTopRightButton.state = self.selectedAction == .topRight ? .on : .off
        self.actionRightButton.state = self.selectedAction == .right ? .on : .off
        self.actionBottomRightButton.state = self.selectedAction == .bottomRight ? .on : .off
        self.actionBottomButton.state = self.selectedAction == .bottom ? .on : .off
        self.actionBottomLeftButton.state = self.selectedAction == .bottomLeft ? .on : .off
        self.actionLeftButton.state = self.selectedAction == .left ? .on : .off
        self.actionTopLeftButton.state = self.selectedAction == .topLeft ? .on : .off
        self.actionDblClickButton.state = self.selectedAction == .dblClick ? .on : .off
    }
    
    private func updateActionDescription() {
        switch self.selectedAction {
        case .top:
            self.actionDescription.stringValue = "• With trackpad: Two-finger swipe up\n• With mouse: Drag a window and throw it to top direction\n• With keyboard: Press up arrow key"
        case .topRight:
            self.actionDescription.stringValue = "• With trackpad: Two-finger swipe to top-right direction\n• With mouse: Drag a window and throw it to top-right direction\n• With keyboard: Press up + right arrow keys"
        case .right:
            self.actionDescription.stringValue = "• With trackpad: Two-finger swipe right\n• With mouse: Drag a window and throw it to right direction\n• With keyboard: Press right arrow key"
        case .bottomRight:
            self.actionDescription.stringValue = "• With trackpad: Two-finger swipe to bottom-right direction\n• With mouse: Drag a window and throw it to bottom-right direction\n• With keyboard: Press down + right arrow keys"
        case .bottom:
            self.actionDescription.stringValue = "• With trackpad: Two-finger swipe down\n• With mouse: Drag a window and throw it to down direction\n• With keyboard: Press down arrow key"
        case .bottomLeft:
            self.actionDescription.stringValue = "• With trackpad: Two-finger swipe to bottom-left direction\n• With mouse: Drag a window and throw it to bottom-left direction\n• With keyboard: Press down + left arrow keys"
        case .left:
            self.actionDescription.stringValue = "• With trackpad: Two-finger swipe left\n• With mouse: Drag a window and throw it to left direction\n• With keyboard: Press left arrow key"
        case .topLeft:
            self.actionDescription.stringValue = "• With trackpad: Two-finger swipe to top-left direction\n• With mouse: Drag a window and throw it to top-left direction\n• With keyboard: Press left + up arrow keys"
        case .dblClick:
            self.actionDescription.stringValue = "• With trackpad: Double tap on a window\n• With mouse: Double click on a window\n• With keyboard: Press enter key"
        }
    }
    
    private func updateSliders() {
        guard self.selectedScreen != nil else {
            Logger.shared.log("Could not update sliders, selectedScreen is nil")
            return
        }
        
        let screenNumber = self.selectedScreen!.getScreenNumber()
        guard screenNumber != nil else {
            Logger.shared.log("Could not update sliders, selectedScreen's screenNumber is undefined")
            return
        }
        
        let customActions = Preferences.shared.getCustomActions(forScreenNumber: screenNumber!)
        let customActionEntry = customActions[self.selectedAction.rawValue]
        guard customActionEntry != nil else {
            Logger.shared.log("Could not update sliders, customAction returned nil", [
                "customActionsForScreen": customActions,
                "selectedAction": self.selectedAction.rawValue
            ])
            return
        }
        
        do {
            try self.setSliderValue(self.widthSlider, ratio: customActionEntry![0])
            try self.setSliderValue(self.heightSlider, ratio: customActionEntry![1])
        } catch {
            Logger.shared.log("Could not update sliders' value: \(error)", customActionEntry!)
        }
    }
    
    @objc private func onWidthSliderChange() {
        guard self.selectedScreen != nil else {
            Logger.shared.log("Unexpected error on width slider change, selectedScreen is nil")
            return
        }
        
        let screenNumber = self.selectedScreen!.getScreenNumber()
        guard screenNumber != nil else {
            Logger.shared.log("Unexpected error on width slider change, selectedScreen's screenNumber is undefined")
            return
        }
        
        var customActions = Preferences.shared.getCustomActions(forScreenNumber: screenNumber!)
        guard customActions[self.selectedAction.rawValue] != nil else {
            Logger.shared.log("Unexpected error on width slider change, custom action returned nil", [
                "customActionsForScreen": customActions,
                "selectedAction": self.selectedAction.rawValue
            ])
            return
        }
        
        do {
            let ratio = try getRatioFromSlider(self.widthSlider)
            customActions[self.selectedAction.rawValue]![0] = ratio
            Preferences.shared.setCustomActions(customActions, forScreenNumber: screenNumber!)
        } catch {
            Logger.shared.log("Unexpected error on width slider change: \(error)", [
                "widthSliderValue": self.widthSlider.integerValue,
                "selectedAction": self.selectedAction.rawValue
            ])
        }
    }
    
    @objc private func onHeightSliderChange() {
        guard self.selectedScreen != nil else {
            Logger.shared.log("Unexpected error on height slider change, selectedScreen is nil")
            return
        }
        
        let screenNumber = self.selectedScreen!.getScreenNumber()
        guard screenNumber != nil else {
            Logger.shared.log("Unexpected error on height slider change, selectedScreen's screenNumber is undefined")
            return
        }
        
        var customActions = Preferences.shared.getCustomActions(forScreenNumber: screenNumber!)
        guard customActions[self.selectedAction.rawValue] != nil else {
            Logger.shared.log("Unexpected error on height slider change, custom action returned nil", [
                "customActionsForScreen": customActions,
                "selectedAction": self.selectedAction.rawValue
            ])
            return
        }
        
        do {
            let ratio = try getRatioFromSlider(self.heightSlider)
            customActions[self.selectedAction.rawValue]![1] = ratio
            Preferences.shared.setCustomActions(customActions, forScreenNumber: screenNumber!)
        } catch {
            Logger.shared.log("Unexpected error on height slider change: \(error)", [
                "heightSliderValue": self.heightSlider.integerValue,
                "selectedAction": self.selectedAction.rawValue
            ])
        }
    }
    
    func getRatioFromSlider(_ slider: NSSlider) throws -> Double {
        if slider.integerValue == 1 { return 0.25 }
        if slider.integerValue == 2 { return 0.3333 }
        if slider.integerValue == 3 { return 0.5 }
        if slider.integerValue == 4 { return 0.6666 }
        if slider.integerValue == 5 { return 0.75 }
        if slider.integerValue == 6 { return 1 }
        throw PreferencesCustomizeActionsError.unexpectedSliderIntValue
    }
    
    func setSliderValue(_ slider: NSSlider, ratio: Double) throws {
        let ratioRounded = Double(floor(100 * ratio) / 100)
        
        if ratio == 0.25 { slider.integerValue = 1 }
        else if ratioRounded == 0.33 { slider.integerValue = 2 }
        else if ratio == 0.5 { slider.integerValue = 3 }
        else if ratioRounded == 0.66 { slider.integerValue = 4 }
        else if ratio == 0.75 { slider.integerValue = 5 }
        else if ratio == 1.0 { slider.integerValue = 6 }
        else {
            throw PreferencesCustomizeActionsError.unexpectedSliderRatioValue
        }
    }
    
}


extension PreferencesCustomizeActionsViewController {
    // MARK: Storyboard instantiation
    static func freshController() -> PreferencesCustomizeActionsViewController {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let identifier = "PreferencesCustomizeActionsViewController"
        guard let viewController = storyboard.instantiateController(withIdentifier: identifier) as? PreferencesCustomizeActionsViewController else {
            fatalError("Not found PreferencesCustomizeActionsViewController in Main.storyboard")
        }
        return viewController
    }
}
