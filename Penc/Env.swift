//
//  Env.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 18.05.2018.
//  Copyright © 2018 Deniz Gurkaynak. All rights reserved.
//

import Foundation


struct Env {
    
    private static let production : Bool = {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }()
    
    static func isProduction () -> Bool {
        return self.production
    }
    
}
