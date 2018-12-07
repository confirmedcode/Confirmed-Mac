//
//  PaymentsViewController.swift
//  Tunnels
//
//  Copyright © 2018, Confirmed, Inc. All rights reserved.
//

import Cocoa
import WebKit
import CocoaLumberjackSwift

class PaymentsViewController: OnboardingPageViewController, WKUIDelegate, WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        guard let user = Global.keychain[Global.kConfirmedEmail], let password = Global.keychain[Global.kConfirmedPassword] else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        let creds = URLCredential.init(user: user, password: password, persistence: .forSession)
        completionHandler(.useCredential, creds)
    }
    
    @IBAction func backButtonPressed (_ sender: Any) {
        delegate?.prevPage()
    }
    
    @IBAction func refreshPage (_ sender: Any) {
        self.startStripePageLoad()
    }
    
    func startStripePageLoad() {
        self.loadingView?.alphaValue = 1.0
        self.loadingProgressView?.animate = true
        self.refreshButton?.isEnabled = false
        self.refreshButton?.alphaValue = 0
        loadingText?.stringValue = "Loading"
        self.loadingProgressView?.alphaValue = 1
        setupPaymentsController()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        startStripePageLoad()
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        self.loadingProgressView?.stopAnimation()
    }
    
    
    @objc func setupPaymentsController() {
        
        if let email = Global.keychain[Global.kConfirmedEmail], let password = Global.keychain[Global.kConfirmedPassword] {
            let defaultLocale = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
            let myURL = URL(string: Global.paymentURL + "&" + defaultLocale) //add default locale for currency
            let myRequest = URLRequest(url: myURL!)
            
            let configuration = WKWebViewConfiguration()
            paymentWebview = WKWebView(frame: .zero, configuration: configuration)
            paymentWebview?.translatesAutoresizingMaskIntoConstraints = false
            paymentWebview?.navigationDelegate = self
            paymentWebview?.uiDelegate = self
            self.view.addSubview(paymentWebview!, positioned: .below, relativeTo: self.loadingView)
            
            paymentWebview?.load(myRequest)
            self.backButton?.removeFromSuperview()
            self.view.addSubview(self.backButton!, positioned: .below, relativeTo: self.loadingView)
            
            [paymentWebview?.topAnchor.constraint(equalTo: view.topAnchor),
             paymentWebview?.bottomAnchor.constraint(equalTo: (backButton?.topAnchor)!),
                paymentWebview?.leftAnchor.constraint(equalTo: view.leftAnchor),
                paymentWebview?.rightAnchor.constraint(equalTo: view.rightAnchor)].forEach  {
                    anchor in
                    anchor?.isActive = true
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.loadingView?.wantsLayer = true
        self.loadingView?.layer?.backgroundColor = NSColor.white.cgColor
        
        Utils.addTrackingArea(button: backButton!)
        backButton?.buttonColor = NSColor(calibratedRed: 62/255.0, green: 140/255.0, blue: 200/255.0, alpha: 1.0)
        backButton?.buttonPressedColor = NSColor(calibratedRed: 62/255.0, green: 100/255.0, blue: 180/255.0, alpha: 1.0)
        backButton?.buttonHighlightedColor = NSColor(calibratedRed: 102/255.0, green: 180/255.0, blue: 240/255.0, alpha: 1.0)
        
        NotificationCenter.default.addObserver(self, selector: #selector(paymentAccepted(_:)), name: .paymentAccepted, object: nil)

    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0) {
            NSAnimationContext.runAnimationGroup({_ in
                NSAnimationContext.current.duration = 0.3
                self.loadingView?.animator().alphaValue = 0
            }, completionHandler:{
                DDLogInfo("Animation completed")
            })
        }
    }
    
    //for errors, show manual reload button
    func handleError() {
        loadingText?.stringValue = "There was an error loading the page. Please click refresh to try again or e-mail team@confirmedvpn.com"
        refreshButton?.isEnabled = true
        NSAnimationContext.runAnimationGroup({_ in
            NSAnimationContext.current.duration = 0.3
            self.refreshButton?.animator().alphaValue = 1
            self.loadingProgressView?.alphaValue = 0
        }, completionHandler:{
            DDLogInfo("Animation completed")
            self.loadingProgressView?.animate = false
            
        })
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        DDLogError("Error loading webview " + error.localizedDescription)
        handleError()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        DDLogError("Error prov loading webview " + error.localizedDescription)
        handleError()
    }
    
    //next page on payment accepted URL
    @objc func paymentAccepted(_ notification: Notification?) {
        delegate?.nextPage(result: 0)
    }
    
    
    //MARK: - VARIABLES
    @IBOutlet var loadingText: NSTextField?
    @IBOutlet var loadingProgressView: MaterialProgress?
    @IBOutlet var loadingView: NSView?
    
    @IBOutlet var refreshButton: TunnelsButton?
    
    
    @IBOutlet var nextButton: TunnelsButton?
    @IBOutlet var backButton: TunnelsButton?
    var paymentWebview: WKWebView?
}
