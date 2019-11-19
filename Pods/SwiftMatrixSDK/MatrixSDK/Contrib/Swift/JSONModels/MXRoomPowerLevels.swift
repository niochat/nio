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

extension MXRoomPowerLevels {
    
    /**
     Helper to get the minimum power level the user must have to send an event of the given type
     as a message.
     
     - parameter eventType: the type of event.
     - returns: the required minimum power level.
     */
    @nonobjc func minimumPowerLevelForSendingMessageEvent(_ eventType: MXEventType) -> Int {
        return __minimumPowerLevelForSendingEvent(asMessage: eventType.identifier)
    }
    
    /**
     Helper to get the minimum power level the user must have to send an event of the given type
     as a state event.
     
     - parameter eventType: the type of event.
     - returns: the required minimum power level.
     */
    @nonobjc func minimumPowerLevelForSendingStateEvent(_ eventType: MXEventType) -> Int {
        return __minimumPowerLevelForSendingEvent(asStateEvent: eventType.identifier)
    }
    
}
