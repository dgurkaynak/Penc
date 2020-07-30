//
//  PreferencesCustomizeActionsViewController.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 26.07.2020.
//  Copyright © 2020 Deniz Gurkaynak. All rights reserved.
//

import Cocoa

enum PreferencesCustomizeActionsError: Error {
    case unexpectedSliderValue
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
    @IBOutlet var actionTopLeftButton: NSButton!
    @IBOutlet var actionTopButton: NSButton!
    @IBOutlet var actionTopRightButton: NSButton!
    @IBOutlet var actionRightButton: NSButton!
    @IBOutlet var actionBottomRightButton: NSButton!
    @IBOutlet var actionBottomButton: NSButton!
    @IBOutlet var actionBottomLeftButton: NSButton!
    @IBOutlet var actionLeftButton: NSButton!
    @IBOutlet var actionDblClickButton: NSButton!
    @IBOutlet var widthSlider: NSSlider!
    @IBOutlet var heightSlider: NSSlider!
    
    private var selectedScreen: NSScreen?
    private var selectedAction = ActionType.topLeft
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        self.preferredContentSize = NSSize(width: self.view.frame.width, height: self.view.frame.height)
        
        self.screenPopUpButton.removeAllItems()
        self.screenPopUpButton.target = self
        self.screenPopUpButton.action = #selector(onScreenPopUpButtonChange)
        self.updateScreens()
        
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
        
        self.widthSlider.target = self
        self.widthSlider.action = #selector(onWidthSliderChange)
        
        self.heightSlider.target = self
        self.heightSlider.action = #selector(onHeightSliderChange)
    }
    
    func update() {
        self.updateScreens()
        self.updateActionButtonStates()
        // TODO: Update sliders
    }
    
    @objc private func onScreenPopUpButtonChange() {
        print("selected screen index \(self.screenPopUpButton.indexOfSelectedItem)")
    }
    
    private func updateScreens() {
        self.screenPopUpButton.removeAllItems()
        
        var selectedScreenStillExists = false
        var selectedScreenNumber: NSNumber?
            
        if self.selectedScreen != nil {
            selectedScreenNumber = (self.selectedScreen!.deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as! NSNumber)
        }
        
        for (index, screen) in NSScreen.screens.enumerated() {
            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as! NSNumber
            
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
            // TODO: Update slider values
        }
    }
    
    @objc private func onWidthSliderChange() {
        do {
            let ratio = try getRatioFromSlider(self.widthSlider)
            print("width ratio is \(ratio)")
        } catch {
            Logger.shared.error("Unexpected width-slider value recieved \(error)")
        }
    }
    
    @objc private func onHeightSliderChange() {
        do {
            let ratio = try getRatioFromSlider(self.heightSlider)
            print("height ratio is \(ratio)")
        } catch {
            Logger.shared.error("Unexpected height-slider value recieved \(error)")
        }
    }
    
    func getRatioFromSlider(_ slider: NSSlider) throws -> Double {
        if slider.integerValue == 1 { return 0.25 }
        if slider.integerValue == 2 { return 0.3333 }
        if slider.integerValue == 3 { return 0.5 }
        if slider.integerValue == 4 { return 0.6666 }
        if slider.integerValue == 5 { return 0.75 }
        if slider.integerValue == 6 { return 1 }
        throw PreferencesCustomizeActionsError.unexpectedSliderValue
    }
    
    @objc private func onActionTopClicked() {
        self.selectedAction = .top
        self.updateActionButtonStates()
    }
    
    @objc private func onActionTopRightClicked() {
        self.selectedAction = .topRight
        self.updateActionButtonStates()
    }
    
    @objc private func onActionRightClicked() {
        self.selectedAction = .right
        self.updateActionButtonStates()
    }
    
    @objc private func onActionBottomRightClicked() {
        self.selectedAction = .bottomRight
        self.updateActionButtonStates()
    }
    
    @objc private func onActionBottomClicked() {
        self.selectedAction = .bottom
        self.updateActionButtonStates()
    }
    
    @objc private func onActionBottomLeftClicked() {
        self.selectedAction = .bottomLeft
        self.updateActionButtonStates()
    }
    
    @objc private func onActionLeftClicked() {
        self.selectedAction = .left
        self.updateActionButtonStates()
    }
    
    @objc private func onActionTopLeftClicked() {
        self.selectedAction = .topLeft
        self.updateActionButtonStates()
    }
    
    @objc private func onActionDblClickClicked() {
        self.selectedAction = .dblClick
        self.updateActionButtonStates()
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
