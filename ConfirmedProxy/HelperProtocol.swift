//
//  HelperProtocol.swift
//  MyApplication
//
//  Created by Erik Berglund on 2016-12-06.
//  Copyright © 2016 Erik Berglund. All rights reserved.
//

import Foundation

struct HelperConstants {
    static let machServiceName = "com.confirmed.ConfirmedProxy"
}

// Protocol to list all functions the main application can call in the helper
@objc(HelperProtocol)
protocol HelperProtocol {
    func getVersion(reply: @escaping (String) -> Void)
    
    func startConfirmedProxy(reply: @escaping (NSNumber) -> Void)
    func stopConfirmedProxy(reply: @escaping (NSNumber) -> Void)
    
}
