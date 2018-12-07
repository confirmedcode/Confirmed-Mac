//
//  HoshiTextField.swift
//  Tunnels
//
//  Copyright © 2018 Confirmed, Inc. All rights reserved.
//
//  Inspired by - https://github.com/raulriera/TextFieldEffects

import Foundation
import Cocoa

class SecureVerticallyAlignedTextFieldCell: NSSecureTextFieldCell {
    private static let padding = CGSize(width: 0.0, height: 10.0)
    private static let yPadding : CGFloat = 7
    
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let newRect = NSRect(x: rect.origin.x, y: rect.origin.y + SecureVerticallyAlignedTextFieldCell.yPadding, width: rect.size.width, height: rect.size.height)
        
        return super.drawingRect(forBounds: newRect)
    }
    
    override func cellSize(forBounds rect: NSRect) -> NSSize {
        var size = super.cellSize(forBounds: rect)
        size.height += (SecureVerticallyAlignedTextFieldCell.padding.height * 2)
        return size
    }
    
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        return rect.insetBy(dx: SecureVerticallyAlignedTextFieldCell.padding.width, dy: SecureVerticallyAlignedTextFieldCell.padding.height)
    }
    
    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        let insetRect = rect.insetBy(dx: SecureVerticallyAlignedTextFieldCell.padding.width, dy: SecureVerticallyAlignedTextFieldCell.padding.height)
        
        let newRect = NSRect(x: insetRect.origin.x, y: insetRect.origin.y + SecureVerticallyAlignedTextFieldCell.yPadding, width: insetRect.size.width, height: insetRect.size.height)
        
        super.edit(withFrame: newRect, in: controlView, editor: textObj, delegate: delegate, event: event)
    }
    
    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        let insetRect = rect.insetBy(dx: SecureVerticallyAlignedTextFieldCell.padding.width, dy: SecureVerticallyAlignedTextFieldCell.padding.height)
        
        let newRect = NSRect(x: insetRect.origin.x, y: insetRect.origin.y + SecureVerticallyAlignedTextFieldCell.yPadding, width: insetRect.size.width, height: insetRect.size.height)
        
        super.select(withFrame: newRect, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }
    
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let insetRect = cellFrame.insetBy(dx: SecureVerticallyAlignedTextFieldCell.padding.width, dy: SecureVerticallyAlignedTextFieldCell.padding.height)
        
        super.drawInterior(withFrame: insetRect, in: controlView)
    }
}

class VerticallyAlignedTextFieldCell: NSTextFieldCell {
    private static let padding = CGSize(width: 0.0, height: 10.0)
    private static let yPadding : CGFloat = 7
    
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let newRect = NSRect(x: rect.origin.x, y: rect.origin.y + VerticallyAlignedTextFieldCell.yPadding, width: rect.size.width, height: rect.size.height)
        
        return super.drawingRect(forBounds: newRect)
    }
    
    override func cellSize(forBounds rect: NSRect) -> NSSize {
        var size = super.cellSize(forBounds: rect)
        size.height += (VerticallyAlignedTextFieldCell.padding.height * 2)
        return size
    }
    
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        return rect.insetBy(dx: VerticallyAlignedTextFieldCell.padding.width, dy: VerticallyAlignedTextFieldCell.padding.height)
    }
    
    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        let insetRect = rect.insetBy(dx: VerticallyAlignedTextFieldCell.padding.width, dy: VerticallyAlignedTextFieldCell.padding.height)
        
        let newRect = NSRect(x: insetRect.origin.x, y: insetRect.origin.y + VerticallyAlignedTextFieldCell.yPadding, width: insetRect.size.width, height: insetRect.size.height)
        
        super.edit(withFrame: newRect, in: controlView, editor: textObj, delegate: delegate, event: event)
    }
    
    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        let insetRect = rect.insetBy(dx: VerticallyAlignedTextFieldCell.padding.width, dy: VerticallyAlignedTextFieldCell.padding.height)
        
        let newRect = NSRect(x: insetRect.origin.x, y: insetRect.origin.y + VerticallyAlignedTextFieldCell.yPadding, width: insetRect.size.width, height: insetRect.size.height)
        
        super.select(withFrame: newRect, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }
    
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let insetRect = cellFrame.insetBy(dx: VerticallyAlignedTextFieldCell.padding.width, dy: VerticallyAlignedTextFieldCell.padding.height)
        
        super.drawInterior(withFrame: insetRect, in: controlView)
    }
    
}

class HoshiTextField : NSTextField
{
    /**
     The type of animation a TextFieldEffect can perform.
     
     - TextEntry: animation that takes effect when the textfield has focus.
     - TextDisplay: animation that takes effect when the textfield loses focus.
     */
    public enum AnimationType: Int {
        case textEntry
        case textDisplay
    }
    
    /**
     Closure executed when an animation has been completed.
     */
    public typealias AnimationCompletionHandler = (_ type: AnimationType)->()
    
    /**
     UILabel that holds all the placeholder information
     */
    open let placeholderLabel = NSTextField()
    
    /**
     The animation completion handler is the best place to be notified when the text field animation has ended.
     */
    open var animationCompletionHandler: AnimationCompletionHandler?
    
    open func updateViewsForBoundsChange(_ bounds: CGRect) {
        fatalError("\(#function) must be overridden")
    }
    
    // MARK: - Overrides
    
    var setupEffects = false
    override open func draw(_ rect: CGRect) {
        if !setupEffects
        {
            self.drawsBackground = false
            self.isBordered = false
            self.focusRingType = .none
            drawViewsForRect(rect)
            setupEffects = true
        }
        super.draw(rect)
    }
    
    override open var stringValue: String {
        didSet {
            if !stringValue.isEmpty {
                animateViewsForTextEntry()
            } else {
                animateViewsForTextDisplay()
            }
        }
    }
    
    /**
     The textfield has started an editing session.
     */
    @objc open func textFieldDidBeginEditing() {
        animateViewsForTextEntry()
    }
    
    /**
     The textfield has ended an editing session.
     */
    @objc open func textFieldDidEndEditing() {
        animateViewsForTextDisplay()
    }
    
    override func becomeFirstResponder() -> Bool {
        let status = super.becomeFirstResponder()
        if(status)
        {
            animateViewsForTextEntry()
        }
        else {
            animateViewsForTextEntry()
        }
        return status
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        animateViewsForTextEntry()
    }
    
    override func validateProposedFirstResponder(_ responder: NSResponder, for event: NSEvent?) -> Bool {
        return true
    }
    
    override func textDidBeginEditing(_ notification: Notification) {
        animateViewsForTextEntry()
        
        super.textDidBeginEditing(notification)
    }
    
    override func textDidEndEditing(_ notification: Notification) {
        animateViewsForTextDisplay()
        
        super.textDidEndEditing(notification)
    }
    
    // MARK: - Interface Builder
    
    override open func prepareForInterfaceBuilder() {
        drawViewsForRect(frame)
    }
    
    /**
     The color of the border when it has no content.
     
     This property applies a color to the lower edge of the control. The default value for this property is a clear color.
     */
    
    @IBInspectable dynamic open var borderInactiveColor: NSColor = .white {
        didSet {
            updateBorder()
        }
    }
    
    /**
     The color of the border when it has content.
     
     This property applies a color to the lower edge of the control. The default value for this property is a clear color.
     */
    @IBInspectable dynamic open var borderActiveColor: NSColor = .black {
        didSet {
            updateBorder()
        }
    }
    
    /**
     The color of the placeholder text.
     
     This property applies a color to the complete placeholder string. The default value for this property is a black color.
     */
    @IBInspectable dynamic open var placeholderColor: NSColor = .black {
        didSet {
            updatePlaceholder()
        }
    }
    
    /**
     The scale of the placeholder font.
     
     This property determines the size of the placeholder label relative to the font size of the text field.
     */
    @IBInspectable dynamic open var placeholderFontScale: CGFloat = 1.0 {
        didSet {
            updatePlaceholder()
        }
    }
    
    override open var bounds: CGRect {
        didSet {
            updateBorder()
            updatePlaceholder()
        }
    }
    
    private let borderThickness: (active: CGFloat, inactive: CGFloat) = (active: 2, inactive: 0.5)
    private let placeholderInsets = CGPoint(x: 0, y: 2)
    private let textFieldInsets = CGPoint(x: 0, y: 12)
    private let inactiveBorderLayer = CALayer()
    private let activeBorderLayer = CALayer()
    private var activePlaceholderPoint: CGPoint = CGPoint.zero
    private var placeHolderStringStor: String = ""
    
    // MARK: - TextFieldEffects
    
    open func drawViewsForRect(_ rect: CGRect) {
        if placeholderString != nil
        {
            placeHolderStringStor = placeholderString!
            placeholderString = nil
        }
        
        let frame = CGRect(origin: CGPoint.zero, size: CGSize(width: rect.size.width, height: rect.size.height))
        
        placeholderLabel.frame = frame.insetBy(dx: placeholderInsets.x, dy: placeholderInsets.y)
        placeholderLabel.font = placeholderFontFromFont(font!)
        placeholderLabel.isEditable = false
        placeholderLabel.isSelectable = false
        placeholderLabel.isBordered = false
        placeholderLabel.drawsBackground = false
        
        if self.layer == nil
        {
            self.wantsLayer = true
        }
        
        self.layer!.masksToBounds = false
        
        updateBorder()
        updatePlaceholder()
        
        layer!.addSublayer(inactiveBorderLayer)
        layer!.addSublayer(activeBorderLayer)

        addSubview(placeholderLabel, positioned: .below, relativeTo: nil)
    }
    
    open func animateViewsForTextEntry() {
        if stringValue.isEmpty {
            NSAnimationContext.runAnimationGroup({_ in
                NSAnimationContext.current.duration = 0.3
                self.placeholderLabel.animator().frame.origin = CGPoint(x: 10, y: self.placeholderLabel.frame.origin.y)
            }, completionHandler:{
                self.animationCompletionHandler?(.textEntry)
            })
        }
        
        layoutPlaceholderInTextRect()
        placeholderLabel.frame.origin = activePlaceholderPoint
        self.placeholderLabel.font = NSFont.init(name: (self.placeholderLabel.font?.fontName)!, size: (self.font?.pointSize)! * 0.8)
        if #available(OSX 10.12, *) {
            NSAnimationContext.runAnimationGroup({_ in
                NSAnimationContext.current.duration = 0.4
            })
        } else {
            // Fallback on earlier versions
        }
        
        activeBorderLayer.frame = rectForBorder(borderThickness.active, isFilled: true)
    }
    
    open func animateViewsForTextDisplay() {
        if stringValue.isEmpty {
            NSAnimationContext.runAnimationGroup({_ in
                NSAnimationContext.current.duration = 0.35
                NSAnimationContext.current.allowsImplicitAnimation = true
                self.layoutPlaceholderInTextRect()
            }, completionHandler:{
                self.animationCompletionHandler?(.textDisplay)
            })
            
            activeBorderLayer.frame = self.rectForBorder(self.borderThickness.active, isFilled: false)
            self.placeholderLabel.font = NSFont.init(name: (self.placeholderLabel.font?.fontName)!, size: (self.font?.pointSize)! * 1.0)
            
        }
        else {
            self.placeholderLabel.font = NSFont.init(name: (self.placeholderLabel.font?.fontName)!, size: (self.font?.pointSize)! * 0.8)
        }
    }
    
    // MARK: - Private
    
    private func updateBorder() {
        inactiveBorderLayer.frame = rectForBorder(borderThickness.inactive, isFilled: true)
        inactiveBorderLayer.backgroundColor = borderInactiveColor.cgColor
        
        activeBorderLayer.frame = rectForBorder(borderThickness.active, isFilled: false)
        activeBorderLayer.backgroundColor = borderActiveColor.cgColor
    }
    
    private func updatePlaceholder() {
        placeholderLabel.stringValue = placeHolderStringStor
        placeholderLabel.textColor = placeholderColor
        placeholderLabel.sizeToFit()
        placeholderLabel.frame = NSRect(x: placeholderLabel.frame.origin.x, y: placeholderLabel.frame.origin.y, width: placeholderLabel.frame.size.width, height: max(placeholderLabel.frame.size.height, 23))
        
        layoutPlaceholderInTextRect()
        
        if !stringValue.isEmpty
        {
            animateViewsForTextEntry()
        }
    }
    
    private func placeholderFontFromFont(_ font: NSFont) -> NSFont! {
        var smallerFont = NSFont(name: font.fontName, size: font.pointSize * placeholderFontScale)
        return smallerFont
    }
    
    private func rectForBorder(_ thickness: CGFloat, isFilled: Bool) -> CGRect {
        if isFilled {
            return CGRect(origin: CGPoint(x: 2, y: frame.height-thickness), size: CGSize(width: frame.width, height: thickness))
        } else {
            return CGRect(origin: CGPoint(x: 2, y: frame.height-thickness), size: CGSize(width: 0, height: thickness))
        }
    }
    
    private func layoutPlaceholderInTextRect() {
        let textRect = self.bounds.offsetBy(dx: textFieldInsets.x, dy: textFieldInsets.y)
        
        var originX = textRect.origin.x
        switch self.alignment {
        case .center:
            originX += textRect.size.width/2 - placeholderLabel.bounds.width/2
        case .right:
            originX += textRect.size.width - placeholderLabel.bounds.width
        default:
            break
        }
        
        placeholderLabel.frame = CGRect(x: originX, y: 10,
                                        width: placeholderLabel.bounds.width, height: placeholderLabel.bounds.height)
        activePlaceholderPoint = CGPoint(x: placeholderLabel.frame.origin.x, y: textRect.height/2 - placeholderLabel.frame.size.height - placeholderInsets.y)
        
    }
}
