//
//  BackgroundImageView.swift
//  
//
//

import Cocoa

class BackgroundImageView: NSImageView {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    override var mouseDownCanMoveWindow:Bool {
        return true
    }
    
}
