/*
 Copyright 2014 OpenMarket Ltd
 Copyright 2018 New Vector Ltd

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

#import "MXSessionEventListener.h"

#import "MXSession.h"
#import "MXRoom.h"
#import "MXTools.h"

@interface MXSessionEventListener()
{
    // A global listener needs to listen to each MXRoom new events
    // roomEventListeners is the list of all MXRoom listener for this MXSessionEventListener
    // The key is the roomId. The valuse, the registered MXEventListener of the MXRoom
    NSMutableDictionary<NSString *, id> *roomEventListeners;
}
@end

@implementation MXSessionEventListener

- (instancetype)initWithSender:(id)sender andEventTypes:(NSArray<MXEventTypeString> *)eventTypes andListenerBlock:(MXOnEvent)listenerBlock
{
    self = [super initWithSender:sender andEventTypes:eventTypes andListenerBlock:listenerBlock];
    if (self)
    {
        roomEventListeners = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)addRoomToSpy:(MXRoom*)room
{
    if (![roomEventListeners objectForKey:room.roomId])
    {
        self->roomEventListeners[room.roomId] =
        [room listenToEventsOfTypes:self.eventTypes onEvent:^(MXEvent *event, MXTimelineDirection direction, MXRoomState *roomState) {
            self.listenerBlock(event, direction, roomState);
        }];
    }
}

- (void)removeSpiedRoom:(MXRoom*)room
{
    if ([roomEventListeners objectForKey:room.roomId])
    {
        [room removeListener:self->roomEventListeners[room.roomId]];
        [roomEventListeners removeObjectForKey:room.roomId];
    }
}

- (void)removeAllSpiedRooms
{
    // Here sender is the MXSession instance. Cast it
    MXSession *mxSession = (MXSession *)self.sender;
    
    for (NSString *roomId in roomEventListeners)
    {
        MXRoom *room = [mxSession roomWithRoomId:roomId];
        [room removeListener:self->roomEventListeners[room.roomId]];
    }
    [roomEventListeners removeAllObjects];
}

@end
