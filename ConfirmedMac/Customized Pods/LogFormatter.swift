//
//  LogFormatter.swift
//  Alamofire
//
//  Copyright © 2018 Confirmed, Inc. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

var logFileDataArray: [NSURL] {
    get {
        let logFilePaths = fileLogger.logFileManager.sortedLogFilePaths as! [String]
        var logFileDataArray = [NSURL]()
        for logFilePath in logFilePaths {
            let fileURL = NSURL(fileURLWithPath: logFilePath)
            if let logFileData = try? NSData(contentsOf: fileURL as URL, options: NSData.ReadingOptions.mappedIfSafe) {
                // Insert at front to reverse the order, so that oldest logs appear first.
                logFileDataArray.insert(fileURL, at: 0)
            }
        }
        return logFileDataArray
    }
}

class LogFormatter: DDDispatchQueueLogFormatter {
    let dateFormatter: DateFormatter
    
    override init() {
        dateFormatter = DateFormatter()
        dateFormatter.formatterBehavior = .behavior10_4
        dateFormatter.dateFormat = "HH:mm:ss"
        
        super.init()
    }
    
    override func format(message logMessage: DDLogMessage) -> String {
        let dateAndTime = dateFormatter.string(from: logMessage.timestamp)
        
        var logType = "LOG"
        switch logMessage.level {
        case .debug:
            logType = "DEBUG"
        case .error:
            logType = "ERROR"
        case .info:
            logType = "INFO"
        case .verbose:
            logType = "VERBOSE"
        case .warning:
            logType = "WARNING"
        default:
            logType = "LOG"
        }
        
        
        return "\(logType): \(dateAndTime) [\(logMessage.fileName):\(logMessage.line)]: \(logMessage.message)"
    }
}
