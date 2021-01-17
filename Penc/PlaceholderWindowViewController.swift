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
        self.box.cornerRadius = 5
        self.box.fillColor = NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 0.75)
        self.styleNormal()
    }
    
    func styleNormal() {
        self.box.borderWidth = 1
        self.box.borderColor = NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.5)
        
        self.windowSizeTextField.alphaValue = 0
        self.windowTitleTextField.alphaValue = 0
    }
    
    func styleHover() {
        self.box.borderWidth = 3
        self.box.borderColor = NSColor(calibratedRed: 0.106, green: 0.537, blue: 0.937, alpha: 1.0)
        
        self.windowSizeTextField.alphaValue = 1
        self.windowTitleTextField.alphaValue = 1
    }
    
    func updateWindowTitleTextField(_ title: String) {
        self.windowTitleTextField.stringValue = title
    }
    
    func updateWindowSizeTextField(_ windowFrame: CGRect) {
        self.windowSizeTextField.stringValue = "\(Int(windowFrame.width)) x \(Int(windowFrame.height))"
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

