//
//  OnboardingViewController.swift
//  Tunnels
//
//  Copyright © 2018 Confirmed, Inc. All rights reserved.
//

import Cocoa
import CocoaLumberjackSwift

protocol OnboardingDelegate: class {
    func nextPage(result: Int?)
    func prevPage()
    func unblockInteraction()
    func blockInteraction()
}

class OnboardingViewController: NSViewController, OnboardingDelegate {
    
    /*
        * window -> center & front
        * add all views
        * start onboarding at zero
        * right now only used for initialization
            * future want to use for sign out but currently just restart app
     */
    @objc func restartOnboarding() {
        NSApp.activate(ignoringOtherApps: true)
        currentSlide = 0
        mainViewController.view.frame = NSRect(x: 0, y: 0, width: mainViewController.view.frame.size.width, height: mainViewController.view.frame.size.height)
        
        orderedViews = [mainViewController, emailViewController, eulaViewController, paymentsViewController, installViewController, whitelistingVC]
        
        
        for (_, element) in orderedViews.enumerated() {
            element.view.alphaValue = 0
            element.view.isHidden = true
            element.delegate = self
            self.view.addSubview(element.view)
        }
        mainViewController.view.isHidden = false
        
        NotificationCenter.default.addObserver(self, selector: #selector(emailConfirmed(_:)), name: .emailConfirmed, object: nil)
        
        currentView = orderedViews[0]

    }
    
    @objc func signoutUserFromOnboarding() {
        orderedViews = [mainViewController, emailViewController, eulaViewController, paymentsViewController, installViewController, whitelistingVC]
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        restartOnboarding()
        self.mainViewController.view.alphaValue = 1.0
        self.startOnboardingButton?.alphaValue = 1.0
        self.quitOnboardingButton?.alphaValue = 1.0
        
        NotificationCenter.default.addObserver(self, selector: #selector(restartOnboarding), name: .signoutUser, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(signoutUserFromOnboarding), name: .signoutUserDuringOnboarding, object: nil)

    }
    
    func fadeInIntroView() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) {
            self.mainViewController.view.alphaValue = 1.0
            self.startOnboardingButton?.alphaValue = 1.0
            self.quitOnboardingButton?.alphaValue = 1.0
            NSAnimationContext.runAnimationGroup({_ in
                //Indicate the duration of the animation
                NSAnimationContext.current.duration = 0.5
                //What is being animated? In this example I’m making a view transparent
                self.mainViewController.view.animator().alphaValue = 1.0
                self.startOnboardingButton?.animator().alphaValue = 1.0
                self.quitOnboardingButton?.animator().alphaValue = 1.0
            }, completionHandler:{
                //In here we add the code that should be triggered after the animation completes.
                DDLogInfo("Animation completed")
                
            })
        }
    }
    
    
    /*
        * use these methods to prevent quick double clicks by accident during page transitions
     */
    func blockInteraction() {
        DispatchQueue.main.async {
            self.interactionBlock?.removeFromSuperview()
            self.view.addSubview(self.interactionBlock!)
        }
    }
    
    func unblockInteraction() {
        DispatchQueue.main.async {
            self.interactionBlock?.removeFromSuperview()
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        if let email = Global.keychain[Global.kConfirmedEmail], let password = Global.keychain[Global.kConfirmedPassword] {
            Auth.signInForCookie(email: email, password: password, cookieCallback: {(_ status: Bool, _ errorCode : Int) -> Void in
                self.fadeInIntroView()
            })
        }
        else {
            self.fadeInIntroView()
        }
    }
    
    func animateView(viewOut: NSViewController, viewIn: NSViewController) {
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            viewIn.view.isHidden = false
            viewIn.view.alphaValue = 0.0
            self.currentView = viewIn
            
            NSAnimationContext.runAnimationGroup({_ in
                NSAnimationContext.current.duration = self.pageAnimationTime
                viewOut.view.animator().alphaValue = 0.0
                viewIn.view.animator().alphaValue = 1.0
            }, completionHandler:{
                DDLogInfo("Animation completed")
                viewOut.view.isHidden = true
                objc_sync_exit(self)
            })
        }
    }
    
    @IBAction func emailConfirmed (_ sender: Any) {
        if currentView == emailViewController {
            //nextPage()
        }
    }
    
    /*
        * called by individual pages in onboarding to advance or go back one page
        * basic error checking
     */
    func nextPage(result: Int? = 0) {
        blockInteraction()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.unblockInteraction()
        }
        //adding this to prevent double clicks from advancing two pages
        if abs(lastSlideChange.timeIntervalSinceNow) < pageAnimationTime {
            return
        }
        objc_sync_enter(self)
        lastSlideChange = NSDate.init(timeIntervalSinceNow: 0)
        currentSlide += 1
        
        //remove payments page if we are starting onboarding with already signed in and valid account
        if orderedViews[currentSlide] == eulaViewController && result == 0 {
            if let index = orderedViews.index(of: paymentsViewController) {
                DDLogInfo("Index \(index)")
                orderedViews.remove(at: index)
            }
        }
        DDLogInfo("Animating out view \(String(describing: currentView)), inView \(currentSlide)")
        animateView(viewOut: currentView!, viewIn: orderedViews[currentSlide])
    }
    
    func prevPage() {
        blockInteraction()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.unblockInteraction()
        }
        //adding this to prevent double clicks from advancing two pages
        if abs(lastSlideChange.timeIntervalSinceNow) < pageAnimationTime {
            return;
        }
        objc_sync_enter(self)
        lastSlideChange = NSDate.init(timeIntervalSinceNow: 0)
        if currentSlide == 0 { //can't go before the first slide!!
            objc_sync_exit(self)
            return;
        }
        currentSlide -= 1
        animateView(viewOut: currentView!, viewIn: orderedViews[currentSlide])
    }
    
    
    var currentSlide = 0
    var lastSlideChange = NSDate.init(timeIntervalSinceNow: 0)
    let pageAnimationTime = 0.75
    @IBOutlet var startOnboardingButton: TunnelsButton?
    @IBOutlet var quitOnboardingButton: TunnelsButton?
    @IBOutlet var backgroundView: NSImageView?
    
    let mainViewController = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "IntroScreen")) as! OnboardingPageViewController
    let emailViewController = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "EmailScreen")) as! OnboardingPageViewController
    let eulaViewController = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "EULAScreen")) as! OnboardingPageViewController
    let paymentsViewController = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "PaymentsScreen")) as! OnboardingPageViewController
    let installViewController = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "InstallVPNScreen")) as! OnboardingPageViewController
    let whitelistingVC = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "WhitelistingOnboarding")) as! OnboardingPageViewController
    
    
    
    var currentView : NSViewController?
    @IBOutlet var interactionBlock : InteractionBlock?
    
    var orderedViews = [OnboardingPageViewController]()
}
