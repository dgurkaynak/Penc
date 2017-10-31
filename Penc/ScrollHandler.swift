//
//  ScrollHandler.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 31.10.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Foundation
import Cocoa

enum ScrollHandlerPhase {
    case BEGAN
    case CHANGED
    case CANCELLED
    case ENDED
}

protocol ScrollHandlerDelegate: class {
    func onScrollBegan(scrollHandler: ScrollHandler)
    func onScrollChanged(scrollHandler: ScrollHandler, delta: (x: CGFloat, y: CGFloat))
    func onScrollCancelled(scrollHandler: ScrollHandler)
    func onScrollEnded(scrollHandler: ScrollHandler, delta: (x: CGFloat, y: CGFloat)?)
}

class ScrollHandler {
    weak var delegate: ScrollHandlerDelegate?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    var phase = ScrollHandlerPhase.ENDED
    var originalPhase = NSEvent.Phase.ended
    var latestDelta: (x: CGFloat, y: CGFloat)?
    var paused = false
    
    init() {
        self.localMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { (event) in
            self.originalPhase = event.phase
            if self.paused { return event }
            self.onEvent(event)
            return event
        }
        self.globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { (event) in
            self.originalPhase = event.phase
            if self.paused { return }
            self.onEvent(event)
        }
    }
    
    func setDelegate(_ delegate: ScrollHandlerDelegate?) {
        self.delegate = delegate
    }
    
    func pause() {
        if self.paused { return }
        self.paused = true
        
        if self.phase == .BEGAN || self.phase == .CHANGED {
            self.cancel()
        }
    }
    
    func resume() {
        if !self.paused { return }
        self.paused = false
        
        if self.originalPhase == NSEvent.Phase.began || self.originalPhase == NSEvent.Phase.changed {
            self.begin()
        }
    }
    
    private func onEvent(_ event: NSEvent) {
        if event.phase == NSEvent.Phase.began {
            self.begin()
        } else if event.phase == NSEvent.Phase.cancelled {
            self.cancel()
        } else if event.phase == NSEvent.Phase.changed {
            if self.phase != .BEGAN && self.phase != .CHANGED {
                return
            }
            self.latestDelta = (x: event.scrollingDeltaX, y: event.scrollingDeltaY)
            self.change()
        } else if event.phase == NSEvent.Phase.ended {
            self.end()
        }
    }
    
    private func begin() {
        self.phase = ScrollHandlerPhase.BEGAN
        self.delegate?.onScrollBegan(scrollHandler: self)
    }
    
    private func cancel() {
        self.phase = ScrollHandlerPhase.CANCELLED
        self.delegate?.onScrollCancelled(scrollHandler: self)
        self.latestDelta = nil
    }
    
    private func change() {
        self.phase = ScrollHandlerPhase.CHANGED
        self.delegate?.onScrollChanged(scrollHandler: self, delta: self.latestDelta!)
    }
    
    private func end() {
        self.phase = ScrollHandlerPhase.ENDED
        self.delegate?.onScrollEnded(scrollHandler: self, delta: self.latestDelta)
        self.latestDelta = nil
    }
    
    deinit {
        NSEvent.removeMonitor(self.globalMonitor as Any)
        NSEvent.removeMonitor(self.localMonitor as Any)
    }
}
