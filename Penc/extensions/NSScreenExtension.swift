//
//  NSScreenExtension.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 30.07.2020.
//  Copyright © 2020 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa

// Borrowed from:
// https://gist.github.com/suzp1984/f14cfab6871e51bee70979a40c1c9760

// See also:
// https://stackoverflow.com/questions/61456922/how-can-i-get-the-localized-name-of-an-nsscreen-on-macos-older-than-10-15

extension CGDirectDisplayID {
    func getIOService() -> io_service_t {
        var serialPortIterator = io_iterator_t()
        var ioServ: io_service_t = 0

        let matching = IOServiceMatching("IODisplayConnect")

        let kernResult = IOServiceGetMatchingServices(kIOMasterPortDefault, matching, &serialPortIterator)
        if KERN_SUCCESS == kernResult && serialPortIterator != 0 {
            ioServ = IOIteratorNext(serialPortIterator)

            while ioServ != 0 {
                let info = IODisplayCreateInfoDictionary(ioServ, UInt32(kIODisplayOnlyPreferredName)).takeRetainedValue() as NSDictionary as! [String: AnyObject]
                let venderID = info[kDisplayVendorID] as? UInt32
                let productID = info[kDisplayProductID] as? UInt32
                let serialNumber = info[kDisplaySerialNumber] as? UInt32 ?? 0

                if CGDisplayVendorNumber(self) == venderID &&
                    CGDisplayModelNumber(self) == productID &&
                    CGDisplaySerialNumber(self) == serialNumber {
                    break
                }

                ioServ = IOIteratorNext(serialPortIterator)
            }

            IOObjectRelease(serialPortIterator)
        }

        return ioServ
    }
}

extension NSScreen {
    func getDeviceName() -> String? {
        if #available(OSX 10.15, *) {
            return self.localizedName
        }
        
        // NSScreenNumber is unique, and it does not change after system reboot etc.
        // https://stackoverflow.com/a/16164331
        guard let displayID = deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }

        let ioServicePort = displayID.getIOService()
        if ioServicePort == 0 {
            return nil
        }

        guard let info = IODisplayCreateInfoDictionary(ioServicePort, UInt32(kIODisplayOnlyPreferredName)).takeRetainedValue() as? [String: AnyObject] else {
            return nil
        }

        if let productName = info["DisplayProductName"] as? [String: String],
            let firstKey = Array(productName.keys).first {
            return productName[firstKey]!
        }

        return nil
    }
    
    func getScreenNumber() -> NSNumber? {
        return self.deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? NSNumber
    }
}
