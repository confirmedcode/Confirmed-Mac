//
//  EULAViewController.swift
//  Tunnels
//
//  Copyright © 2018 Confirmed, Inc. All rights reserved.
//

import Cocoa
import CocoaLumberjackSwift

class EULAViewController: OnboardingPageViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.nextButton?.isEnabled = false
        Utils.addTrackingArea(button: nextButton!)
        Utils.addTrackingArea(button: backButton!)
    }
    
    @IBAction func viewEulaButtonPressed (_ sender: Any) {
        if let url = URL(string: "https://confirmedvpn.com/privacy"),
            NSWorkspace.shared.open(url) {
        }
    }
    
    @IBAction func acceptToggled (_ sender: Any) {
        let toggle = sender as! NSButton
        if toggle.state == .on {
            self.nextButton?.isEnabled = true
            self.nextButton?.mouseExited(with: NSEvent())
        }
        else {
            self.nextButton?.isEnabled = false
            self.nextButton?.mouseExited(with: NSEvent())
        }
    }
    
    @IBAction func backButtonPressed (_ sender: Any) {
        delegate?.prevPage()
    }
    
    @IBAction func nextButtonPressed (_ sender: Any) {
        delegate?.nextPage(result: 0)
    }
    
    @IBOutlet var nextButton: TunnelsButton?
    @IBOutlet var backButton: TunnelsButton?
    @IBOutlet var viewEULAButton: TunnelsButton?
    
}
