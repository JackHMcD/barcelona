//
//  IMDPersistence.swift
//  CoreBarcelona
//
//  Created by Eric Rabil on 1/29/21.
//  Copyright © 2021 Eric Rabil. All rights reserved.
//

import Foundation
import IMDPersistence
import BarcelonaDB
import IMCore
import IMSharedUtilities
import Logging

private let log = Logger(label: "IMDPersistenceQueries")

#if DEBUG
private var IMDWithinBlock = false

private let IMDQueue: DispatchQueue = {
    atexit {
        if IMDWithinBlock {
            log.warning("IMDPersistence tried to exit! Let's talk about that.")
        }
    }
    
    return DispatchQueue(label: "com.barcelona.IMDPersistence")
}()
#else
private let IMDQueue: DispatchQueue = DispatchQueue(label: "com.barcelona.IMDPersistence")
#endif

@_transparent
private func withinIMDQueue<R>(_ exp: @autoclosure() -> R) -> R {
    #if DEBUG
    IMDQueue.sync {
        IMDWithinBlock = true
        
        defer { IMDWithinBlock = false }
        
        return exp()
    }
    #else
    IMDQueue.sync(execute: exp)
    #endif
}

private let IMDCreateIMItemFromIMDMessageRecordRefWithServiceResolve_imp: (@convention(c) (Any?, Any?, Bool, Any?) -> Unmanaged<IMItem>?)? = CBWeakLink(against: .privateFramework(name: "IMDPersistence"), options: [
    .symbol("IMDCreateIMItemFromIMDMessageRecordRefWithServiceResolve").preMonterey,
    .symbol("IMDCreateIMItemFromIMDMessageRecordRefWithAccountLookup").monterey
])

// MARK: - IMDPersistence
private func BLCreateIMItemFromIMDMessageRecordRefs(_ refs: NSArray) -> [IMItem] {
    guard let IMDCreateIMItemFromIMDMessageRecordRefWithServiceResolve_imp = IMDCreateIMItemFromIMDMessageRecordRefWithServiceResolve_imp else {
        return []
    }
    
    #if DEBUG
    log.debug("converting \(refs.count) refs")
    #endif
    
    if refs.count == 0 {
        #if DEBUG
        log.debug("early-exit, zero refs")
        #endif
        return []
    }
    
    return refs.compactMap {
        withinIMDQueue(IMDCreateIMItemFromIMDMessageRecordRefWithServiceResolve_imp($0, nil, false, nil))?.takeRetainedValue()
    }
}

/// Loads an array of IMDMessageRecordRefs from IMDPersistence
/// - Parameter guids: guids of the messages to load
/// - Returns: an array of the IMDMessageRecordRefs
private func BLLoadIMDMessageRecordRefsWithGUIDs(_ guids: [String]) -> NSArray {
    #if DEBUG
    log.debug("loading \(guids.count) guids")
    #endif
    
    if guids.count == 0 {
        #if DEBUG
        log.debug("early-exit: 0 guids provided")
        #endif
        return []
    }
    
    guard let results = withinIMDQueue(IMDMessageRecordCopyMessagesForGUIDs(guids as CFArray)) else {
        #if DEBUG
        log.debug("could not copy messages from IMDPersistance. guids: \(guids)")
        #endif
        return []
    }
    
    #if DEBUG
    log.debug("loaded \(guids.count) guids")
    #endif
    
    return results as NSArray
}

// MARK: - Helpers
private func ERCreateIMMessageFromIMItem(_ items: [IMItem]) -> [IMMessage] {
    #if DEBUG
    log.debug("converting \(items.count) IMItems to IMMessage")
    #endif
    
    guard items.count > 0 else {
        #if DEBUG
        log.debug("early-exit: empty array passed for conversion")
        #endif
        return []
    }
    
    let items = items.compactMap {
        $0 as? IMMessageItem
    }
    
    guard items.count > 0 else {
        #if DEBUG
        log.debug("early-exit: no IMMessageItem found")
        #endif
        return []
    }
    
    let messages = items.compactMap {
        IMMessage.message(fromUnloadedItem: $0)
    }
    
    #if DEBUG
    log.debug("loaded \(messages.count) IMMessages from \(items.count) items")
    #endif
    
    return messages
}

private func BLCreateIMMessageFromIMDMessageRecordRefs(_ refs: NSArray) -> [IMMessage] {
    ERCreateIMMessageFromIMItem(BLCreateIMItemFromIMDMessageRecordRefs(refs))
}

// MARK: - Private API

/// Parses an array of IMDMessageRecordRef
/// - Parameters:
///   - refs: the refs to parse
///   - chat: the ID of the chat the messages reside in. if omitted, the chat ID will be resolved at ingestion
/// - Returns: An NIO future of ChatItems
private func BLIngestIMDMessageRecordRefs(_ refs: NSArray, in chat: String? = nil, service: IMServiceStyle) -> Promise<[ChatItem]> {
    if refs.count == 0 {
        return .success([])
    }
    
    var items = BLCreateIMItemFromIMDMessageRecordRefs(refs)
    
    return BLIngestObjects(items, inChat: chat, service: service)
}

internal func ERResolveGUIDsForChats(withChatIdentifiers chatIdentifiers: [String], afterDate: Date? = nil, beforeDate: Date? = nil, afterGUID: String? = nil, beforeGUID: String? = nil, limit: Int? = nil) -> Promise<[(messageID: String, chatID: String)]> {
    #if DEBUG
    log.debug("Resolving GUIDs for chat \(chatIdentifiers) before time \((beforeDate?.timeIntervalSince1970 ?? 0).description) before guid \( beforeGUID ?? "(nil)") limit \((limit ?? -1).description)")
    #endif
    
    let result = DBReader.shared.newestMessageGUIDs(forChatIdentifiers: chatIdentifiers, beforeDate: beforeDate, afterDate: afterDate, beforeMessageGUID: beforeGUID, afterMessageGUID: afterGUID, limit: limit)
    #if DEBUG
    result.observeAlways { result in
        switch result {
        case .success(let GUIDs):
            log.debug("Got \(GUIDs.count) GUIDs")
        case .failure(let error):
            log.debug("Failed to load newest GUIDs: \(error as NSError)")
        }
    }
    #endif
    return result
}

// MARK: - API

public func BLLoadIMMessageItems(withGUIDs guids: [String]) -> [IMMessageItem] {
    if guids.count == 0 {
        return []
    }
    
    return autoreleasepool {
        BLCreateIMItemFromIMDMessageRecordRefs(BLLoadIMDMessageRecordRefsWithGUIDs(guids)).compactMap {
            $0 as? IMMessageItem
        }
    }
}

public func BLLoadIMMessageItem(withGUID guid: String) -> IMMessageItem? {
    BLLoadIMMessageItems(withGUIDs: [guid]).first
}

public func BLLoadIMMessages(withGUIDs guids: [String]) -> [IMMessage] {
    BLLoadIMMessageItems(withGUIDs: guids).compactMap(IMMessage.message(fromUnloadedItem:))
}

public func BLLoadIMMessage(withGUID guid: String) -> IMMessage? {
    BLLoadIMMessages(withGUIDs: [guid]).first
}

/// Resolves ChatItems with the given GUIDs
/// - Parameters:
///   - guids: GUIDs of messages to load
///   - chat: ID of the chat to load. if omitted, it will be resolved at ingestion.
/// - Returns: NIO future of ChatItems
public func BLLoadChatItems(withGUIDs guids: [String], chatID: String? = nil, service: IMServiceStyle) -> Promise<[ChatItem]> {
    if guids.count == 0 {
        return .success([])
    }
    
    let (buffer, remaining) = IMDPersistenceMarshal.partialBuffer(guids)

    guard let guids = remaining else {
        return buffer
    }
    
    let refs = BLLoadIMDMessageRecordRefsWithGUIDs(guids)
    
    return IMDPersistenceMarshal.putBuffers(guids, BLIngestIMDMessageRecordRefs(refs, in: chatID, service: service)) + buffer
}

public func BLLoadChatItems(withGraph graph: [String: ([String], IMServiceStyle)]) -> Promise<[ChatItem]> {
    if graph.count == 0 {
        return .success([])
    }
    
    let guids = graph.values.flatMap(\.0)
    let (buffer, remaining) = IMDPersistenceMarshal.partialBuffer(guids)
    
    guard let guids = remaining else {
        return buffer
    }
    
    let refs = BLCreateIMItemFromIMDMessageRecordRefs(BLLoadIMDMessageRecordRefsWithGUIDs(guids))
    let items = refs.dictionary(keyedBy: \.id)

    let pendingIngestion = Promise.all(graph.mapValues { (guids, service) in
        (guids.compactMap { items[$0] }, service)
    }.map { chatID, properties -> Promise<[ChatItem]> in
        let (items, service) = properties
        return BLIngestObjects(items, inChat: chatID, service: service)
    }).flatten()
    
    return IMDPersistenceMarshal.putBuffers(guids, pendingIngestion) + buffer
}

/// Resolves ChatItems with the given parameters
/// - Parameters:
///   - chatIdentifier: identifier of the chat to load messages from
///   - services: chat services to load messages from
///   - beforeGUID: GUID of the message all messages must precede
///   - limit: max number of messages to return
/// - Returns: NIO future of ChatItems
public func BLLoadChatItems(withChats chats: [(id: String, service: IMServiceStyle)], afterDate: Date? = nil, beforeDate: Date? = nil, afterGUID: String? = nil, beforeGUID: String? = nil, limit: Int? = nil) -> Promise<[ChatItem]> {
    // We turn the list of chats into just a list of chatIdentifiers
    let chatIdentifiers = chats.map(\.0)

    // Then we load the messages in those chats with the specified guid bounds
    return ERResolveGUIDsForChats(withChatIdentifiers: chatIdentifiers, afterDate: afterDate, beforeDate: beforeDate, afterGUID: afterGUID, beforeGUID: beforeGUID, limit: limit).then { messages in

        // Once we've got the messages, we turn them into the graph form that the other function wants
        let graph = messages.reduce(into: [String: ([String], IMServiceStyle)]()) { dict, value in
            // We get the chat that this one relates to so that we can grab its service
            if let chat = chats.first(where: { $0.id == value.chatID }) {
                // Then, if it's new to the dictionary, we just insert it
                if dict[chat.id] == nil {
                    dict[chat.id] = ([value.messageID], chat.service)
                } else {
                    // Else, we append it to what's already there
                    // And we have to do the nasty `.0.0` thing because subscript can return a (K, V) tuple,
                    // and swift is inferring that's what we wnat here, so we have to grab the value from the
                    // tuple that it returns, then append to the first item in that tuple.
                    dict[chat.id]?.0.append(value.messageID)
                }
            }
        }
        return BLLoadChatItems(withGraph: graph)
    }
}

typealias IMFileTransferFromIMDAttachmentRecordRefType = @convention(c) (_ record: Any) -> IMFileTransfer?

private let IMDaemonCore = "/System/Library/PrivateFrameworks/IMDaemonCore.framework/IMDaemonCore".withCString({
    dlopen($0, RTLD_LAZY)
})!

private let _IMFileTransferFromIMDAttachmentRecordRef = "IMFileTransferFromIMDAttachmentRecordRef".withCString ({ dlsym(IMDaemonCore, $0) })
private let IMFileTransferFromIMDAttachmentRecordRef = unsafeBitCast(_IMFileTransferFromIMDAttachmentRecordRef, to: IMFileTransferFromIMDAttachmentRecordRefType.self)

public func BLLoadFileTransfer(withGUID guid: String) -> IMFileTransfer? {
    guard let attachment = IMDAttachmentRecordCopyAttachmentForGUID(guid as CFString) else {
        return nil
    }
    
    return IMFileTransferFromIMDAttachmentRecordRef(attachment)
}

public func BLLoadAttachmentPathForTransfer(withGUID guid: String) -> String? {
    BLLoadFileTransfer(withGUID: guid)?.localPath
}
