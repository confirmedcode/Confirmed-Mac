//
//  NSNotificationCenter+Additions.swift
//  Tunnels
//
//  Copyright © 2018 Confirmed, Inc. All rights reserved.
//

import Foundation

//notifications

extension Notification.Name {
    static let tunnelsSuccessfullyInstalled = Notification.Name("TunnelsSuccesfullyInstalled")
    static let onboardingCompleted = Notification.Name("OnboardingCompleted")
    static let userSignedIn = Notification.Name("UserSignedIn")
    static let paymentAccepted = Notification.Name("PaymentAccepted")
    static let emailConfirmed = Notification.Name("EmailConfirmed")
    static let signoutUser = Notification.Name("SignOutUser")
    static let signoutUserDuringOnboarding = Notification.Name("SignOutUserDuringOnboarding")
    static let openPreferences = Notification.Name("OpenPreferencesWindow")
    static let sameVersionOpened = Notification.Name("ConfirmedSameVersionIsOpened")
    static let switchingAPIVersions = Notification.Name("Switching API Versions")
}

extension NotificationCenter {
    static func post(name : NSNotification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }
}


