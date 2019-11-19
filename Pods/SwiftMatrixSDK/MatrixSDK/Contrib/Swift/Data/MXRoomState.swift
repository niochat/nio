/*
 Copyright 2017 Avery Pierce
 Copyright 2017 Vector Creations Ltd
 
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

extension MXRoomState {
    
    /// The history visibility of the room
    public var historyVisibility: MXRoomHistoryVisibility! {
        return MXRoomHistoryVisibility(identifier: self.__historyVisibility)
    }
    
    /// The join rule of the room
    public var joinRule: MXRoomJoinRule! {
        return MXRoomJoinRule(identifier: self.__joinRule)
    }
    
    /// The guest access of the room
    public var guestAccess: MXRoomGuestAccess! {
        return MXRoomGuestAccess(identifier: self.__guestAccess)
    }
    
    
    /// The membership state of the logged in user for this room
    ///
    /// If the membership is `invite`, the room state contains few information.
    /// Join the room with [MXRoom join] to get full information about the room.
    public var membership: MXMembership {
        return MXMembership(identifier: self.__membership)
    }
    
    /**
     Return the state events with the given type.
     
     - parameter type: The type of the event
     - returns: The state events
     */
    public func stateEvents(with type: MXEventType) -> [MXEvent]? {
        return __stateEvents(withType: type.identifier)
    }
}
