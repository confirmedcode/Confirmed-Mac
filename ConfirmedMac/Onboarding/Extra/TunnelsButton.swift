//
//  TunnelsButton.swift
//  Tunnels
//
//  Copyright © 2018 Confirmed, Inc. All rights reserved.
//

import Cocoa

extension NSButton {
    var checked: Bool {
        get {return state == NSControl.StateValue.on}
        set {state = newValue ? NSControl.StateValue.on : NSControl.StateValue.off}
    }
}

@IBDesignable
class TunnelsButton: NSButton {
    var centeredStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
    
    var cornerRadius:CGFloat = 5
    var disabledColor:NSColor = NSColor.lightGray
    
    @IBInspectable open var isCheckable: Bool = false {
        didSet {
            
        }
    }
    
    @IBInspectable open var backgroundColor: NSColor = NSColor.clear {
        didSet {
            //(self.cell as! NSButtonCell).isBordered = false//The background color is used only when drawing borderless buttons.
            //(self.cell as! NSButtonCell).backgroundColor = backgroundColor
            
        }
    }
    
    @IBInspectable open var uncheckedButtonColor: NSColor = NSColor.red {
        didSet {
            self.attributedTitle = NSAttributedString(string: self.attributedTitle.string, attributes: [NSAttributedStringKey.paragraphStyle : centeredStyle, NSAttributedStringKey.foregroundColor : buttonColor, NSAttributedStringKey.font:  NSFont(name: (self.font?.fontName)!, size: (self.font?.pointSize)!)])
        }
    }
    
    @IBInspectable open var buttonColor: NSColor = NSColor.white {
        didSet {
            self.attributedTitle = NSAttributedString(string: self.attributedTitle.string, attributes: [NSAttributedStringKey.paragraphStyle : centeredStyle, NSAttributedStringKey.foregroundColor : buttonColor, NSAttributedStringKey.font:  NSFont(name: (self.font?.fontName)!, size: (self.font?.pointSize)!)])
        }
    }
    
    @IBInspectable open var buttonHighlightedColor: NSColor = NSColor(calibratedRed: 255.0/255.0, green: 255.0/255.0, blue: 255.0/255.0, alpha: 0.7) {
        didSet {
            self.attributedTitle = NSAttributedString(string: self.attributedTitle.string, attributes: [NSAttributedStringKey.paragraphStyle : centeredStyle, NSAttributedStringKey.foregroundColor : buttonColor, NSAttributedStringKey.font:  NSFont(name: (self.font?.fontName)!, size: (self.font?.pointSize)!)])
        }
    }
    
    @IBInspectable open var buttonPressedColor: NSColor = NSColor(calibratedRed: 255.0/255.0, green: 255.0/255.0, blue: 255.0/255.0, alpha: 0.3) {
        didSet {
            self.attributedTitle = NSAttributedString(string: self.attributedTitle.string, attributes: [NSAttributedStringKey.paragraphStyle : centeredStyle, NSAttributedStringKey.foregroundColor : buttonColor, NSAttributedStringKey.font:  NSFont(name: (self.font?.fontName)!, size: (self.font?.pointSize)!)])
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        centeredStyle.alignment = self.alignment //NSTextAlignment.center
        
        self.layer?.cornerRadius = cornerRadius
        self.layer?.masksToBounds = true
        //self.layer?.backgroundColor = NSColor.white.cgColor
        //self.wantsLayer = true
        
        /*if self.checked == false {
            self.attributedTitle = NSAttributedString(string: self.attributedTitle.string, attributes: [NSAttributedStringKey.paragraphStyle : centeredStyle, NSAttributedStringKey.foregroundColor : uncheckedButtonColor, NSAttributedStringKey.font:  NSFont(name: "AvenirNext-Regular", size: (self.font?.pointSize)!)])
            
            return
        }*/
        
        if self.isHighlighted {
            self.attributedTitle = NSAttributedString(string: self.attributedTitle.string, attributes: [NSAttributedStringKey.paragraphStyle : centeredStyle, NSAttributedStringKey.foregroundColor : buttonHighlightedColor, NSAttributedStringKey.font:  NSFont(name: (self.font?.fontName)!, size: (self.font?.pointSize)!)])
        }
        else {
            if (isMouseInside) {
                self.attributedTitle = NSAttributedString(string: self.attributedTitle.string, attributes: [NSAttributedStringKey.paragraphStyle : centeredStyle, NSAttributedStringKey.foregroundColor : buttonPressedColor, NSAttributedStringKey.font:  NSFont(name: (self.font?.fontName)!, size: (self.font?.pointSize)!)])
                
            }
            else {
                var color = buttonColor
                if self.isCheckable && !self.checked {
                    color = uncheckedButtonColor
                }
                if self.isEnabled == false {
                    //(self.cell as! NSButtonCell).backgroundColor = NSColor.lightGray
                }
                else {
                    //(self.cell as! NSButtonCell).backgroundColor = self.backgroundColor
                }
                
                self.attributedTitle = NSAttributedString(string: self.attributedTitle.string, attributes: [NSAttributedStringKey.paragraphStyle : centeredStyle, NSAttributedStringKey.foregroundColor : color, NSAttributedStringKey.font:  NSFont(name: (self.font?.fontName)!, size: (self.font?.pointSize)!)])
            }
        }
        
        //setBackground()
        var path = NSBezierPath(roundedRect: dirtyRect, xRadius: cornerRadius, yRadius: cornerRadius)
        if self.isEnabled {
            backgroundColor.setFill()
        }
        else {
            if self.backgroundColor.alphaComponent == 0 {
                backgroundColor.setFill()
            }
            else {
                disabledColor.setFill()
            }
        }
        
        path.fill()
        
        super.draw(dirtyRect)
        
        //[self.title drawInRect:self.bounds withAttributes:self.attributedTitle.attributes];
        
    }
    
    func setBackground() {
        var path = NSBezierPath(roundedRect: self.frame, xRadius: 5, yRadius: 5)
        backgroundColor.setFill()
        path.fill()
        
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        var color = buttonPressedColor
        if self.isCheckable && !self.checked {
            color = uncheckedButtonColor
        }

        if self.isEnabled == false {
            //(self.cell as! NSButtonCell).backgroundColor = NSColor.lightGray
        }
        else {
            //(self.cell as! NSButtonCell).backgroundColor = self.backgroundColor
        }
        
        //self.layer?.backgroundColor = NSColor.clear.cgColor
        self.attributedTitle = NSAttributedString(string: self.attributedTitle.string, attributes: [NSAttributedStringKey.paragraphStyle : centeredStyle, NSAttributedStringKey.foregroundColor : color, NSAttributedStringKey.font:  NSFont(name: (self.font?.fontName)!, size: (self.font?.pointSize)!)])
        self.setNeedsDisplay()
        
    }
    
    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
        NSCursor.pointingHand.set()
        
        var color = buttonHighlightedColor
        if self.isCheckable && !self.checked {
            color = uncheckedButtonColor
        }
        if self.isEnabled == false {
            //(self.cell as! NSButtonCell).backgroundColor = NSColor.lightGray
        }
        else {
            //(self.cell as! NSButtonCell).backgroundColor = self.backgroundColor
        }
        self.attributedTitle = NSAttributedString(string: self.attributedTitle.string, attributes: [NSAttributedStringKey.paragraphStyle : centeredStyle, NSAttributedStringKey.foregroundColor : buttonHighlightedColor, NSAttributedStringKey.font:  NSFont(name: (self.font?.fontName)!, size: (self.font?.pointSize)!)])
        
    }
    
    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        NSCursor.arrow.set()
        
        var color = buttonColor
        if self.isCheckable && !self.checked {
            color = uncheckedButtonColor
        }
        if self.isEnabled == false {
            //(self.cell as! NSButtonCell).backgroundColor = NSColor.lightGray
        }
        else {
            //(self.cell as! NSButtonCell).backgroundColor = self.backgroundColor
        }
        
        self.attributedTitle = NSAttributedString(string: self.attributedTitle.string, attributes: [NSAttributedStringKey.paragraphStyle : centeredStyle, NSAttributedStringKey.foregroundColor : color, NSAttributedStringKey.font:  NSFont(name: (self.font?.fontName)!, size: (self.font?.pointSize)!)])
    }
    
    var isMouseInside : Bool! = false
    
}
