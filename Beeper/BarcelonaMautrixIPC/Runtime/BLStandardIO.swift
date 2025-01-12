//
//  BLMautrixTask.swift
//  BarcelonaMautrixIPC
//
//  Created by Eric Rabil on 5/24/21.
//  Copyright © 2021 Eric Rabil. All rights reserved.
//

import Foundation
import CoreFoundation
import BarcelonaFoundation
import Barcelona
import Combine

public extension FileHandle {
    private static var threads: [FileHandle: Thread] = [:]
    private static var callbacks: [FileHandle: (Data) -> ()] = [:]
    private static var runLoops: [FileHandle: CFRunLoop] = [:]
    
    var dataCallback: (Data) -> () {
        get {
            Self.callbacks[self] ?? { _ in }
        }
        set {
            Self.callbacks[self] = newValue
        }
    }
    
    private var thread: Thread {
        if let thread = Self.threads[self] {
            return thread
        }
        
        let thread = Thread {
            Self.runLoops[self] = CFRunLoopGetCurrent()
            
            RunLoop.current.schedule {
                NotificationCenter.default.addObserver(forName: .NSFileHandleDataAvailable, object: self, queue: nil) { notif in
                    let handle = notif.object as! FileHandle
                    self.dataCallback(handle.availableData)
                    handle.waitForDataInBackgroundAndNotify()
                }
                self.waitForDataInBackgroundAndNotify()
            }
            
            RunLoop.current.run()
        }
        Self.threads[self] = thread
        
        return thread
    }
    
    func performOnThread(_ callback: @escaping () -> ()) {
        guard let runLoop = Self.runLoops[self] else {
            callback()
            return
        }
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue, callback)
        CFRunLoopWakeUp(runLoop)
    }
    
    func handleDataAsynchronously(_ cb: @escaping (Data) -> ()) {
        dataCallback = cb
        thread.start()
    }
}

extension FileHandle: MautrixIPCInputChannel {
    public func listen(_ cb: @escaping (Data) -> ()) {
        self.handleDataAsynchronously(cb)
    }
}

extension FileHandle: MautrixIPCOutputChannel {
    // FileHandle implements func write(_ data: Data) already.
}

extension Formatter {
    static let iso8601withFractionalSeconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSxxx"
        return formatter
    }()
}

extension JSONEncoder.DateEncodingStrategy {
    static let iso8601withFractionalSeconds = custom {
        var container = $1.singleValueContainer()
        try container.encode(Formatter.iso8601withFractionalSeconds.string(from: $0))
    }
}
