//
//  MovableWindow.swift
//  Tunnels
//
//  Copyright © 2018 Confirmed, Inc. All rights reserved.
//

import Cocoa

class MovableWindow: NSWindow {

    override init(contentRect: NSRect,
         styleMask style: NSWindow.StyleMask,
         backing backingStoreType: NSWindow.BackingStoreType,
         defer flag: Bool)
    {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        self.titlebarAppearsTransparent     =     true
        self.titleVisibility                =    .hidden
        self.isMovableByWindowBackground = true
        self.level = .floating
        if #available(OSX 10.13, *) {
            self.backgroundColor = NSColor.init(named: NSColor.Name(rawValue: "onboarding_background_color"))
        } else {
            self.backgroundColor = NSColor.white
        }
        
        self.center()
    }
    
    override func setContentSize(_ size: NSSize) {
        
        super.setContentSize(size)
    }
    
    override var canBecomeKey:Bool {
        return true
    }
    
}
