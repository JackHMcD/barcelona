//
//  GetMessagesAfter+Handler.swift
//  BarcelonaMautrixIPC
//
//  Created by Eric Rabil on 8/23/21.
//  Copyright © 2021 Eric Rabil. All rights reserved.
//

import Foundation
import Barcelona
import Logging

extension GetMessagesAfterCommand: Runnable, AuthenticatedAsserting {
    var log: Logging.Logger {
        Logger(label: "GetMessagesAfterCommand")
    }
    public func run(payload: IPCPayload, ipcChannel: MautrixIPCChannel) {
        log.debug("Getting messages for chat guid \(chat_guid) after time \(timestamp)")
        
        guard let chat = chat else {
            log.debug("Unknown chat with guid \(chat_guid)")
            return payload.fail(strategy: .chat_not_found, ipcChannel: ipcChannel)
        }
        
        let siblings = chat.siblings
        
        if let lastMessageTime = siblings.compactMap(\.lastMessage?.time?.timeIntervalSince1970).max(),
           lastMessageTime < timestamp {
            log.debug("Not processing get_messages_after because chats last message timestamp \(lastMessageTime) is before req.timestamp \(timestamp)")
            return payload.respond(.messages([]), ipcChannel: ipcChannel)
        }

        BLLoadChatItems(withChats: siblings.compactMap(\.chatIdentifier).map({ ($0, service) }), afterDate: date, limit: limit).then(\.blMessages).then {
            payload.respond(.messages($0), ipcChannel: ipcChannel)
        }
    }
}

extension GetRecentMessagesCommand: Runnable, AuthenticatedAsserting {
    public func run(payload: IPCPayload, ipcChannel: MautrixIPCChannel) {
        if MXFeatureFlags.shared.mergedChats, chat_guid.starts(with: "SMS;") {
            return payload.respond(.messages([]), ipcChannel: ipcChannel)
        }
        
        guard let chat = chat else {
            return payload.fail(strategy: .chat_not_found, ipcChannel: ipcChannel)
        }
        
        let siblings = chat.siblings

        BLLoadChatItems(withChats: siblings.compactMap(\.chatIdentifier).map({ ($0, service) }), limit: limit).then(\.blMessages).then {
            payload.respond(.messages($0), ipcChannel: ipcChannel)
        }
    }
}
