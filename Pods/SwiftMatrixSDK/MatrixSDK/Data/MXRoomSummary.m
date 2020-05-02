/*
 Copyright 2017 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2018 New Vector Ltd
 Copyright 2019 The Matrix.org Foundation C.I.C

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

#import "MXRoomSummary.h"

#import "MXRoom.h"
#import "MXRoomState.h"
#import "MXSession.h"
#import "MXSDKOptions.h"
#import "MXTools.h"
#import "MXEventRelations.h"
#import "MXEventReplace.h"

#import <Security/Security.h>
#import <CommonCrypto/CommonCryptor.h>

/**
 RoomEncryptionTrustLevel represents the room members trust level in an encrypted room.
 */
typedef NS_ENUM(NSUInteger, MXRoomSummaryNextTrustComputation) {
    MXRoomSummaryNextTrustComputationNone,
    MXRoomSummaryNextTrustComputationPending,
    MXRoomSummaryNextTrustComputationPendingWithForceDownload,
};


NSString *const kMXRoomSummaryDidChangeNotification = @"kMXRoomSummaryDidChangeNotification";

/**
 Time to wait before refreshing trust when a change has been detected.
 */
static NSUInteger const kMXRoomSummaryTrustComputationDelayMs = 1000;


@interface MXRoomSummary ()
{
    // Cache for the last event to avoid to read it from the store everytime
    MXEvent *lastMessageEvent;

    // Flag to avoid to notify several updates
    BOOL updatedWithStateEvents;

    // The store to store events
    id<MXStore> store;

    // The listener to edits in the room.
    id eventEditsListener;
    
    MXRoomSummaryNextTrustComputation nextTrustComputation;
}

@end

@implementation MXRoomSummary

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        updatedWithStateEvents = NO;
        nextTrustComputation = MXRoomSummaryNextTrustComputationNone;
    }
    return self;
}

- (instancetype)initWithRoomId:(NSString *)roomId andMatrixSession:(MXSession *)mxSession
{
    // Let's use the default store
    return [self initWithRoomId:roomId matrixSession:mxSession andStore:mxSession.store];
}

- (instancetype)initWithRoomId:(NSString *)roomId matrixSession:(MXSession *)mxSession andStore:(id<MXStore>)theStore
{
    self = [self init];
    if (self)
    {
        _roomId = roomId;
        _lastMessageOthers = [NSMutableDictionary dictionary];
        _others = [NSMutableDictionary dictionary];
        store = theStore;

        [self setMatrixSession:mxSession];
    }

    return self;
}

- (void)destroy
{
    NSLog(@"[MXKRoomSummary] Destroy %p - room id: %@", self, _roomId);

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXEventDidChangeSentStateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXEventDidChangeIdentifierNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXRoomDidFlushDataNotification object:nil];
    [self unregisterEventEditsListener];
}

- (void)setMatrixSession:(MXSession *)mxSession
{
    if (!_mxSession)
    {
        _mxSession = mxSession;
        store = mxSession.store;

        // Listen to the event sent state changes
        // This is used to follow evolution of local echo events
        // (ex: when a sentState change from sending to sentFailed)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(eventDidChangeSentState:) name:kMXEventDidChangeSentStateNotification object:nil];

        // Listen to the event id change
        // This is used to follow evolution of local echo events
        // when they changed their local event id to the final event id
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(eventDidChangeIdentifier:) name:kMXEventDidChangeIdentifierNotification object:nil];

        // Listen to data being flush in a room
        // This is used to update the room summary in case of a state event redaction
        // We may need to update the room displayname when it happens
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(roomDidFlushData:) name:kMXRoomDidFlushDataNotification object:nil];

        // Listen to event edits within the room
        [self registerEventEditsListener];
    }
 }

- (void)save:(BOOL)commit
{
    if ([store respondsToSelector:@selector(storeSummaryForRoom:summary:)])
    {
        [store storeSummaryForRoom:_roomId summary:self];
    }
    if (commit && [store respondsToSelector:@selector(commit)])
    {
        [store commit];
    }

    // Broadcast the change
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXRoomSummaryDidChangeNotification object:self userInfo:nil];
}

- (MXRoom *)room
{
    // That makes self.room a really weak reference
    return [_mxSession roomWithRoomId:_roomId];
}


#pragma mark - Data related to room state

- (void)resetRoomStateData
{
    // Reset data
    MXRoom *room = self.room;

    _avatar = nil;
    _displayname = nil;
    _topic = nil;
    _aliases = nil;

    MXWeakify(self);
    [room state:^(MXRoomState *roomState) {
        MXStrongifyAndReturnIfNil(self);

        BOOL updated = [self.mxSession.roomSummaryUpdateDelegate session:self.mxSession updateRoomSummary:self withStateEvents:roomState.stateEvents roomState:roomState];

        if (self.displayname == nil || self.avatar == nil)
        {
            // Avatar and displayname may not be recomputed from the state event list if
            // the latter does not contain any `name` or `avatar` event. So, in this case,
            // we reapply the Matrix name/avatar calculation algorithm.
            updated |= [self.mxSession.roomSummaryUpdateDelegate session:self.mxSession updateRoomSummary:self withServerRoomSummary:nil roomState:roomState];
        }

        if (updated)
        {
            [self save:YES];
        }
    }];
}


#pragma mark - Data related to the last message

- (MXEvent *)lastMessageEvent
{
    if (!lastMessageEvent)
    {
        // The storage of the event depends if it is a true matrix event or a local echo
        if (![_lastMessageEventId hasPrefix:kMXEventLocalEventIdPrefix])
        {
            lastMessageEvent = [store eventWithEventId:_lastMessageEventId inRoom:_roomId];
        }
        else
        {
            for (MXEvent *event in [store outgoingMessagesInRoom:_roomId])
            {
                if ([event.eventId isEqualToString:_lastMessageEventId])
                {
                    lastMessageEvent = event;
                    break;
                }
            }
        }
    }

    // Decrypt event if necessary
    if (lastMessageEvent.eventType == MXEventTypeRoomEncrypted)
    {
        if (![_mxSession decryptEvent:lastMessageEvent inTimeline:nil])
        {
            NSLog(@"[MXRoomSummary] lastMessageEvent: Warning: Unable to decrypt event. Error: %@", lastMessageEvent.decryptionError);
        }
    }

    return lastMessageEvent;
}

- (void)setLastMessageEvent:(MXEvent *)event
{
    lastMessageEvent = event;
    _lastMessageEventId = lastMessageEvent.eventId;
    _lastMessageOriginServerTs = lastMessageEvent.originServerTs;
    _isLastMessageEncrypted = event.isEncrypted;
}

- (MXHTTPOperation *)resetLastMessage:(void (^)(void))complete failure:(void (^)(NSError *))failure commit:(BOOL)commit
{
    lastMessageEvent = nil;
    _lastMessageEventId = nil;
    _lastMessageOriginServerTs = -1;
    _lastMessageString = nil;
    _lastMessageAttributedString = nil;
    [_lastMessageOthers removeAllObjects];

    return [self fetchLastMessage:complete failure:failure lastEventIdChecked:nil operation:nil commit:commit];
}

/**
 Find the event to be used as last message.

 @param complete A block object called when the operation completes.
 @param failure A block object called when the operation fails.
 @param lastEventIdChecked the id of the last candidate event checked to be the last message.
        Nil means we will start checking from the last event in the store.
 @param operation the current http operation if any.
        The method may need several requests before fetching the right last message.
        If it happens, the first one is mutated to the others with [MXHTTPOperation mutateTo:].
 @param commit tell whether the updated room summary must be committed to the store. Use NO when a more
 global [MXStore commit] will happen. This optimises IO.
 @return a MXHTTPOperation
 */
- (MXHTTPOperation *)fetchLastMessage:(void (^)(void))complete failure:(void (^)(NSError *))failure lastEventIdChecked:(NSString*)lastEventIdChecked operation:(MXHTTPOperation *)operation commit:(BOOL)commit
{
    MXRoom *room = self.room;
    if (!room)
    {
        if (failure)
        {
            failure(nil);
        }
        return nil;
    }

    if (!operation)
    {
        // Create an empty operation that will be mutated later
        operation = [[MXHTTPOperation alloc] init];
    }

    MXWeakify(self);
    [self.room state:^(MXRoomState *roomState) {
        MXStrongifyAndReturnIfNil(self);

        // Start by checking events we have in the store
        MXRoomState *state = roomState;
        id<MXEventsEnumerator> messagesEnumerator = room.enumeratorForStoredMessages;
        NSUInteger messagesInStore = messagesEnumerator.remaining;
        MXEvent *event = messagesEnumerator.nextEvent;
        NSString *lastEventIdCheckedInBlock = lastEventIdChecked;

        // 1.1 Find where we stopped at the previous call in the fetchLastMessage calls loop
        BOOL firstIteration = YES;
        if (lastEventIdCheckedInBlock)
        {
            firstIteration = NO;
            while (event)
            {
                NSString *eventId = event.eventId;

                event = messagesEnumerator.nextEvent;

                if ([eventId isEqualToString:lastEventIdCheckedInBlock])
                {
                    break;
                }
            }
        }

        // 1.2 Check events one by one until finding the right last message for the room
        BOOL lastMessageUpdated = NO;
        while (event)
        {
            // Decrypt the event if necessary
            if (event.eventType == MXEventTypeRoomEncrypted)
            {
                if (![self.mxSession decryptEvent:event inTimeline:nil])
                {
                    NSLog(@"[MXRoomSummary] fetchLastMessage: Warning: Unable to decrypt event: %@\nError: %@", event.content[@"body"], event.decryptionError);
                }
            }

            if (event.isState)
            {
                // Need to go backward in the state to provide it as it was when the event occured
                if (state.isLive)
                {
                    state = [state copy];
                    state.isLive = NO;
                }

                [state handleStateEvents:@[event]];
            }

            lastEventIdCheckedInBlock = event.eventId;

            // Propose the event as last message
            lastMessageUpdated = [self.mxSession.roomSummaryUpdateDelegate session:self.mxSession updateRoomSummary:self withLastEvent:event eventState:state roomState:roomState];
            if (lastMessageUpdated)
            {
                // The event is accepted. We have our last message
                // The roomSummaryUpdateDelegate has stored the _lastMessageEventId
                break;
            }

            event = messagesEnumerator.nextEvent;
        }

        // 2.1 If lastMessageEventId is still nil, fetch events from the homeserver
        MXWeakify(self);
        [room liveTimeline:^(MXEventTimeline *liveTimeline) {
            MXStrongifyAndReturnIfNil(self);

            if (!self->_lastMessageEventId && [liveTimeline canPaginate:MXTimelineDirectionBackwards])
            {
                NSUInteger messagesToPaginate = 30;

                // Reset pagination the first time
                if (firstIteration)
                {
                    [liveTimeline resetPagination];

                    // Make sure we paginate more than the events we have already in the store
                    messagesToPaginate += messagesInStore;
                }

                // Paginate events from the homeserver
                // XXX: Pagination on the timeline may conflict with request from the app
                __block MXHTTPOperation *newOperation;
                newOperation = [liveTimeline paginate:messagesToPaginate direction:MXTimelineDirectionBackwards onlyFromStore:NO complete:^{

                    // Received messages have been stored in the store. We can make a new loop
                    // XXX: This is only true for a permanent storage. Only MXNoStore is not permanent.
                    // MXNoStore is only used for tests. We can skip it here.
                    if (self.mxSession.store.isPermanent)
                    {
                        [self fetchLastMessage:complete failure:failure
                            lastEventIdChecked:lastEventIdCheckedInBlock
                                     operation:(operation ? operation : newOperation)
                                        commit:commit];
                    }

                } failure:failure];

                // Update the current HTTP operation
                [operation mutateTo:newOperation];
            }
            else
            {
                if (complete)
                {
                    complete();
                }

                [self save:commit];
            }
        }];
    }];

    return operation;
}

- (void)eventDidChangeSentState:(NSNotification *)notif
{
    MXEvent *event = notif.object;

    // If the last message is a local echo, update it.
    // Do nothing when its sentState becomes sent. In this case, the last message will be
    // updated by the true event coming back from the homeserver.
    if (event.sentState != MXEventSentStateSent && [event.eventId isEqualToString:_lastMessageEventId])
    {
        [self handleEvent:event];
    }
}

- (void)eventDidChangeIdentifier:(NSNotification *)notif
{
    MXEvent *event = notif.object;
    NSString *previousId = notif.userInfo[kMXEventIdentifierKey];

    if ([_lastMessageEventId isEqualToString:previousId])
    {
        [self handleEvent:event];
    }
}

- (void)roomDidFlushData:(NSNotification *)notif
{
    MXRoom *room = notif.object;
    if (_mxSession == room.mxSession && [_roomId isEqualToString:room.roomId])
    {
        NSLog(@"[MXRoomSummary] roomDidFlushData: %@", _roomId);

        [self resetRoomStateData];
    }
}


#pragma mark - Edits management
- (void)registerEventEditsListener
{
    MXWeakify(self);
    eventEditsListener = [_mxSession.aggregations listenToEditsUpdateInRoom:_roomId block:^(MXEvent * _Nonnull replaceEvent) {
        MXStrongifyAndReturnIfNil(self);

        // Update the last event if it has been edited
        if ([replaceEvent.relatesTo.eventId isEqualToString:self.lastMessageEventId])
        {
            MXEvent *editedEvent = [self.lastMessageEvent editedEventFromReplacementEvent:replaceEvent];
            [self handleEvent:editedEvent];
        }
    }];
}

- (void)unregisterEventEditsListener
{
    if (eventEditsListener)
    {
        [self.mxSession.aggregations removeListener:eventEditsListener];
        eventEditsListener = nil;
    }
}


#pragma mark - Trust management

- (void)setIsEncrypted:(BOOL)isEncrypted
{
    _isEncrypted = isEncrypted;
    
    if (_isEncrypted && [MXSDKOptions sharedInstance].computeE2ERoomSummaryTrust)
    {
        [self bootstrapTrustLevelComputation];
    }
}

- (void)setMembersCount:(MXRoomMembersCount *)membersCount
{
    _membersCount = membersCount;
    if (_isEncrypted && [MXSDKOptions sharedInstance].computeE2ERoomSummaryTrust)
    {
        [self triggerComputeTrust:YES];
    }
}

- (void)bootstrapTrustLevelComputation
{
    if (_isEncrypted && [MXSDKOptions sharedInstance].computeE2ERoomSummaryTrust)
    {
        // Bootstrap trust computation
        [self registerTrustLevelDidChangeNotifications];
        
        if (!self.trust)
        {
            [self triggerComputeTrust:YES];
        }
    }
}

- (void)registerTrustLevelDidChangeNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceInfoTrustLevelDidChange:) name:MXDeviceInfoTrustLevelDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(crossSigningInfoTrustLevelDidChange:) name:MXCrossSigningInfoTrustLevelDidChangeNotification object:nil];
}

- (void)deviceInfoTrustLevelDidChange:(NSNotification*)notification
{
    MXDeviceInfo *deviceInfo = notification.object;
    
    NSString *userId = deviceInfo.userId;
    if (userId)
    {
        [self encryptionTrustLevelDidChangeRelatedToUserId:userId];
    }
}

- (void)crossSigningInfoTrustLevelDidChange:(NSNotification*)notification
{
    MXCrossSigningInfo *crossSigningInfo = notification.object;
    
    NSString *userId = crossSigningInfo.userId;
    if (userId)
    {
        [self encryptionTrustLevelDidChangeRelatedToUserId:userId];
    }
}

- (void)encryptionTrustLevelDidChangeRelatedToUserId:(NSString*)userId
{
    [self.room members:^(MXRoomMembers *roomMembers) {
        MXRoomMember *roomMember = [roomMembers memberWithUserId:userId];
        
        // If user belongs to the room refresh the trust level
        if (roomMember)
        {
            [self triggerComputeTrust:NO];
        }
        
    } failure:^(NSError *error) {
        NSLog(@"[MXRoomSummary] trustLevelDidChangeRelatedToUserId fails to retrieve room members");
    }];
}

- (void)triggerComputeTrust:(BOOL)forceDownload
{
    if (!_isEncrypted || ![MXSDKOptions sharedInstance].computeE2ERoomSummaryTrust)
    {
        return;
    }
    
    // Decide what to do
    if (nextTrustComputation == MXRoomSummaryNextTrustComputationNone)
    {
        nextTrustComputation = forceDownload ? MXRoomSummaryNextTrustComputationPendingWithForceDownload
        : MXRoomSummaryNextTrustComputationPending;
    }
    else
    {
        if (forceDownload)
        {
            nextTrustComputation = MXRoomSummaryNextTrustComputationPendingWithForceDownload;
        }
        
        // Skip this request. Wait for the current one to finish
        NSLog(@"[MXRoomSummary] triggerComputeTrust: Skip it. A request is pending");
        return;
    }
    
    // TODO: To improve
    // This delay allows to gather multiple changes that occured in a room
    // and make only computation and request
    MXWeakify(self);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kMXRoomSummaryTrustComputationDelayMs * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        MXStrongifyAndReturnIfNil(self);

        BOOL forceDownload = (self->nextTrustComputation == MXRoomSummaryNextTrustComputationPendingWithForceDownload);
        self->nextTrustComputation = MXRoomSummaryNextTrustComputationNone;

        if (self.mxSession.state == MXSessionStateRunning)
        {
            [self computeTrust:forceDownload];
        }
        else
        {
            [self triggerComputeTrust:forceDownload];
        }
    });
}

- (void)computeTrust:(BOOL)forceDownload
{
    [self.room membersTrustLevelSummaryWithForceDownload:forceDownload success:^(MXUsersTrustLevelSummary *usersTrustLevelSummary) {
        
        self.trust = usersTrustLevelSummary;
        [self save:YES];
        
    } failure:^(NSError *error) {
        NSLog(@"[MXRoomSummary] computeTrust: fails to retrieve room members trusted progress");
    }];
}


#pragma mark - Others
- (NSUInteger)localUnreadEventCount
{
    // Check for unread events in store
    return [store localUnreadEventCount:_roomId withTypeIn:_mxSession.unreadEventTypes];
}

- (BOOL)isDirect
{
    return (self.directUserId != nil);
}

- (void)markAllAsRead
{
    [self.room markAllAsRead];
    
    _notificationCount = 0;
    _highlightCount = 0;
    
    // Broadcast the change
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXRoomSummaryDidChangeNotification object:self userInfo:nil];
}

#pragma mark - Server sync
- (void)handleStateEvents:(NSArray<MXEvent *> *)stateEvents
{
    if (stateEvents.count)
    {
        MXWeakify(self);
        [self.room state:^(MXRoomState *roomState) {
            MXStrongifyAndReturnIfNil(self);

            self->updatedWithStateEvents |= [self.mxSession.roomSummaryUpdateDelegate session:self.mxSession updateRoomSummary:self withStateEvents:stateEvents roomState:roomState];
        }];
    }
}

- (void)handleJoinedRoomSync:(MXRoomSync*)roomSync
{
    MXWeakify(self);
    [self.room state:^(MXRoomState *roomState) {
        MXStrongifyAndReturnIfNil(self);

        // Changes due to state events have been processed previously
        BOOL updated = self->updatedWithStateEvents;
        self->updatedWithStateEvents = NO;

        // Handle room summary sent by the home server
        // Call the method too in case of non lazy loading and no server room summary.
        // This will share the same algorithm to compute room name, avatar, members count.
        if (roomSync.summary || updated)
        {
            updated |= [self.mxSession.roomSummaryUpdateDelegate session:self.mxSession updateRoomSummary:self withServerRoomSummary:roomSync.summary roomState:roomState];
        }

        // Handle the last message starting by the most recent event.
        // Then, if the delegate refuses it as last message, pass the previous event.
        BOOL lastMessageUpdated = NO;
        MXRoomState *state = roomState;
        for (MXEvent *event in roomSync.timeline.events.reverseObjectEnumerator)
        {
            if (event.isState)
            {
                // Need to go backward in the state to provide it as it was when the event occured
                if (state.isLive)
                {
                    state = [state copy];
                    state.isLive = NO;
                }

                [state handleStateEvents:@[event]];
            }

            lastMessageUpdated = [self.mxSession.roomSummaryUpdateDelegate session:self.mxSession updateRoomSummary:self withLastEvent:event eventState:state roomState:roomState];
            if (lastMessageUpdated)
            {
                break;
            }
        }

        // Store notification counts from unreadNotifications field in /sync response
        if (roomSync.unreadNotifications)
        {
            // Caution: the server may provide a not null count whereas we know locally the user has read all room messages
            // (see for example this issue https://github.com/matrix-org/synapse/issues/2193).
            // Patch: Ignore the server information when the user has read all messages.
            if (roomSync.unreadNotifications.notificationCount && self.localUnreadEventCount == 0)
            {
                if (self.notificationCount != 0)
                {
                    self->_notificationCount = 0;
                    self->_highlightCount = 0;
                    updated = YES;
                }
            }
            else if (self.notificationCount != roomSync.unreadNotifications.notificationCount
                     || self.highlightCount != roomSync.unreadNotifications.highlightCount)
            {
                self->_notificationCount = roomSync.unreadNotifications.notificationCount;
                self->_highlightCount = roomSync.unreadNotifications.highlightCount;
                updated = YES;
            }
        }

        if (updated || lastMessageUpdated)
        {
            [self save:NO];
        }

    }];
}

- (void)handleInvitedRoomSync:(MXInvitedRoomSync*)invitedRoomSync
{
    MXWeakify(self);
    [self.room state:^(MXRoomState *roomState) {
        MXStrongifyAndReturnIfNil(self);

        BOOL updated = self->updatedWithStateEvents;
        self->updatedWithStateEvents = NO;

        // Fake the last message with the invitation event contained in invitedRoomSync.inviteState
        updated |= [self.mxSession.roomSummaryUpdateDelegate session:self.mxSession updateRoomSummary:self withLastEvent:invitedRoomSync.inviteState.events.lastObject eventState:nil roomState:roomState];

        if (updated)
        {
            [self save:NO];
        }
    }];
}


#pragma mark - Single update
- (void)handleEvent:(MXEvent*)event
{
    MXRoom *room = self.room;

    if (room)
    {
        MXWeakify(self);
        [self.room state:^(MXRoomState *roomState) {
            MXStrongifyAndReturnIfNil(self);

            BOOL updated = [self.mxSession.roomSummaryUpdateDelegate session:self.mxSession updateRoomSummary:self withLastEvent:event eventState:nil roomState:roomState];

            if (updated)
            {
                [self save:YES];
            }
        }];

    }
}


#pragma mark - NSCoding
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [self init];
    if (self)
    {
        _roomId = [aDecoder decodeObjectForKey:@"roomId"];

        _avatar = [aDecoder decodeObjectForKey:@"avatar"];
        _displayname = [aDecoder decodeObjectForKey:@"displayname"];
        _topic = [aDecoder decodeObjectForKey:@"topic"];
        _aliases = [aDecoder decodeObjectForKey:@"aliases"];
        _membership = (MXMembership)[aDecoder decodeIntegerForKey:@"membership"];
        _membersCount = [aDecoder decodeObjectForKey:@"membersCount"];
        _isConferenceUserRoom = [(NSNumber*)[aDecoder decodeObjectForKey:@"isConferenceUserRoom"] boolValue];

        _others = [aDecoder decodeObjectForKey:@"others"];
        _isEncrypted = [aDecoder decodeBoolForKey:@"isEncrypted"];
        _trust = [aDecoder decodeObjectForKey:@"trust"];
        _notificationCount = (NSUInteger)[aDecoder decodeIntegerForKey:@"notificationCount"];
        _highlightCount = (NSUInteger)[aDecoder decodeIntegerForKey:@"highlightCount"];
        _directUserId = [aDecoder decodeObjectForKey:@"directUserId"];

        _lastMessageEventId = [aDecoder decodeObjectForKey:@"lastMessageEventId"];
        _lastMessageOriginServerTs = [aDecoder decodeInt64ForKey:@"lastMessageOriginServerTs"];
        _isLastMessageEncrypted = [aDecoder decodeBoolForKey:@"isLastMessageEncrypted"];

        NSDictionary *lastMessageData;
        if (_isLastMessageEncrypted)
        {
            NSData *lastMessageEncryptedData = [aDecoder decodeObjectForKey:@"lastMessageEncryptedData"];
            NSData *lastMessageDataData = [self decrypt:lastMessageEncryptedData];
            lastMessageData = [NSKeyedUnarchiver unarchiveObjectWithData:lastMessageDataData];
        }
        else
        {
            lastMessageData = [aDecoder decodeObjectForKey:@"lastMessageData"];
        }
        _lastMessageString = lastMessageData[@"lastMessageString"];
        _lastMessageAttributedString = lastMessageData[@"lastMessageAttributedString"];
        _lastMessageOthers = lastMessageData[@"lastMessageOthers"];
        
        _hiddenFromUser = [aDecoder decodeBoolForKey:@"hiddenFromUser"];
        
        if (_isEncrypted && [MXSDKOptions sharedInstance].computeE2ERoomSummaryTrust)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self bootstrapTrustLevelComputation];
            });
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_roomId forKey:@"roomId"];

    [aCoder encodeObject:_avatar forKey:@"avatar"];
    [aCoder encodeObject:_displayname forKey:@"displayname"];
    [aCoder encodeObject:_topic forKey:@"topic"];
    [aCoder encodeObject:_aliases forKey:@"aliases"];
    [aCoder encodeInteger:(NSInteger)_membership forKey:@"membership"];
    [aCoder encodeObject:_membersCount forKey:@"membersCount"];
    [aCoder encodeObject:@(_isConferenceUserRoom) forKey:@"isConferenceUserRoom"];

    [aCoder encodeObject:_others forKey:@"others"];
    [aCoder encodeBool:_isEncrypted forKey:@"isEncrypted"];
    if (_trust)
    {
        [aCoder encodeObject:_trust forKey:@"trust"];
    }
    [aCoder encodeInteger:(NSInteger)_notificationCount forKey:@"notificationCount"];
    [aCoder encodeInteger:(NSInteger)_highlightCount forKey:@"highlightCount"];
    [aCoder encodeObject:_directUserId forKey:@"directUserId"];

    // Store last message metadata
    [aCoder encodeObject:_lastMessageEventId forKey:@"lastMessageEventId"];
    [aCoder encodeInt64:_lastMessageOriginServerTs forKey:@"lastMessageOriginServerTs"];
    [aCoder encodeBool:_isLastMessageEncrypted forKey:@"isLastMessageEncrypted"];

    // Build last message sensitive data
    NSMutableDictionary *lastMessageData = [NSMutableDictionary dictionary];
    if (_lastMessageString)
    {
        lastMessageData[@"lastMessageString"] = _lastMessageString;
    }
    if (_lastMessageAttributedString)
    {
        lastMessageData[@"lastMessageAttributedString"] = _lastMessageAttributedString;
    }
    if (_lastMessageOthers)
    {
        lastMessageData[@"lastMessageOthers"] = _lastMessageOthers;
    }

    // And encrypt it if necessary
    if (_isLastMessageEncrypted)
    {
        NSData *lastMessageDataData = [NSKeyedArchiver archivedDataWithRootObject:lastMessageData];
        NSData *lastMessageEncryptedData = [self encrypt:lastMessageDataData];

        if (lastMessageEncryptedData)
        {
            [aCoder encodeObject:lastMessageEncryptedData forKey:@"lastMessageEncryptedData"];
        }
    }
    else
    {
        [aCoder encodeObject:lastMessageData forKey:@"lastMessageData"];
    }
    
    [aCoder encodeBool:_hiddenFromUser forKey:@"hiddenFromUser"];
}


#pragma mark - Last message data encryption
/**
 The AES-256 key used for encrypting MXRoomSummary sensitive data.
 */
+ (NSData*)encryptionKey
{
    NSData *encryptionKey;

    // Create a dictionary to look up the key in the keychain
    NSDictionary *searchDict = @{
                                 (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                 (__bridge id)kSecAttrService: @"org.matrix.sdk.keychain",
                                 (__bridge id)kSecAttrAccount: @"MXRoomSummary",
                                 (__bridge id)kSecReturnData: (__bridge id)kCFBooleanTrue,
                                 };

    // Make the search
    CFDataRef foundKey = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)searchDict, (CFTypeRef*)&foundKey);

    if (status == errSecSuccess)
    {
        // Use the found key
        encryptionKey = (__bridge NSData*)(foundKey);
    }
    else if (status == errSecItemNotFound)
    {
        NSLog(@"[MXRoomSummary] encryptionKey: Generate the key and store it to the keychain");

        // There is not yet a key in the keychain
        // Generate an AES key
        NSMutableData *newEncryptionKey = [[NSMutableData alloc] initWithLength:kCCKeySizeAES256];
        int retval = SecRandomCopyBytes(kSecRandomDefault, kCCKeySizeAES256, newEncryptionKey.mutableBytes);
        if (retval == 0)
        {
            encryptionKey = [NSData dataWithData:newEncryptionKey];

            // Store it to the keychain
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:searchDict];
            dict[(__bridge id)kSecValueData] = encryptionKey;

            status = SecItemAdd((__bridge CFDictionaryRef)dict, NULL);
            if (status != errSecSuccess)
            {
                // TODO: The iOS 10 simulator returns the -34018 (errSecMissingEntitlement) error.
                // We need to fix it but there is no issue with the app on real device nor with iOS 9 simulator.
                NSLog(@"[MXRoomSummary] encryptionKey: SecItemAdd failed. status: %i", (int)status);
            }
        }
        else
        {
            NSLog(@"[MXRoomSummary] encryptionKey: Cannot generate key. retval: %i", retval);
        }
    }
    else
    {
        NSLog(@"[MXRoomSummary] encryptionKey: Keychain failed. OSStatus: %i", (int)status);
    }
    
    if (foundKey)
    {
        CFRelease(foundKey);
    }

    return encryptionKey;
}

- (NSData*)encrypt:(NSData*)data
{
    NSData *encryptedData;

    CCCryptorRef cryptor;
    CCCryptorStatus status;

    NSData *key = [MXRoomSummary encryptionKey];

    status = CCCryptorCreateWithMode(kCCDecrypt, kCCModeCTR, kCCAlgorithmAES,
                                     ccNoPadding, NULL, key.bytes, key.length,
                                     NULL, 0, 0, kCCModeOptionCTR_BE, &cryptor);
    if (status == kCCSuccess)
    {
        size_t bufferLength = CCCryptorGetOutputLength(cryptor, data.length, false);
        NSMutableData *buffer = [NSMutableData dataWithLength:bufferLength];

        size_t outLength;
        status |= CCCryptorUpdate(cryptor,
                                  data.bytes,
                                  data.length,
                                  [buffer mutableBytes],
                                  [buffer length],
                                  &outLength);

        status |= CCCryptorRelease(cryptor);

        if (status == kCCSuccess)
        {
            encryptedData = buffer;
        }
        else
        {
            NSLog(@"[MXRoomSummary] encrypt: CCCryptorUpdate failed. status: %i", status);
        }
    }
    else
    {
        NSLog(@"[MXRoomSummary] encrypt: CCCryptorCreateWithMode failed. status: %i", status);
    }

    return encryptedData;
}

- (NSData*)decrypt:(NSData*)encryptedData
{
    NSData *data;

    CCCryptorRef cryptor;
    CCCryptorStatus status;

    NSData *key = [MXRoomSummary encryptionKey];

    status = CCCryptorCreateWithMode(kCCDecrypt, kCCModeCTR, kCCAlgorithmAES,
                                     ccNoPadding, NULL, key.bytes, key.length,
                                     NULL, 0, 0, kCCModeOptionCTR_BE, &cryptor);
    if (status == kCCSuccess)
    {
        size_t bufferLength = CCCryptorGetOutputLength(cryptor, encryptedData.length, false);
        NSMutableData *buffer = [NSMutableData dataWithLength:bufferLength];

        size_t outLength;
        status |= CCCryptorUpdate(cryptor,
                                  encryptedData.bytes,
                                  encryptedData.length,
                                  [buffer mutableBytes],
                                  [buffer length],
                                  &outLength);

        status |= CCCryptorRelease(cryptor);

        if (status == kCCSuccess)
        {
            data = buffer;
        }
        else
        {
            NSLog(@"[MXRoomSummary] decrypt: CCCryptorUpdate failed. status: %i", status);
        }
    }
    else
    {
        NSLog(@"[MXRoomSummary] decrypt: CCCryptorCreateWithMode failed. status: %i", status);
    }
    
    return data;
}


- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ %@: %@ - %@", super.description, _roomId, _displayname, _lastMessageString];
}

@end
