//
//  CountryCell.swift
//  Confirmed VPN
//
//  Copyright © 2018 Confirmed, Inc. All rights reserved.
//

import Cocoa

class CountryCell: NSTableRowView {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    @IBOutlet var countryName : NSTextField?
    @IBOutlet var countryFlag : NSImageView?
    
}
