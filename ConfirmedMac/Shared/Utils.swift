//
//  Utils.swift
//
//  Copyright © 2018 Confirmed, Inc. All rights reserved.
//

import AppKit
import NetworkExtension
import Sparkle
import ServiceManagement
import GBDeviceInfo
import Alamofire
import CocoaLumberjackSwift

enum InterfaceStyle : String {
    case Dark, Light
    
    init() {
        let type = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") ?? "Light"
        self = InterfaceStyle(rawValue: type)!
    }
}

extension String {
    var data:          Data  { return Data(utf8) }
    var base64Encoded: Data  { return data.base64EncodedData() }
    var base64Decoded: Data? { return Data(base64Encoded: self) }
    
    func localized(bundle: Bundle = .main, tableName: String = "Localizable") -> String {
        //return NSLocalizedString(self, tableName: tableName, value: "***\(self)***", comment: "") USE THIS TO DEBUG MISSING STRINGS
        return NSLocalizedString(self, tableName: tableName, value: "\(self)", comment: "")
    }
}

extension NSImage {
    func resizeImage(maxSize:NSSize) -> NSImage {
        var ratio:Float = 0.0
        let imageWidth = Float(self.size.width)
        let imageHeight = Float(self.size.height)
        let maxWidth = Float(maxSize.width)
        let maxHeight = Float(maxSize.height)
        
        // Get ratio (landscape or portrait)
        if (imageWidth > imageHeight) {
            // Landscape
            ratio = maxWidth / imageWidth;
        }
        else {
            // Portrait
            ratio = maxHeight / imageHeight;
        }
        
        // Calculate new size based on the ratio
        let newWidth = imageWidth * ratio
        let newHeight = imageHeight * ratio
        
        // Create a new NSSize object with the newly calculated size
        let newSize:NSSize = NSSize(width: Int(newWidth), height: Int(newHeight))
        
        // Cast the NSImage to a CGImage
        var imageRect:CGRect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
        let imageRef = self.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
        
        // Create NSImage from the CGImage using the new size
        let imageWithNewSize = NSImage(cgImage: imageRef!, size: newSize)
        
        // Return the new image
        return imageWithNewSize
    }
    
    func imageWithTintColor(tintColor: NSColor) -> NSImage {
        if self.isTemplate == false {
            return self
        }
        
        let image = self.copy() as! NSImage
        image.lockFocus()
        
        tintColor.set()
        __NSRectFillUsingOperation(NSMakeRect(0, 0, image.size.width, image.size.height), NSCompositingOperation.sourceAtop)
        
        image.unlockFocus()
        image.isTemplate = false
        
        return image
    }
}


class Utils: SharedUtils {

    /*
        * after app updates, relaunch
        * need to wait a reasonable amount of time to finish
        * it is in background so not time sensitive
            * long term check that file is there
     */
    static func relaunchAfterUpdate() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 30.0) {
            Utils.relaunch(afterDelay: 1.0)
        }
    }
    
    /*
        * helper function to relaunch app
    */
    static func relaunchFromCommandLine() {
        if !CommandLine.arguments.contains("-NSDocumentRevisionsDebugMode") && !CommandLine.arguments.contains("launchedFromCommandLine") {
            let task = Process()
            task.launchPath = "/bin/sh"
            task.arguments = ["-c", "sleep \(1); \"\(Bundle.main.bundlePath)/Contents/MacOS/Tunnels\" launchedFromCommandLine"]
            task.launch()
            
            NSApp.terminate(nil)
        }
    }
    
    static func relaunch(afterDelay seconds: TimeInterval = 0.5) {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "sleep \(seconds); open \"\(Bundle.main.bundlePath)\""]
        task.launch()
        
        NSApp.terminate(nil)
    }
    
    static func getClientId() -> String? {
        return Global.keychain[Global.kConfirmedID]
    }
    
    /*
        * format and return current version of app
        * default to 1.0.0 if for some reason it can't be retrieved
     */
    static func getTunnelsVersion() -> String {
        if let text = Bundle.main.infoDictionary?["CFBundleShortVersionString"]  as? String {
            return text
        }
        return "1.0.0"
    }
    
    /*
        * called to get callbacks to add different colors for hovering on buttons
     */
    static func addTrackingArea(button: NSButton) {
        let trackingArea = NSTrackingArea(rect: button.bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: button, userInfo: nil)
        button.addTrackingArea(trackingArea)
        button.addCursorRect(button.bounds, cursor: NSCursor.pointingHand)
    
    }
    
    
    /*
        * macOS 10.12 and older requires an blessed XPC helper to change proxy settings
            * these are in System Preferences > Network > WiFi > Advanced > Proxies
            * this is how we implement whitelisting on macOS
     */
    static func shouldInstallHelper(callback: @escaping (Bool) -> Void){
        if GBDeviceInfo.deviceInfo().osVersion.minor >= 13 {
            callback(false)
            return
        }
        
        let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchServices/\(HelperConstants.machServiceName)")
        let helperBundleInfo = CFBundleCopyInfoDictionaryForURL(helperURL as CFURL!)
        if helperBundleInfo != nil {
            let helperInfo = helperBundleInfo as! NSDictionary
            let helperVersion = helperInfo["CFBundleVersion"] as! String
            
            
            //check appropriate folders
            if !FileManager.default.fileExists(atPath: "/Library/LaunchDaemons/com.confirmed.ConfirmedProxy.plist") ||
                !FileManager.default.fileExists(atPath: "/Library/PrivilegedHelperTools/com.confirmed.ConfirmedProxy") {
                callback(true)
                return
            }
            
            DDLogInfo("Helper: Bundle Version => \(helperVersion)")
             let helper = self.helperConnection()?.remoteObjectProxyWithErrorHandler({
                error in
                callback(true)
            }) as! HelperProtocol
            
            helper.getVersion(reply: { installedVersion in
                DDLogInfo("Helper: Installed Version => \(installedVersion)")
                callback(helperVersion != installedVersion)
            })
        } else {
            callback(false)
        }
    }
    
    /*
        request permission & install helper to control proxy settings
     */
    static func installHelper() {
        
        var authRef:AuthorizationRef?
        var authItem = AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0, value:UnsafeMutableRawPointer(bitPattern: 0), flags: 0)
        var authRights:AuthorizationRights = AuthorizationRights(count: 1, items:&authItem)
        let authFlags: AuthorizationFlags = [ [], .extendRights, .interactionAllowed, .preAuthorize ]
        
        let status = AuthorizationCreate(&authRights, nil, authFlags, &authRef)
        if (status != errAuthorizationSuccess){
            let error = NSError(domain:NSOSStatusErrorDomain, code:Int(status), userInfo:nil)
            DDLogInfo("Authorization error: \(error)")
        } else {
            var cfError: Unmanaged<CFError>? = nil
            if !SMJobBless(kSMDomainSystemLaunchd, HelperConstants.machServiceName as CFString, authRef, &cfError) {
                let blessError = cfError!.takeRetainedValue() as Error
                DDLogError("Bless Error: \(blessError)")
            } else {
                DDLogInfo("\(HelperConstants.machServiceName) installed successfully")
            }
        }
    }
    
    static func helperConnection() -> NSXPCConnection? {
        if (xpcHelperConnection == nil){
            xpcHelperConnection = NSXPCConnection(machServiceName:HelperConstants.machServiceName, options:NSXPCConnection.Options.privileged)
            xpcHelperConnection!.exportedObject = self
            xpcHelperConnection!.exportedInterface = NSXPCInterface(with:ProcessProtocol.self)
            xpcHelperConnection!.remoteObjectInterface = NSXPCInterface(with:HelperProtocol.self)
            xpcHelperConnection!.invalidationHandler = {
                xpcHelperConnection?.invalidationHandler = nil
                OperationQueue.main.addOperation(){
                    xpcHelperConnection = nil
                    DDLogInfo("XPC Connection Invalidated\n")
                }
            }
            xpcHelperConnection?.resume()
        }
        return xpcHelperConnection
    }
    
    static func setProxySettings() {
        if GBDeviceInfo.deviceInfo().osVersion.minor >= 13 {
            Utils.startConfirmedProxyWithoutXPC(reply: { (reply) in
                DDLogInfo("Reply here \(reply)")
            })
        }
        else {
            // Connect to the helper and run the function runCommandLs(path:reply:)
            let xpcService = self.helperConnection()?.remoteObjectProxyWithErrorHandler() { error -> Void in
                DDLogError("XPCService error: \(error)")
                } as? HelperProtocol
            
            xpcService?.startConfirmedProxy(reply: { (exitStatus) in
                DDLogInfo("Command exit status: \(exitStatus)")
            })
        }
    }
    
    static func disableProxySettings() {
        if GBDeviceInfo.deviceInfo().osVersion.minor >= 13 {
            Utils.stopConfirmedProxyWithoutXPC(reply: { (reply) in
                DDLogInfo("Reply here \(reply)")
            })
        }
        else {
            let xpcService = self.helperConnection()?.remoteObjectProxyWithErrorHandler() { error -> Void in
                DDLogError("XPCService error: \(error)")
                } as? HelperProtocol
            
            xpcService?.stopConfirmedProxy(reply: { (exitStatus) in
                DDLogInfo("Command exit status: \(exitStatus)")
            })
        }
    }
    
    static func setupAndInstallProxyIfNeeded() {
        if GBDeviceInfo.deviceInfo().osVersion.minor >= 13 {
            return
        }
       
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Global.kForceVPNOnMac) {
            Utils.shouldInstallHelper(callback: {
                shouldInstall in
                if shouldInstall {
                    Utils.installHelper()
                    Utils.xpcHelperConnection = nil  //  Nulls the connection to force a reconnection
                }
            })
        }
        else {
            disableProxySettings()
        }
    }
    
    static var proxyTaskQueue = OperationQueue.init()
    static func startConfirmedProxyWithoutXPC(reply: @escaping (NSNumber) -> Void) {
        
        //we should probably iterate through all interfaces?
        proxyTaskQueue.maxConcurrentOperationCount = 1
        proxyTaskQueue.cancelAllOperations()
        
        let startOp = BlockOperation.init()
        startOp.addExecutionBlock {
            if startOp.isCancelled { return }
            let command = "/usr/sbin/networksetup"
            var arguments = ["-setwebproxy", "wi-fi", "127.0.0.1", "9090"]
            runTask(command: command, arguments: arguments, reply:reply)

            if startOp.isCancelled { return }
            arguments = ["-setsecurewebproxy", "wi-fi", "127.0.0.1", "9090"]
            runTask(command: command, arguments: arguments, reply:reply)
            
            if startOp.isCancelled { return }
            arguments = ["-setwebproxystate", "wi-fi", "on"]
            runTask(command: command, arguments: arguments, reply:reply)
            
            if startOp.isCancelled { return }
            arguments = ["-setsecurewebproxystate", "wi-fi", "on"]
            runTask(command: command, arguments: arguments, reply:reply)
        }
        
        proxyTaskQueue.addOperation(startOp)
    }
    
    static func stopConfirmedProxyWithoutXPC(reply: @escaping (NSNumber) -> Void) {
        
        proxyTaskQueue.maxConcurrentOperationCount = 1
        proxyTaskQueue.cancelAllOperations()
        
        let stopOp = BlockOperation.init()
        stopOp.addExecutionBlock {
            if stopOp.isCancelled { return }
            let command = "/usr/sbin/networksetup"
            var arguments = ["-setwebproxystate", "wi-fi", "off"]
            runTask(command: command, arguments: arguments, reply:reply)
            
            if stopOp.isCancelled { return }
            arguments = ["-setsecurewebproxystate", "wi-fi", "off"]
            runTask(command: command, arguments: arguments, reply:reply)
        }
        
        proxyTaskQueue.addOperation(stopOp)
    }
    
    /*
        * helper to run a generic terminal command
        * must be called asynchronously as this can take up to 15 seconds
        * kills task after 15 seconds to prevent freeze
        * should build a retry mechanism in future (this is only used for whitelisting domains right now and non-essential to ensure privacy & encryption)
     */
    static func runTask(command: String, arguments: Array<String>, reply:@escaping ((NSNumber) -> Void)) -> Void
    {
        let task:Process = Process()
        let stdOut:Pipe = Pipe()
        
        let stdOutHandler =  { (file: FileHandle!) -> Void in
            usleep(100000)
            let data = file.availableData
            guard NSString(data: data, encoding: String.Encoding.utf8.rawValue) != nil else { return }
            
        }
        stdOut.fileHandleForReading.readabilityHandler = stdOutHandler
        
        let stdErr:Pipe = Pipe()
        let stdErrHandler =  { (file: FileHandle!) -> Void in
            usleep(100000)
            let data = file.availableData
            guard NSString(data: data, encoding: String.Encoding.utf8.rawValue) != nil else { return }
            
        }
        stdErr.fileHandleForReading.readabilityHandler = stdErrHandler
        
        task.launchPath = command
        task.arguments = arguments
        task.standardOutput = stdOut
        task.standardError = stdErr
        
        task.terminationHandler = { task in
            reply(NSNumber(value: task.terminationStatus))
        }
        
        task.launch()
        
        let startDate = Date.init()
        while task.isRunning {
            sleep(1)
            if abs(startDate.timeIntervalSinceNow) > 15 { //wait some reasonable amount of time, otherwise kill process
                DDLogWarn("Killing long running task")
                task.terminate()
                break
            }
        }
        
        
    }
    
    static func shell(launchPath path: String, arguments args: [String]) -> String {
        let task = Process()
        task.launchPath = path
        task.arguments = args
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)
        task.waitUntilExit()
        
        return(output!)
    }
    
    /*
        * add general information to log file to help debugging
     */
    static func setupLogging() {
        DDLog.add(DDTTYLogger.sharedInstance)
        DDLog.add(DDASLLogger.sharedInstance)
        DDTTYLogger.sharedInstance.logFormatter = LogFormatter()
        DDASLLogger.sharedInstance.logFormatter = LogFormatter()
        
        fileLogger.rollingFrequency = TimeInterval(60*60*24)  // 24 hours
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        fileLogger.logFormatter = LogFormatter()
        DDLog.add(fileLogger)
        //DDTTYLogger.sharedInstance.colorsEnabled = true
        let nsObject: String? = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        
        DDLogInfo("")
        DDLogInfo("")
        DDLogInfo("")
        DDLogInfo("************************************************")
        DDLogInfo("Confirmed VPN (Mac): v" + nsObject!)
        DDLogInfo("macOS version: \(osVersion)")
        DDLogInfo("************************************************")
    }
    
    /*
        * move app to /Applications
            * makes updating and debugging much easier
        * only run on release to allow Xcode debugging
     */
    static func moveToApplicationsFolder() {
        #if DEBUG
        #else
            if (MoveToApplicationsFolder()) {
                //exit(0);
                //[NSApp terminate:self];
                return;
            }
            LaunchAtLogin.setLaunchOnLogin(true)
            SUUpdater.shared().automaticallyDownloadsUpdates = true
        #endif
    }
    
    static func restoreVPNState() {
        if UserDefaults.standard.bool(forKey: Global.kConnectOnLaunch) {
            UserDefaults.standard.set(false, forKey: Global.kConnectOnLaunch)
            UserDefaults.standard.synchronize()
            VPNController.connectToVPN()
        }
    }
    
    /*
        * add high level info for user when e-mailing team
            * help debugging, but nothing persnoal
     */
    static func emailTeam() {
        //log a few things to help debug for user
        
        DDLogInfo("")
        DDLogInfo("")
        DDLogInfo("Email: \(Global.keychain[Global.kConfirmedEmail] ?? "No Email")")
        DDLogInfo("UserId: \(Global.keychain[Global.kConfirmedID] ?? "No User ID")")
        DDLogInfo("Sign in Error: \(Auth.signInError)")
        
        let cstorage = Alamofire.SessionManager.default.session.configuration.httpCookieStorage
        if let cookies = cstorage?.cookies {
            for cookie in cookies {
                if cookie.domain.contains("confirmedvpn.com") {
                    DDLogInfo("Has Confirmed cookie.") //get our cookie to test login issues
                }
            }
        }
        DDLogInfo("")
        
        
        let sharingService = NSSharingService(named: NSSharingService.Name.composeEmail)
        sharingService?.recipients = ["team@confirmedvpn.com"] //could be more than one
        sharingService?.subject = "Confirmed VPN Info (macOS)"
        
        //sharingService?.messageBody = "Hey Confirmed Team, \n\n Can you help me with this issue? \n\n\n"
        var items: [Any] = []
        for logFileData in logFileDataArray {
            items.append(logFileData)
        }
        
        if sharingService!.canPerform(withItems: items) {
            sharingService?.perform(withItems: items)
        } else {
            let alert = NSAlert()
            alert.messageText = "Mail Not Set Up"
            alert.informativeText = "Please set up the Mail client on your Mac to send an e-mail to Confirmed or e-mail us directly at team@confirmedvpn.com."
            alert.addButton(withTitle: "Ok")
            alert.runModal()
            
        }
        sharingService?.perform(withItems: items)
        
    }
    
    
    static func updateActualReachability(completion: @escaping (_ isActuallyReachable : Bool) -> Void) {
        URLCache.shared.removeAllCachedResponses()
        URLCache.shared = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)
        Alamofire.SessionManager.default.retrier = nil
        Alamofire.SessionManager.default.session.configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
       
        //use random to prevent weird cache issue
        Alamofire.SessionManager.default.request("https://www.apple.com", method: .get, parameters: ["random" : arc4random_uniform(1000000)]).response { response in
                if response.response?.statusCode == 200 {
                isInternetActuallyReachable = true
            }
            else {
                print("Status code \(response.response?.statusCode)")
                isInternetActuallyReachable = false
            }
            completion(isInternetActuallyReachable)
        }
    }
    
    static var xpcHelperConnection: NSXPCConnection?
    static var isInternetActuallyReachable = true
}
