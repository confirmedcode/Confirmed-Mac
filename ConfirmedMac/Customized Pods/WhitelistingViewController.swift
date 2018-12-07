//
//  WhitelistingViewController.swift
//  Confirmed VPN
//
//  Copyright © 2018 Confirmed, Inc. All rights reserved.
//

import Cocoa
import CocoaLumberjackSwift

class WhitelistingViewController: NSViewController, RHPreferencesViewControllerProtocol, NSTableViewDelegate, NSTableViewDataSource {
    
    //MARK: - TABLE METHODS
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == confirmedTable {
            return Utils.getConfirmedWhitelist().count
        }
        else {
            return Utils.getUserWhitelist().count
        }
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if tableView == customTable && row == tableView.numberOfRows - 1 {
            return 60
        }
        return 20
    }

    @objc func addCustomDomain(sender : NSTextField) {
        DDLogInfo("Adding custom Domain")
        
        if sender.stringValue.count == 0 {
            return
        }
        
        Utils.addDomainToUserWhitelist(key: sender.stringValue)
        customTable?.reloadData()
        sender.stringValue = ""
        VPNController.toggleVPN()
    }
    
    @objc func removeWhitelistCell(sender : NSButton) {
        Utils.removeDomainFromUserWhitelist(key: (sender.identifier?.rawValue)!)
        customTable?.reloadData()
        VPNController.toggleVPN()
    }
    
    @objc func toggleWhitelistCell(sender : NSButton) {
        if let domain = sender.identifier?.rawValue {
            var confirmedWhitelist = Utils.getConfirmedWhitelist()
            confirmedWhitelist[domain] = (sender.state == .on ? NSNumber.init(value: true) : NSNumber.init(value: false))
            
            let defaults = Global.sharedUserDefaults()
            defaults.set(confirmedWhitelist, forKey: Global.kConfirmedWhitelistedDomains)
            defaults.synchronize()
            
            VPNController.toggleVPN()
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor viewForTableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        if tableView == customTable {
            if (viewForTableColumn?.identifier)!.rawValue == "whitelistColumn" {
                //update the UI based on saved whitelisted settings
                
                if let rowCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "whitelistCell"), owner: self) as? WhitelistStatusCell, let checkbox = rowCell.checkbox {
                    //last row of user whitelist should allow user to add
                    checkbox.isHidden = row == tableView.numberOfRows - 1 ? true : false
                    let domains = Array(Utils.getUserWhitelist().keys)
                    if domains.count > row {
                        checkbox.state = .on
                        checkbox.identifier = NSUserInterfaceItemIdentifier(rawValue: domains[row])
                        checkbox.target = self
                        checkbox.action = #selector(removeWhitelistCell(sender:))
                    }
                    
                    return rowCell
                }
            }
            else {
                
                if row == tableView.numberOfRows - 1 {
                    let rowCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "addDomainTableCell"), owner: self) as! WhitelistAddDomainCell
                    let textField = rowCell.addDomain
                    textField?.animateViewsForTextDisplay()
                    textField?.drawViewsForRect((textField?.frame)!)
                    textField?.draw((textField?.frame)!)
                    
                    return rowCell
                }
                else {
                    let rowCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "domainTableCell"), owner: self) as! WhitelistDomainCell
                    
                    let textField = rowCell.domain
                    let userDomains = Array(Utils.getUserWhitelist().keys)
                    if userDomains.count > row {
                        textField?.stringValue = userDomains[row]
                    }
                    
                    textField?.target = self
                    textField?.action = #selector(addCustomDomain(sender:))
                    return rowCell
                }
            }
        }
        else {
            //users can only toggle confirmed suggested domains
            if (viewForTableColumn?.identifier)!.rawValue == "whitelistColumn" {
                let rowCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "whitelistCell"), owner: self) as! WhitelistStatusCell
                
                let checkbox = rowCell.checkbox
                let confirmedDomains = Array(Utils.getConfirmedWhitelist().keys)
                let confirmedDomainsStatus = Array(Utils.getConfirmedWhitelist().values) as! Array<NSNumber>
                
                if confirmedDomains.count > row, confirmedDomainsStatus.count > row {
                    checkbox?.state = confirmedDomainsStatus[row].boolValue ? .on : .off
                    checkbox?.identifier = NSUserInterfaceItemIdentifier(rawValue: confirmedDomains[row])
                    checkbox?.target = self
                    checkbox?.action = #selector(toggleWhitelistCell(sender:))
                }
                
                return rowCell
            }
            else {
                let rowCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "domainTableCell"), owner: self) as! NSTableCellView
                let confirmedDomains = Array(Utils.getConfirmedWhitelist().keys)
                if confirmedDomains.count > row {
                    rowCell.textField?.stringValue = confirmedDomains[row]
                }
                
                return rowCell
            }
        }
        
        return nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Utils.addTrackingArea(button: confirmedButton!)
        Utils.addTrackingArea(button: customButton!)
        Utils.addTrackingArea(button: requireVPNButton!)
        
        //if setting is on, show in UI
        //otherwise set default
        if UserDefaults.standard.bool(forKey: Global.kForceVPNOnMac) {
            forceVPNButton?.state = UserDefaults.standard.bool(forKey: Global.kForceVPNOnMac) ? .on : .off
        }
        else {
            UserDefaults.standard.set(NSNumber.init(value: false), forKey: Global.kForceVPNOnMac)
            UserDefaults.standard.synchronize()
            forceVPNButton?.state = .off
        }
    }
    
    /*
        * switches force VPN and saves in user defaults
        * enabling this will ensure no traffic process outside of the VPN
            * still allows whitelisted sites
            * defaulted to false as it is an advanced & extreme setting
            * if VPN accidentally disables, your Internet will stop functioning
     */
    @IBAction func toggleRequireVPNButton (_ sender: NSButton) {
        if sender.state == .on {
            UserDefaults.standard.set(NSNumber.init(value: true), forKey: Global.kForceVPNOnMac)
            UserDefaults.standard.synchronize()
            
            Utils.shouldInstallHelper(callback: { shouldInstall in
                if shouldInstall {
                    Utils.installHelper()
                    Utils.xpcHelperConnection = nil  //  Nulls the connection to force a reconnection
                }
                
                Utils.setProxySettings()
            })
        }
        else {
            UserDefaults.standard.set(NSNumber.init(value: false), forKey: Global.kForceVPNOnMac)
            UserDefaults.standard.synchronize()
        }
    }
    
    //MARK: - TAB ACTIONS
    //manual implementation of tab switches
    @IBAction func switchToRequireVPNButton (_ sender: Any) {
        self.confirmedButton?.state = NSControl.StateValue.off
        self.customButton?.state = NSControl.StateValue.off
        self.requireVPNButton?.state = NSControl.StateValue.on
        
        self.domainTabs?.selectTabViewItem(at: 0)
    }
    
    @IBAction func switchToConfirmedButton (_ sender: Any) {
        self.confirmedButton?.state = NSControl.StateValue.on
        self.customButton?.state = NSControl.StateValue.off
        self.requireVPNButton?.state = NSControl.StateValue.off
        
        self.domainTabs?.selectTabViewItem(at: 1)
    }
    
    @IBAction func switchToCustomButton (_ sender: Any) {
        self.confirmedButton?.state = NSControl.StateValue.off
        self.customButton?.state = NSControl.StateValue.on
        self.requireVPNButton?.state = NSControl.StateValue.off
        
        self.domainTabs?.selectTabViewItem(at: 2)
    }
    
    //MARK: - VARIABLES
    
    @IBOutlet var domainTabs: NSTabView?
    @IBOutlet var requireVPNButton: TunnelsButton?
    @IBOutlet var confirmedButton: TunnelsButton?
    @IBOutlet var customButton: TunnelsButton?
    @IBOutlet var forceVPNButton: NSButton?
    
    @IBOutlet var confirmedTable: NSTableView?
    @IBOutlet var customTable: NSTableView?
    
    var vcID: String! { get { return self.className } }
    var toolbarItemImage: NSImage! { get { return .checkmarkIcon } }
    var toolbarItemLabel: String! { get { return "Whitelist" } }
    
}
