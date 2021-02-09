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
    @IBOutlet var imageView: NSImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do view setup here.
        self.box.borderType = .grooveBorder
        self.box.cornerRadius = 10
        self.windowSizeTextField.textColor = NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.75)
        self.windowTitleTextField.textColor = NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.75)
        self.styleNormal()
        
        self.imageView.imageScaling = .scaleProportionallyUpOrDown
    }
    
    func styleNormal() {
        self.box.borderWidth = 1
        self.box.borderColor = NSColor(calibratedRed: 0.75, green: 0.75, blue: 0.75, alpha: 0.5)
        self.box.fillColor = NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.75)
    }
    
    func styleSelected() {
        self.box.borderWidth = 5
        self.box.borderColor = NSColor(calibratedRed: 0.106, green: 0.537, blue: 0.937, alpha: 1.0)
        self.box.fillColor = NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.05, alpha: 0.95)
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

