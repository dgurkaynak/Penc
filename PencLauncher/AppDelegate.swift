//
//  AppDelegate.swift
//  PencLauncher
//
//  Created by Deniz Gurkaynak on 16.05.2018.
//  Copyright © 2018 Deniz Gurkaynak. All rights reserved.
//

import Cocoa


extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

@NSApplicationMain
class AppDelegate: NSObject {
    
    @objc func terminate() {
        NSApp.terminate(nil)
    }
    
}

extension AppDelegate: NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        let mainAppId = "com.denizgurkaynak.Penc"
        let runningApps = NSWorkspace.shared.runningApplications
        let isMainAppRunning = !runningApps.filter { $0.bundleIdentifier == mainAppId }.isEmpty
        if !isMainAppRunning {
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(self.terminate), name: .killLauncher, object: mainAppId)
            
            let path = Bundle.main.bundlePath as NSString
            var components = path.pathComponents
            components.removeLast()
            components.removeLast()
            components.removeLast()
            components.append("MacOS")
            components.append("Penc")
            
            let newPath = NSString.path(withComponents: components)
            NSWorkspace.shared.launchApplication(newPath)
        } else {
            self.terminate()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}

