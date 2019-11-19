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

#import "MXEvent.h"
#import "MXEventTimeline.h"

/**
 Block called when an event of the registered types has been handled by the Matrix SDK.
 
 @param event the new event.
 @param direction the origin of the event.
 @param customObject additional contect for the event. In case of room event, customObject is a
 RoomState instance.
 */
typedef void (^MXOnEvent)(MXEvent *event, MXTimelineDirection direction, id customObject);

/**
 The `MXEventListener` class stores information about a listener to MXEvents that
 are handled by the Matrix SDK.
 */
@interface MXEventListener : NSObject

- (instancetype)initWithSender:(id)sender
                 andEventTypes:(NSArray<MXEventTypeString>*)eventTypes
              andListenerBlock:(MXOnEvent)listenerBlock;

/**
 Inform the listener about a new event.
 
 The listener will fire `listenerBlock` to its owner if the event matches `eventTypes`.

 @param event the new event.
 @param direction the origin of the event.
 */
- (void)notify:(MXEvent*)event direction:(MXTimelineDirection)direction andCustomObject:(id)customObject;

@property (nonatomic, readonly) id sender;
@property (nonatomic, readonly) NSArray<MXEventTypeString>* eventTypes;
@property (nonatomic, readonly) MXOnEvent listenerBlock;

@end
