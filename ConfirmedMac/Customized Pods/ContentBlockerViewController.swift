//
//  ContentBlockerViewController.swift
//  Confirmed VPN
//
//  Copyright © 2018 Confirmed, Inc. All rights reserved.
//

import Cocoa
import SafariServices
import CocoaLumberjackSwift

class ContentBlockerViewController: NSViewController, RHPreferencesViewControllerProtocol {
    var vcID: String! {
        get {
            return self.className
        }
    }
    

    var toolbarItemImage: NSImage! {
        get {
            return .blockIcon
        }
    }
    
    var toolbarItemLabel: String! {
        get {
            return "Content Blocker"
        }
    }
    
    func setContentBlockerSetting(key : String, val : Bool) {
        DDLogInfo("Setting to \(val)")
        if let defaults = UserDefaults(suiteName: "group.com.confirmed.tunnelsMac") {
            defaults.set(val, forKey: key)
            defaults.synchronize()
        }
        
        reloadData()
    }
    
    @IBAction func toggleAdTracker(sender : NSButton) {
        DDLogInfo("Toggling tracker")
        setContentBlockerSetting(key: "AdBlockingEnabled", val: sender.state == .on)
    }
    
    @IBAction func togglePrivacyTracker(sender : NSButton) {
        DDLogInfo("Toggling tracker")
        setContentBlockerSetting(key: "PrivacyBlockingEnabled", val: sender.state == .on)
    }
    
    @IBAction func toggleSocialTracker(sender : NSButton) {
        DDLogInfo("Toggling tracker")
        setContentBlockerSetting(key: "SocialBlockingEnabled", val: sender.state == .on)
    }
    
    func reloadData() {
        SFContentBlockerManager.reloadContentBlocker(
        withIdentifier: "com.confirmed.tunnelsMac.Confirmed-Blocker") { (_ error: Error?) -> Void in
            if error != nil {
                //reload again
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.reloadData()
                }
            }
            DDLogInfo("Reloaded blocker with error \(error)")
        }
    }
    
    func refreshSettingsView() {
        if let defaults = UserDefaults(suiteName: "group.com.confirmed.tunnelsMac") {
            if defaults.object(forKey: "AdBlockingEnabled") != nil {
                adBlockingButton?.state = defaults.bool(forKey: "AdBlockingEnabled") == true ? .on : .off
            }
            else {
                setContentBlockerSetting(key: "AdBlockingEnabled", val: true)
            }
            
            if defaults.object(forKey: "PrivacyBlockingEnabled") != nil {
                trackingScriptBlockingButton?.state = defaults.bool(forKey: "PrivacyBlockingEnabled") == true ? .on : .off
            }
            else {
                setContentBlockerSetting(key: "PrivacyBlockingEnabled", val: true)
            }
            
            if defaults.object(forKey: "SocialBlockingEnabled") != nil {
                socialBlockingButton?.state = defaults.bool(forKey: "SocialBlockingEnabled") == true ? .on : .off
            }
            else {
                setContentBlockerSetting(key: "SocialBlockingEnabled", val: true)
            }
            
            DDLogInfo("Setting \(defaults.bool(forKey: "SocialBlockingEnabled"))")
        }
        
        if SFSafariServicesAvailable() {
            SFContentBlockerManager.getStateOfContentBlocker(withIdentifier: "com.confirmed.tunnelsMac.Confirmed-Blocker", completionHandler: { (state, error) in
                if let error = error {
                    // TODO: handle the error
                    DDLogInfo("error loading blocker content \(error)")
                }
                if let state = state {
                    DispatchQueue.main.async(execute: {
                        if state.isEnabled {
                            self.headerLabel?.stringValue = "Confirmed includes a Content Blocker that protects your privacy and increases performance in Safari by blocking invasive code."
                        }
                        else {
                            self.headerLabel?.stringValue = "Confirmed includes a Content Blocker that protects your privacy and increases performance in Safari by blocking invasive code.\n\nTo enable, open Safari > Preferences > Extensions"
                        }
                    })
                }
            })
        }
        else {
            DDLogInfo("Safari Services not available")
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        refreshSettingsView()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        refreshSettingsView()
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        refreshSettingsView()
    }
    
    @IBOutlet var headerLabel: NSTextField?
    
    @IBOutlet var adBlockingButton: NSButton?
    @IBOutlet var trackingScriptBlockingButton: NSButton?
    @IBOutlet var socialBlockingButton: NSButton?
    
}
