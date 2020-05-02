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

#import "MXMemoryStore.h"

#import "MXMemoryRoomStore.h"

#import "MXTools.h"

@interface MXMemoryStore()
{
    NSString *eventStreamToken;
    MXWellKnown *homeserverWellknown;
}
@end


@implementation MXMemoryStore

@synthesize eventStreamToken, userAccountData, syncFilterId, homeserverWellknown;

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        roomStores = [NSMutableDictionary dictionary];
        receiptsByRoomId = [NSMutableDictionary dictionary];
        users = [NSMutableDictionary dictionary];
        groups = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)openWithCredentials:(MXCredentials *)someCredentials onComplete:(void (^)(void))onComplete failure:(void (^)(NSError *))failure
{
    credentials = someCredentials;
    // Nothing to do
    if (onComplete)
    {
        onComplete();
    }
}

- (void)storeEventForRoom:(NSString*)roomId event:(MXEvent*)event direction:(MXTimelineDirection)direction
{
    MXMemoryRoomStore *roomStore = [self getOrCreateRoomStore:roomId];
    [roomStore storeEvent:event direction:direction];
}

- (void)replaceEvent:(MXEvent *)event inRoom:(NSString *)roomId
{
    MXMemoryRoomStore *roomStore = [self getOrCreateRoomStore:roomId];
    [roomStore replaceEvent:event];
}

- (BOOL)eventExistsWithEventId:(NSString *)eventId inRoom:(NSString *)roomId
{
    return (nil != [self eventWithEventId:eventId inRoom:roomId]);
}

- (MXEvent *)eventWithEventId:(NSString *)eventId inRoom:(NSString *)roomId
{
    MXMemoryRoomStore *roomStore = [self getOrCreateRoomStore:roomId];
    return [roomStore eventWithEventId:eventId];
}

- (void)deleteAllMessagesInRoom:(NSString *)roomId
{
    MXMemoryRoomStore *roomStore = [self getOrCreateRoomStore:roomId];
    [roomStore removeAllMessages];
    roomStore.paginationToken = nil;
    roomStore.hasReachedHomeServerPaginationEnd = NO;
}

- (void)deleteRoom:(NSString *)roomId
{
    if (roomStores[roomId])
    {
        [roomStores removeObjectForKey:roomId];
    }
    
    if (receiptsByRoomId[roomId])
    {
        [receiptsByRoomId removeObjectForKey:roomId];
    }
}

- (void)deleteAllData
{
    [roomStores removeAllObjects];
}

- (void)storePaginationTokenOfRoom:(NSString*)roomId andToken:(NSString*)token
{
    MXMemoryRoomStore *roomStore = [self getOrCreateRoomStore:roomId];
    roomStore.paginationToken = token;
}

- (NSString*)paginationTokenOfRoom:(NSString*)roomId
{
    MXMemoryRoomStore *roomStore = [self getOrCreateRoomStore:roomId];
    return roomStore.paginationToken;
}

- (void)storeHasReachedHomeServerPaginationEndForRoom:(NSString*)roomId andValue:(BOOL)value
{
    MXMemoryRoomStore *roomStore = [self getOrCreateRoomStore:roomId];
    roomStore.hasReachedHomeServerPaginationEnd = value;
}

- (BOOL)hasReachedHomeServerPaginationEndForRoom:(NSString*)roomId
{
    MXMemoryRoomStore *roomStore = [self getOrCreateRoomStore:roomId];
    return roomStore.hasReachedHomeServerPaginationEnd;
}

- (void)storeHasLoadedAllRoomMembersForRoom:(NSString *)roomId andValue:(BOOL)value
{
    MXMemoryRoomStore *roomStore = [self getOrCreateRoomStore:roomId];
    roomStore.hasLoadedAllRoomMembersForRoom = value;
}

- (BOOL)hasLoadedAllRoomMembersForRoom:(NSString *)roomId
{
    MXMemoryRoomStore *roomStore = [self getOrCreateRoomStore:roomId];
    return roomStore.hasLoadedAllRoomMembersForRoom;
}


- (id<MXEventsEnumerator>)messagesEnumeratorForRoom:(NSString *)roomId
{
    MXMemoryRoomStore *roomStore = [self getOrCreateRoomStore:roomId];
    return roomStore.messagesEnumerator;
}

- (id<MXEventsEnumerator>)messagesEnumeratorForRoom:(NSString *)roomId withTypeIn:(NSArray *)types
{
    MXMemoryRoomStore *roomStore = [self getOrCreateRoomStore:roomId];
    return [roomStore enumeratorForMessagesWithTypeIn:types];
}

- (void)storePartialTextMessageForRoom:(NSString *)roomId partialTextMessage:(NSString *)partialTextMessage
{
    MXMemoryRoomStore *roomStore = [self getOrCreateRoomStore:roomId];
    roomStore.partialTextMessage = partialTextMessage;
}

- (NSString *)partialTextMessageOfRoom:(NSString *)roomId
{
    MXMemoryRoomStore *roomStore = [self getOrCreateRoomStore:roomId];
    return roomStore.partialTextMessage;
}

- (NSArray<MXReceiptData*> *)getEventReceipts:(NSString*)roomId eventId:(NSString*)eventId sorted:(BOOL)sort
{
    NSMutableArray* receipts = [[NSMutableArray alloc] init];
    
    NSMutableDictionary* receiptsByUserId = receiptsByRoomId[roomId];
    
    if (receiptsByUserId)
    {
        @synchronized (receiptsByUserId)
        {
            for (NSString* userId in receiptsByUserId)
            {
                MXReceiptData* receipt = receiptsByUserId[userId];

                if (receipt && [receipt.eventId isEqualToString:eventId])
                {
                    [receipts addObject:receipt];
                }
            }
        }
    }

    if (sort)
    {
        return [receipts sortedArrayUsingComparator:^NSComparisonResult(id a, id b)
                                {
                                    MXReceiptData *first =  (MXReceiptData*)a;
                                    MXReceiptData *second = (MXReceiptData*)b;
                                    
                                    return (first.ts < second.ts) ? NSOrderedDescending : NSOrderedAscending;
                                }];
    }
    
    return receipts;
}

- (BOOL)storeReceipt:(MXReceiptData*)receipt inRoom:(NSString*)roomId
{
    NSMutableDictionary* receiptsByUserId = receiptsByRoomId[roomId];
    
    if (!receiptsByUserId)
    {
        receiptsByUserId = [[NSMutableDictionary alloc] init];
        receiptsByRoomId[roomId] = receiptsByUserId;
    }
    
    MXReceiptData* curReceipt = receiptsByUserId[receipt.userId];
    
    // not yet defined or a new event
    if (!curReceipt || (![receipt.eventId isEqualToString:curReceipt.eventId] && (receipt.ts > curReceipt.ts)))
    {
        @synchronized (receiptsByUserId)
        {
            receiptsByUserId[receipt.userId] = receipt;
        }
        return true;
    }
    
    return false;
}

- (MXReceiptData *)getReceiptInRoom:(NSString*)roomId forUserId:(NSString*)userId
{
    NSMutableDictionary* receipsByUserId = receiptsByRoomId[roomId];

    if (receipsByUserId)
    {
        MXReceiptData* data = receipsByUserId[userId];
        if (data)
        {
            return [data copy];
        }
    }
    
    return nil;
}

- (NSUInteger)localUnreadEventCount:(NSString*)roomId withTypeIn:(NSArray*)types
{
    // @TODO: This method is only logic which could be moved to MXRoom
    MXMemoryRoomStore* store = [roomStores valueForKey:roomId];
    NSMutableDictionary* receipsByUserId = [receiptsByRoomId objectForKey:roomId];
    NSUInteger count = 0;
    
    if (store && receipsByUserId)
    {
        MXReceiptData* data = [receipsByUserId objectForKey:credentials.userId];
        
        if (data)
        {
            // Check the current stored events (by ignoring oneself events)
            NSArray *array = [store eventsAfter:data.eventId except:credentials.userId withTypeIn:[NSSet setWithArray:types]];
            
            // Check whether these unread events have not been redacted.
            for (MXEvent *event in array)
            {
                if (event.redactedBecause == nil)
                {
                    count ++;
                }
            }
        }
    }
   
    return count;
}

- (void)storeHomeserverWellknown:(nonnull MXWellKnown *)wellknown
{
    homeserverWellknown = wellknown;
}

- (NSArray<MXEvent*>* _Nonnull)relationsForEvent:(nonnull NSString*)eventId inRoom:(nonnull  NSString*)roomId relationType:(NSString*)relationType
{
    MXMemoryRoomStore *roomStore = [self getOrCreateRoomStore:roomId];
    return [roomStore relationsForEvent:eventId relationType:relationType];
}

- (BOOL)isPermanent
{
    return NO;
}

- (NSArray *)rooms
{
    return roomStores.allKeys;
}


#pragma mark - Matrix users
- (void)storeUser:(MXUser *)user
{
    users[user.userId] = user;
}

- (NSArray<MXUser *> *)users
{
    return users.allValues;
}

- (MXUser *)userWithUserId:(NSString *)userId
{
    return users[userId];
}

#pragma mark - Matrix groups
- (void)storeGroup:(MXGroup *)group
{
    if (group.groupId.length)
    {
        groups[group.groupId] = group;
    }
}

- (NSArray<MXGroup *> *)groups
{
    return groups.allValues;
}

- (MXGroup *)groupWithGroupId:(NSString *)groupId
{
    if (groupId.length)
    {
        return groups[groupId];
    }
    return nil;
}

- (void)deleteGroup:(NSString *)groupId
{
    if (groupId.length)
    {
        [groups removeObjectForKey:groupId];
    }
}

#pragma mark - Outgoing events
- (void)storeOutgoingMessageForRoom:(NSString*)roomId outgoingMessage:(MXEvent*)outgoingMessage
{
    MXMemoryRoomStore *roomStore = [self getOrCreateRoomStore:roomId];
    [roomStore storeOutgoingMessage:outgoingMessage];
}

- (void)removeAllOutgoingMessagesFromRoom:(NSString*)roomId
{
    MXMemoryRoomStore *roomStore = [self getOrCreateRoomStore:roomId];
    [roomStore removeAllOutgoingMessages];
}

- (void)removeOutgoingMessageFromRoom:(NSString*)roomId outgoingMessage:(NSString*)outgoingMessageEventId
{
    MXMemoryRoomStore *roomStore = [self getOrCreateRoomStore:roomId];
    [roomStore removeOutgoingMessage:outgoingMessageEventId];
}

- (NSArray<MXEvent*>*)outgoingMessagesInRoom:(NSString*)roomId
{
    MXMemoryRoomStore *roomStore = [self getOrCreateRoomStore:roomId];
    return roomStore.outgoingMessages;
}


#pragma mark - Matrix filters
- (void)storeFilter:(nonnull MXFilterJSONModel*)filter withFilterId:(nonnull NSString*)filterId
{
    if (!filters)
    {
        filters = [NSMutableDictionary dictionary];
    }

    filters[filterId] = filter.jsonString;
}

- (void)filterWithFilterId:(nonnull NSString*)filterId
                   success:(nonnull void (^)(MXFilterJSONModel * _Nullable filter))success
                   failure:(nullable void (^)(NSError * _Nullable error))failure
{
    MXFilterJSONModel *filter;

    NSString *jsonString = filters[filterId];
    if (jsonString)
    {
        NSDictionary *json = [MXTools deserialiseJSONString:jsonString];
        filter = [MXFilterJSONModel modelFromJSON:json];
    }

    success(filter);
}

- (void)filterIdForFilter:(nonnull MXFilterJSONModel*)filter
                  success:(nonnull void (^)(NSString * _Nullable filterId))success
                  failure:(nullable void (^)(NSError * _Nullable error))failure
{
    NSString *theFilterId;

    for (NSString *filterId in filters)
    {
        NSDictionary *json = [MXTools deserialiseJSONString:filters[filterId]];
        MXFilterJSONModel *cachedFilter = [MXFilterJSONModel modelFromJSON:json];

        if ([cachedFilter isEqual:filter])
        {
            theFilterId = filterId;
            break;
        }
    }

    success(theFilterId);
}


#pragma mark - Protected operations
- (MXMemoryRoomStore*)getOrCreateRoomStore:(NSString*)roomId
{
    MXMemoryRoomStore *roomStore = roomStores[roomId];
    if (nil == roomStore)
    {
        roomStore = [[MXMemoryRoomStore alloc] init];
        roomStores[roomId] = roomStore;
    }
    return roomStore;
}

@end
