//
//  SendMediaMessageCommand+Handler.swift
//  BarcelonaFoundation
//
//  Created by Eric Rabil on 8/23/21.
//  Copyright © 2021 Eric Rabil. All rights reserved.
//

import Foundation
import Barcelona
import IMCore
import Sentry
import Logging

protocol Runnable {
    func run(payload: IPCPayload, ipcChannel: MautrixIPCChannel)
}

protocol AuthenticatedAsserting {}

extension SendMediaMessageCommand: Runnable, AuthenticatedAsserting {
    var log: Logging.Logger {
        Logger(label: "SendMediaMessageCommand")
    }
    public func run(payload: IPCPayload, ipcChannel: MautrixIPCChannel) {
        guard let chat = cbChat, let imChat = chat.imChat else {
            return payload.fail(strategy: .chat_not_found, ipcChannel: ipcChannel)
        }

        let transfer = CBInitializeFileTransfer(filename: file_name, path: URL(fileURLWithPath: path_on_disk))
        guard let guid = transfer.guid else {
            return payload.fail(strategy: .internal_error("created transfer was not assigned a guid!!!"), ipcChannel: ipcChannel)
        }
        var messageCreation = CreateMessage(parts: [
            .init(type: .attachment, details: guid)
        ])
        messageCreation.metadata = metadata
        
        if CBFeatureFlags.permitAudioOverMautrix && is_audio_message == true {
            messageCreation.isAudioMessage = true
        }
        
        do {
            var monitor: BLMediaMessageMonitor?, message: IMMessage?
            
            func resolveMessageService() -> String {
                if let message = message {
                    if let item = message._imMessageItem {
                        return item.service
                    }
                    if message.wasDowngraded {
                        return "SMS"
                    }
                }
                if imChat.isDowngraded() {
                    return "SMS"
                }
                return imChat.account.serviceName
            }
            
            monitor = BLMediaMessageMonitor(messageID: message?.id ?? "", transferGUIDs: [guid]) { success, failureCode, shouldCancel in
                guard let message = message else {
                    return
                }
                if !success && shouldCancel {
                    let chatGuid = imChat.blChatGUID
                    ipcChannel.writePayload(.init(command: .send_message_status(.init(guid: message.id, chatGUID: chatGuid, status: .failed, service: resolveMessageService(), message: failureCode?.localizedDescription, statusCode: failureCode?.description))))
                }
                if !success && shouldCancel {
                    imChat.cancel(message)
                }
                
                withExtendedLifetime(monitor) { monitor = nil }
            }
            
            message = try chat.sendReturningRaw(message: messageCreation)
            
            payload.reply(withResponse: .message_receipt(BLPartialMessage(guid: message!.id, service: resolveMessageService(), timestamp: Date().timeIntervalSinceNow)), ipcChannel: ipcChannel)
        } catch {
            log.error("failed to send media message: \(error as NSError)", source: "BLMautrix")
            payload.fail(code: "internal_error", message: "Sorry, we're having trouble processing your attachment upload.", ipcChannel: ipcChannel)
        }
    }
}
