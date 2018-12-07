//
//  StatusBarController.swift
//  ConfirmedMac
//
//  Copyright © 2018 Confirmed, Inc. All rights reserved.
//

import Cocoa
import NetworkExtension

class StatusBarController: NSObject {
    
    static let shared = StatusBarController()
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    let popover = NSPopover()
    var eventDetector: Any?
    
    func setupStatusBar() {
        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
            setIconState()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object:
        NEVPNManager.shared().connection, queue: OperationQueue.main) { (notification) -> Void in
            self.setIconState()
        }
        
        let mainViewController = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "StatusBarViewController")) as! NSViewController
        
        popover.contentViewController = mainViewController
        popover.behavior = .transient
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        setIconState()
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    /*
        * help users see state of VPN based on icon
        * dark blue is connected
        * faded blue is connecting
        * dark gray is disconnected
    */
    func setIconState() {
        let manager = NEVPNManager.shared()
        manager.loadFromPreferences(completionHandler: {(_ error: Error?) -> Void in
            if manager.connection.status == .connected {
                if let button = self.statusItem.button {
                    let image = NSImage.statusBarIcon
                    image?.isTemplate = false
                    button.image = image
                    button.appearsDisabled = false
                }
            }
            else if manager.connection.status == .connecting {
                if let button = self.statusItem.button {
                    let image = NSImage.statusBarIcon
                    image?.isTemplate = false
                    button.image = image
                    button.appearsDisabled = true
                }
            }
            else {
                if let button = self.statusItem.button {
                    let image = NSImage.statusBarIconDisabled
                    button.image = image
                    button.appearsDisabled = false
                }
            }
        })
    }
    
    func showPopover(_ sender: AnyObject?) {
        if popover.contentViewController == nil {
            return
        }
            
        eventDetector = NSEvent.addGlobalMonitorForEvents(matching:[NSEvent.EventTypeMask.leftMouseDown, NSEvent.EventTypeMask.rightMouseDown], handler: { [weak self] event in
            self?.closePopover(sender)
        })
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
    }
    
    func closePopover(_ sender: AnyObject?) {
        if popover.contentViewController == nil {
            return
        }
        
        if let detector = eventDetector {
            NSEvent.removeMonitor(detector)
        }
        eventDetector = nil
        popover.performClose(sender)
    }
    
}
