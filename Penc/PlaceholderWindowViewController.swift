//
//  PlaceholderWindowViewController.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 8.11.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Cocoa

class PlaceholderWindowViewController: NSViewController, NSWindowDelegate {
    @IBOutlet var box: NSBox!
    @IBOutlet var windowSizeTextField: NSTextField!
    @IBOutlet var windowTitleTextField: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do view setup here.
        self.box.borderType = .grooveBorder
        self.box.borderWidth = 3
        self.box.cornerRadius = 5
        self.box.borderColor = NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        self.box.fillColor = NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 0.25)
    }
    
    func updateWindowTitleTextField(_ title: String) {
        self.windowTitleTextField.stringValue = title
    }
    
    func updateWindowSizeTextField(_ windowFrame: CGRect) {
        self.windowSizeTextField.stringValue = "\(Int(windowFrame.width)) x \(Int(windowFrame.height))"
    }
    
    func toggleWindowSizeTextField(_ show: Bool) {
        self.windowSizeTextField.alphaValue = show ? 1 : 0
    }
}

extension PlaceholderWindowViewController {
    // MARK: Storyboard instantiation
    static func freshController() -> PlaceholderWindowViewController {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let identifier = "PlaceholderWindowViewController"
        guard let viewController = storyboard.instantiateController(withIdentifier: identifier) as? PlaceholderWindowViewController else {
            fatalError("Not found PlaceholderWindowViewController in Main.storyboard")
        }
        return viewController
    }
}

