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

/**
 Block called when an event of the registered types has been handled by the `MXSession` instance.
 This is a specialisation of the `MXOnEvent` block.
 
 - parameters:
    - event: the new event.
    - direction: the origin of the event.
    - customObject: additional contect for the event. In case of room event, `customObject` is a `RoomState` instance. In the case of a presence, `customObject` is `nil`.
 */
public typealias MXOnSessionEvent = (_ event: MXEvent, _ direction: MXTimelineDirection, _ customObject: Any?) -> Void;
