//
//  VPNController.swift
//
//
//  Copyright © 2018 Confirmed, Inc. All rights reserved.
//

import NetworkExtension
import Alamofire
import NEKit
import CocoaLumberjackSwift

class VPNController: NSObject {
    
    
    //MARK: - PROXY SETTINGS
    /*
        * the proxy is a simple way to force traffic through the VPN or not at all
            * the proxy needs to synchronize with the state of the VPN
        * proxy settings are used to force traffic through VPN  (in netork settings)
        * proxy server is used to route traffic around VPN for whitelisting
        * if the user has forceVPNOn (non-whitelisted traffic only allowed to go through VPN if VPN is on)
            * check if user had the VPN on
                * if so, turn on proxy settings
                * if not, disable proxy (the user does not want the VPN on, so doesn't make sense to enforce this setting)
        * if the setting is not on, disable the proxy settings (in netork settings), but proxy server can remain enabled
        * if Internet is unreachable, disable proxy
     */
    static func syncProxy() {
        let defaults = UserDefaults.standard
        
        if Global.reachability?.connection == .wifi || Global.reachability?.connection == .cellular  {
            if defaults.bool(forKey: Global.kForceVPNOnMac) {
                if let isConnected = defaults.object(forKey:Global.kIsLastStateConnected) as? NSNumber, isConnected.boolValue {
                    Utils.setProxySettings()
                }
                else {
                    Utils.disableProxySettings()
                    
                }
                enableProxy()
            }
            else {
                Utils.disableProxySettings()
            }
        }
        else {
            Utils.disableProxySettings()
        }
    }
    
    /*
     * the proxy server runs at 127.0.0.1:9090
     * it is used as a backup for failed connections
     */
    private static func enableProxy() {
        
        objc_sync_enter(proxyServer)
        proxyServer.stop()
        try? proxyServer.start()
        objc_sync_enter(proxyServer)
        
    }
    
    /*
        * fetch VPN state
            * if connecting or connected, proxy server should be enabled
            * if not, synchronize proxy to current state of vpn
                * if vpn should be connected but is not, enable proxy
                * if vpn should not be disconnected, disable proxy
                * the vpn can be off when it should be on because on-demand doesn't work reliably on macOS
     */
    static func setProxyForVPNState() {
        if NEVPNManager.shared().connection.status == .connected || NEVPNManager.shared().connection.status == .connecting{
            enableProxy()
        }
        else {
            VPNController.syncProxy()
            if abs(lastReconnectTime.timeIntervalSinceNow) < 5 { //limit enabling VPN too quickly
                DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
                    if abs(lastReconnectTime.timeIntervalSinceNow) > 5 {
                        VPNController.syncVPNToState()
                    }
                }
            }
            else {
                lastReconnectTime = NSDate.init(timeIntervalSinceNow: 0)
                VPNController.syncVPNToState()
            }
        }
    }
    
    /*
        * register for VPN status changes
            * set state on each change
            * set state for current state
     */
    static func setupVPNChangeNotifications() {
        let manager = NEVPNManager.shared()
        manager.loadFromPreferences(completionHandler: {(_ error: Error?) -> Void in
            NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object:
            NEVPNManager.shared().connection, queue: OperationQueue.main) { (notification) -> Void in
                setProxyForVPNState()
            }

            setProxyForVPNState()
        })
    }
    
    //MARK: - VPN FUNCTIONS
    /*
        * master function for initiating VPN connections
        * set user default to track 'connecected' status
            * helps keep track of state when user quits
            * need this setting to create our own on demand since Apple's is broken
    */
    static  func connectToVPN() {
        UserDefaults.standard.set(true, forKey: Global.kIsLastStateConnected)
        UserDefaults.standard.synchronize()
        
        let domain = Utils.getSavedRegion()
        self.setupVPN(ipAddress: domain, p12Pass: Global.vpnPassword, localId: Utils.getClientId()!, completion: {
                self.enableVPN()
            });
        
        VPNController.syncProxy()
    }
    
    /*
        * set to disconnect will control whether this is user initiated or toggling the VPN
            * this setting is used to imitiate on-demand
     
     */
    static func disconnectFromVPN(setToDisconnect : Bool) {
        proxyServer.stop()
        
        if setToDisconnect { //need this setting to create our own on demand since Apple's is broken
            UserDefaults.standard.set(false, forKey: Global.kIsLastStateConnected)
            UserDefaults.standard.synchronize()
        }
        
        let manager = NEVPNManager.shared()
        manager.loadFromPreferences(completionHandler: {(_ error: Error?) -> Void in
            NEVPNManager.shared().isOnDemandEnabled = false
            manager.saveToPreferences(completionHandler: {(_ error: Error?) -> Void in
                NEVPNManager.shared().connection.stopVPNTunnel();
                DDLogInfo("Stopping VPN \(String(describing: error))")
            })
        })
        
        Utils.disableProxySettings()
    }
    
    
    /*
        * load whitelisted rules & always connect rule (may not work on some versions of mac)
     */
    static func loadRules() -> Array<NEOnDemandRule> {
        let rules = Utils.setupRules()
        let disconnectDomainRule = NEEvaluateConnectionRule(matchDomains: rules, andAction: .neverConnect)
        let disconnectRule = NEOnDemandRuleEvaluateConnection()
        disconnectRule.connectionRules = [disconnectDomainRule]
        
        let connectRule = NEOnDemandRuleConnect()
        connectRule.interfaceTypeMatch = .any
        
        if rules.count > 0 {
            return [disconnectRule, connectRule]
        }
        else {
            return [connectRule]
        }
    }
    
    /*
        * function mostly used to reload rules & settings when changed
        * starting VPN is delayed by 1s as it can sometimes cause weird stuck in disconnecting state
            * may not be thread safe, even though Apple says it is
     */
    static func toggleVPN() {
        let manager = NEVPNManager.shared()
        manager.loadFromPreferences(completionHandler: {(_ error: Error?) -> Void in
            
            manager.onDemandRules = VPNController.loadRules()
            manager.isEnabled = true
            
            manager.saveToPreferences(completionHandler: {(_ error: Error?) -> Void in
                DDLogInfo("Starting VPN \(String(describing: error))")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    connectToVPN()
                }
            })
        })
    }
    
    /*
        * force vpn state based on last user interaction
            * called frequently from a timer
        * this method makes sure if the VPN is on, the tunnel is on, vice versa
        * part of our implementation of on-demand
            * workaround for an Apple bug where on demand does not work for tunnel configs
     */
    static func syncVPNToState() {
        let manager = NEVPNManager.shared()
        
        if Global.reachability?.connection == .wifi || Global.reachability?.connection == .cellular  {
            if let isConnected = UserDefaults.standard.object(forKey:Global.kIsLastStateConnected) as? NSNumber {
                if isConnected.boolValue {
                    manager.loadFromPreferences(completionHandler: {(_ error: Error?) -> Void in
                        if manager.connection.status != .connected && manager.connection.status != .connecting && manager.localizedDescription == Global.vpnName {
                            self.enableVPN()
                        }
                    })
                }
                else {
                    manager.loadFromPreferences(completionHandler: {(_ error: Error?) -> Void in
                        if manager.connection.status == .connected || manager.connection.status == .connecting {
                            self.disconnectFromVPN(setToDisconnect:true)
                        }
                    })
                }
            }
        }
        else {
            manager.loadFromPreferences(completionHandler: {(_ error: Error?) -> Void in
                if manager.connection.status == .connected || manager.connection.status == .connecting && manager.localizedDescription == Global.vpnName {
                    VPNController.disconnectFromVPN(setToDisconnect: false)
                }
            })
        }
    }
    
    /*
        * this method grounds the VPN to an inaccessible URL
        * called if authentication fails
        * for benefit of user instead of constantly failing authentication
     */
    static func forceVPNOff() {
        UserDefaults.standard.set(false, forKey: Global.kIsLastStateConnected)
        UserDefaults.standard.synchronize()
        
        DDLogInfo("Forcing VPN off")
        
        let manager = NEVPNManager.shared()
        manager.loadFromPreferences(completionHandler: {(_ error: Error?) -> Void in
            DDLogInfo("Loading Error \(String(describing: error))")
            let p = NEVPNProtocolIKEv2()

            p.serverAddress = "local." + Global.vpnDomain
            p.serverCertificateIssuerCommonName = "local." + Global.vpnDomain
            p.remoteIdentifier = "local." + Global.vpnDomain
            
            p.deadPeerDetectionRate = NEVPNIKEv2DeadPeerDetectionRate.medium
           
            manager.isOnDemandEnabled = false
            manager.isEnabled = false
            manager.localizedDescription! = Global.vpnName
            
            manager.saveToPreferences(completionHandler: {(_ error: Error?) -> Void in
                DDLogInfo("Saving Error \(String(describing: error))")
            })
        })
        
        Utils.disableProxySettings()
    }
    
    private static func enableVPN() {
        
        let manager = NEVPNManager.shared()
        enableProxy()
        
        manager.loadFromPreferences(completionHandler: {(_ error: Error?) -> Void in
            NEVPNManager.shared().isOnDemandEnabled = true
            manager.isEnabled = true
            manager.protocolConfiguration?.disconnectOnSleep = false
           
            let proxy = NEProxySettings()
            proxy.autoProxyConfigurationEnabled = true
            if !ProcessInfo().isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 10, minorVersion: 13, patchVersion: 0)) {
                //simple fix for whitelisting on 10.13
                proxy.proxyAutoConfigurationJavaScript = "function FindProxyForURL(url, host){return \"PROXY 127.0.0.1:9090;\";}"
            }
            
            proxy.httpEnabled = true;
            proxy.httpsEnabled = true;
            proxy.excludeSimpleHostnames = false;
            manager.protocolConfiguration?.proxySettings = proxy
            
            manager.saveToPreferences(completionHandler: {(_ error: Error?) -> Void in
                do {
                    DDLogInfo("Starting VPN")
                    try NEVPNManager.shared().connection.startVPNTunnel();
                    
                }
                catch {
                    DDLogError("roee: Failed to start vpn: \(error)")
                }
            })
        })
        
        Utils.setupWhitelistedDefaults()
    }
    
    /*
        * setup VPN will only set up the vpn
            * enable vpn will turn it on and save preferences
        * important to set the correct information for VPN before enabling
     */
    private static func setupVPN(ipAddress : String, p12Pass : String, localId: String, completion: @escaping () -> Void) {
        let manager = NEVPNManager.shared()
        
        manager.loadFromPreferences(completionHandler: {(_ error: Error?) -> Void in
            DDLogError("Loading Error \(String(describing: error))")
            
            let p = NEVPNProtocolIKEv2()
            
            /// Configure everything
            p.serverAddress = ipAddress
            p.authenticationMethod = NEVPNIKEAuthenticationMethod.certificate
            p.certificateType = NEVPNIKEv2CertificateType.ECDSA256
            p.serverCertificateIssuerCommonName = Global.remoteIdentifier
            p.localIdentifier = localId
            p.remoteIdentifier = Global.remoteIdentifier
            p.ikeSecurityAssociationParameters.encryptionAlgorithm = NEVPNIKEv2EncryptionAlgorithm.algorithmAES128GCM
            p.ikeSecurityAssociationParameters.diffieHellmanGroup = NEVPNIKEv2DiffieHellmanGroup.group19
            p.ikeSecurityAssociationParameters.integrityAlgorithm = NEVPNIKEv2IntegrityAlgorithm.SHA512
            p.ikeSecurityAssociationParameters.lifetimeMinutes = 1440
            p.childSecurityAssociationParameters.encryptionAlgorithm = NEVPNIKEv2EncryptionAlgorithm.algorithmAES128GCM
            p.childSecurityAssociationParameters.diffieHellmanGroup = NEVPNIKEv2DiffieHellmanGroup.group19
            p.childSecurityAssociationParameters.integrityAlgorithm = NEVPNIKEv2IntegrityAlgorithm.SHA512
            p.childSecurityAssociationParameters.lifetimeMinutes = 1440
            p.deadPeerDetectionRate = NEVPNIKEv2DeadPeerDetectionRate.medium
            p.disableRedirect = true
            
            /// Read the cert from the keychain
            let certificate = getCertificate()
            var ref: CFData?
            
            if (certificate == nil) {
                DDLogError("Certificate missing!!!")
                return
            }
            
            let perstat = SecKeychainItemCreatePersistentReference(certificate!, &ref)
            
            p.identityReference = (ref as Data?)!
            p.disconnectOnSleep = false
            
            
            let proxy = NEProxySettings()
            proxy.httpEnabled = true;
            proxy.httpServer = NEProxyServer.init(address: proxyServerName, port: proxyServerPort)
            proxy.httpsEnabled = true;
            proxy.httpsServer = NEProxyServer.init(address: proxyServerName, port: proxyServerPort)
            proxy.excludeSimpleHostnames = false;
            proxy.matchDomains = []
            
            p.proxySettings = proxy
            
            manager.protocolConfiguration = p
            manager.isOnDemandEnabled = true
            
            manager.onDemandRules = VPNController.loadRules()

            manager.localizedDescription = Global.vpnName
            manager.isEnabled = true
            
            manager.saveToPreferences(completionHandler: { (error) in
                if let e = error {
                    DDLogError("Saving Error \(e)")
                    
                    if ((error! as NSError).code == 4) { //if config is stale, probably multithreading bug
                        DDLogInfo("Trying again")
                        self.setupVPN(ipAddress: ipAddress, p12Pass: p12Pass, localId: localId, completion: {
                            completion()
                        })
                    }
                }
                else {
                    completion()
                }
            })
        })
    }
    
    //MARK: - INSTALL VPN
    /*
        * In macOS, a password is required on p12 for some reason
        * add password if fetched from there
     */
    static func addPasswordFromP12(rootCertData : Data) -> Data {
        let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("com.confirmed.tunnelsMac")
        let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("com.confirmed.tunnelsMac/serverCert.p12")
        let tempAppSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("com.confirmed.tunnelsMac/temp.pem")
        let outputAppSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("com.confirmed.tunnelsMac/severCertProtected.p12")
        
        do {
            try FileManager.default.createDirectory(at: appSupportDirectory!, withIntermediateDirectories: true, attributes: nil)
            
        } catch {
            print(error)
            
            let alert = NSAlert()
            alert.messageText = "Error Installing VPN"
            alert.informativeText = "Please contact the Confirmed Team to resolve the issue: \(error)"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        
        try? rootCertData.write(to: appSupportPath!)
        var res = Utils.shell(launchPath: "/usr/bin/openssl", arguments: ["pkcs12", "-in", (appSupportPath?.path)!, "-out", (tempAppSupportPath?.path)!, "-passin", "pass:", "-passout", "pass:" + Global.vpnPassword])
        sleep(1)
        res = Utils.shell(launchPath: "/usr/bin/openssl", arguments: ["pkcs12", "-export", "-in", (tempAppSupportPath?.path)!, "-out", (outputAppSupportPath?.path)!, "-passin", "pass:" + Global.vpnPassword, "-passout", "pass:" + Global.vpnPassword])
        
        let passwordCertData = try! Data.init(contentsOf: outputAppSupportPath!)
        
        //remove all 3 files
        try? FileManager.default.removeItem(at: appSupportPath!)
        try? FileManager.default.removeItem(at: tempAppSupportPath!)
        try? FileManager.default.removeItem(at: outputAppSupportPath!)
        
        return passwordCertData
    }
    
    /*
        * this is only called in onboarding
        * installs p12 certificate
        * trusts confirmed certificate chain as root CA
     */
    static func installVPNInternal (vpnInstallationStatusCallback: @escaping (_ status: Bool) -> Void) {
        
        Auth.getKey(callback: { (status, reason, errorCode) in
            if status {
                do {
                    let p12Encoded = Global.keychain[Global.kConfirmedP12Key]
                    var p12Decoded = p12Encoded?.base64Decoded
                    if !Global.isVersion(version: .v1API) {
                        p12Decoded = addPasswordFromP12(rootCertData: p12Decoded!)
                    }
                        
                    var clientCertificates: CFArray? = nil
                    let certificate = getCertificate()
                    
                    let certOptions:NSDictionary = [kSecImportExportPassphrase as NSString:Global.vpnPassword as NSString]
                    let importResult: OSStatus = SecPKCS12Import(p12Decoded! as CFData, certOptions, &clientCertificates)
                    
                    switch importResult {
                    case noErr:
                        DDLogInfo("noErr: Success \(String(describing: clientCertificates))")
                    case errSecAuthFailed:
                        DDLogError("errSecAuthFailed: Authorization/Authentication failed. \(String(describing: clientCertificates))")
                    default:
                        DDLogInfo("Unspecified OSStatus error: \(importResult)")
                    }
                        
                    let err = VPNController.trustRootCert()
                    DDLogError("Error with root cert \(err)")
                    
                    if err != 0 { //requires user to install root certificate to progress
                        vpnInstallationStatusCallback(false)
                    }
                    else {
                         vpnInstallationStatusCallback(true)
                    }
                }
            }
            else {
                DDLogError("Unknown error \(errorCode)")
                vpnInstallationStatusCallback(false)
            }
        })
    }
    
    static func isTunnelsVPNInstalled(vpnStatusCallback: @escaping (_ status: Bool) -> Void) {
        let manager = NEVPNManager.shared()
        manager.loadFromPreferences(completionHandler: {(_ error: Error?) -> Void in
            DDLogInfo("Is enabled \(manager.isEnabled)")
            if manager.localizedDescription?.range(of:Global.vpnName) != nil && manager.isEnabled {
                vpnStatusCallback(true)
            }
            else {
                vpnStatusCallback(false)
            }
        })
    }
    
    //MARK: - CERTIFICATE FUNCTIONS
    /*
        * fetch certificate from keychain
     */
    private static func getCertificate() -> SecKeychainItem? {
        let localID = Global.keychain[Global.kConfirmedID]
        
        let getquery: [String: Any] = [kSecClass as String: kSecClassCertificate,
                                       kSecAttrLabel as String: localID!,
                                       kSecReturnRef as String: kCFBooleanTrue]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(getquery as CFDictionary, &item)
        guard status == errSecSuccess else { return nil}
        
        //let certificate = item as! SecCertificate
        
        return (item as! SecKeychainItem)
    }
    
    /*
        * get certificate from keychain
        * request user to enable as root certificate
     
     */
    static func trustRootCert() -> OSStatus {
        let getquery: [String: Any] = [kSecClass as String: kSecClassCertificate,
                                       kSecAttrLabel as String: Global.endPoint(base: "www"),
                                       kSecReturnRef as String: kCFBooleanTrue]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(getquery as CFDictionary, &item)
        guard status == errSecSuccess else { return status }
        
        let certificate = item as! SecCertificate
        
        return SecTrustSettingsSetTrustSettings(certificate, SecTrustSettingsDomain.user, nil);
    }
    
    
    //MARK: - VARIABLES
    static var proxyServerPort = 9090;
    static var proxyServerName = "127.0.0.1";
    static var proxyServer = GCDHTTPProxyServer.init(address: IPAddress(fromString: proxyServerName), port: Port(port: 9090))
    
    
    static var lastReconnectTime = NSDate.init(timeIntervalSinceNow: -100)
    
}
