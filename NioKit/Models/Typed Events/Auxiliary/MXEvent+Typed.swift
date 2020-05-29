import SwiftMatrixSDK

extension MXEvent {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    public func typed() throws -> NIOEventProtocol? {
        switch self.eventType {
        case .roomName: return try NIORoomNameEvent(event: self)
        case .roomTopic: return try NIORoomTopicEvent(event: self)
        case .roomAvatar: return try NIORoomAvatarEvent(event: self)
        case .roomBotOptions: return nil
        case .roomMember: return nil
        case .roomCreate: return nil
        case .roomJoinRules: return nil
        case .roomPowerLevels: return nil
        case .roomAliases: return nil
        case .roomCanonicalAlias: return nil
        case .roomEncrypted: return nil
        case .roomEncryption: return nil
        case .roomGuestAccess: return nil
        case .roomHistoryVisibility: return nil
        case .roomKey: return nil
        case .roomForwardedKey: return nil
        case .roomKeyRequest: return nil
        case .roomMessage: return try NIORoomMessageEvent(event: self)
        case .roomMessageFeedback: return nil
        case .roomPlumbing: return nil
        case .roomRedaction: return nil
        case .roomThirdPartyInvite: return nil
        case .roomRelatedGroups: return nil
        case .roomPinnedEvents: return nil
        case .roomTag: return nil
        case .presence: return nil
        case .typingNotification: return nil
        case .reaction: return nil
        case .receipt: return nil
        case .read: return nil
        case .readMarker: return nil
        case .callInvite: return nil
        case .callCandidates: return nil
        case .callAnswer: return nil
        case .callHangup: return nil
        case .sticker: return nil
        case .roomTombStone: return nil
        case .keyVerificationRequest: return nil
        case .keyVerificationReady: return nil
        case .keyVerificationStart: return nil
        case .keyVerificationAccept: return nil
        case .keyVerificationKey: return nil
        case .keyVerificationMac: return nil
        case .keyVerificationCancel: return nil
        case .keyVerificationDone: return nil
        case .secretRequest: return nil
        case .secretSend: return nil
        case _: return nil
        }
    }

    public func typed<T>(as type: T.Type) throws -> T
    where
        T: MXEventInitializable & NIOEventProtocol
    {
        try T(event: self)
    }
}
