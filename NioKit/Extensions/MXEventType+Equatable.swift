import Foundation
import SwiftMatrixSDK

// TODO: Remove, once
// https://github.com/matrix-org/matrix-ios-sdk/pull/755
// has been merged or the lack of `Equatable` been resolved upstream.
extension MXEventType: Equatable {
    // swiftlint:disable:next cyclomatic_complexity
    public static func == (lhs: MXEventType, rhs: MXEventType) -> Bool {
        switch (lhs, rhs) {
        case (.roomName, .roomName): return true
        case (.roomTopic, .roomTopic): return true
        case (.roomAvatar, .roomAvatar): return true
        case (.roomMember, .roomMember): return true
        case (.roomCreate, .roomCreate): return true
        case (.roomJoinRules, .roomJoinRules): return true
        case (.roomPowerLevels, .roomPowerLevels): return true
        case (.roomAliases, .roomAliases): return true
        case (.roomCanonicalAlias, .roomCanonicalAlias): return true
        case (.roomEncrypted, .roomEncrypted): return true
        case (.roomEncryption, .roomEncryption): return true
        case (.roomGuestAccess, .roomGuestAccess): return true
        case (.roomHistoryVisibility, .roomHistoryVisibility): return true
        case (.roomKey, .roomKey): return true
        case (.roomForwardedKey, .roomForwardedKey): return true
        case (.roomKeyRequest, .roomKeyRequest): return true
        case (.roomMessage, .roomMessage): return true
        case (.roomMessageFeedback, .roomMessageFeedback): return true
        case (.roomRedaction, .roomRedaction): return true
        case (.roomThirdPartyInvite, .roomThirdPartyInvite): return true
        case (.roomTag, .roomTag): return true
        case (.presence, .presence): return true
        case (.typing, .typing): return true
        case (.callInvite, .callInvite): return true
        case (.callCandidates, .callCandidates): return true
        case (.callAnswer, .callAnswer): return true
        case (.callHangup, .callHangup): return true
        case (.reaction, .reaction): return true
        case (.receipt, .receipt): return true
        case (.roomTombStone, .roomTombStone): return true
        case (.keyVerificationStart, .keyVerificationStart): return true
        case (.keyVerificationAccept, .keyVerificationAccept): return true
        case (.keyVerificationKey, .keyVerificationKey): return true
        case (.keyVerificationMac, .keyVerificationMac): return true
        case (.keyVerificationCancel, .keyVerificationCancel): return true
        default: return false
        }
    }
}
