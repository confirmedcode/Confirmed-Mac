//
//  IntroViewController.swift
//  Tunnels
//
//  Copyright © 2018 Confirmed, Inc. All rights reserved.
//

import Cocoa

class IntroViewController: OnboardingPageViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        Utils.addTrackingArea(button: startOnboardingButton!)
        Utils.addTrackingArea(button: quitOnboardingButton!)
        
    }
    
    @IBAction func nextPage (_ sender: Any) {
        delegate?.nextPage(result: 0)
    }
    
    @IBAction func quitApp (_ sender: Any) {
        NSApp.terminate(sender)
    }
    
    @IBOutlet var startOnboardingButton: TunnelsButton?
    @IBOutlet var quitOnboardingButton: TunnelsButton?
    
}
