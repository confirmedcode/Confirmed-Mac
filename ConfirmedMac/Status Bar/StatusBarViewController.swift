//
//  ViewController.swift
//  ConfirmedMac
//
//  Copyright © 2018 Confirmed, Inc. All rights reserved.
//

import Cocoa
import NetworkExtension
import Sparkle
import Alamofire
import CocoaLumberjackSwift

class StatusBarViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSUserNotificationCenterDelegate {
    
    /*
        * setup available regions
     */
    func initializeCountries() {
        loadEndpoints()
        
        for i in 0...items.count - 1 {
            if items[i].endpoint == Utils.getSavedRegion() {
                countryButton?.title = items[i].countryName
                countryButtonFlag?.image = NSImage(named: NSImage.Name(rawValue: items[i].flagImagePath))
                return
            }
        }
    }
    
    func loadEndpoints() {
        items.removeAll()
        
        items.append(ServerEndpoint.init(countryName: "United States - West".localized(), flagImagePath: "usa_flag", countryCode: "us", endpoint: Global.endPoint(base: "us-west")))
        items.append(ServerEndpoint.init(countryName: "United States - East".localized(), flagImagePath: "usa_flag", countryCode: "us", endpoint: Global.endPoint(base: "us-east")))
        items.append(ServerEndpoint.init(countryName: "United Kingdom".localized(), flagImagePath: "great_brittain", countryCode: "uk", endpoint: Global.endPoint(base: "eu-london")))
        items.append(ServerEndpoint.init(countryName: "Ireland".localized(), flagImagePath: "ireland_flag", countryCode: "irl", endpoint: Global.endPoint(base: "eu-ireland")))
        items.append(ServerEndpoint.init(countryName: "Germany".localized(), flagImagePath: "germany_flag", countryCode: "de", endpoint: Global.endPoint(base: "eu-frankfurt")))
        items.append(ServerEndpoint.init(countryName: "Canada".localized(), flagImagePath: "canada_flag", countryCode: "ca", endpoint: Global.endPoint(base: "canada")))
        items.append(ServerEndpoint.init(countryName: "Japan".localized(), flagImagePath: "japan_flag", countryCode: "jp", endpoint: Global.endPoint(base: "ap-tokyo")))
        items.append(ServerEndpoint.init(countryName: "Australia".localized(), flagImagePath: "australia_flag", countryCode: "au", endpoint: Global.endPoint(base: "ap-sydney")))
        items.append(ServerEndpoint.init(countryName: "South Korea".localized(), flagImagePath: "korea_flag", countryCode: "kr", endpoint: Global.endPoint(base: "ap-seoul")))
        items.append(ServerEndpoint.init(countryName: "Singapore".localized(), flagImagePath: "singapore_flag", countryCode: "sg", endpoint: Global.endPoint(base: "ap-singapore")))
        items.append(ServerEndpoint.init(countryName: "India".localized(), flagImagePath: "india_flag", countryCode: "in", endpoint: Global.endPoint(base: "ap-mumbai")))
        items.append(ServerEndpoint.init(countryName: "Brazil".localized(), flagImagePath: "brazil_flag", countryCode: "br", endpoint: Global.endPoint(base: "sa")))
    }
    
    @IBAction func countryChanged(_ sender: Any) {
        let popupButton = sender as! NSPopUpButton
        for i in 0...items.count - 1 {
            if items[i].countryName == popupButton.title {
                VPNController.disconnectFromVPN(setToDisconnect: false)
                Utils.setSavedRegion(region: items[i].endpoint)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    VPNController.connectToVPN()
                }
                return
            }
        }
    }
    
    @IBAction func signoutUser(_ sender: Any) {
        NotificationCenter.post(name: .signoutUser)
    }
    
    /*
        * respond to vpn change notifications by updating UI
    */
    
    func setUIForVPNState() {
        if NEVPNManager.shared().connection.status == .connected {
            self.setVPNButtonEnabled()
        } else if NEVPNManager.shared().connection.status == .disconnected {
            self.setVPNButtonDisabled()
        } else if NEVPNManager.shared().connection.status == .connecting {
            self.setVPNButtonConnecting()
        }
        else if NEVPNManager.shared().connection.status == .disconnecting {
            self.setVPNButtonDisconnecting()
        }
    }
    
    /*
        * set up notifications for changing UI
        * call once immediately to set UI for current state
     */
    func setupVPNNotification() {
        let manager = NEVPNManager.shared()
        manager.loadFromPreferences(completionHandler: {(_ error: Error?) -> Void in
            NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object:
            NEVPNManager.shared().connection, queue: OperationQueue.main) { (notification) -> Void in
                self.setUIForVPNState()
                DDLogInfo("Status changed \(NEVPNManager.shared().connection.status.rawValue)");
            }
            
            self.setUIForVPNState()
            
        })
    }
    
    override func awakeFromNib() {
        
        networkIssuesView?.wantsLayer = true
        networkIssuesView?.layer?.backgroundColor = NSColor.init(red: 255.0/255.0, green: 140.0/255.0, blue: 0.0, alpha: 1.0).cgColor
        
        Global.reachability?.whenReachable = { reachability in
            if Global.reachability?.connection == .wifi {
                DDLogInfo("Reachable via WiFi")
            } else {
                DDLogInfo("Reachable via Cellular")
            }
            DispatchQueue.main.async {
                self.networkIssuesView?.alphaValue = 0.0
            }
            
        }
        Global.reachability?.whenUnreachable = { _ in
            DDLogInfo("Internet not reachable")
            DispatchQueue.main.async {
                self.networkIssuesView?.alphaValue = 1.0
            }
        }
        
        do {
            try Global.reachability?.startNotifier()
        } catch {
            DDLogInfo("Unable to start notifier")
        }
        
        if Global.reachability?.connection == .wifi || Global.reachability?.connection == .cellular {
            DispatchQueue.main.async {
                self.networkIssuesView?.alphaValue = 0.0
            }
        }
        else {
            DispatchQueue.main.async {
                self.networkIssuesView?.alphaValue = 1.0
            }
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupIPAddressUpdater()
        
        vpnLoadingView?.animate = true
        vpnLoadingView?.wantsLayer = true
        vpnLoadingView?.layer?.cornerRadius = (vpnLoadingView?.frame.size.width)! / 2.0
        vpnLoadingView?.layer?.backgroundColor = NSColor.white.cgColor
        
        self.countryButton?.addCursorRect((self.countryButton?.frame)!, cursor: NSCursor.pointingHand)
        self.countryButton?.cornerRadius = 0
        
        self.settingsButton?.image = NSImage.settingsIcon?.imageWithTintColor(tintColor: NSColor.white)
        
        initializeCountries()
        
        let pstyle : NSMutableParagraphStyle = NSMutableParagraphStyle()
        pstyle.alignment = .center

        //if VPN gets installed, this button should appear
        self.installVPNButton?.attributedTitle = NSAttributedString(string: "Install", attributes: [ NSAttributedStringKey.foregroundColor : NSColor.tunnelsBlueColor, NSAttributedStringKey.paragraphStyle : pstyle, NSAttributedStringKey.font:  NSFont(name: "AvenirNext-DemiBold", size: 16)])
        
        countryTableView?.reloadData()
        countryTableView?.action = #selector(onItemClicked)
        
        self.setupVPNNotification()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadServerEndpoints), name: .switchingAPIVersions, object: nil)
        reloadServerEndpoints()
    }
    
    @objc private func onItemClicked() {
        if let row = countryTableView?.clickedRow {
            print("row \(row)")
            self.countryButtonSelected(self)
            Utils.setSavedRegion(region: items[row].endpoint)
            VPNController.disconnectFromVPN(setToDisconnect: false)
            VPNController.connectToVPN()
            
            let countryName = items[row].countryName
            let countryFlag = NSImage(named: NSImage.Name(rawValue: items[row].flagImagePath))
            countryButtonFlag?.image = countryFlag

            let centeredStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle

            countryButton?.attributedTitle = NSAttributedString(string: countryName, attributes: [NSAttributedStringKey.paragraphStyle : centeredStyle, NSAttributedStringKey.foregroundColor : countryButton?.buttonColor ?? NSColor.tunnelsLightBlueColor, NSAttributedStringKey.font:  NSFont(name: (countryButton?.font?.fontName)!, size: (countryButton?.font?.pointSize)!) ?? 12])
        }
        
    }
    
    
    @objc func reloadServerEndpoints() {
        self.loadEndpoints()
    }
    
    override func viewWillDisappear() {
        DDLogInfo("View disappearing")
        showCountrySelection = true //force hide the country menu
        countryButtonSelected(self)
    }
    
    /*
        * if vpn gets uninstalled, we should show an install button of some kind to restore functionality
     */
    override func viewWillAppear() {
        
        VPNController.isTunnelsVPNInstalled(vpnStatusCallback: {(_ status: Bool) -> Void in
            DDLogInfo("Checking status")
            if (!status) {
                self.vpnPowerButton?.isHidden = true
                self.installVPNButton?.isHidden = false
                self.countryButton?.isHidden = true
                self.countryButtonFlag?.isHidden = true
            }
            else {
                self.vpnPowerButton?.isHidden = false
                self.installVPNButton?.isHidden = true
                self.countryButton?.isHidden = false
                self.countryButtonFlag?.isHidden = false
            }
        })
        
        
        //dark mode customizations
        if InterfaceStyle.init() == .Dark {
            self.countryButton?.buttonColor = NSColor.init(white: 255.0/255.0, alpha: 1.0)
            self.countryButton?.backgroundColor = NSColor.init(white: 40/255.0, alpha: 1.0)
        }
        else {
            self.countryButton?.buttonColor = NSColor.init(white: 80.0/255.0, alpha: 1.0)
            self.countryButton?.backgroundColor = NSColor.init(white: 250/255.0, alpha: 1.0)
        }
        
        if InterfaceStyle.init() == .Dark {
            countryButtonArrow?.image = NSImage.upArrowWhite
        }
        else {
            countryButtonArrow?.image = NSImage.upArrow
        }
        
        countryTableView?.reloadData()
    }
    
    /*
        * respond to pressing the VPN power button
     */
    @IBAction func toggleVPN(_ sender: Any) {
        let manager = NEVPNManager.shared()
        manager.loadFromPreferences(completionHandler: {(_ error: Error?) -> Void in
            if manager.connection.status == .disconnected || manager.connection.status == .invalid {
                VPNController.connectToVPN()
            }
            else {
                VPNController.disconnectFromVPN(setToDisconnect: true)
            }
        })
    }

    func setupIPAddressUpdater() {
        self.updateIPAddress()
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: NEVPNManager.shared().connection, queue: OperationQueue.main) { (notification) -> Void in
            if NEVPNManager.shared().connection.status == .connected || NEVPNManager.shared().connection.status == .disconnected {
                self.updateIPAddress()
            }
        }
    }
    
    func updateIPAddress() {
        self.ipAddress?.title = "IP: ..."
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
            let sessionManager = Alamofire.SessionManager.default
            sessionManager.retrier = nil
            URLCache.shared.removeAllCachedResponses()
            sessionManager.request(Global.getIPURL, method: .get, parameters: ["random" : arc4random_uniform(10000000)]).responseJSON { response in
                switch response.result {
                case .success:
                    if let json = response.result.value as? [String: Any], let publicIPAddress = json["ip"] as? String {
                        self.ipAddress?.title = "IP: \(publicIPAddress)"
                    }
                    else {
                        self.ipAddress?.title = ""
                    }
                case .failure(let error):
                    DDLogError("Error loading IP Address \(error)")
                    self.ipAddress?.title = ""
                }
            }
        })
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }
    
    func startSpeedTest() {
        StatusBarController.shared.closePopover(self)
        NSUserNotificationCenter.default.delegate = self
        NSUserNotificationCenter.default.removeAllDeliveredNotifications()
        
        var vpnStatusString = "with the VPN on"
        if NEVPNManager.shared().connection.status != .connected {
            vpnStatusString = "with the VPN off"
        }
        
        let notification = NSUserNotification()
        notification.title = "Speed Test Started"
        notification.informativeText = "Confirmed will take 10-30 seconds to run the speed test \(vpnStatusString)."
        notification.soundName = nil
        notification.otherButtonTitle = "Ok"
        notification.hasActionButton = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0, execute: {
            NSUserNotificationCenter.default.deliver(notification)
        })
        
        TunnelSpeed().testDownloadSpeedWithTimout(timeout: 20.0) { (megabytesPerSecond, error) -> () in
            NSUserNotificationCenter.default.removeAllDeliveredNotifications()
            let notification = NSUserNotification()
            notification.title = "Speed Test Result"
            notification.soundName = nil
            notification.otherButtonTitle = "Ok"
            notification.hasActionButton = false
            
            if megabytesPerSecond > 0 {
                notification.informativeText = "Your Internet speed is \(String(format: "%.1f", megabytesPerSecond)) Mbps \(vpnStatusString)."
            }
            else {
                notification.informativeText = "There was an error trying to measure your Internet speed. Please try again."
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.0, execute: {
                NSUserNotificationCenter.default.deliver(notification)
            })
        }
    }
    
    
    //MARK: - VPN States
    func setVPNButtonConnecting() {
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            NSAnimationContext.current.duration = 1.0
            self.vpnStatusLabel?.stringValue = "CONNECTING"
            self.vpnLoadingView?.progressLayer.strokeEnd = 0.8
            self.vpnLoadingView?.foreground = NSColor.tunnelsBlueColor
            MaterialProgress.strokeRange = (start: 0.0, end: 0.8)
            self.vpnLoadingView?.makeStrokeAnimationGroup()
            self.vpnLoadingView?.animate = true
            
            self.vpnPowerButton?.image = NSImage.powerIcon?.imageWithTintColor(tintColor: NSColor.tunnelsBlueColor)
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
            //if it is still connecting after 5 seconds, toggle the connection on and off
            //long run, intelligently validate P12 file and redownload after a certain number of tries, or stop and warn user
            let manager = NEVPNManager.shared()
            manager.loadFromPreferences(completionHandler: {(_ error: Error?) -> Void in
                if manager.connection.status == .connecting {
                    VPNController.disconnectFromVPN(setToDisconnect: false)
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                        VPNController.connectToVPN()
                    }
                }
            })
        }
        
        DDLogInfo("Connecting")
    }
    
    func setVPNButtonDisconnecting() {
        //self.vpnLoadingView?.foreground = tunnelsColor
        //self.vpnLoadingView?.displayAfterAnimationEnds = false
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            NSAnimationContext.current.duration = 1.0
            self.vpnStatusLabel?.stringValue = "DISCONNECTING"
            self.vpnLoadingView?.progressLayer.strokeEnd = 0.8
            self.vpnLoadingView?.foreground = NSColor.lightGray
            MaterialProgress.strokeRange = (start: 0.0, end: 0.8)
            self.vpnLoadingView?.makeStrokeAnimationGroup()
            self.vpnLoadingView?.animate = true
            
            self.vpnPowerButton?.image = NSImage.powerIcon?.imageWithTintColor(tintColor: NSColor.lightGray)
        }
        
        DDLogInfo("Disconnecting")
    }
    
    func setVPNButtonDisabled() {
        //self.vpnLoadingView?.foreground = tunnelsColor
        //self.vpnLoadingView?.displayAfterAnimationEnds = false
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            NSAnimationContext.current.duration = 1.0
            self.vpnLoadingView?.progressLayer.strokeEnd = 1.0
            self.vpnStatusLabel?.stringValue = "DISCONNECTED"
            self.vpnLoadingView?.foreground = NSColor.lightGray
            MaterialProgress.strokeRange = (start: 0.0, end: 1.0)
            self.vpnLoadingView?.makeStrokeAnimationGroup()
            self.vpnLoadingView?.animate = false
            
            self.vpnPowerButton?.image = NSImage.powerIcon?.imageWithTintColor(tintColor: NSColor.lightGray)
        }
        
        DDLogInfo("Disconnected")
    }
    
    func setVPNButtonEnabled() {
        //self.vpnLoadingView?.foreground = tunnelsColor
        //self.vpnLoadingView?.displayAfterAnimationEnds = false
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            NSAnimationContext.current.duration = 1.0
            self.vpnStatusLabel?.stringValue = "PROTECTED"
            self.vpnLoadingView?.progressLayer.strokeEnd = 1.0
            MaterialProgress.strokeRange = (start: 0.0, end: 1.0)
            self.vpnLoadingView?.makeStrokeAnimationGroup()
            self.vpnLoadingView?.animate = false
            
            self.vpnPowerButton?.image = NSImage.powerIcon?.imageWithTintColor(tintColor: NSColor.tunnelsBlueColor)
        }
        
        DDLogInfo("Connected")
    }
    
    //MARK: - Other menu bar actions
    @IBAction func installVPN (_ sender: Any) {
        //download mobile config
        VPNController.installVPNInternal(vpnInstallationStatusCallback: {(_ status: Bool) -> Void in
            if (status) {
                VPNController.connectToVPN()
            }
            else {
                
            }
        })
    }
    
    @IBAction func speedTest (_ sender: Any) {
        startSpeedTest()
        self.resignFirstResponder()
    }
    
    @IBAction func manageAccount (_ sender: Any) {
        if let url = URL(string: Global.masterURL + "/account"), NSWorkspace.shared.open(url) {
        }
    }
    
    @IBAction func showTunnelsMenu(_ sender: Any) {
        self.updateIPAddress()
        settingsVersion?.title = "Version " + Utils.getTunnelsVersion() + "-" + Global.apiVersionPrefix()
        if let event = NSApplication.shared.currentEvent {
            NSMenu.popUpContextMenu(settingsMenu!, with: event, for: self.settingsButton!)
        }
    }
    
    @IBAction func checkForUpdates (_ sender: Any) {
        SUUpdater.shared().checkForUpdates(sender)
    }
    
    @IBAction func openPreferences (_ sender: Any) {
        NotificationCenter.post(name: .openPreferences)
    }
    
    func showDialog(question: String, text: String) -> Bool {
        let alert: NSAlert = NSAlert()
        alert.messageText = question
        alert.informativeText = text
        alert.alertStyle = NSAlert.Style.warning
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        let res = alert.runModal()
        if res == NSApplication.ModalResponse.alertFirstButtonReturn {
            return true
        }
        return false
    }
    
    @IBAction func emailTeam (_ sender: Any) {
        Utils.emailTeam()
    }
    
    @IBAction func quitTunnels (_ sender: Any) {
        
        if UserDefaults.standard.bool(forKey: Global.kIsLastStateConnected) {
            let answer = showDialog(question:"Are you sure you want to quit?", text: "Confirmed VPN requires the app to be running to function properly. The VPN will be disabled until you reopen & enable the VPN again.")
            if answer {
                UserDefaults.standard.set(true, forKey: "ConnectOnLaunch")
                UserDefaults.standard.synchronize()
                VPNController.disconnectFromVPN(setToDisconnect: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    NSApp.terminate(self)
                }
            }
        }
        else {
            VPNController.disconnectFromVPN(setToDisconnect: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                NSApp.terminate(self)
            }
        }
    }
    
    //MARK: - Table Methods
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
//        let rowCell = tableView.rowView(atRow: row, makeIfNecessary: false) as? CountryCell
//        let rowText = rowCell?.countryName
//
//        self.countryButtonSelected(self)
//
//        NSAnimationContext.runAnimationGroup({_ in
//            NSAnimationContext.current.duration = 0.3
//            rowCell?.animator().backgroundColor = NSColor.tunnelsBlueColor
//            rowText?.animator().textColor = NSColor.white
//
//        }, completionHandler:{
//            DDLogInfo("Animation completed")
//            self.countryButtonSelected(self)
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                NSAnimationContext.runAnimationGroup({_ in
//                    NSAnimationContext.current.duration = 0.3
//                    if InterfaceStyle.init() == .Dark {
//                        rowCell?.animator().backgroundColor = NSColor.init(white: 40/255.0, alpha: 1.0)
//                        rowText?.animator().textColor = NSColor.init(white: 250/255.0, alpha: 1.0)
//
//                    }
//                    else {
//                        rowCell?.animator().backgroundColor = NSColor.white
//                        rowText?.animator().textColor = NSColor.darkGray
//                    }
//                }, completionHandler:{
//                    DDLogInfo("Animation completed")
//                    tableView.deselectAll(self)
//                })
//            }
//        })
        
        Utils.setSavedRegion(region: items[row].endpoint)
        VPNController.disconnectFromVPN(setToDisconnect: false)
        VPNController.connectToVPN()
        
//        NSAnimationContext.runAnimationGroup({_ in
//            NSAnimationContext.current.duration = 0.3
//            let countryName = items[row].countryName
//            let countryFlag = NSImage(named: NSImage.Name(rawValue: items[row].flagImagePath))
//            countryButtonFlag?.animator().image = countryFlag
//
//            let centeredStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
//
//            countryButton?.animator().attributedTitle = NSAttributedString(string: countryName, attributes: [NSAttributedStringKey.paragraphStyle : centeredStyle, NSAttributedStringKey.foregroundColor : countryButton?.buttonColor ?? NSColor.tunnelsLightBlueColor, NSAttributedStringKey.font:  NSFont(name: (countryButton?.font?.fontName)!, size: (countryButton?.font?.pointSize)!) ?? 12])
//
//
//        }, completionHandler:{
//            DDLogInfo("Animation completed")
//        })
        
        
        return true
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier = "CountryCell"
        
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? CountryCell {
            let countryName = items[row].countryName
            let countryFlag = NSImage(named: NSImage.Name(rawValue: items[row].flagImagePath))
            
            cell.countryName?.stringValue = countryName
            cell.countryFlag?.image = countryFlag
            //cell.imageView?.image = image ?? nil
            
            if InterfaceStyle.init() == .Dark {
                cell.countryName?.textColor = NSColor.init(white: 250/255.0, alpha: 1.0)
                countryTableView?.backgroundColor = NSColor.init(white: 40/255.0, alpha: 1.0)
            }
            else {
                cell.countryName?.textColor = NSColor.init(white: 80/255.0, alpha: 1.0)
                countryTableView?.backgroundColor = NSColor.init(white: 255/255.0, alpha: 1.0)
            }
            
            return cell
        }

        return nil
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }
    
    @IBAction func countryButtonSelected(_ sender: Any) {
        showCountrySelection = !showCountrySelection
        var newHeight : CGFloat = -1.0
        
        if showCountrySelection {
            newHeight = self.view.frame.size.height + 1 - (self.countryButton?.frame.size.height)!
            if InterfaceStyle.init() == .Dark {
                countryButtonArrow?.image = NSImage.downArrowWhite
            }
            else {
                countryButtonArrow?.image = NSImage.downArrow
            }
        }
        else {
            if InterfaceStyle.init() == .Dark {
                countryButtonArrow?.image = NSImage.upArrowWhite
            }
            else {
                countryButtonArrow?.image = NSImage.upArrow
            }
        }
    
        NSAnimationContext.runAnimationGroup({_ in
            countryButtonBottomContstraint?.animator().constant = newHeight
        }, completionHandler:{
            DDLogInfo("Animation completed")
        })
    }
    
    //MARK: - VARIABLES
    
    var showCountrySelection = false
    
    @IBOutlet var vpnLoadingView: MaterialProgress?
    @IBOutlet var vpnPowerButton: NSButton?
    @IBOutlet var countryButton: TunnelsButton?
    @IBOutlet var countryButtonBottomContstraint: NSLayoutConstraint?
    @IBOutlet var countryButtonFlag: NSImageView?
    @IBOutlet var countryButtonArrow: NSImageView?
    @IBOutlet var countryTableView: NSTableView?
    
    @IBOutlet var settingsButton: NSButton?
    @IBOutlet var settingsMenu: NSMenu?
    @IBOutlet var settingsVersion: NSMenuItem?
    @IBOutlet var ipAddress: NSMenuItem?
    @IBOutlet var installVPNButton: NSButton?
    @IBOutlet var vpnStatusLabel: NSTextField?
    @IBOutlet var networkIssuesView: NSView?
    
    var items = [ServerEndpoint]() // = []
    
}

