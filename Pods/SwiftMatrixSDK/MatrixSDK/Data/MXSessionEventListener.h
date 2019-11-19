/*
 Copyright 2014 OpenMarket Ltd
 
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

#import <Foundation/Foundation.h>

#import "MXEventListener.h"

@class MXSession;
@class MXRoom;

/**
 Block called when an event of the registered types has been handled by the `MXSession` instance.
 This is a specialisation of the `MXOnEvent` block.
 
 @param event the new event.
 @param direction the origin of the event.
 @param customObject additional contect for the event. In case of room event, customObject is a
                     RoomState instance. In the case of a presence, customObject is nil.
 */
typedef void (^MXOnSessionEvent)(MXEvent *event, MXTimelineDirection direction, id customObject) NS_REFINED_FOR_SWIFT;


/**
 The `MXSessionEventListener` class stores information about a listener to MXSession events
 Such listener is called here global listener since it listens to all events and not the ones limited to a room.
 */
@interface MXSessionEventListener : MXEventListener


/**
 Add a MXRoom the MXSessionEventListener must listen to events from.
 
 @param room the MXRoom to listen to.
 */
- (void)addRoomToSpy:(MXRoom*)room;

/**
 Stop spying to a MXRoom events.
 
 @param room the MXRoom to stop listening to.
 */
- (void)removeSpiedRoom:(MXRoom*)room;

/**
 Stop spying to all registered MXRooms.
 */
- (void)removeAllSpiedRooms;

@end
