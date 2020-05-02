import Foundation

import SwiftMatrixSDK

public class RoomEventStore {
    private var eventsById: [String: MXEvent] = [:]

    public func add(event: MXEvent) {
        self.eventsById[event.eventId] = event

        switch event.eventType {
        case .roomName:
            break
        case .roomTopic:
            break
        case .roomAvatar:
            break
        case .roomMember:
            break
        case .roomCreate:
            break
        case .roomJoinRules:
            break
        case .roomPowerLevels:
            break
        case .roomAliases:
            break
        case .roomCanonicalAlias:
            break
        case .roomEncrypted:
            break
        case .roomEncryption:
            break
        case .roomGuestAccess:
            break
        case .roomHistoryVisibility:
            break
        case .roomKey:
            break
        case .roomForwardedKey:
            break
        case .roomKeyRequest:
            break
        case .roomMessage:
            break
        case .roomMessageFeedback:
            break
        case .roomRedaction:
            break
        case .roomThirdPartyInvite:
            break
        case .roomTag:
            break
        case .presence:
            break
        case .typing:
            break
        case .callInvite:
            break
        case .callCandidates:
            break
        case .callAnswer:
            break
        case .callHangup:
            break
        case .reaction:
            break
        case .receipt:
            break
        case .roomTombStone:
            break
        case .keyVerificationStart:
            break
        case .keyVerificationAccept:
            break
        case .keyVerificationKey:
            break
        case .keyVerificationMac:
            break
        case .keyVerificationCancel:
            break
        case .custom(String):
            break
        default:
            <#code#>
        }
    }

    public func add<S>(events: S) where S: Sequence, S.Element == MXEvent {

    }
}
