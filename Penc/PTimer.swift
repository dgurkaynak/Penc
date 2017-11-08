//
//  Timer.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 7.11.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Foundation

class PTimer {
    let startTime = mach_absolute_time()
    
    func end() -> UInt64 {
        let elapsed = mach_absolute_time() - self.startTime
        var timeBaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timeBaseInfo)
        let elapsedNano = elapsed * UInt64(timeBaseInfo.numer) / UInt64(timeBaseInfo.denom)
        return elapsedNano
    }
}
