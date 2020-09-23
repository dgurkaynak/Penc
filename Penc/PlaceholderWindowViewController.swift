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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
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

