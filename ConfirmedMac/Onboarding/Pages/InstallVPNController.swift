//
//  InstallVPNController.swift
//  Confirmed VPN
//
//  Copyright © 2018 Confirmed, Inc.. All rights reserved.
//

import Cocoa
import Alamofire
import NetworkExtension

class InstallVPNController: OnboardingPageViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        Utils.addTrackingArea(button: installVPNButton!)
    }
    
    @IBAction func installVPN (_ sender: Any) {
        //if installed, skip?
        
        installVPNButton?.startLoadingAnimation()
        delegate?.blockInteraction()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
            VPNController.installVPNInternal(vpnInstallationStatusCallback: {(_ status: Bool) -> Void in
                if (status) {
                    VPNController.connectToVPN()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        NotificationCenter.post(name: .tunnelsSuccessfullyInstalled)
                        self.delegate?.nextPage(result: 0)
                    }
                }
                else {
                    //error handling with failed installation
                    self.delegate?.unblockInteraction()
                }
                self.installVPNButton?.setOriginalState()
            })
        })
    }
    
    @IBOutlet var installVPNButton: TKTransitionSubmitButton?
}
