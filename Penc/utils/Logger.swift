//
//  Logger.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 24.07.2020.
//  Copyright © 2020 Deniz Gurkaynak. All rights reserved.
//

import Foundation

enum LogLevel: String {
    case debug = "debug"
    case info = "info"
    case warn = "warn"
    case error = "error"
}

class Logger {
    static let shared = Logger()
    
    let fileUrl = URL(fileURLWithPath: "/tmp/penc.log")
    let fileHandle: FileHandle?
    
    private init() {
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
    
    func debug(_ message: String) {
        self.log(level: .debug, message: message)
    }
    
    func info(_ message: String) {
        self.log(level: .info, message: message)
    }
    
    func warn(_ message: String) {
        self.log(level: .warn, message: message)
    }
    
    func error(_ message: String) {
        self.log(level: .error, message: message)
    }
    
    func log(level: LogLevel, message: String) {
        let ts = Date().timeIntervalSince1970
        let logString = "\(ts) - [\(level)] \(message)"
        
        #if DEBUG
        print(logString)
        #endif
        
        self.fileHandle?.write("\(logString)\n".data(using: .utf8)!)
    }
}
