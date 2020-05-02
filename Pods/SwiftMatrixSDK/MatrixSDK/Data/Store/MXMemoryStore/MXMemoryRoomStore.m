/*
 Copyright 2014 OpenMarket Ltd
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

#import "MXMemoryRoomStore.h"

#import "MXEventsEnumeratorOnArray.h"
#import "MXEventsByTypesEnumeratorOnArray.h"

@interface MXMemoryRoomStore ()
{
}

@end

@implementation MXMemoryRoomStore
@synthesize outgoingMessages;

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        messages = [NSMutableArray array];
        messagesByEventIds = [NSMutableDictionary dictionary];
        outgoingMessages = [NSMutableArray array];
        _hasReachedHomeServerPaginationEnd = NO;
        _hasLoadedAllRoomMembersForRoom = NO;
    }
    return self;
}

- (void)storeEvent:(MXEvent *)event direction:(MXTimelineDirection)direction
{
    if (MXTimelineDirectionForwards == direction)
    {
        [messages addObject:event];
    }
    else
    {
        [messages insertObject:event atIndex:0];
    }

    if (event.eventId)
    {
        messagesByEventIds[event.eventId] = event;
    }
}

- (void)replaceEvent:(MXEvent*)event
{
    NSUInteger index = messages.count;
    while (index--)
    {
        MXEvent *anEvent = [messages objectAtIndex:index];
        if ([anEvent.eventId isEqualToString:event.eventId])
        {
            [messages replaceObjectAtIndex:index withObject:event];

            messagesByEventIds[event.eventId] = event;
            break;
        }
    }
}

- (MXEvent *)eventWithEventId:(NSString *)eventId
{
    return messagesByEventIds[eventId];
}

- (void)removeAllMessages
{
    [messages removeAllObjects];
    [messagesByEventIds removeAllObjects];
}

- (id<MXEventsEnumerator>)messagesEnumerator
{
    return [[MXEventsEnumeratorOnArray alloc] initWithMessages:messages];
}

- (id<MXEventsEnumerator>)enumeratorForMessagesWithTypeIn:(NSArray*)types
{
    return [[MXEventsByTypesEnumeratorOnArray alloc] initWithMessages:messages andTypesIn:types];
}

- (NSArray*)eventsAfter:(NSString *)eventId except:(NSString*)userId withTypeIn:(NSSet*)types
{
    NSMutableArray* list = [[NSMutableArray alloc] init];

    if (eventId)
    {
        // Check messages from the most recent
        for (NSInteger i = messages.count - 1; i >= 0 ; i--)
        {
            MXEvent *event = messages[i];

            if (NO == [event.eventId isEqualToString:eventId])
            {
                // Keep events matching filters
                if ((!types || [types containsObject:event.type]) && ![event.sender isEqualToString:userId])
                {
                    [list insertObject:event atIndex:0];
                }
            }
            else
            {
                // We are done
                break;
            }
        }
    }

    return list;
}

- (NSArray<MXEvent*>*)relationsForEvent:(NSString*)eventId relationType:(NSString*)relationType
{
    NSMutableArray<MXEvent*>* referenceEvents = [NSMutableArray new];
    
    for (MXEvent* event in messages)
    {
        MXEventContentRelatesTo *relatesTo = event.relatesTo;
        
        if (relatesTo && [relatesTo.eventId isEqualToString:eventId] && [relatesTo.relationType isEqualToString:relationType])
        {
            [referenceEvents addObject:event];
        }
    }
    
    return referenceEvents;
}

- (void)storeOutgoingMessage:(MXEvent*)outgoingMessage
{
    // Sanity check: prevent from adding multiple occurrences of the same object.
    if ([outgoingMessages indexOfObject:outgoingMessage] == NSNotFound)
    {
        [outgoingMessages addObject:outgoingMessage];
    }
}

- (void)removeAllOutgoingMessages
{
    [outgoingMessages removeAllObjects];
}

- (void)removeOutgoingMessage:(NSString*)outgoingMessageEventId
{
    for (NSUInteger i = 0; i < outgoingMessages.count; i++)
    {
        MXEvent *outgoingMessage = outgoingMessages[i];
        if ([outgoingMessage.eventId isEqualToString:outgoingMessageEventId])
        {
            [outgoingMessages removeObjectAtIndex:i];
            break;
        }
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%tu messages - paginationToken: %@ - hasReachedHomeServerPaginationEnd: %@ - hasLoadedAllRoomMembersForRoom: %@", messages.count, _paginationToken, @(_hasReachedHomeServerPaginationEnd), @(_hasLoadedAllRoomMembersForRoom)];
}

@end
