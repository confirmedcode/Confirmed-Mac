//
//  ContentBlockerRequestHandler.swift
//  Confirmed Blocker
//
//  Copyright © 2018 Confirmed, Inc. All rights reserved.
//

import Foundation

class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {

    func attachmentForSettings() -> NSItemProvider {
        var blockArray = [] as? Array<String>
        
        if let defaults = UserDefaults(suiteName: "group.com.confirmed.tunnelsMac") {
            if defaults.object(forKey: "AdBlockingEnabled") != nil {
                if defaults.bool(forKey: "AdBlockingEnabled") {
                    blockArray?.append("adBlockList")
                    blockArray?.append("adBlockListTwo")
                    //blockArray?.append("adBlockListThree")
                }
            }
            else { //include if key is not initialized
                blockArray?.append("adBlockList")
                blockArray?.append("adBlockListTwo")
                //blockArray?.append("adBlockListThree")
            }
            
            if defaults.object(forKey: "PrivacyBlockingEnabled") != nil {
                if defaults.bool(forKey: "PrivacyBlockingEnabled") {
                    blockArray?.append("privacyBlockList")
                }
            }
            else { //include if key is not initialized
                blockArray?.append("privacyBlockList")
            }
            
            if defaults.object(forKey: "SocialBlockingEnabled") != nil {
                if defaults.bool(forKey: "SocialBlockingEnabled") {
                    blockArray?.append("socialBlockList")
                }
            }
            else { //include if key is not initialized
                blockArray?.append("socialBlockList")
            }
        }
        
        var finalList = [NSDictionary]()
        
        for blockerList in blockArray! {
            let data = try! Data(contentsOf: Bundle.main.url(forResource: blockerList, withExtension: "json")!)
            var obj = try! JSONSerialization.jsonObject(with: data, options: []) as! [NSDictionary]
            finalList.append(contentsOf: obj)
        }
        
        let finalListJSON = try! JSONSerialization.data(withJSONObject: finalList, options: JSONSerialization.WritingOptions(rawValue: 0))
        let attachment = NSItemProvider(item: finalListJSON as NSSecureCoding?, typeIdentifier: kUTTypeJSON as String)
        //let attachment = NSItemProvider(contentsOf: Bundle.main.url(forResource: "adBlockList", withExtension: "json"))!
        
        return attachment
    }
    
    func beginRequest(with context: NSExtensionContext) {
        
        //let attachment = NSItemProvider(contentsOf: Bundle.main.url(forResource: "adBlockListThree", withExtension: "json"))!
        
        let item = NSExtensionItem()
        item.attachments = [attachmentForSettings()]
        
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }
    
}
