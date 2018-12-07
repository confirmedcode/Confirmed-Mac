//
//  LaunchAtLogin.swift
//  Tunnels
//
//  Copyright © 2018 Confirmed, Inc. All rights reserved.
//  Credit: https://github.com/sindresorhus/LaunchAtLogin
//

import Cocoa

final class LaunchAtLogin: NSObject {
    
    class var isAppLoginItem: Bool {
        return itemReferencesInLoginItems.existingReference != nil
    }
    
    private class var itemReferencesInLoginItems: (existingReference: LSSharedFileListItem?, lastReference: LSSharedFileListItem?) {
        
        if let loginItemsRef = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil).takeRetainedValue() as LSSharedFileList? {
            let loginItems = LSSharedFileListCopySnapshot(loginItemsRef, nil).takeRetainedValue() as NSArray as! [LSSharedFileListItem]
            if loginItems.count > 0 {
                
                let appUrl = URL(fileURLWithPath: Bundle.main.bundlePath)
                let itemUrl = UnsafeMutablePointer<Unmanaged<CFURL>?>.allocate(capacity: 1)
                defer { itemUrl.deallocate(capacity: 1) }
                
                for i in loginItems {
                    if let itemUrl = LSSharedFileListItemCopyResolvedURL(i, 0, nil), itemUrl.takeRetainedValue() as URL == appUrl {
                        return (i, loginItems.last)
                    }
                }
                return (nil, loginItems.last)
            } else {
                return(nil, kLSSharedFileListItemBeforeFirst.takeRetainedValue())
            }
        }
        return (nil, nil)
    }
    
    class func setLaunchOnLogin(_ launch: Bool) {
        
        let itemReferences = itemReferencesInLoginItems
        let isSet = itemReferences.existingReference != nil
        let type = kLSSharedFileListSessionLoginItems.takeUnretainedValue()
        if let loginItemsRef = LSSharedFileListCreate(nil, type, nil).takeRetainedValue() as LSSharedFileList? {
            if launch && !isSet {
                let appUrl = URL(fileURLWithPath: Bundle.main.bundlePath) as CFURL
                LSSharedFileListInsertItemURL(loginItemsRef, itemReferences.lastReference, nil, nil, appUrl, nil, nil)
            } else if !launch && isSet, let itemRef = itemReferences.existingReference {
                LSSharedFileListItemRemove(loginItemsRef, itemRef)
            }
        }
    }
    
}
