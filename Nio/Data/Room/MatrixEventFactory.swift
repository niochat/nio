import SwiftMatrixSDK

// Implementation heavily inspired by [Messagerie](https://github.com/manuroe/messagerie).

struct MatrixEventFactory {
    let session: MatrixSession

    func event(from event: MXEvent, direction: MXTimelineDirection, roomState: MXRoomState) -> MatrixEvent? {
        guard let eventId = event.eventId, let messageContent = self.content(from: event) else { return nil }

        let senderDisplayName = roomState.members.memberName(event.sender)
            ?? event.sender
            ?? L10n.Event.unknownSenderFallback
        let senderAvatar = roomState.members.member(withUserId: event.sender)?
            .avatarUrl
            .flatMap { self.session.mediaURL(for: $0, size: CGSize(width: 100, height: 100)) }

        return MatrixEvent(eventId: eventId,
                           sender: event.sender,
                           senderDisplayName: senderDisplayName,
                           senderAvatar: senderAvatar,
                           content: messageContent,
                           timestamp: event.timestamp)
    }

    private func content(from event: MXEvent) -> MatrixEvent.Content? {
        guard let type = event.type else { return nil }
        let eventType = MXEventType(identifier: type)

        switch eventType {
        case .roomMessage:
            guard let messageType = event.content["msgtype"] as? String else { return nil }
            return self.roomMessageContent(from: event, messageType: MXMessageType(identifier: messageType))
        default:
            return nil
        }
    }
}

extension MatrixEventFactory {
    private func roomMessageContent(from event: MXEvent, messageType: MXMessageType) -> MatrixEvent.Content? {
        switch messageType {
        case .text:
            // swiftlint:disable:next force_cast
            return .text(event.content["body"] as! String)
        case .image:
            guard let imageURL = (event.content["url"] as? String).flatMap({ session.mediaURL(for: $0) }) else {
                return nil
            }
            let info: [String: Any]? = event.content(valueFor: "info")

            let size: CGSize
            if let width = info?["w"] as? Int, let height = info?["h"] as? Int {
                size = CGSize(width: width, height: height)
            } else {
                size = CGSize()
            }
            return .image(url: imageURL, size: size)
        default:
            return nil
        }
    }
}
