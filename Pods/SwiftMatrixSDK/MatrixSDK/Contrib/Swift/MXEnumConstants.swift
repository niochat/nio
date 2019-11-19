/*
 Copyright 2017 Avery Pierce
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation


public enum MXRoomHistoryVisibility {
    case worldReadable, shared, invited, joined
    
    public var identifier: String {
        switch self {
        case .worldReadable: return kMXRoomHistoryVisibilityWorldReadable
        case .shared: return kMXRoomHistoryVisibilityShared
        case .invited: return kMXRoomHistoryVisibilityInvited
        case .joined: return kMXRoomHistoryVisibilityJoined
        }
    }
    
    public init?(identifier: String?) {
        let historyVisibilities: [MXRoomHistoryVisibility] = [.worldReadable, .shared, .invited, .joined]
        guard let value = historyVisibilities.first(where: {$0.identifier == identifier}) else { return nil }
        self = value
    }
}



/**
 Room join rule.
 
 The default homeserver value is invite.
 */
public enum MXRoomJoinRule {
    
    /// Anyone can join the room without any prior action
    case `public`
    
    /// A user who wishes to join the room must first receive an invite to the room from someone already inside of the room.
    case invite
    
    /// Reserved keyword which is not implemented by homeservers.
    case `private`, knock
    
    public var identifier: String {
        switch self {
        case .public: return kMXRoomJoinRulePublic
        case .invite: return kMXRoomJoinRuleInvite
        case .private: return kMXRoomJoinRulePrivate
        case .knock: return kMXRoomJoinRuleKnock
        }
    }
    
    public init?(identifier: String?) {
        let joinRules: [MXRoomJoinRule] = [.public, .invite, .private, .knock]
        guard let value = joinRules.first(where: { $0.identifier == identifier}) else { return nil }
        self = value
    }
}



/// Room guest access. The default homeserver value is forbidden.
public enum MXRoomGuestAccess {
    
    /// Guests can join the room
    case canJoin
    
    /// Guest access is forbidden
    case forbidden
    
    /// String identifier
    public var identifier: String {
        switch self {
        case .canJoin: return kMXRoomGuestAccessCanJoin
        case .forbidden: return kMXRoomGuestAccessForbidden
        }
    }
    
    public init?(identifier: String?) {
        let accessRules: [MXRoomGuestAccess] = [.canJoin, .forbidden]
        guard let value = accessRules.first(where: { $0.identifier == identifier}) else { return nil }
        self = value
    }
}



/**
 Room visibility in the current homeserver directory.
 The default homeserver value is private.
 */
public enum MXRoomDirectoryVisibility {
    
    /// The room is not listed in the homeserver directory
    case `private`
    
    /// The room is listed in the homeserver directory
    case `public`
    
    public var identifier: String {
        switch self {
        case .private: return kMXRoomDirectoryVisibilityPrivate
        case .public: return kMXRoomDirectoryVisibilityPublic
        }
    }
    
    public init?(identifier: String?) {
        let visibility: [MXRoomDirectoryVisibility] = [.public, .private]
        guard let value = visibility.first(where: { $0.identifier == identifier}) else { return nil }
        self = value
    }
}




/// Room presets.
/// Define a set of state events applied during a new room creation.
public enum MXRoomPreset {
    
    /// join_rules is set to invite. history_visibility is set to shared.
    case privateChat
    
    /// join_rules is set to invite. history_visibility is set to shared. All invitees are given the same power level as the room creator.
    case trustedPrivateChat
    
    /// join_rules is set to public. history_visibility is set to shared.
    case publicChat
    
    
    public var identifier: String {
        switch self {
        case .privateChat: return kMXRoomPresetPrivateChat
        case .trustedPrivateChat: return kMXRoomPresetTrustedPrivateChat
        case .publicChat: return kMXRoomPresetPublicChat
        }
    }
    
    public init?(identifier: String?) {
        let presets: [MXRoomPreset] = [.privateChat, .trustedPrivateChat, .publicChat]
        guard let value = presets.first(where: {$0.identifier == identifier }) else { return nil }
        self = value
    }
}



/**
 The direction of an event in the timeline.
 */
public enum MXTimelineDirection {
    
    /// Forwards when the event is added to the end of the timeline.
    /// These events come from the /sync stream or from forwards pagination.
    case forwards
    
    /// Backwards when the event is added to the start of the timeline.
    /// These events come from a back pagination.
    case backwards
    
    public var identifier: __MXTimelineDirection {
        switch self {
        case .forwards: return __MXTimelineDirectionForwards
        case .backwards: return __MXTimelineDirectionBackwards
        }
    }
    
    public init(identifer _identifier: __MXTimelineDirection) {
        self = (_identifier == __MXTimelineDirectionForwards ? .forwards : .backwards)
    }
}

