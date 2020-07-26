//
//  PreferencesCustomizeActionsViewController.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 26.07.2020.
//  Copyright © 2020 Deniz Gurkaynak. All rights reserved.
//

import Cocoa

class PreferencesCustomizeActionsViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        self.preferredContentSize = NSSize(width: self.view.frame.width, height: self.view.frame.height)
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
