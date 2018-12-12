//
//  SignupViewController.swift
//  Tunnels
//
//  Copyright © 2018 Confirmed, Inc. All rights reserved.
//

import Cocoa
import CocoaLumberjackSwift

class SignupViewController: OnboardingPageViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Creates a hoverable button
        Utils.addTrackingArea(button: nextButton!)
        Utils.addTrackingArea(button: backButton!)
        Utils.addTrackingArea(button: signinButton!)
        Utils.addTrackingArea(button: signupButton!)
        Utils.addTrackingArea(button: continueButton!)
        Utils.addTrackingArea(button: signoutButton!)
        Utils.addTrackingArea(button: forgotPasswordButton!)
        
        //default to sign up
        self.signinButton?.state = NSControl.StateValue.off
        self.signupButton?.state = NSControl.StateValue.on
        self.signinButton?.mouseExited(with: NSEvent())
        self.signupButton?.mouseExited(with: NSEvent())
        
        //move forward on email confirmation URL from browser
        NotificationCenter.default.addObserver(self, selector: #selector(emailConfirmed(_:)), name: .emailConfirmed, object: nil)
        
    }
    
    /*
        * check to make sure the view is shown
            * the user can advance on their own once the e-mail is confirmed
        * simulate pressing the continue button
            * this will test the login
     */
    @objc func emailConfirmed (_ sender: Any) {
        if !self.view.isHidden {
            continueButtonPressed(self)
        }
    }
    
    override func viewWillAppear() {
        let email = Global.keychain[Global.kConfirmedEmail]
        let password = Global.keychain[Global.kConfirmedPassword]
        
        //if e-mail/password is not saved in keychain, show default view
        //otherwise show 'contine as' view
        if (email != nil && password != nil) {
            self.signupView?.alphaValue = 0.0
            self.signupView?.isHidden = true
            self.signedInView?.alphaValue = 1.0
            self.signedInView?.isHidden = false
            self.signedInEmail?.stringValue = email!
        }
        else {
            self.signupView?.alphaValue = 1.0
            self.signupView?.isHidden = false
            self.signedInView?.alphaValue = 0.0
            self.signedInView?.isHidden = true
        }
    }
    
    @IBAction func backButtonPressed (_ sender: Any) {
        self.delegate?.prevPage()
    }
    
    @IBAction func switchToSignup (_ sender: Any) {
        self.signinButton?.isEnabled = false
        self.signupButton?.isEnabled = false
        
        self.signinButton?.state = NSControl.StateValue.off
        self.signupButton?.state = NSControl.StateValue.on
        self.passwordConfirmationTextField?.isHidden = false
        
        NSAnimationContext.runAnimationGroup({_ in
            NSAnimationContext.current.duration = 0.6
            self.passwordConfirmationTextField?.animator().alphaValue = 1.0
            self.forgotPasswordButton?.animator().alphaValue = 0.0
            self.signupError?.animator().alphaValue = 0.0
            self.signinButton?.mouseExited(with: NSEvent())
            
        }, completionHandler:{
            DDLogInfo("Animation completed")
            self.signinButton?.isEnabled = true
            self.signupButton?.isEnabled = true
        })
    }
    
    @IBAction func switchToSignin (_ sender: Any) {
        self.signinButton?.isEnabled = false
        self.signupButton?.isEnabled = false
        
        self.signinButton?.state = NSControl.StateValue.on
        self.signupButton?.state = NSControl.StateValue.off
        self.forgotPasswordButton?.alphaValue = 0.0
        self.forgotPasswordButton?.isHidden = false
        
        NSAnimationContext.runAnimationGroup({_ in
            NSAnimationContext.current.duration = 0.6
            self.passwordConfirmationTextField?.animator().alphaValue = 0.0
            self.signupError?.animator().alphaValue = 0.0
            self.signupButton?.mouseExited(with: NSEvent())
            self.forgotPasswordButton?.animator().alphaValue = 1.0
            
        }, completionHandler:{
            DDLogInfo("Animation completed")
            self.passwordConfirmationTextField?.isHidden = true
            self.signinButton?.isEnabled = true
            self.signupButton?.isEnabled = true
            
            
        })
    }

    @IBAction func signoutButtonPressed (_ sender: Any) {
        Auth.signoutUser()
        NotificationCenter.post(name: .signoutUserDuringOnboarding)
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.signupView?.alphaValue = 0.0
            self.signupView?.isHidden = false
            NSAnimationContext.runAnimationGroup({_ in
                NSAnimationContext.current.duration = 1.0
                self.signupView?.animator().alphaValue = 1.0
                self.signedInView?.animator().alphaValue = 0.0
            }, completionHandler:{
                DDLogInfo("Animation completed")
                self.signedInView?.isHidden = true
            })
        }
    }
    
    /*
        * if credentials are saved, get-key
        * get cookie & get key are both required
            * need result to determine showing payment screen
     */
    @IBAction func continueButtonPressed (_ sender: Any) {
        self.delegate?.blockInteraction()
        continueButton?.startLoadingAnimation()
        Auth.clearCookies()
        
        Auth.getKey(callback: { (status, reason, errorCode) in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if status || errorCode == 0 || errorCode == Global.kMissingPaymentErrorCode { //no payment can move forward
                    self.delegate?.nextPage(result: errorCode)
                }
                else {
                    self.showErrorFromCode(errorCode: errorCode, defaultString: "Unknown error", textField: self.continueError!)
                }
                self.delegate?.unblockInteraction()
                self.continueButton?.setOriginalState()
            }
        })
    }
    
    @IBAction func forgotPasswordPressed (_ sender: Any) {
        if let url = URL(string: Global.masterURL + "/forgot-password"), NSWorkspace.shared.open(url) {
        }
    }
    
    /*
        * action shared for create & sign in
        * for sign in
            * need to get cookie
            * need to get key
                * result to determine showing payment screen
        * for create user, just one call
     */
    @IBAction func submitButtonPressed (_ sender: Any) {
        delegate?.blockInteraction()
        Auth.clearCookies()
        NSAnimationContext.runAnimationGroup({_ in
            NSAnimationContext.current.duration = 0.7
            self.signupError?.animator().alphaValue = 0.0
        }, completionHandler:{
        })
        
        let emailText = (self.emailTextField?.stringValue)!
        let passwordText = (self.passwordTextField?.stringValue)!
        
        nextButton?.startLoadingAnimation()
        
        if (signinButton?.checked)! {
            Auth.signInForCookie(email: emailText, password: passwordText, cookieCallback: {(_ status: Bool, errorCode : Int) -> Void in
                if status {
                    Auth.getKey(callback: { (status, reason, errorCode) in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if status || errorCode == 0 || errorCode == Global.kMissingPaymentErrorCode { //no payment can move forward
                                self.delegate?.nextPage(result: errorCode)
                            }
                            else {
                                self.showErrorFromCode(errorCode: errorCode, defaultString: "Unknown error", textField: self.signupError!)
                            }
                            self.delegate?.unblockInteraction()
                            self.nextButton?.setOriginalState()
                        }
                    })
                }
                else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.showErrorFromCode(errorCode: errorCode, defaultString: "Unknown error.", textField: self.signupError!)
                        self.delegate?.unblockInteraction()
                        self.nextButton?.setOriginalState()
                    }
                }
            })
        }
        else {
            Auth.createUser(email: emailText, password: passwordText, passwordConfirmation: (self.passwordConfirmationTextField?.stringValue)!, createUserCallback: {(_ status: Bool, _ reason: String, _ errorCode: Int) -> Void in
                DispatchQueue.main.async {
                    if status {
                        if errorCode == 0 || errorCode == Global.kMissingPaymentErrorCode {
                            self.delegate?.nextPage(result: errorCode)
                        }
                        else {
                            if errorCode == Global.kEmailNotConfirmed {
                                Global.keychain[Global.kConfirmedEmail] = emailText
                                Global.keychain[Global.kConfirmedPassword] = passwordText
                                
                                //successful user creation, switch to continue view
                                self.switchToWaitingForConfirmedEmailView()
                            }
                            else {
                                self.showErrorFromCode(errorCode: errorCode, defaultString: reason, textField: self.signupError!)
                            }
                            self.delegate?.unblockInteraction()
                        }
                    }
                    else {
                        if errorCode == Global.kEmailNotConfirmed {
                            //successful user creation, switch to continue view
                            Global.keychain[Global.kConfirmedEmail] = emailText
                            Global.keychain[Global.kConfirmedPassword] = passwordText
                            
                            self.switchToWaitingForConfirmedEmailView()
                        }
                        else {
                            self.showErrorFromCode(errorCode: errorCode, defaultString: reason, textField: self.signupError!)
                        }
                        self.delegate?.unblockInteraction()
                    }
                    self.nextButton?.setOriginalState()
                }
            })
        }
    }
    
    func switchToWaitingForConfirmedEmailView() {
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.signedInView?.alphaValue = 0.0
            self.signedInView?.isHidden = false
            
            let emailText = (self.emailTextField?.stringValue)!
            self.signedInEmail?.stringValue = emailText
            NSAnimationContext.runAnimationGroup({_ in
                NSAnimationContext.current.duration = 1.0
                self.signupView?.animator().alphaValue = 0.0
                self.signedInView?.animator().alphaValue = 1.0
            }, completionHandler:{
                self.signupView?.isHidden = true
                self.showErrorFromCode(errorCode: Global.kEmailNotConfirmed, defaultString: Global.errorMessageForError(eCode:Global.kEmailNotConfirmed), textField: self.continueError!)
            })
        }
    }
    
    func showErrorFromCode(errorCode : Int, defaultString: String, textField : NSTextField) {
        textField.stringValue = Global.errorMessageForError(eCode:errorCode)
        if errorCode == Global.kInvalidEmail { //use default string for this as error is more complicated
            textField.stringValue = defaultString
        }
        
        textField.animator().alphaValue = 0.0
        textField.animator().isHidden = false
        NSAnimationContext.runAnimationGroup({_ in
            NSAnimationContext.current.duration = 1.0
            textField.animator().alphaValue = 1.0
        }, completionHandler:{
        })
    }

    //MARK: - VARIABLES
    
    @IBOutlet var emailTextField: NSTextField?
    @IBOutlet var passwordTextField: NSTextField?
    @IBOutlet var passwordConfirmationTextField: NSTextField?
    
    @IBOutlet var signupError: NSTextField?
    @IBOutlet var nextButton: TKTransitionSubmitButton?
    @IBOutlet var backButton: TunnelsButton?
    
    @IBOutlet var continueButton: TKTransitionSubmitButton?
    @IBOutlet var signoutButton: TunnelsButton?
    @IBOutlet var continueError: NSTextField?
    
    @IBOutlet var signupButton: TunnelsButton?
    @IBOutlet var signinButton: TunnelsButton?
    @IBOutlet var forgotPasswordButton: TunnelsButton?
    
    @IBOutlet var signupView: NSView?
    @IBOutlet var signedInView: NSView?
    
    @IBOutlet var signedInEmail: NSTextField?
    
}
