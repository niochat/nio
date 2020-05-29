import SwiftMatrixSDK

extension MXEvent {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    public func typed() throws -> NIOEventProtocol {
        switch self.eventType {
        case .roomName: throw MXEventValidationError.notYetImplemented
        case .roomTopic: throw MXEventValidationError.notYetImplemented
        case .roomAvatar: throw MXEventValidationError.notYetImplemented
        case .roomBotOptions: throw MXEventValidationError.notYetImplemented
        case .roomMember: throw MXEventValidationError.notYetImplemented
        case .roomCreate: throw MXEventValidationError.notYetImplemented
        case .roomJoinRules: throw MXEventValidationError.notYetImplemented
        case .roomPowerLevels: throw MXEventValidationError.notYetImplemented
        case .roomAliases: throw MXEventValidationError.notYetImplemented
        case .roomCanonicalAlias: throw MXEventValidationError.notYetImplemented
        case .roomEncrypted: throw MXEventValidationError.notYetImplemented
        case .roomEncryption: throw MXEventValidationError.notYetImplemented
        case .roomGuestAccess: throw MXEventValidationError.notYetImplemented
        case .roomHistoryVisibility: throw MXEventValidationError.notYetImplemented
        case .roomKey: throw MXEventValidationError.notYetImplemented
        case .roomForwardedKey: throw MXEventValidationError.notYetImplemented
        case .roomKeyRequest: throw MXEventValidationError.notYetImplemented
        case .roomMessage: throw MXEventValidationError.notYetImplemented
        case .roomMessageFeedback: throw MXEventValidationError.notYetImplemented
        case .roomPlumbing: throw MXEventValidationError.notYetImplemented
        case .roomRedaction: throw MXEventValidationError.notYetImplemented
        case .roomThirdPartyInvite: throw MXEventValidationError.notYetImplemented
        case .roomRelatedGroups: throw MXEventValidationError.notYetImplemented
        case .roomPinnedEvents: throw MXEventValidationError.notYetImplemented
        case .roomTag: throw MXEventValidationError.notYetImplemented
        case .presence: throw MXEventValidationError.notYetImplemented
        case .typingNotification: throw MXEventValidationError.notYetImplemented
        case .reaction: throw MXEventValidationError.notYetImplemented
        case .receipt: throw MXEventValidationError.notYetImplemented
        case .read: throw MXEventValidationError.notYetImplemented
        case .readMarker: throw MXEventValidationError.notYetImplemented
        case .callInvite: throw MXEventValidationError.notYetImplemented
        case .callCandidates: throw MXEventValidationError.notYetImplemented
        case .callAnswer: throw MXEventValidationError.notYetImplemented
        case .callHangup: throw MXEventValidationError.notYetImplemented
        case .sticker: throw MXEventValidationError.notYetImplemented
        case .roomTombStone: throw MXEventValidationError.notYetImplemented
        case .keyVerificationRequest: throw MXEventValidationError.notYetImplemented
        case .keyVerificationReady: throw MXEventValidationError.notYetImplemented
        case .keyVerificationStart: throw MXEventValidationError.notYetImplemented
        case .keyVerificationAccept: throw MXEventValidationError.notYetImplemented
        case .keyVerificationKey: throw MXEventValidationError.notYetImplemented
        case .keyVerificationMac: throw MXEventValidationError.notYetImplemented
        case .keyVerificationCancel: throw MXEventValidationError.notYetImplemented
        case .keyVerificationDone: throw MXEventValidationError.notYetImplemented
        case .secretRequest: throw MXEventValidationError.notYetImplemented
        case .secretSend: throw MXEventValidationError.notYetImplemented
        case _: throw MXEventValidationError.notYetImplemented
        }
    }

    public func typed<T>(as type: T.Type) throws -> T
    where
        T: MXEventInitializable & NIOEventProtocol
    {
        try T(event: self)
    }
}
