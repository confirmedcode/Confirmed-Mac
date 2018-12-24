//
//  AppDelegate.swift
//  ConfirmedMac
//
//  Copyright © 2018 Confirmed, Inc. All rights reserved.
//
//NounProject - https://thenounproject.com/search/?q=settings&i=960836 unlimicon

import Cocoa
import NetworkExtension
import SystemConfiguration
import ServiceManagement
import Sparkle
import KeychainAccess
import Alamofire
import CocoaLumberjackSwift
import SafariServices
import Reachability

let fileLogger: DDFileLogger = DDFileLogger() // File Logger

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, SUUpdaterDelegate {
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
        UserDefaults.standard.synchronize()
        DDLogInfo("Launching here")
        Utils.moveToApplicationsFolder()
        
        Utils.chooseAPIVersion()
        Utils.setupLogging()
        Utils.checkForSwitchedEnvironments()
        Utils.restoreVPNState()
        Utils.setupWhitelistedDefaults()
        
        SUUpdater.shared().delegate = self
        
        VPNController.isTunnelsVPNInstalled(vpnStatusCallback: {(_ status: Bool) -> Void in
            if status {
                //we should test sign in asynchronously
                /*self.sb.setupStatusBar()
                Utils.setupAndInstallProxyIfNeeded()
                VPNController.setupVPNChangeNotifications()*/
                
                //WE SHOULD SIGN IN TO CHECK CREDENTIALS WORK
                //Auth.getKey(callback: <#T##(Bool, String, Int) -> Void#>)
                Auth.getKey(callback: {(_ status: Bool, reason: String, errorCode : Int) -> Void in
                    DispatchQueue.main.async {
                        if status || errorCode == Global.kInternetDownError || errorCode == Global.kServerDownError || errorCode == Global.kInternetConnectionLost || errorCode == Global.kStreamError || errorCode == Global.kServerTimedOutError {
                            self.sb.setupStatusBar()
                            Utils.setupAndInstallProxyIfNeeded()
                            VPNController.setupVPNChangeNotifications()
                        }
                        else {
                            self.onboardingWindow.showWindow(self)
                        }
                    }
                })
            }
            else {
                Auth.signInError = 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) {
                    self.onboardingWindow.window?.alphaValue = 0.0
                    self.onboardingWindow.showWindow(self)
                    NSAnimationContext.runAnimationGroup({_ in
                        NSAnimationContext.current.duration = 0.5
                       self.onboardingWindow.window?.animator().alphaValue = 1.0
                    }, completionHandler:{
                        DDLogInfo("Animation completed")
                    })
                }
            }
        })
        
        
        //setup notification handlers
        NotificationCenter.default.addObserver(self, selector: #selector(tunnelsInstalled(_:)), name: .tunnelsSuccessfullyInstalled, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onboardingCompleted(_:)), name: .onboardingCompleted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(signoutUser(_:)), name: .signoutUser, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(openPreferencesWindow(_:)), name: .openPreferences, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(macDidWake(_:)), name: NSWorkspace.didWakeNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(openMenubarPanel), name: .sameVersionOpened, object: nil)
        
        
        
        NSAppleEventManager.shared().setEventHandler(self,
                                                     andSelector: #selector(handleGetURLEvent),
                                                     forEventClass: AEEventClass(kInternetEventClass),
                                                     andEventID: AEEventID(kAEGetURL))
        
        
        let manager = NEVPNManager.shared()
        manager.loadFromPreferences(completionHandler: {(_ error: Error?) -> Void in
            NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object:
            NEVPNManager.shared().connection, queue: OperationQueue.main) { (notification) -> Void in
                if NEVPNManager.shared().connection.status == .disconnected {
                    Utils.updateActualReachability(completion: { isActuallyReachable in
                        if isActuallyReachable {
                            self.synchronizeVPNToState()
                        }
                    })
                }             }
        })
        
        //timer to synchronize proxy & VPN
        let syncVPNToStateTimer = Timer.scheduledTimer(timeInterval: 10.0, target: self, selector: #selector(synchronizeVPNToState), userInfo: nil, repeats: true)
        syncVPNToStateTimer.fire()
        
    }

    /*
        * ensure vpn is functinoing properly
            * we have to implement on-demand ourselves
     */
    @objc func macDidWake(_ notification: Notification?) {
        DDLogInfo("Mac did wake")
        VPNController.syncVPNToState()
    }
    
    @objc func openPreferencesWindow(_ notification: Notification?) {
        let whitelistVC = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "WhitelistingViewController")) as! WhitelistingViewController
        let contentVC = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "ContentBlockerViewController")) as! ContentBlockerViewController
        
        let arr = [whitelistVC, contentVC]
        preferencesWindowController = RHPreferencesWindowController.init(viewControllers: arr, andTitle: "Preferences")
        
        preferencesWindowController?.window?.toolbar?.displayMode = .iconAndLabel
        preferencesWindowController?.window?.titleVisibility = .visible
        
        preferencesWindowController?.showWindow(self)
        preferencesWindowController?.window?.level = .floating
    }
    
    
    //MARK: - HANDLE NOTIFICATIONS
    /*
        * Our own on-demand function
        * If not Internet not reachable, don't keep re-connecting
     */
    @objc func synchronizeVPNToState() {
        if Utils.isInternetActuallyReachable {
             VPNController.syncVPNToState()
        }
        else {
            Utils.updateActualReachability(completion: { isActuallyReachable in
                if isActuallyReachable {
                    VPNController.syncVPNToState()
                }
                else { //retry after 5 seconds (faster than timer
                    DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
                        Utils.updateActualReachability(completion: { isActuallyReachable in
                            if isActuallyReachable {
                                VPNController.syncVPNToState()
                            }
                        })
                    }
                }
            })
        }
        
    }
    
    @objc func openMenubarPanel() {
        sb.showPopover(self)
    }
    
    //callback from onboarding page to install VPN
    @IBAction func tunnelsInstalled (_ sender: Any) {
        self.sb.setupStatusBar()
    }
    
    /*
        * callback after onboarding to show user where the UI is
     */
    @IBAction func onboardingCompleted (_ sender: Any) {
        onboardingWindow.close()
        sb.showPopover(self)
    }
    
    /*
        * use these to handle notifications from the browser
        * email confirmation from accepting & opening browser
        * payment confirmatin from webview in onboarding
     */
    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor?, replyEvent: NSAppleEventDescriptor?) {
        let urlPassed = NSURL(string: (event?.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))!.stringValue!)!)
        DDLogInfo("Url \(String(describing: urlPassed))")
        if urlPassed?.absoluteString == Global.kPaymentAcceptedURL {
            NotificationCenter.default.post(name: .paymentAccepted, object: nil)
        }
        else if urlPassed?.absoluteString == Global.kEmailConfirmedURL {
            //TODO: Progress to next screen
            NotificationCenter.default.post(name: .emailConfirmed, object: nil)
        }
    }
    
    
    //MARK: - CLEANUP
    func applicationWillTerminate(_ aNotification: Notification) {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Global.kForceVPNOnMac) {
                
        }
        else {
                 Utils.disableProxySettings()
        }
    }
    
    /*
        * clear up all variables & personal information
        * easier to relaunch app from there
     */
    @objc func signoutUser (_ sender: Any) {
        Auth.signoutUser()
        
        //show onboarding & hide menu item
        NSStatusBar.system.removeStatusItem(sb.statusItem)
        DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
            Utils.relaunch(afterDelay: 0.3) //just easier to relaunch app than reset everything
        }
    }
    
    //MARK: - SPARKLE UPDATER METHODS
    func updater(_ updater: SUUpdater, didFinishLoading appcast: SUAppcast) {
        let appcastItem = appcast.items?.first as! SUAppcastItem
        SUUpdater.shared().checkForUpdates(nil)
    }
    
    
    func updater(_ updater: SUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Utils.relaunchAfterUpdate()
    }
    
    //MARK: - VARIABLES
    let sb = StatusBarController.shared
    let onboardingWindow = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "onboardingWindow")) as! NSWindowController
    var preferencesWindowController : RHPreferencesWindowController?
    
}

