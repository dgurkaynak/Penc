//
//  Logger.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 24.07.2020.
//  Copyright © 2020 Deniz Gurkaynak. All rights reserved.
//

import Foundation

class Logger {
    static let shared = Logger()
    
    let enabled = CommandLine.arguments.contains("--enable-logging")
    let fileUrl = URL(fileURLWithPath: "/tmp/penc.log")
    var fileHandle: FileHandle? = nil
    
    private init() {
        // Only initalize file handle if the app is running w/ `--enable-logging` argument
        if self.enabled {
            // Ensure file (create if not exists)
            if !FileManager.default.fileExists(atPath: fileUrl.path) {
                do {
                    try "".write(to: fileUrl, atomically: false, encoding: .utf8)
                }
                catch {
                    print("[ERROR] Could not create log file (\(self.fileUrl): \(error.localizedDescription)", error)
                }
            }
            
            // Open & save file handle for later usage
            do {
                self.fileHandle = try FileHandle(forWritingTo: fileUrl)
                self.fileHandle!.seekToEndOfFile()
            } catch {
                print("[ERROR] Could not open file handle: \(error.localizedDescription)", error)
                self.fileHandle = nil
            }
        }
    }
    
    func log(_ message: String, _ payload: Any...) {
        let ts = Date().timeIntervalSince1970
        var logString = "\(ts) - \(message)"
        
        payload.forEach { (item) in
            logString = "\(logString)\n\(item)"
        }
        
        // If you want to log to xcode console in debug mode, uncomment following lines:
        // #if DEBUG
        // print(logString)
        // #endif
        
        self.fileHandle?.write("\(logString)\n".data(using: .utf8)!)
    }
}
