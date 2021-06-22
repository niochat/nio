import Foundation
import Combine

import MatrixSDK

import os
import Intents
import CoreSpotlight
import CoreServices

public struct RoomItem: Codable, Hashable {
    public static func == (lhs: RoomItem, rhs: RoomItem) -> Bool {
        return lhs.displayName == rhs.displayName &&
          lhs.roomId == rhs.roomId
    }

    public let roomId: String
    public let displayName: String
    public let messageDate: UInt64

    public init(room: MXRoom) {
        self.roomId = room.summary.roomId
        self.displayName = room.summary.displayname ?? ""
        self.messageDate = room.summary.lastMessageOriginServerTs
    }
}

@MainActor
public class NIORoom: ObservableObject {
    static let logger = Logger(subsystem: "chat.nio", category: "ROOM")
    
    public let room: MXRoom

    @Published
    public var summary: NIORoomSummary

    @Published
    internal var eventCache: [MXEvent] = []

    // MARK: - computed vars
    public var isDirect: Bool {
        room.isDirect
    }

    public var isEncrypted: Bool {
        room.summary.isEncrypted
    }

    public var displayName: String {
        room.summary.displayname
    }

    public var avatarUrl: URL? {
        get {
            guard let avatar = (self.room.summary.avatar ?? nil) else {
                return nil
            }

            if avatar.starts(with: "http") {
                return URL(string: avatar)
            }

            return URL(string: self.room.mxSession.mediaManager.url(ofContent: avatar))
        }
    }

    public var lastMessage: String {
        if summary.membership == .invite {
            let inviteEvent = eventCache.last {
                $0.type == kMXEventTypeStringRoomMember && $0.stateKey == room.mxSession.myUserId
            }
            guard let sender = inviteEvent?.sender else { return "" }
            return "Invitation from: \(sender)"
        }

        let lastMessageEvent = eventCache.last {
            $0.type == kMXEventTypeStringRoomMessage
        }
        if lastMessageEvent?.isEdit() ?? false {
            let newContent = lastMessageEvent?.content["m.new_content"]! as? NSDictionary
            return newContent?["body"] as? String ?? ""
        } else {
            return lastMessageEvent?.content["body"] as? String ?? ""
        }
    }

    // MARK: - init
    public init(_ room: MXRoom) {
        self.room = room
        self.summary = NIORoomSummary(room.summary)

        let enumerator = room.enumeratorForStoredMessages//WithType(in: Self.displayedMessageTypes)
        let currentBatch = enumerator?.nextEventsBatch(200) ?? []
        print("Got \(currentBatch.count) events.")

        self.eventCache.append(contentsOf: currentBatch)
    }

    public func add(event: MXEvent, direction: MXTimelineDirection, roomState: MXRoomState?) {
        print("New event of type: \(event.type!)")

        switch direction {
        case .backwards:
            self.eventCache.insert(event, at: 0)
        case .forwards:
            self.eventCache.append(event)
            self.donateNotification(event: event)
        @unknown default:
            assertionFailure("Unknown direction value")
        }
    }
    
    @available(*, deprecated, message: "Prefer `createNotification` to create an intent and donate that response")
    public func donateNotification(event: MXEvent) {
        guard event.type == "m.room.message" else {
            return
        }
        if event.timestamp.distance(to: Date()) >= -100 {
            print("skipping? \(String(describing: event.eventId))")
            return
        }
        async {
            do {
                let intent = try await self.createIntent(event: event)
                let interaction = try await self.createNotification(event: event, messageIntent: intent)
            
                try await interaction.donate()
            } catch {
                Self.logger.warning("could not donate intent for add: \(error.localizedDescription)")
            }
        }
    }
    
    public func createIntent(event: MXEvent) async throws -> INSendMessageIntent {
        let members = try await self.room.members()?.members ?? []
        //let recipients = await  members.filter({ $0.userId != event.sender }).map({ $0.inPerson })
        var recipients: [INPerson] = []
        for recipient in members.filter({ $0.userId != event.sender}) {
            recipients.append( await recipient.inPerson(isMe: recipient.userId == AccountStore.shared.credentials?.userId ))
        }
        
        print("sender")
        //let sender = await members.filter({ $0.userId == event.sender }).first?.inPerson
        let senderMember = members.filter({ $0.userId == event.sender }).first
        let sender = await senderMember?.inPerson()
        
        let body = event.content["body"] as? String
        
        let messageIntent = INSendMessageIntent(
            recipients: recipients,
            outgoingMessageType: .outgoingMessageText,
            content: body,
            speakableGroupName: self.isDirect ? nil : INSpeakableString(spokenPhrase: room.summary.displayname),
            conversationIdentifier: room.id.id,
            serviceName: "matrix",
            sender: sender,
            attachments: nil)
        
        return messageIntent
    }
    
    public func createNotification(event: MXEvent, messageIntent: INSendMessageIntent) async throws -> INInteraction {
        guard let selfId = AccountStore.shared.credentials?.userId else {
            throw AccountStoreError.noCredentials
        }
        let isMe = event.sender == selfId
        
        let userActivity = NSUserActivity(activityType: "chat.nio.chat")
        userActivity.isEligibleForHandoff = true
        userActivity.isEligibleForSearch = true
        userActivity.isEligibleForPrediction = true
        userActivity.title = self.displayName
        userActivity.userInfo = ["id": self.id.rawValue as String]
        
        let attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
        
        attributes.contentDescription = "Open chat with \(self.displayName)"
        attributes.instantMessageAddresses = [ self.room.roomId ]
        userActivity.contentAttributeSet = attributes
        userActivity.webpageURL = URL(string: "https://matrix.to/#/\(self.room.roomId ?? "")")
        
        let response = INSendMessageIntentResponse(code: .success, userActivity: userActivity)
        let interaction = INInteraction(intent: messageIntent, response: response)
        // TODO: remove?
        interaction.direction = isMe ? INInteractionDirection.outgoing : INInteractionDirection.incoming
        interaction.dateInterval = DateInterval(start: event.timestamp, duration: 0)
        return interaction
    }

    public func events() -> EventCollection {
        return EventCollection(eventCache + room.outgoingMessages())
    }

    // MARK: Sending Events

    public func send(text: String, publishIntent: Bool = true) async {
        guard !text.isEmpty else { return }

        objectWillChange.send()             // room.outgoingMessages() will change
        var localEcho: MXEvent? = nil
        do {
            try await room.sendTextMessage(text, localEcho: &localEcho)
        } catch {
            Self.logger.warning("could not send text message to \(self.displayName): \(error.localizedDescription)")
        }
        // localEcho.sentState has(!) changed
        self.objectWillChange.send()
        
        if publishIntent {
            guard let localEcho = localEcho else {
                return
            }
            do {
                let messageIntent = try await createIntent(event: localEcho)
                let intent = try await createNotification(event: localEcho, messageIntent: messageIntent)
                intent.direction = .outgoing
                if !self.isDirect {
                    intent.groupIdentifier = localEcho.roomId
                }
                try await intent.donate()
            } catch {
                Self.logger.warning("could not donate text message to \(self.displayName): \(error.localizedDescription)")
            }
        }
    }
    
    public func react(toEvent event: MXEvent.MXEventId, emoji: String) async {
        let content = try! ReactionEvent(eventId: event.id, key: emoji).encodeContent()
        
        await self.sendEvent(.reaction, content: content)
    }
    
    @available(*, deprecated, message: "Prefer MXEvent.MXEventId methode")
    public func react(toEventId eventId: String, emoji: String) {
        async {
            await self.react(toEvent: MXEvent.MXEventId(eventId), emoji: emoji)
        }
    }
    
    public func sendEvent(_ eventType: MXEventType, content: [String: Any]) async {
        var localEcho: MXEvent?
        
        do {
            try await room.sendEvent(eventType, content: content, localEcho: &localEcho)
        } catch {
            Self.logger.warning("could not send \(eventType.identifier): \(error.localizedDescription)")
        }
        self.objectWillChange.send()
    }

    public func edit(text: String, eventId: String) {
        guard !text.isEmpty else { return }

        var localEcho: MXEvent? = nil
        // swiftlint:disable:next force_try
        let content = try! EditEvent(eventId: eventId, text: text).encodeContent()
        // TODO: Use localEcho to show sent message until it actually comes back
        // TODO: async
        room.sendMessage(withContent: content, localEcho: &localEcho) { _ in }
    }

    public func redact(eventId: String, reason: String?) {
        // TODO: async
        room.redactEvent(eventId, reason: reason) { _ in }
    }

    public func sendImage(image: UXImage) async {
        guard let imageData = image.jpeg(.lowest) else { return }

        var localEcho: MXEvent? = nil
        objectWillChange.send()             // room.outgoingMessages() will change
        do {
            try await room.sendImage(
                data: imageData,
                size: image.size,
                mimeType: "image/jpeg",
                thumbnail: image,
                localEcho: &localEcho)
        } catch {
            Self.logger.warning("could not send image to \(self.displayName): \(error.localizedDescription)")
        }
        // localEcho.sentState has(!) changed
        self.objectWillChange.send()

        guard let localEcho = localEcho else {
            return
        }
        do {
            let messageIntent = try await createIntent(event: localEcho)
            let intent = try await createNotification(event: localEcho, messageIntent: messageIntent)
            intent.direction = .outgoing
            if !self.isDirect {
                intent.groupIdentifier = localEcho.roomId
            }
            try await intent.donate()
        } catch {
            Self.logger.warning("could not donate image message to \(self.displayName): \(error.localizedDescription)")
        }
    }
    
    public func createReply(toEventId eventId: MXEvent.MXEventId, text: String, htmlText: String? = nil) async throws -> [String : Any] {
        let event = try await AccountStore.shared.session?.event(withEventId: eventId, inRoom: self.id)
        
        guard let event = event else {
            throw AccountStoreError.noSessionOpened
        }
        
        return try self.createReply(toEvent: event, text: text, htmlText: htmlText)
    }
    
    public func createReply(toEvent event: MXEvent, text: String, htmlText: String? = nil) throws -> [String: Any] {
        return try event.createReply(text: text, htmlText: htmlText).encodeContent()
    }

    public func markAllAsRead() {
        room.markAllAsRead()
    }

    public func removeOutgoingMessage(_ event: MXEvent) {
        objectWillChange.send()             // room.outgoingMessages() will change
        room.removeOutgoingMessage(event.eventId)
    }
    
    // intent
    @available(*, deprecated, message: "Prefer `createNotification` to create an intent and donate that response")
    private func donateOutgoingIntent(_ text: String? = nil) async {
        do {
            let senderId = room.mxSession.credentials.userId
            //let recipients = try await self.room.members()?.members.filter({ $0.userId != senderId }).map({$0.inPerson})
            let members = try await self.room.members()?.members.filter({ $0.userId != senderId }) ?? []
            var recipients: [INPerson] = []
            for recipient in members {
                recipients.append( await recipient.inPerson)
            }
            
            let senderPersonHandle = INPersonHandle(value: senderId, type: .unknown)
            let sender = INPerson(
                personHandle: senderPersonHandle,
                nameComponents: nil,
                displayName: nil,
                image: nil,
                contactIdentifier: nil,
                customIdentifier: room.mxSession.credentials.userId,
                isMe: true,
                suggestionType: .instantMessageAddress)
            
            let messageIntent = INSendMessageIntent(
                recipients: recipients,
                outgoingMessageType: .outgoingMessageText,
                content: text,
                speakableGroupName: INSpeakableString(spokenPhrase: room.summary.displayname),
                conversationIdentifier: room.roomId,
                serviceName: "matrix",
                sender: sender,
                attachments: nil)
            
            let userActivity = NSUserActivity(activityType: "chat.nio.chat")
            userActivity.isEligibleForHandoff = true
            userActivity.isEligibleForSearch = true
            userActivity.isEligibleForPrediction = true
            userActivity.title = self.displayName
            userActivity.userInfo = ["id": self.id.rawValue as String]
            
            let attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
            
            attributes.contentDescription = "Open chat with \(self.displayName)"
            attributes.instantMessageAddresses = [ self.room.roomId ]
            userActivity.contentAttributeSet = attributes
            userActivity.webpageURL = URL(string: "https://matrix.to/#/\(self.room.roomId ?? "")")
            let response = INSendMessageIntentResponse(code: .success, userActivity: userActivity)
            
            let intent = INInteraction(intent: messageIntent, response: response)
            intent.direction = .outgoing
            //intent.intentHandlingStatus = .success
            try await intent.donate()
        } catch {
            Self.logger.warning("Could not donate intent: \(error.localizedDescription)")
        }
    }
    
    //private var lastPaginatedEvent: MXEvent?
    private var timeline: MXEventTimeline?
    
    public func paginate(_ event: MXEvent, direction: MXTimelineDirection = .backwards, numItems: UInt = 40) async {
        /*guard event != lastPaginatedEvent else {
            return
        }*/
        
        if timeline == nil {
            return await createPagination()
            /*Self.logger.debug("creating timeline for room '\(self.displayName)' with event '\(event.eventId)'")
            //lastPaginatedEvent = event
            timeline = room.timeline(onEvent: event.eventId)
            let _ = timeline?.listenToEvents {
                event, direction, roomState in
                if direction == .backwards {
                    // eventCache is published, so no objectWillChanges.send here
                    self.add(event: event, direction: direction, roomState: roomState)
                }
            }
            timeline?.resetPagination()*/
        }
        
        if timeline?.canPaginate(direction) ?? false {
            do {
                try await timeline?.paginate(numItems, direction: direction, onlyFromStore: false)
            } catch {
                Self.logger.warning("could not paginate: \(error.localizedDescription)")
            }
        } else {
            Self.logger.debug("cannot paginate: \(self.displayName)")
        }
    }
    
    public func createPagination() async {
        guard timeline == nil else {
            return
        }
        Self.logger.debug("Bootstraping pagination")
        
        timeline = await room.liveTimeline
        timeline?.resetPagination()
        if timeline?.canPaginate(.backwards) ?? false {
            do {
                try await timeline?.paginate(40, direction: .backwards)
            } catch {
                Self.logger.warning("could not bootstrap pagination: \(error.localizedDescription)")
            }
        } else {
            Self.logger.warning("could not bootstrap pagination")
        }
    }
    
    public func findEvent(id: MXEvent.MXEventId) -> MXEvent? {
        self.eventCache.filter({ $0.id == id }).first
    }
}

extension NIORoom: Identifiable {
    public nonisolated var id: MXRoom.MXRoomId {
        room.id
    }
}

extension UXImage {
    public enum JPEGQuality: CGFloat {
        case lowest  = 0
        case low     = 0.25
        case medium  = 0.5
        case high    = 0.75
        case highest = 1
    }

    public func jpeg(_ jpegQuality: JPEGQuality) -> Data? {
        #if os(macOS)
            return tiffRepresentation(using  : .jpeg,
                                      factor : Float(jpegQuality.rawValue))
        #else
            return jpegData(compressionQuality: jpegQuality.rawValue)
        #endif
    }
}
