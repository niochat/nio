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
        @unknown default:
            assertionFailure("Unknown direction value")
        }
    }

    public func events() -> EventCollection {
        return EventCollection(eventCache + room.outgoingMessages())
    }

    // MARK: Sending Events

    public func send(text: String) async {
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
        
        await self.donateOutgoingIntent(text)
    }
    
    public func react(toEventId eventId: String, emoji: String) {
        // swiftlint:disable:next force_try
        let content = try! ReactionEvent(eventId: eventId, key: emoji).encodeContent()

        objectWillChange.send()             // room.outgoingMessages() will change
        var localEcho: MXEvent? = nil
        // TODO: async
        room.sendEvent(.reaction, content: content, localEcho: &localEcho) { _ in
            self.objectWillChange.send()    // localEcho.sentState has(!) changed
        }
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

        
        await self.donateOutgoingIntent()
    }

    public func markAllAsRead() {
        room.markAllAsRead()
    }

    public func removeOutgoingMessage(_ event: MXEvent) {
        objectWillChange.send()             // room.outgoingMessages() will change
        room.removeOutgoingMessage(event.eventId)
    }
    
    // intent
    private func donateOutgoingIntent(_ text: String? = nil) async {
        do {
            let recipients = try await self.room.members()?.inPerson
            
            let senderPersonHandle = INPersonHandle(value: room.mxSession.credentials.userId, type: .unknown)
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
