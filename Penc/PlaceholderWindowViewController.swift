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
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
//        self.box.fillColor = NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 0.5)
    }
}

extension PlaceholderWindowViewController {
    // MARK: Storyboard instantiation
    static func freshController() -> PlaceholderWindowViewController {
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier(rawValue: "PlaceholderWindowViewController")
        guard let viewController = storyboard.instantiateController(withIdentifier: identifier) as? PlaceholderWindowViewController else {
            fatalError("Not found PlaceholderWindowViewController in Main.storyboard")
        }
        return viewController
    }
}

