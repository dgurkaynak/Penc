//
//  AboutViewController.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 6.11.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Cocoa

class AboutViewController: NSViewController {
    @IBOutlet var versionLabel: NSTextField!
    @IBOutlet var sourceCodeButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let dictionary = Bundle.main.infoDictionary!
        let version = dictionary["CFBundleShortVersionString"] as! String
        let build = dictionary["CFBundleVersion"] as! String
        self.versionLabel.stringValue = "Version \(version) (\(build))"
        
        self.sourceCodeButton.target = self
        self.sourceCodeButton.action = #selector(onSourceCodeButtonClick)
    }
    
    @objc private func onSourceCodeButtonClick() {
        if let url = URL(string: "https://github.com/dgurkaynak/Penc") {
            NSWorkspace.shared.open(url)
        }
    }
}

extension AboutViewController {
    // MARK: Storyboard instantiation
    static func freshController() -> AboutViewController {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let identifier = "AboutViewController"
        guard let viewController = storyboard.instantiateController(withIdentifier: identifier) as? AboutViewController else {
            fatalError("Not found AboutViewController in Main.storyboard")
        }
        return viewController
    }
}
