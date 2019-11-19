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
 Block called when an event of the registered types has been handled in the timeline.
 This is a specialisation of the `MXOnEvent` block.
 
 - parameters:
    - event: the new event.
    - direction: the origin of the event.
    - roomState: the room state right before the event.
 */
public typealias MXOnRoomEvent = (_ event: MXEvent, _ direction: MXTimelineDirection, _ roomState: MXRoomState) -> Void

public extension MXEventTimeline {
    
    /**
     Check if this timelime can be extended.
     
     This returns true if we either have more events, or if we have a pagination
     token which means we can paginate in that direction. It does not necessarily
     mean that there are more events available in that direction at this time.
     
     `canPaginate` in forward direction has no meaning for a live timeline.
     
     - parameter direction: The direction to check
     
     - returns: `true` if we can paginate in the given direction.
     */
    @nonobjc func canPaginate(_ direction: MXTimelineDirection) -> Bool {
        return __canPaginate(direction.identifier)
    }
    
    
    /**
     Reset the pagination timelime and start loading the context around its `initialEventId`.
     The retrieved (backwards and forwards) events will be sent to registered listeners.
     
     - parameters:
        - limit: the maximum number of messages to get around the initial event.
        - completion: A block object called when the operation completes.
        - response: Indicates whether the operation succeeded or failed.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func resetPaginationAroundInitialEvent(withLimit limit: UInt, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __resetPaginationAroundInitialEvent(withLimit: limit, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    /**
     Get more messages.
     The retrieved events will be sent to registered listeners.
     
     Note it is not possible to paginate forwards on a live timeline.
     
     - parameters:
        - numItems: the number of items to get.
        - direction: `.forwards` or `.backwards`.
        - onlyFromStore: if true, return available events from the store, do not make a pagination request to the homeserver.
        - completion: A block object called when the operation completes.
        - response: Indicates whether the operation succeeded or failed.
     
     - returns: a MXHTTPOperation instance. This instance can be nil if no request to the homeserver is required.
     */
    @nonobjc @discardableResult func paginate(_ numItems: UInt, direction: MXTimelineDirection, onlyFromStore: Bool, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation? {
        return __paginate(numItems, direction: direction.identifier, onlyFromStore: onlyFromStore, complete: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    
    /**
     Register a listener to events of this timeline.
     
     - parameters:
        - types: an array of event types to listen to
        - block: the block that will called once a new event has been handled.
     - returns: a reference to use to unregister the listener
     */
    @nonobjc func listenToEvents(_ types: [MXEventType]? = nil, _ block: @escaping MXOnRoomEvent) -> Any {
        
        let legacyBlock: __MXOnRoomEvent = { (event, direction, state) in
            guard let event = event, let state = state else { return }
            block(event, MXTimelineDirection(identifer: direction), state)
        }
        
        if let types = types {
            let typeStrings = types.map({ return $0.identifier })
            return __listen(toEventsOfTypes: typeStrings, onEvent: legacyBlock)
        } else {
            return __listen(toEvents: legacyBlock)
        }
    }
}
