//
//  PreferencesWindowController.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 26.07.2020.
//  Copyright © 2020 Deniz Gurkaynak. All rights reserved.
//

import Cocoa

class PreferencesWindowController: NSWindowController {

    @IBOutlet var toolbar: NSToolbar!
    @IBOutlet var generalToolbarItem: NSToolbarItem!
    @IBOutlet var customizeActionsToolbarItem: NSToolbarItem!
    
    private var generalViewController = PreferencesGeneralViewController.freshController()
    private var customizeActionsViewController = PreferencesCustomizeActionsViewController.freshController()
    
    override func windowDidLoad() {
        super.windowDidLoad()
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        
        self.generalToolbarItem.target = self
        self.generalToolbarItem.action = #selector(onToolbarItemClick)
        
        self.customizeActionsToolbarItem.target = self
        self.customizeActionsToolbarItem.action = #selector(onToolbarItemClick)
        
        // Initially show general tab
        self.toolbar.selectedItemIdentifier = self.generalToolbarItem.itemIdentifier
        self.contentViewController = self.generalViewController
    }
    
    @objc private func onToolbarItemClick(_ sender: NSToolbarItem) {
        if sender.tag == 0 {
            self.contentViewController = self.generalViewController
        } else if sender.tag == 1 {
            self.contentViewController = self.customizeActionsViewController
        }
    }

}

extension PreferencesWindowController {
    // MARK: Storyboard instantiation
    static func freshController() -> PreferencesWindowController {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let identifier = "PreferencesWindowController"
        guard let windowController = storyboard.instantiateController(withIdentifier: identifier) as? PreferencesWindowController else {
            fatalError("Not found PreferencesWindowController in Main.storyboard")
        }
        return windowController
    }
}
