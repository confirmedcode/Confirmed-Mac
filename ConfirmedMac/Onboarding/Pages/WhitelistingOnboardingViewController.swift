//
//  WhitelistingViewController.swift
//  Confirmed VPN
//
//  Copyright © 2018 Confirmed, Inc. All rights reserved.
//

import Cocoa

class WhitelistingOnboardingViewController: OnboardingPageViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        Utils.addTrackingArea(button: saveAndContinue!)
        Utils.addTrackingArea(button: openPreferences!)
    }
    
    
    @IBAction func openPreferencesPressed (_ sender: Any) {
        NotificationCenter.post(name: .openPreferences)
    }
    
    @IBAction func nextButtonPressed (_ sender: Any) {
        NotificationCenter.post(name: .onboardingCompleted)
    }
    
    
    @IBOutlet var saveAndContinue: TKTransitionSubmitButton?
    @IBOutlet var openPreferences: TKTransitionSubmitButton?
}
