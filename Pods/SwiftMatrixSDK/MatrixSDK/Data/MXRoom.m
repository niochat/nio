/*
 Copyright 2014 OpenMarket Ltd
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

#import "MXRoom.h"

#import "MXSession.h"
#import "MXTools.h"
#import "NSData+MatrixSDK.h"
#import "MXDecryptionResult.h"

#import "MXEncryptedAttachments.h"
#import "MXEncryptedContentFile.h"

#import "MXMediaManager.h"
#import "MXRoomOperation.h"
#import "MXSendReplyEventDefaultStringLocalizations.h"

#import "MXError.h"

NSString *const kMXRoomDidFlushDataNotification = @"kMXRoomDidFlushDataNotification";
NSString *const kMXRoomInitialSyncNotification = @"kMXRoomInitialSyncNotification";

@interface MXRoom ()
{
    /**
     The list of room operations (sending of text, images...) that must be sent
     in the same order as the user typed them.
     These operations are stored in a FIFO and executed one after the other.
     */
    NSMutableArray<MXRoomOperation*> *orderedOperations;

    /**
     The liveTimeline instance.
     Its data is loaded only when [self liveTimeline:] is called.
     */
    MXEventTimeline *liveTimeline;

    /**
     Flag to indicate that the data for `_liveTimeline` must be loaded before use.
     */
    BOOL needToLoadLiveTimeline;

    /**
     FIFO queue of objects waiting for [self liveTimeline:]. 
     */
    NSMutableArray<void (^)(MXEventTimeline *)> *pendingLiveTimelineRequesters;

    /**
     FIFO queue of success blocks waiting for [self members:].
     */
    NSMutableArray<void (^)(MXRoomMembers *)> *pendingMembersRequesters;
    
    /**
     FIFO queue of failure blocks waiting for [self members:].
     */
    NSMutableArray<void (^)(NSError *)> *pendingMembersFailureBlocks;
}
@end

@implementation MXRoom
@synthesize mxSession;

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _accountData = [[MXRoomAccountData alloc] init];

        _typingUsers = [NSArray array];
        
        orderedOperations = [NSMutableArray array];

        needToLoadLiveTimeline = NO;
    }
    
    return self;
}

- (id)initWithRoomId:(NSString *)roomId andMatrixSession:(MXSession *)mxSession2
{
    // Let's the live MXEventTimeline use its default store.
    return [self initWithRoomId:roomId matrixSession:mxSession2 andStore:nil];
}

- (id)initWithRoomId:(NSString *)roomId matrixSession:(MXSession *)mxSession2 andStore:(id<MXStore>)store
{
    self = [self init];
    if (self)
    {
        _roomId = roomId;
        mxSession = mxSession2;

        if (store)
        {
            liveTimeline = [[MXEventTimeline alloc] initWithRoom:self initialEventId:nil andStore:store];
        }
        else
        {
            // Let the timeline use the session store
            liveTimeline = [[MXEventTimeline alloc] initWithRoom:self andInitialEventId:nil];
        }
        
        // Update the stored outgoing messages, by removing the sent messages and tagging as failed the others.
        [self refreshOutgoingMessages];
    }
    return self;
}

+ (id)loadRoomFromStore:(id<MXStore>)store withRoomId:(NSString *)roomId matrixSession:(MXSession *)matrixSession
{
    MXRoom *room = [[MXRoom alloc] initWithRoomId:roomId andMatrixSession:matrixSession];
    if (room)
    {
        MXRoomAccountData *accountData = [store accountDataOfRoom:roomId];

        room->needToLoadLiveTimeline = YES;

        // Report the provided accountData.
        // Allocate a new instance if none, in order to handle room tag events for this room.
        room->_accountData = accountData ? accountData : [[MXRoomAccountData alloc] init];

        // Check whether the room is pending on an invitation.
        if (room.summary.membership == MXMembershipInvite)
        {
            // Handle direct flag to decide if it is direct or not
            [room handleInviteDirectFlag];
        }
    }
    return room;
}

- (void)close
{
    // Clean MXRoom
    [liveTimeline removeAllListeners];
}

#pragma mark - Properties implementation
- (MXRoomSummary *)summary
{
    // That makes self.summary a really weak reference
    return [mxSession roomSummaryWithRoomId:_roomId];
}

- (void)liveTimeline:(void (^)(MXEventTimeline *))onComplete
{
    // Is timelime ready?
    if (needToLoadLiveTimeline || pendingLiveTimelineRequesters)
    {
        // Queue the requester
        if (!pendingLiveTimelineRequesters)
        {
            pendingLiveTimelineRequesters = [NSMutableArray array];

            MXWeakify(self);
            [MXRoomState loadRoomStateFromStore:self.mxSession.store withRoomId:self.roomId matrixSession:self.mxSession onComplete:^(MXRoomState *roomState) {
                MXStrongifyAndReturnIfNil(self);

                [self->liveTimeline setState:roomState];

                // Provide the timelime to pending requesters
                NSArray<void (^)(MXEventTimeline *)> *liveTimelineRequesters = [self->pendingLiveTimelineRequesters copy];
                self->pendingLiveTimelineRequesters = nil;

                for (void (^onRequesterComplete)(MXEventTimeline *) in liveTimelineRequesters)
                {
                    onRequesterComplete(self->liveTimeline);
                }
                NSLog(@"[MXRoom] liveTimeline loaded. Pending requesters: %@", @(liveTimelineRequesters.count));
            }];
        }

        [pendingLiveTimelineRequesters addObject:onComplete];

        self->needToLoadLiveTimeline = NO;
    }
    else
    {
        onComplete(liveTimeline);
    }
}

- (void)state:(void (^)(MXRoomState *))onComplete
{
    [self liveTimeline:^(MXEventTimeline *theLiveTimeline) {
        onComplete(theLiveTimeline.state);
    }];
}

- (MXHTTPOperation *)members:(void (^)(MXRoomMembers *roomMembers))success
                    failure:(void (^)(NSError *error))failure
{
    return [self members:success lazyLoadedMembers:nil failure:failure];
}

- (MXHTTPOperation*)members:(void (^)(MXRoomMembers *members))success
          lazyLoadedMembers:(void (^)(MXRoomMembers *lazyLoadedMembers))lazyLoadedMembers
                    failure:(void (^)(NSError *error))failure
{
    // Create an empty operation that will be mutated later
    MXHTTPOperation *operation = [[MXHTTPOperation alloc] init];

    MXWeakify(self);
    [self liveTimeline:^(MXEventTimeline *liveTimeline) {
        MXStrongifyAndReturnIfNil(self);

        // Return directly liveTimeline.state.members if we have already all of them
        if ([self.mxSession.store hasLoadedAllRoomMembersForRoom:self.roomId])
        {
            success(liveTimeline.state.members);
        }
        else
        {
            // Return already lazy-loaded room members if requested
            if (lazyLoadedMembers)
            {
                lazyLoadedMembers(liveTimeline.state.members);
            }

            // Queue the requester
            if (!self->pendingMembersRequesters)
            {
                self->pendingMembersRequesters = [NSMutableArray array];
                self->pendingMembersFailureBlocks = [NSMutableArray array];

                // Else get them from the homeserver
                NSDictionary *parameters;
                if (self.mxSession.store.eventStreamToken)
                {
                    parameters = @{
                                   kMXMembersOfRoomParametersAt: self.mxSession.store.eventStreamToken,
                                   kMXMembersOfRoomParametersNotMembership: kMXMembershipStringLeave
                                   };
                }

                MXWeakify(self);
                MXHTTPOperation *operation2 = [self.mxSession.matrixRestClient membersOfRoom:self.roomId
                                                                              withParameters:parameters
                                                                                     success:^(NSArray *roomMemberEvents)
                {
                    MXStrongifyAndReturnIfNil(self);

                    // Manage the possible race condition where we could have received
                    // update of members from the events stream (/sync) while the /members
                    // request was pending.
                    // In that case, the response of /members is not up-to-date. We must not
                    // use this response as is.
                    // To fix that:
                    //    - we consider that all lazy-loaded members are up-to-date
                    //    - we ignore in the /member response all member events corresponding
                    //      to these already lazy-loaded members
                    NSMutableArray *updatedRoomMemberEvents = [NSMutableArray array];
                    for (MXEvent *roomMemberEvent in roomMemberEvents)
                    {
                        if (![liveTimeline.state.members memberWithUserId:roomMemberEvent.stateKey])
                        {
                            // User not lazy loaded yet, keep their member event from /members response
                            [updatedRoomMemberEvents addObject:roomMemberEvent];
                        }
                    }
                    roomMemberEvents = updatedRoomMemberEvents;

                    // Check if the room has not been left while waiting for the response
                    if ([self.mxSession hasRoomWithRoomId:self.roomId])
                    {
                        [liveTimeline handleLazyLoadedStateEvents:roomMemberEvents];

                        [self.mxSession.store storeHasLoadedAllRoomMembersForRoom:self.roomId andValue:YES];
                        if ([self.mxSession.store respondsToSelector:@selector(commit)])
                        {
                            [self.mxSession.store commit];
                        }
                    }

                    // Provide the members to pending requesters
                    NSArray<void (^)(MXRoomMembers *)> *pendingMembersRequesters = [self->pendingMembersRequesters copy];
                    self->pendingMembersRequesters = nil;
                    self->pendingMembersFailureBlocks = nil;

                    for (void (^onRequesterComplete)(MXRoomMembers *) in pendingMembersRequesters)
                    {
                        onRequesterComplete(liveTimeline.state.members);
                    }
                    NSLog(@"[MXRoom] members loaded. Pending requesters: %@", @(pendingMembersRequesters.count));

                } failure:^(NSError *error) {
                    // Notify the failure to the pending requesters
                    NSArray<void (^)(NSError *)> *pendingRequesters = [self->pendingMembersFailureBlocks copy];
                    self->pendingMembersRequesters = nil;
                    self->pendingMembersFailureBlocks = nil;
                    
                    for (void (^onFailure)(NSError *) in pendingRequesters)
                    {
                        onFailure(error);
                    }
                    NSLog(@"[MXRoom] get members failed. Pending requesters: %@", @(pendingRequesters.count));
                }];

                [operation mutateTo:operation2];
            }

            if (success)
            {
                [self->pendingMembersRequesters addObject:success];
            }
            
            if (failure)
            {
                [self->pendingMembersFailureBlocks addObject:failure];
            }
        }
    }];

    return operation;
}


- (void)setPartialTextMessage:(NSString *)partialTextMessage
{
    [mxSession.store storePartialTextMessageForRoom:self.roomId partialTextMessage:partialTextMessage];
    if ([mxSession.store respondsToSelector:@selector(commit)])
    {
        [mxSession.store commit];
    }
}

- (NSString *)partialTextMessage
{
    return [mxSession.store partialTextMessageOfRoom:self.roomId];
}


#pragma mark - Sync
- (void)handleJoinedRoomSync:(MXRoomSync *)roomSync
{
    MXWeakify(self);
    [self liveTimeline:^(MXEventTimeline *theLiveTimeline) {
        MXStrongifyAndReturnIfNil(self);

        // Let the live timeline handle live events
        [theLiveTimeline handleJoinedRoomSync:roomSync];

        // Handle here ephemeral events (if any)
        for (MXEvent *event in roomSync.ephemeral.events)
        {
            // Report the room id in the event as it is skipped in /sync response
            event.roomId = self.roomId;

            // Handle first typing notifications
            if (event.eventType == MXEventTypeTypingNotification)
            {
                // Typing notifications events are not room messages nor room state events
                // They are just volatile information
                MXJSONModelSetArray(self->_typingUsers, event.content[@"user_ids"]);

                // Notify listeners
                [theLiveTimeline notifyListeners:event direction:MXTimelineDirectionForwards];
            }
            else if (event.eventType == MXEventTypeReceipt)
            {
                [self handleReceiptEvent:event direction:MXTimelineDirectionForwards];
            }
        }

        // Handle account data events (if any)
        [self handleAccounDataEvents:roomSync.accountData.events liveTimeline:theLiveTimeline direction:MXTimelineDirectionForwards];
    }];
}

- (void)handleInvitedRoomSync:(MXInvitedRoomSync *)invitedRoomSync
{
    [self liveTimeline:^(MXEventTimeline *theLiveTimeline) {

        // Let the live timeline handle live events
        [theLiveTimeline handleInvitedRoomSync:invitedRoomSync];

        // Handle direct flag to decide if it is direct or not
        [self handleInviteDirectFlag];
    }];
}

- (void)handleInviteDirectFlag
{
    // Handle here invite data to decide if it is direct or not
    MXWeakify(self);
    [self state:^(MXRoomState *roomState) {
        MXStrongifyAndReturnIfNil(self);

        // We can use roomState.members because, even in case of lazy loading of room members,
        // my user must be in roomState.members
        MXRoomMembers *roomMembers = roomState.members;
        MXRoomMember *myUser = [roomMembers memberWithUserId:self.mxSession.myUserId];
        BOOL isDirect = NO;

        if (myUser.originalEvent.content[@"is_direct"])
        {
            isDirect = [((NSNumber*)myUser.originalEvent.content[@"is_direct"]) boolValue];
        }

        if (isDirect)
        {
            // Mark as direct this room with the invite sender.
            [self setIsDirect:YES withUserId:myUser.originalEvent.sender success:nil failure:^(NSError *error) {
                NSLog(@"[MXRoom] Failed to tag an invite as a direct chat");
            }];
        }
    }];
}

#pragma mark - Room private account data handling
/**
 Handle private user data events.

 @param accounDataEvents the events to handle.
 @param direction the process direction: MXTimelineDirectionSync or MXTimelineDirectionForwards. MXTimelineDirectionBackwards is not applicable here.
 */
- (void)handleAccounDataEvents:(NSArray<MXEvent*>*)accounDataEvents liveTimeline:(MXEventTimeline*)theLiveTimeline direction:(MXTimelineDirection)direction
{
    for (MXEvent *event in accounDataEvents)
    {
        [_accountData handleEvent:event];

        // Update the store
        if ([mxSession.store respondsToSelector:@selector(storeAccountDataForRoom:userData:)])
        {
            [mxSession.store storeAccountDataForRoom:self.roomId userData:_accountData];
        }

        // And notify listeners
        [theLiveTimeline notifyListeners:event direction:direction];
    }
}


#pragma mark - Stored messages enumerator
- (id<MXEventsEnumerator>)enumeratorForStoredMessages
{
    return [mxSession.store messagesEnumeratorForRoom:self.roomId];
}

- (id<MXEventsEnumerator>)enumeratorForStoredMessagesWithTypeIn:(NSArray<MXEventTypeString> *)types
{
    return [mxSession.store messagesEnumeratorForRoom:self.roomId withTypeIn:types];
}

- (NSUInteger)storedMessagesCount
{
    NSUInteger storedMessagesCount = 0;

    @autoreleasepool
    {
        // Note: For performance, it may worth to have a dedicated MXStore method to get
        // this value
        storedMessagesCount = self.enumeratorForStoredMessages.remaining;
    }

    return storedMessagesCount;
}


#pragma mark - Room operations
- (MXHTTPOperation*)sendEventOfType:(MXEventTypeString)eventTypeString
                            content:(NSDictionary*)content
                          localEcho:(MXEvent**)localEcho
                            success:(void (^)(NSString *eventId))success
                            failure:(void (^)(NSError *error))failure
{

    __block MXRoomOperation *roomOperation;

    __block MXEvent *event;
    if (localEcho)
    {
        event = *localEcho;
    }

    // Protect the SDK against changes in `content`
    // It is useful in case of:
    //    - e2e encryption where several asynchronous requests may be required before actually sending the event
    //    - message order mechanism where events may be queued
    NSDictionary *contentCopy = [[NSDictionary alloc] initWithDictionary:content copyItems:YES];

    void(^onSuccess)(NSString *) = ^(NSString *eventId) {

        if (event)
        {
            // Update the local echo with its actual identifier (by keeping the initial id).
            NSString *localEventId = event.eventId;
            event.eventId = eventId;

            // Update the local echo state (This will trigger kMXEventDidChangeSentStateNotification notification).
            event.sentState = MXEventSentStateSent;

            // Update stored echo.
            // We keep this event here as local echo to handle correctly outgoing messages from multiple devices.
            // The echo will be removed when the corresponding event will come through the server sync.
            [self updateOutgoingMessage:localEventId withOutgoingMessage:event];
        }

        if (success)
        {
            success(eventId);
        }

        [self handleNextOperationAfter:roomOperation];
    };

    void(^onFailure)(NSError *) = ^(NSError *error) {

        if (event)
        {
            // Update the local echo with the error state (This will trigger kMXEventDidChangeSentStateNotification notification).
            event.sentError = error;
            event.sentState = MXEventSentStateFailed;

            // Update the stored echo.
            [self updateOutgoingMessage:event.eventId withOutgoingMessage:event];
        }

        if (failure)
        {
            failure(error);
        }

        [self handleNextOperationAfter:roomOperation];
    };

    // Check whether the content must be encrypted before sending
    if (mxSession.crypto
        && self.summary.isEncrypted
        && [self isEncryptionRequiredForEventType:eventTypeString])
    {
        // Check whether the provided content is already encrypted
        if ([eventTypeString isEqualToString:kMXEventTypeStringRoomEncrypted])
        {
            // We handle here the case where we have to resent an encrypted message event.
            if (event)
            {
                // Update the local echo sent state.
                event.sentState = MXEventSentStateSending;

                // Update the stored echo.
                [self updateOutgoingMessage:event.eventId withOutgoingMessage:event];
            }

            roomOperation = [self preserveOperationOrder:event block:^{
                MXHTTPOperation *operation = [self _sendEventOfType:eventTypeString content:contentCopy txnId:event.eventId success:onSuccess failure:onFailure];
                [roomOperation.operation mutateTo:operation];
            }];
        }
        else
        {
            NSDictionary *relatesToJSON = nil;
            
            NSDictionary *contentCopyToEncrypt = nil;
            
            // Store the "m.relates_to" data and remove them from event clear content before encrypting the event content
            if (contentCopy[@"m.relates_to"])
            {
                relatesToJSON = contentCopy[@"m.relates_to"];
                NSMutableDictionary *updatedContent = [contentCopy mutableCopy];
                updatedContent[@"m.relates_to"] = nil;
                contentCopyToEncrypt = [updatedContent copy];
            }
            else
            {
                contentCopyToEncrypt = contentCopy;
            }
            
            // Check whether a local echo is required
            if ([eventTypeString isEqualToString:kMXEventTypeStringRoomMessage]
                || [eventTypeString isEqualToString:kMXEventTypeStringSticker])
            {
                if (!event)
                {
                    // Add a local echo for this message during the sending process.
                    event = [self addLocalEchoForMessageContent:contentCopy eventType:eventTypeString withState:MXEventSentStateEncrypting];

                    if (localEcho)
                    {
                        // Return the created event.
                        *localEcho = event;
                    }
                }
                else
                {
                    // Update the local echo state (This will trigger kMXEventDidChangeSentStateNotification notification).
                    event.sentState = MXEventSentStateEncrypting;

                    // Update the stored echo.
                    [self updateOutgoingMessage:event.eventId withOutgoingMessage:event];
                }
            }

            MXWeakify(self);
            roomOperation = [self preserveOperationOrder:event block:^{
                MXStrongifyAndReturnIfNil(self);

                NSLog(@"[MXRoom] sendEventOfType(MXCrypto): Encrypting event %@", event.eventId);

                MXWeakify(self);
                MXHTTPOperation *operation = [self->mxSession.crypto encryptEventContent:contentCopyToEncrypt withType:eventTypeString inRoom:self success:^(NSDictionary *encryptedContent, NSString *encryptedEventType) {
                    MXStrongifyAndReturnIfNil(self);

                    NSLog(@"[MXRoom] sendEventOfType(MXCrypto): Encrypt event %@ -> DONE using sessionId: %@", event.eventId, encryptedContent[@"session_id"]);

                    NSDictionary *finalEncryptedContent;
                    
                    // Add "m.relates_to" to encrypted event content if any
                    if (relatesToJSON)
                    {
                        NSMutableDictionary *updatedEncryptedContent = [encryptedContent mutableCopy];
                        updatedEncryptedContent[@"m.relates_to"] = relatesToJSON;
                        finalEncryptedContent = [updatedEncryptedContent copy];
                    }
                    else
                    {
                        finalEncryptedContent = encryptedContent;
                    }
                    
                    if (event)
                    {
                        // Encapsulate the resulting event in a fake encrypted event
                        MXEvent *clearEvent = [self fakeEventWithEventId:event.eventId eventType:eventTypeString andContent:event.content];

                        event.wireType = encryptedEventType;
                        event.wireContent = finalEncryptedContent;

                        MXEventDecryptionResult *decryptionResult = [[MXEventDecryptionResult alloc] init];
                        decryptionResult.clearEvent = clearEvent.JSONDictionary;
                        decryptionResult.senderCurve25519Key = self.mxSession.crypto.deviceCurve25519Key;
                        decryptionResult.claimedEd25519Key = self.mxSession.crypto.deviceEd25519Key;

                        [event setClearData:decryptionResult];

                        // Update the local echo state (This will trigger kMXEventDidChangeSentStateNotification notification).
                        event.sentState = MXEventSentStateSending;

                        // Update stored echo.
                        [self updateOutgoingMessage:event.eventId withOutgoingMessage:event];
                    }

                    // Send the encrypted content
                    MXHTTPOperation *operation2 = [self _sendEventOfType:encryptedEventType content:finalEncryptedContent txnId:event.eventId success:^(NSString *eventId) {

                        NSLog(@"[MXRoom] sendEventOfType(MXCrypto): Send event %@ -> DONE. Final event id: %@", event.eventId, eventId);
                        onSuccess(eventId);

                    } failure:onFailure];

                    if (operation2)
                    {
                        // Mutate MXHTTPOperation so that the user can cancel this new operation
                        [roomOperation.operation mutateTo:operation2];
                    }

                } failure:^(NSError *error) {

                    NSLog(@"[MXRoom] sendEventOfType(MXCrypto): Cannot encrypt event %@. Error: %@", event.eventId, error);

                    onFailure(error);
                }];

                [roomOperation.operation mutateTo:operation];
            }];
        }
    }
    else
    {
        // Check whether a local echo is required
        if ([eventTypeString isEqualToString:kMXEventTypeStringRoomMessage]
            || [eventTypeString isEqualToString:kMXEventTypeStringSticker])
        {
            if (!event)
            {
                // Add a local echo for this message during the sending process.
                event = [self addLocalEchoForMessageContent:contentCopy eventType:eventTypeString withState:MXEventSentStateSending];

                if (localEcho)
                {
                    // Return the created event.
                    *localEcho = event;
                }
            }
            else
            {
                // Update the local echo state (This will trigger kMXEventDidChangeSentStateNotification notification).
                event.sentState = MXEventSentStateSending;

                // Update the stored echo. It will be used to suppress this echo in [self pendingLocalEchoRelatedToEvent];
                [self updateOutgoingMessage:event.eventId withOutgoingMessage:event];
            }
        }

        roomOperation = [self preserveOperationOrder:event block:^{
            MXHTTPOperation *operation = [self _sendEventOfType:eventTypeString content:contentCopy txnId:event.eventId success:onSuccess failure:onFailure];
            [roomOperation.operation mutateTo:operation];
        }];
    }

    return roomOperation.operation;
}

- (MXHTTPOperation*)_sendEventOfType:(MXEventTypeString)eventTypeString
                            content:(NSDictionary*)content
                            txnId:(NSString*)txnId
                            success:(void (^)(NSString *eventId))success
                            failure:(void (^)(NSError *error))failure
{
    return [mxSession.matrixRestClient sendEventToRoom:self.roomId eventType:eventTypeString content:content txnId:txnId success:success failure:failure];
}

- (MXHTTPOperation*)sendStateEventOfType:(MXEventTypeString)eventTypeString
                                 content:(NSDictionary*)content
                                stateKey:(NSString *)stateKey
                                 success:(void (^)(NSString *eventId))success
                                 failure:(void (^)(NSError *error))failure
{
    return [mxSession.matrixRestClient sendStateEventToRoom:self.roomId eventType:eventTypeString content:content stateKey:stateKey success:success failure:failure];
}

- (MXHTTPOperation*)sendMessageWithContent:(NSDictionary*)content
                                 localEcho:(MXEvent**)localEcho
                                   success:(void (^)(NSString *eventId))success
                                   failure:(void (^)(NSError *error))failure
{
    return [self sendEventOfType:kMXEventTypeStringRoomMessage content:content localEcho:localEcho success:success failure:failure];
}

- (MXHTTPOperation*)sendTextMessage:(NSString*)text
                      formattedText:(NSString*)formattedText
                          localEcho:(MXEvent**)localEcho
                            success:(void (^)(NSString *eventId))success
                            failure:(void (^)(NSError *error))failure
{
    // Prepare the message content
    NSDictionary *msgContent;
    if (!formattedText)
    {
        // This is a simple text message
        msgContent = @{
                       @"msgtype": kMXMessageTypeText,
                       @"body": text
                       };
    }
    else
    {
        // Send the HTML formatted string
        msgContent = @{
                       @"msgtype": kMXMessageTypeText,
                       @"body": text,
                       @"formatted_body": formattedText,
                       @"format": kMXRoomMessageFormatHTML
                       };
    }
    
    return [self sendMessageWithContent:msgContent
                              localEcho:localEcho
                                success:success
                                failure:failure];
}

- (MXHTTPOperation *)sendTextMessage:(NSString *)text
                             success:(void (^)(NSString *))success
                             failure:(void (^)(NSError *))failure
{
    return [self sendTextMessage:text formattedText:nil localEcho:nil success:success failure:failure];
}

- (MXHTTPOperation*)sendEmote:(NSString*)emoteBody
                formattedText:(NSString*)formattedBody
                    localEcho:(MXEvent**)localEcho
                      success:(void (^)(NSString *eventId))success
                      failure:(void (^)(NSError *error))failure
{
    // Prepare the message content
    NSDictionary *msgContent;
    if (!formattedBody)
    {
        // This is a simple text message
        msgContent = @{
                       @"msgtype": kMXMessageTypeEmote,
                       @"body": emoteBody
                       };
    }
    else
    {
        // Send the HTML formatted string
        msgContent = @{
                       @"msgtype": kMXMessageTypeEmote,
                       @"body": emoteBody,
                       @"formatted_body": formattedBody,
                       @"format": kMXRoomMessageFormatHTML
                       };
    }
    
    return [self sendMessageWithContent:msgContent
                              localEcho:localEcho
                                success:success
                                failure:failure];
}

- (MXHTTPOperation*)sendImage:(NSData*)imageData
                withImageSize:(CGSize)imageSize
                     mimeType:(NSString*)mimetype
#if TARGET_OS_IPHONE
                 andThumbnail:(UIImage*)thumbnail
#elif TARGET_OS_OSX
                 andThumbnail:(NSImage*)thumbnail
#endif
                    localEcho:(MXEvent**)localEcho
                      success:(void (^)(NSString *eventId))success
                      failure:(void (^)(NSError *error))failure
{
    __block MXRoomOperation *roomOperation;

    double endRange = 1.0;
    
    // Check whether the content must be encrypted before sending
    if (mxSession.crypto && self.summary.isEncrypted) endRange = 0.9;
    
    // Use the uploader id as fake URL for this image data
    // The URL does not need to be valid as the MediaManager will get the data
    // directly from its cache
    // Pass this id in the URL is a nasty trick to retrieve it later
    MXMediaLoader *uploader = [MXMediaManager prepareUploaderWithMatrixSession:mxSession initialRange:0 andRange:endRange];
    NSString *fakeMediaURI = uploader.uploadId;
    
    NSString *cacheFilePath = [MXMediaManager cachePathForMatrixContentURI:fakeMediaURI andType:mimetype inFolder:self.roomId];
    [MXMediaManager writeMediaData:imageData toFilePath:cacheFilePath];
    
    // Create a fake image name based on imageData to keep the same name for the same image.
    NSString *dataHash = [imageData mx_MD5];
    if (dataHash.length > 7)
    {
        // Crop
        dataHash = [dataHash substringToIndex:7];
    }
    NSString *extension = [MXTools fileExtensionFromContentType:mimetype];
    NSString *filename = [NSString stringWithFormat:@"ima_%@%@", dataHash, extension];
    
    // Prepare the message content for building an echo message
    NSMutableDictionary *msgContent = [@{
                                         @"msgtype": kMXMessageTypeImage,
                                         @"body": filename,
                                         @"url": fakeMediaURI,
                                         @"info": [@{
                                                     @"mimetype": mimetype,
                                                     @"w": @(imageSize.width),
                                                     @"h": @(imageSize.height),
                                                     @"size": @(imageData.length)
                                                     } mutableCopy]
                                         } mutableCopy];
    
    __block MXEvent *event;
    __block id uploaderObserver;

    void(^onSuccess)(NSString *) = ^(NSString *eventId) {

        if (success)
        {
            success(eventId);
        }

        [self handleNextOperationAfter:roomOperation];
    };

    void(^onFailure)(NSError *) = ^(NSError *error) {
        
        // Remove outgoing message when its sent has been cancelled
        if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled)
        {
            [self removeOutgoingMessage:event.eventId];
        }
        else
        {
            // Update the local echo with the error state (This will trigger kMXEventDidChangeSentStateNotification notification).
            event.sentError = error;
            event.sentState = MXEventSentStateFailed;

            // Update the stored echo.
            [self updateOutgoingMessage:event.eventId withOutgoingMessage:event];
        }
        
        if (uploaderObserver)
        {
            [[NSNotificationCenter defaultCenter] removeObserver:uploaderObserver];
            uploaderObserver = nil;
        }
        
        if (failure)
        {
            failure(error);
        }

        [self handleNextOperationAfter:roomOperation];
    };
    
    // Add a local echo for this message during the sending process.
    MXEventSentState initialSentState = (mxSession.crypto && self.summary.isEncrypted) ? MXEventSentStateEncrypting : MXEventSentStateUploading;
    event = [self addLocalEchoForMessageContent:msgContent eventType:kMXEventTypeStringRoomMessage withState:initialSentState];
    
    if (localEcho)
    {
        // Return the created event.
        *localEcho = event;
    }

    MXWeakify(self);
    roomOperation = [self preserveOperationOrder:event block:^{
        MXStrongifyAndReturnIfNil(self);

        // Check whether the content must be encrypted before sending
        if (self.mxSession.crypto && self.summary.isEncrypted)
        {
            // Add uploader observer to update the event state
            MXWeakify(self);
            uploaderObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXMediaLoaderStateDidChangeNotification object:uploader queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {

                MXStrongifyAndReturnIfNil(self);
                MXMediaLoader *loader = (MXMediaLoader*)notif.object;
                
                // Consider only the upload progress state.
                switch (loader.state) {
                    case MXMediaLoaderStateUploadInProgress:
                    {
                        NSNumber* progressNumber = [loader.statisticsDict valueForKey:kMXMediaLoaderProgressValueKey];
                        if (progressNumber.floatValue)
                        {
                            event.sentState = MXEventSentStateUploading;
                            
                            // Update the stored echo.
                            [self updateOutgoingMessage:event.eventId withOutgoingMessage:event];
                            
                            [[NSNotificationCenter defaultCenter] removeObserver:uploaderObserver];
                            uploaderObserver = nil;
                        }
                        break;
                    }
                    default:
                        break;
                }
            }];

            NSURL *localURL = [NSURL URLWithString:cacheFilePath];
            [MXEncryptedAttachments encryptAttachment:uploader mimeType:mimetype localUrl:localURL success:^(MXEncryptedContentFile *result) {

                [msgContent removeObjectForKey:@"url"];
                msgContent[@"file"] = result.JSONDictionary;

                void(^onDidUpload)(void) = ^{

                    // Do not go further if the orignal request has been cancelled
                    if (roomOperation.isCancelled)
                    {
                        [self handleNextOperationAfter:roomOperation];
                        return;
                    }

                    // Send this content (the sent state of the local echo will be updated, its local storage too).
                    MXHTTPOperation *operation2 = [self sendMessageWithContent:msgContent localEcho:&event success:onSuccess failure:onFailure];

                    // Retrieve the MXRoomOperation just created for operation2
                    // And use it as the current operation
                    MXRoomOperation *roomOperation2 = [self roomOperationWithHTTPOperation:operation2];
                    [self mutateRoomOperation:roomOperation to:roomOperation2];
                };

                if (!thumbnail)
                {
                    onDidUpload();
                }
                else
                {
                    // Update the stored echo.
                    [self updateOutgoingMessage:event.eventId withOutgoingMessage:event];

                    MXMediaLoader *thumbUploader = [MXMediaManager prepareUploaderWithMatrixSession:self.mxSession initialRange:0.9 andRange:1];

#if TARGET_OS_IPHONE
                    NSData *pngImageData = UIImagePNGRepresentation(thumbnail);
#elif TARGET_OS_OSX
                    CGImageRef cgRef = [thumbnail CGImageForProposedRect:NULL context:nil hints:nil];
                    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
                    [newRep setSize:[thumbnail size]];
                    NSData *pngImageData = [newRep representationUsingType:NSPNGFileType properties:@{}];
#endif

                    [MXEncryptedAttachments encryptAttachment:thumbUploader mimeType:@"image/png" data:pngImageData success:^(MXEncryptedContentFile *result) {

                        msgContent[@"info"][@"thumbnail_file"] = result.JSONDictionary;

                        onDidUpload();

                    } failure:onFailure];
                }
            } failure:onFailure];
        }
        else
        {
            // Launch the upload to the Matrix Content repository
            [uploader uploadData:imageData filename:filename mimeType:mimetype success:^(NSString *url) {

                // Do not go further if the orignal request has been cancelled
                if (roomOperation.isCancelled)
                {
                    [self handleNextOperationAfter:roomOperation];
                    return;
                }

                // Copy the cached image to the actual cacheFile path
                NSString *actualCacheFilePath = [MXMediaManager cachePathForMatrixContentURI:url andType:mimetype inFolder:self.roomId];
                NSError *error;
                [[NSFileManager defaultManager] copyItemAtPath:cacheFilePath toPath:actualCacheFilePath error:&error];

                // Update the message content with the mxc:// of the media on the homeserver
                msgContent[@"url"] = url;

                // Make the final request that posts the image event (the sent state of the local echo will be updated, its local storage too).
                MXHTTPOperation *operation2 = [self sendMessageWithContent:msgContent localEcho:&event success:onSuccess failure:onFailure];

                // Retrieve the MXRoomOperation just created for operation2
                // And use it as the current operation
                MXRoomOperation *roomOperation2 = [self roomOperationWithHTTPOperation:operation2];
                [self mutateRoomOperation:roomOperation to:roomOperation2];

            } failure:onFailure];
        }
    }];

    return roomOperation.operation;
}

- (MXHTTPOperation*)sendVideo:(NSURL*)videoLocalURL
#if TARGET_OS_IPHONE
                withThumbnail:(UIImage*)videoThumbnail
#elif TARGET_OS_OSX
                withThumbnail:(NSImage*)videoThumbnail
#endif
                    localEcho:(MXEvent**)localEcho
                      success:(void (^)(NSString *eventId))success
                      failure:(void (^)(NSError *error))failure
{
    __block MXRoomOperation *roomOperation;

#if TARGET_OS_IPHONE
    NSData *videoThumbnailData = UIImageJPEGRepresentation(videoThumbnail, 0.8);
#elif TARGET_OS_OSX
    CGImageRef cgRef = [videoThumbnail CGImageForProposedRect:NULL context:nil hints:nil];
    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
    [newRep setSize:[videoThumbnail size]];
    NSData *videoThumbnailData = [newRep representationUsingType:NSJPEGFileType properties: @{NSImageCompressionFactor: @0.8}];
#endif
    
    // Use the uploader id as fake URL for this image data
    // The URL does not need to be valid as the MediaManager will get the data
    // directly from its cache
    // Pass this id in the URL is a nasty trick to retrieve it later
    MXMediaLoader *thumbUploader = [MXMediaManager prepareUploaderWithMatrixSession:self.mxSession initialRange:0 andRange:0.1];
    NSString *fakeMediaURI = thumbUploader.uploadId;
    
    NSString *cacheFilePath = [MXMediaManager cachePathForMatrixContentURI:fakeMediaURI andType:@"image/jpeg" inFolder:self.roomId];
    [MXMediaManager writeMediaData:videoThumbnailData toFilePath:cacheFilePath];
    
    // Prepare the message content for building an echo message
    NSMutableDictionary *msgContent = [@{
                                         @"msgtype": kMXMessageTypeVideo,
                                         @"body": @"Video",
                                         @"url": fakeMediaURI,
                                         @"info": [@{
                                                     @"thumbnail_url": fakeMediaURI,
                                                     @"thumbnail_info": @{
                                                             @"mimetype": @"image/jpeg",
                                                             @"w": @(videoThumbnail.size.width),
                                                             @"h": @(videoThumbnail.size.height),
                                                             @"size": @(videoThumbnailData.length)
                                                             }
                                                     } mutableCopy]
                                         } mutableCopy];
    
    __block MXEvent *event;
    __block id uploaderObserver;

    void(^onSuccess)(NSString *) = ^(NSString *eventId) {

        if (success)
        {
            success(eventId);
        }

        [self handleNextOperationAfter:roomOperation];
    };
    
    void(^onFailure)(NSError *) = ^(NSError *error) {
        
        // Remove outgoing message when its sent has been cancelled
        if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled)
        {
            [self removeOutgoingMessage:event.eventId];
        }
        else
        {
            // Update the local echo with the error state (This will trigger kMXEventDidChangeSentStateNotification notification).
            event.sentError = error;
            event.sentState = MXEventSentStateFailed;

            // Update the stored echo.
            [self updateOutgoingMessage:event.eventId withOutgoingMessage:event];
        }
        
        if (uploaderObserver)
        {
            [[NSNotificationCenter defaultCenter] removeObserver:uploaderObserver];
            uploaderObserver = nil;
        }
        
        if (failure)
        {
            failure(error);
        }

        [self handleNextOperationAfter:roomOperation];
    };
    
    // Add a local echo for this message during the sending process.
    event = [self addLocalEchoForMessageContent:msgContent eventType:kMXEventTypeStringRoomMessage withState:MXEventSentStatePreparing];
    
    if (localEcho)
    {
        // Return the created event.
        *localEcho = event;
    }

    roomOperation = [self preserveOperationOrder:event block:^{

        // Before sending data to the server, convert the video to MP4
        [MXTools convertVideoToMP4:videoLocalURL success:^(NSURL *convertedLocalURL, NSString *mimetype, CGSize size, double durationInMs) {

            if (![[NSFileManager defaultManager] fileExistsAtPath:convertedLocalURL.path])
            {
                failure(nil);
                return;
            }

            // update metadata with result of converter output
            msgContent[@"info"][@"mimetype"] = mimetype;
            msgContent[@"info"][@"w"] = @(size.width);
            msgContent[@"info"][@"h"] = @(size.height);
            msgContent[@"info"][@"duration"] = @(durationInMs);

            if (self.mxSession.crypto && self.summary.isEncrypted)
            {
                [MXEncryptedAttachments encryptAttachment:thumbUploader mimeType:@"image/jpeg" data:videoThumbnailData success:^(MXEncryptedContentFile *result) {

                    // Update thumbnail URL with the actual mxc: URL
                    msgContent[@"info"][@"thumbnail_file"] = result.JSONDictionary;
                    [msgContent[@"info"] removeObjectForKey:@"thumbnail_url"];

                    MXMediaLoader *videoUploader = [MXMediaManager prepareUploaderWithMatrixSession:self.mxSession initialRange:0.1 andRange:1];

                    // Self-proclaimed, "nasty trick" cargoculted from below...
                    // Apply the nasty trick again so that the cell can monitor the upload progress
                    msgContent[@"url"] = videoUploader.uploadId;

                    // Update the local echo state (This will trigger kMXEventDidChangeSentStateNotification notification).
                    event.sentState = MXEventSentStateEncrypting;

                    [self updateOutgoingMessage:event.eventId withOutgoingMessage:event];

                    // Register video uploader observer in order to trigger sent state change
                    MXWeakify(self);
                    uploaderObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXMediaLoaderStateDidChangeNotification object:videoUploader queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {

                        MXStrongifyAndReturnIfNil(self);
                        MXMediaLoader *loader = (MXMediaLoader*)notif.object;
                        
                        // Consider only the upload progress state.
                        switch (loader.state) {
                            case MXMediaLoaderStateUploadInProgress:
                            {
                                NSNumber* progressNumber = [loader.statisticsDict valueForKey:kMXMediaLoaderProgressValueKey];
                                if (progressNumber.floatValue)
                                {
                                    event.sentState = MXEventSentStateUploading;
                                    
                                    // Update the stored echo.
                                    [self updateOutgoingMessage:event.eventId withOutgoingMessage:event];
                                    
                                    [[NSNotificationCenter defaultCenter] removeObserver:uploaderObserver];
                                    uploaderObserver = nil;
                                }
                                break;
                            }
                            default:
                                break;
                        }
                    }];

                    [MXEncryptedAttachments encryptAttachment:videoUploader mimeType:mimetype localUrl:convertedLocalURL success:^(MXEncryptedContentFile *result) {

                        // Do not go further if the orignal request has been cancelled
                        if (roomOperation.isCancelled)
                        {
                            [self handleNextOperationAfter:roomOperation];
                            return;
                        }

                        [msgContent removeObjectForKey:@"url"];
                        msgContent[@"file"] = result.JSONDictionary;

                        // Send this content (the sent state of the local echo will be updated, its local storage too).
                        MXHTTPOperation *operation2 = [self sendMessageWithContent:msgContent localEcho:&event success:onSuccess failure:onFailure];

                        // Retrieve the MXRoomOperation just created for operation2
                        // And use it as the current operation
                        MXRoomOperation *roomOperation2 = [self roomOperationWithHTTPOperation:operation2];
                        [self mutateRoomOperation:roomOperation to:roomOperation2];

                    } failure:onFailure];
                } failure:onFailure];
            }
            else
            {
                // Upload thumbnail
                [thumbUploader uploadData:videoThumbnailData filename:nil mimeType:@"image/jpeg" success:^(NSString *thumbnailUrl) {

                    // Upload video
                    NSData* videoData = [NSData dataWithContentsOfFile:convertedLocalURL.path];
                    if (videoData)
                    {
                        // Copy the cached thumbnail to the actual cacheFile path
                        NSString *actualCacheFilePath = [MXMediaManager cachePathForMatrixContentURI:thumbnailUrl andType:@"image/jpeg" inFolder:self.roomId];
                        NSError *error;
                        [[NSFileManager defaultManager] copyItemAtPath:cacheFilePath toPath:actualCacheFilePath error:&error];

                        MXMediaLoader *videoUploader = [MXMediaManager prepareUploaderWithMatrixSession:self.mxSession initialRange:0.1 andRange:0.9];

                        // Create a fake file name based on videoData to keep the same name for the same file.
                        NSString *dataHash = [videoData mx_MD5];
                        if (dataHash.length > 7)
                        {
                            // Crop
                            dataHash = [dataHash substringToIndex:7];
                        }
                        NSString *extension = [MXTools fileExtensionFromContentType:mimetype];
                        NSString *filename = [NSString stringWithFormat:@"video_%@%@", dataHash, extension];
                        msgContent[@"body"] = filename;

                        // Update thumbnail URL with the actual mxc: URL
                        msgContent[@"info"][@"thumbnail_url"] = thumbnailUrl;

                        // Apply the nasty trick again so that the cell can monitor the upload progress
                        msgContent[@"url"] = videoUploader.uploadId;

                        // Update the local echo state (This will trigger kMXEventDidChangeSentStateNotification notification).
                        event.sentState = MXEventSentStateUploading;

                        [self updateOutgoingMessage:event.eventId withOutgoingMessage:event];

                        [videoUploader uploadData:videoData filename:filename mimeType:mimetype success:^(NSString *videoUrl) {

                            // Do not go further if the orignal request has been cancelled
                            if (roomOperation.isCancelled)
                            {
                                [self handleNextOperationAfter:roomOperation];
                                return;
                            }

                            // Write the video to the actual cacheFile path
                            NSString *actualCacheFilePath = [MXMediaManager cachePathForMatrixContentURI:videoUrl andType:mimetype inFolder:self.roomId];
                            [MXMediaManager writeMediaData:videoData toFilePath:actualCacheFilePath];

                            // Update video URL with the actual mxc: URL
                            msgContent[@"url"] = videoUrl;

                            // And send the Matrix room message video event to the homeserver (the sent state of the local echo will be updated, its local storage too).
                            MXHTTPOperation *operation2 = [self sendMessageWithContent:msgContent localEcho:&event success:onSuccess failure:onFailure];

                            // Retrieve the MXRoomOperation just created for operation2
                            // And use it as the current operation
                            MXRoomOperation *roomOperation2 = [self roomOperationWithHTTPOperation:operation2];
                            [self mutateRoomOperation:roomOperation to:roomOperation2];

                        } failure:onFailure];
                    }
                    else
                    {
                        onFailure(nil);
                    }
                } failure:onFailure];
            }
        } failure:^{

            onFailure(nil);

        }];

    }];

    return roomOperation.operation;
}

- (MXHTTPOperation*)sendFile:(NSURL*)fileLocalURL
                    mimeType:(NSString*)mimeType
                   localEcho:(MXEvent**)localEcho
                     success:(void (^)(NSString *eventId))success
                     failure:(void (^)(NSError *error))failure
{
    return [self sendFile:fileLocalURL mimeType:mimeType localEcho:localEcho success:success failure:failure keepActualFilename:YES];
}

- (MXHTTPOperation*)sendFile:(NSURL*)fileLocalURL
                    mimeType:(NSString*)mimeType
                   localEcho:(MXEvent**)localEcho
                     success:(void (^)(NSString *eventId))success
                     failure:(void (^)(NSError *error))failure
          keepActualFilename:(BOOL)keepActualName
{
    return [self sendFile:fileLocalURL msgType:kMXMessageTypeFile mimeType:mimeType localEcho:localEcho success:success failure:failure keepActualFilename:keepActualName];
}

- (MXHTTPOperation*)sendAudioFile:(NSURL*)fileLocalURL
                    mimeType:(NSString*)mimeType
                   localEcho:(MXEvent**)localEcho
                     success:(void (^)(NSString *eventId))success
                     failure:(void (^)(NSError *error))failure
          keepActualFilename:(BOOL)keepActualName
{
    return [self sendFile:fileLocalURL msgType:kMXMessageTypeAudio mimeType:mimeType localEcho:localEcho success:success failure:failure keepActualFilename:keepActualName];
}

- (MXHTTPOperation*)sendFile:(NSURL*)fileLocalURL
                     msgType:(NSString*)msgType
                    mimeType:(NSString*)mimeType
                   localEcho:(MXEvent**)localEcho
                     success:(void (^)(NSString *eventId))success
                     failure:(void (^)(NSError *error))failure
          keepActualFilename:(BOOL)keepActualName
{
    __block MXRoomOperation *roomOperation;
    
    NSData *fileData = [NSData dataWithContentsOfFile:fileLocalURL.path];
    
    // Use the uploader id as fake URL for this file data
    // The URL does not need to be valid as the MediaManager will get the data
    // directly from its cache
    // Pass this id in the URL is a nasty trick to retrieve it later
    MXMediaLoader *uploader = [MXMediaManager prepareUploaderWithMatrixSession:self.mxSession initialRange:0 andRange:1];
    NSString *fakeMediaURI = uploader.uploadId;
    
    NSString *cacheFilePath = [MXMediaManager cachePathForMatrixContentURI:fakeMediaURI andType:mimeType inFolder:self.roomId];
    [MXMediaManager writeMediaData:fileData toFilePath:cacheFilePath];
    
    // Create a fake name based on fileData to keep the same name for the same file.
    NSString *dataHash = [fileData mx_MD5];
    if (dataHash.length > 7)
    {
        // Crop
        dataHash = [dataHash substringToIndex:7];
    }
    NSString *extension = [MXTools fileExtensionFromContentType:mimeType];
    
    NSString *filename;
    if (keepActualName)
    {
        filename = [fileLocalURL lastPathComponent];
    }
    else
    {
        filename = [NSString stringWithFormat:@"file_%@%@", dataHash, extension];
    }
    
    // Prepare the message content for building an echo message
    NSMutableDictionary *msgContent = [@{
                                         @"msgtype": msgType,
                                         @"body": filename,
                                         @"url": fakeMediaURI,
                                         @"info": @{
                                                 @"mimetype": mimeType,
                                                 @"size": @(fileData.length)
                                                 }
                                         } mutableCopy];
    
    __block MXEvent *event;
    __block id uploaderObserver;

    void(^onSuccess)(NSString *) = ^(NSString *eventId) {

        if (success)
        {
            success(eventId);
        }

        [self handleNextOperationAfter:roomOperation];
    };

    void(^onFailure)(NSError *) = ^(NSError *error) {
        
        // Remove outgoing message when its sent has been cancelled
        if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled)
        {
            [self removeOutgoingMessage:event.eventId];
        }
        else
        {
            // Update the local echo with the error state (This will trigger kMXEventDidChangeSentStateNotification notification).
            event.sentError = error;
            event.sentState = MXEventSentStateFailed;

            // Update the stored echo.
            [self updateOutgoingMessage:event.eventId withOutgoingMessage:event];
        }
        
        if (uploaderObserver)
        {
            [[NSNotificationCenter defaultCenter] removeObserver:uploaderObserver];
            uploaderObserver = nil;
        }
        
        if (failure)
        {
            failure(error);
        }

        [self handleNextOperationAfter:roomOperation];
    };
    
    // Add a local echo for this message during the sending process.
    MXEventSentState initialSentState = (mxSession.crypto && self.summary.isEncrypted) ? MXEventSentStateEncrypting : MXEventSentStateUploading;
    event = [self addLocalEchoForMessageContent:msgContent eventType:kMXEventTypeStringRoomMessage withState:initialSentState];
    
    if (localEcho)
    {
        // Return the created event.
        *localEcho = event;
    }

    roomOperation = [self preserveOperationOrder:event block:^{

        if (self.mxSession.crypto && self.summary.isEncrypted)
        {
            // Register uploader observer
            MXWeakify(self);
            uploaderObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXMediaLoaderStateDidChangeNotification object:uploader queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {

                MXStrongifyAndReturnIfNil(self);
                MXMediaLoader *loader = (MXMediaLoader*)notif.object;
                
                // Consider only the upload progress state.
                switch (loader.state) {
                    case MXMediaLoaderStateUploadInProgress:
                    {
                        NSNumber* progressNumber = [loader.statisticsDict valueForKey:kMXMediaLoaderProgressValueKey];
                        if (progressNumber.floatValue)
                        {
                            event.sentState = MXEventSentStateUploading;
                            
                            // Update the stored echo.
                            [self updateOutgoingMessage:event.eventId withOutgoingMessage:event];
                            
                            [[NSNotificationCenter defaultCenter] removeObserver:uploaderObserver];
                            uploaderObserver = nil;
                        }
                        break;
                    }
                    default:
                        break;
                }

            }];

            [MXEncryptedAttachments encryptAttachment:uploader mimeType:mimeType localUrl:fileLocalURL success:^(MXEncryptedContentFile *result) {

                // Do not go further if the orignal request has been cancelled
                if (roomOperation.isCancelled)
                {
                    [self handleNextOperationAfter:roomOperation];
                    return;
                }

                [msgContent removeObjectForKey:@"url"];
                msgContent[@"file"] = result.JSONDictionary;

                MXHTTPOperation *operation2 = [self sendMessageWithContent:msgContent localEcho:&event success:onSuccess failure:onFailure];

                // Retrieve the MXRoomOperation just created for operation2
                // And use it as the current operation
                MXRoomOperation *roomOperation2 = [self roomOperationWithHTTPOperation:operation2];
                [self mutateRoomOperation:roomOperation to:roomOperation2];

            } failure:onFailure];
        }
        else
        {
            // Launch the upload to the Matrix Content repository
            [uploader uploadData:fileData filename:filename mimeType:mimeType success:^(NSString *url) {

                // Do not go further if the orignal request has been cancelled
                if (roomOperation.isCancelled)
                {
                    [self handleNextOperationAfter:roomOperation];
                    return;
                }

                // Copy the cached file to the actual cacheFile path
                NSString *actualCacheFilePath = [MXMediaManager cachePathForMatrixContentURI:url andType:mimeType inFolder:self.roomId];
                NSError *error;
                [[NSFileManager defaultManager] copyItemAtPath:cacheFilePath toPath:actualCacheFilePath error:&error];

                // Update the message content with the mxc:// of the media on the homeserver
                msgContent[@"url"] = url;

                // Make the final request that posts the image event
                MXHTTPOperation *operation2 = [self sendMessageWithContent:msgContent localEcho:&event success:onSuccess failure:onFailure];

                // Retrieve the MXRoomOperation just created for operation2
                // And use it as the current operation
                MXRoomOperation *roomOperation2 = [self roomOperationWithHTTPOperation:operation2];
                [self mutateRoomOperation:roomOperation to:roomOperation2];

            } failure:onFailure];
        }
    }];
    
    return roomOperation.operation;
}

- (void)cancelSendingOperation:(NSString *)localEchoEventId
{
    MXRoomOperation *roomOperation = [self roomOperationWithLocalEventId:localEchoEventId];
    if (roomOperation)
    {
        [roomOperation cancel];
        [self handleNextOperationAfter:roomOperation];
    }
}

- (MXHTTPOperation*)setTopic:(NSString*)topic
                     success:(void (^)(void))success
                     failure:(void (^)(NSError *error))failure
{
    return [mxSession.matrixRestClient setRoomTopic:self.roomId topic:topic success:success failure:failure];
}

- (MXHTTPOperation*)setAvatar:(NSString*)avatar
                     success:(void (^)(void))success
                     failure:(void (^)(NSError *error))failure
{
    return [mxSession.matrixRestClient setRoomAvatar:self.roomId avatar:avatar success:success failure:failure];
}


- (MXHTTPOperation*)setName:(NSString*)name
                    success:(void (^)(void))success
                    failure:(void (^)(NSError *error))failure
{
    return [mxSession.matrixRestClient setRoomName:self.roomId name:name success:success failure:failure];
}

- (MXHTTPOperation *)setHistoryVisibility:(MXRoomHistoryVisibility)historyVisibility
                                  success:(void (^)(void))success
                                  failure:(void (^)(NSError *))failure
{
    return [mxSession.matrixRestClient setRoomHistoryVisibility:self.roomId historyVisibility:historyVisibility success:success failure:failure];
}

- (MXHTTPOperation*)setJoinRule:(MXRoomJoinRule)joinRule
                        success:(void (^)(void))success
                        failure:(void (^)(NSError *error))failure
{
    return [mxSession.matrixRestClient setRoomJoinRule:self.roomId joinRule:joinRule success:success failure:failure];
}

- (MXHTTPOperation*)setGuestAccess:(MXRoomGuestAccess)guestAccess
                           success:(void (^)(void))success
                           failure:(void (^)(NSError *error))failure
{
    return [mxSession.matrixRestClient setRoomGuestAccess:self.roomId guestAccess:guestAccess success:success failure:failure];
}

- (MXHTTPOperation*)setDirectoryVisibility:(MXRoomDirectoryVisibility)directoryVisibility
                                   success:(void (^)(void))success
                                   failure:(void (^)(NSError *error))failure
{
    return [mxSession.matrixRestClient setRoomDirectoryVisibility:self.roomId directoryVisibility:directoryVisibility success:success failure:failure];
}

- (MXHTTPOperation*)addAlias:(NSString *)roomAlias
                     success:(void (^)(void))success
                     failure:(void (^)(NSError *error))failure
{
    return [mxSession.matrixRestClient addRoomAlias:self.roomId alias:roomAlias success:success failure:failure];
}

- (MXHTTPOperation*)removeAlias:(NSString *)roomAlias
                     success:(void (^)(void))success
                     failure:(void (^)(NSError *error))failure
{
    return [mxSession.matrixRestClient removeRoomAlias:roomAlias success:success failure:failure];
}

- (MXHTTPOperation*)setCanonicalAlias:(NSString *)canonicalAlias
                              success:(void (^)(void))success
                              failure:(void (^)(NSError *error))failure
{
    return [mxSession.matrixRestClient setRoomCanonicalAlias:self.roomId canonicalAlias:canonicalAlias success:success failure:failure];
}

- (MXHTTPOperation*)directoryVisibility:(void (^)(MXRoomDirectoryVisibility directoryVisibility))success
                                failure:(void (^)(NSError *error))failure
{
    return [mxSession.matrixRestClient directoryVisibilityOfRoom:self.roomId success:success failure:failure];
}

- (MXHTTPOperation*)join:(void (^)(void))success
                 failure:(void (^)(NSError *error))failure
{
    // On an invite, there is no need of via parameters.
    // The user homeserver already knows other homeservers
    return [mxSession joinRoom:self.roomId viaServers:nil success:^(MXRoom *room) {
        success();
    } failure:failure];
}

- (MXHTTPOperation*)leave:(void (^)(void))success
                  failure:(void (^)(NSError *error))failure
{
    return [mxSession leaveRoom:self.roomId success:success failure:failure];
}

- (MXHTTPOperation*)inviteUser:(NSString*)userId
                       success:(void (^)(void))success
                       failure:(void (^)(NSError *error))failure
{
    return [mxSession.matrixRestClient inviteUser:userId toRoom:self.roomId success:success failure:failure];
}

- (MXHTTPOperation*)inviteUserByEmail:(NSString*)email
                              success:(void (^)(void))success
                              failure:(void (^)(NSError *error))failure
{
    return [mxSession.matrixRestClient inviteUserByEmail:email toRoom:self.roomId success:success failure:failure];
}

- (MXHTTPOperation*)kickUser:(NSString*)userId
                      reason:(NSString*)reason
                     success:(void (^)(void))success
                     failure:(void (^)(NSError *error))failure
{
    return [mxSession.matrixRestClient kickUser:userId fromRoom:self.roomId reason:reason success:success failure:failure];
}

- (MXHTTPOperation*)banUser:(NSString*)userId
                     reason:(NSString*)reason
                    success:(void (^)(void))success
                    failure:(void (^)(NSError *error))failure
{
    return [mxSession.matrixRestClient banUser:userId inRoom:self.roomId reason:reason success:success failure:failure];
}

- (MXHTTPOperation*)unbanUser:(NSString*)userId
                      success:(void (^)(void))success
                      failure:(void (^)(NSError *error))failure
{
    return [mxSession.matrixRestClient unbanUser:userId inRoom:self.roomId success:success failure:failure];
}

- (MXHTTPOperation*)setPowerLevelOfUserWithUserID:(NSString *)userId powerLevel:(NSInteger)powerLevel
                                          success:(void (^)(void))success
                                          failure:(void (^)(NSError *))failure
{
    // Create an empty operation that will be mutated later
    MXHTTPOperation *operation = [[MXHTTPOperation alloc] init];

    MXWeakify(self);
    [self state:^(MXRoomState *roomState) {
        MXStrongifyAndReturnIfNil(self);

        // To set this new value, we have to take the current powerLevels content,
        // Update it with expected values and send it to the home server.
        NSMutableDictionary *newPowerLevelsEventContent = [NSMutableDictionary dictionaryWithDictionary:roomState.powerLevels.JSONDictionary];

        NSMutableDictionary *newPowerLevelsEventContentUsers = [NSMutableDictionary dictionaryWithDictionary:newPowerLevelsEventContent[@"users"]];
        newPowerLevelsEventContentUsers[userId] = [NSNumber numberWithInteger:powerLevel];

        newPowerLevelsEventContent[@"users"] = newPowerLevelsEventContentUsers;

        // Make the request to the HS
        MXHTTPOperation *operation2 = [self sendStateEventOfType:kMXEventTypeStringRoomPowerLevels content:newPowerLevelsEventContent stateKey:nil success:^(NSString *eventId) {
            success();
        } failure:failure];
        
        [operation mutateTo:operation2];
    }];

    return operation;
}

- (MXHTTPOperation*)sendTypingNotification:(BOOL)typing
                                   timeout:(NSUInteger)timeout
                                   success:(void (^)(void))success
                                   failure:(void (^)(NSError *error))failure
{
    return [mxSession.matrixRestClient sendTypingNotificationInRoom:self.roomId typing:typing timeout:timeout success:success failure:failure];
}

- (MXHTTPOperation*)redactEvent:(NSString*)eventId
                         reason:(NSString*)reason
                        success:(void (^)(void))success
                        failure:(void (^)(NSError *error))failure
{
    return [mxSession.matrixRestClient redactEvent:eventId inRoom:self.roomId reason:reason success:success failure:failure];
}

- (MXHTTPOperation *)reportEvent:(NSString *)eventId
                           score:(NSInteger)score
                          reason:(NSString *)reason
                         success:(void (^)(void))success
                         failure:(void (^)(NSError *))failure
{
    return [mxSession.matrixRestClient reportEvent:eventId inRoom:self.roomId score:score reason:reason success:success failure:failure];
}

- (MXHTTPOperation*)setRelatedGroups:(NSArray<NSString *>*)relatedGroups
                        success:(void (^)(void))success
                        failure:(void (^)(NSError *error))failure
{
    return [mxSession.matrixRestClient setRoomRelatedGroups:self.roomId relatedGroups:relatedGroups success:success failure:failure];
}

- (MXHTTPOperation*)sendReplyToEvent:(MXEvent*)eventToReply
                     withTextMessage:(NSString*)textMessage
                formattedTextMessage:(NSString*)formattedTextMessage
                 stringLocalizations:(id<MXSendReplyEventStringsLocalizable>)stringLocalizations
                           localEcho:(MXEvent**)localEcho
                             success:(void (^)(NSString *eventId))success
                             failure:(void (^)(NSError *error))failure
{
    if (![self canReplyToEvent:eventToReply])
    {
        NSLog(@"[MXRoom] Send reply to this event is not supported");
        return nil;
    }
    
    id<MXSendReplyEventStringsLocalizable> finalStringLocalizations;
    
    if (stringLocalizations)
    {
        finalStringLocalizations = stringLocalizations;
    }
    else
    {
        finalStringLocalizations = [MXSendReplyEventDefaultStringLocalizations new];
    }
    
    MXHTTPOperation* operation = nil;
    
    NSString *replyToBody;
    NSString *replyToFormattedBody;
    
    [self getReplyContentBodiesWithEventToReply:eventToReply
                                    textMessage:textMessage
                           formattedTextMessage:formattedTextMessage
                               replyContentBody:&replyToBody
                      replyContentFormattedBody:&replyToFormattedBody
                            stringLocalizations:finalStringLocalizations];
    
    if (replyToBody && replyToFormattedBody)
    {
        NSString *eventId = eventToReply.eventId;
        
        NSDictionary *relatesToDict = @{ @"m.in_reply_to" :
                                             @{
                                                 @"event_id" : eventId
                                                 }
                                         };
        
        NSMutableDictionary *msgContent = [NSMutableDictionary dictionary];
        
        msgContent[@"format"] = kMXRoomMessageFormatHTML;
        msgContent[@"msgtype"] = kMXMessageTypeText;
        msgContent[@"body"] = replyToBody;
        msgContent[@"formatted_body"] = replyToFormattedBody;
        msgContent[@"m.relates_to"] = relatesToDict;
        
        operation = [self sendMessageWithContent:msgContent
                                       localEcho:localEcho
                                         success:success
                                         failure:failure];
    }
    else
    {
        NSLog(@"[MXRoom] Fail to generate reply body and formatted body");
    }
    
    return operation;
}

/**
 Build reply to body and formatted body.
 
 @param eventToReply the event to reply. Should be 'm.room.message' event type.
 @param textMessage the text to send.
 @param formattedTextMessage the optional HTML formatted string of the text to send.
 @param replyContentBody reply string of the text to send.
 @param replyContentFormattedBody reply HTML formatted string of the text to send.
 @param stringLocalizations string localizations used when building reply content bodies.
 
 */
- (void)getReplyContentBodiesWithEventToReply:(MXEvent*)eventToReply
                                  textMessage:(NSString*)textMessage
                         formattedTextMessage:(NSString*)formattedTextMessage
                             replyContentBody:(NSString**)replyContentBody
                    replyContentFormattedBody:(NSString**)replyContentFormattedBody
                          stringLocalizations:(id<MXSendReplyEventStringsLocalizable>)stringLocalizations
{
    NSString *msgtype;
    MXJSONModelSetString(msgtype, eventToReply.content[@"msgtype"]);
    
    if (!msgtype)
    {
        return;
    }
    
    BOOL eventToReplyIsAlreadyAReply = eventToReply.isReplyEvent;
    BOOL isSenderMessageAnEmote = [msgtype isEqualToString:kMXMessageTypeEmote];
    
    NSString *senderMessageBody;
    NSString *senderMessageFormattedBody;
    
    if ([msgtype isEqualToString:kMXMessageTypeText]
        || [msgtype isEqualToString:kMXMessageTypeNotice]
        || [msgtype isEqualToString:kMXMessageTypeEmote])
    {
        NSString *eventToReplyMessageBody = eventToReply.content[@"body"];
        NSString *eventToReplyMessageFormattedBody = eventToReply.content[@"formatted_body"];
        
        senderMessageBody = eventToReplyMessageBody;
        senderMessageFormattedBody = eventToReplyMessageFormattedBody ?: eventToReplyMessageBody;
    }
    else if ([msgtype isEqualToString:kMXMessageTypeImage])
    {
        senderMessageBody = stringLocalizations.senderSentAnImage;
        senderMessageFormattedBody = senderMessageBody;
    }
    else if ([msgtype isEqualToString:kMXMessageTypeVideo])
    {
        senderMessageBody = stringLocalizations.senderSentAVideo;
        senderMessageFormattedBody = senderMessageBody;
    }
    else if ([msgtype isEqualToString:kMXMessageTypeAudio])
    {
        senderMessageBody = stringLocalizations.senderSentAnAudioFile;
        senderMessageFormattedBody = senderMessageBody;
    }
    else if ([msgtype isEqualToString:kMXMessageTypeFile])
    {
        senderMessageBody = stringLocalizations.senderSentAFile;
        senderMessageFormattedBody = senderMessageBody;
    }
    else
    {
        // Other message types are not supported
        NSLog(@"[MXRoom] Reply to message type %@ is not supported", msgtype);
    }
    
    if (senderMessageBody && senderMessageFormattedBody)
    {
        *replyContentBody = [self replyMessageBodyFromSender:eventToReply.sender
                                           senderMessageBody:senderMessageBody
                                      isSenderMessageAnEmote:isSenderMessageAnEmote
                                     isSenderMessageAReplyTo:eventToReplyIsAlreadyAReply
                                                replyMessage:textMessage];
        
        // As formatted body is mandatory for a reply message, use non formatted to build it
        NSString *finalFormattedTextMessage = formattedTextMessage ?: textMessage;
        
        *replyContentFormattedBody = [self replyMessageFormattedBodyFromEventToReply:eventToReply
                                                          senderMessageFormattedBody:senderMessageFormattedBody
                                                              isSenderMessageAnEmote:isSenderMessageAnEmote
                                                             isSenderMessageAReplyTo:eventToReplyIsAlreadyAReply
                                                               replyFormattedMessage:finalFormattedTextMessage
                                                                 stringLocalizations:stringLocalizations];
    }
}

/**
 Build reply body.
 
 Example of reply body:
 `> <@sender:matrix.org> sent an image.\n\nReply message`
 
 @param sender The sender of the message.
 @param senderMessageBody The message body of the sender.
 @param isSenderMessageAnEmote Indicate if the sender message is an emote (/me).
 @param isSenderMessageAReplyTo Indicate if the sender message is already a reply to message.
 @param replyMessage The response for the sender message.
 
 @return Reply message body.
 */
- (NSString*)replyMessageBodyFromSender:(NSString*)sender
                      senderMessageBody:(NSString*)senderMessageBody
                 isSenderMessageAnEmote:(BOOL)isSenderMessageAnEmote
                isSenderMessageAReplyTo:(BOOL)isSenderMessageAReplyTo
                           replyMessage:(NSString*)replyMessage
{
    // Sender reply body split by lines
    NSMutableArray<NSString*> *senderReplyBodyLines = [[senderMessageBody componentsSeparatedByString:@"\n"] mutableCopy];
    
    // Strip previous reply to, if the event was already a reply
    if (isSenderMessageAReplyTo)
    {
        // Removes lines beginning with `> ` until you reach one that doesn't.
        while (senderReplyBodyLines.count && [senderReplyBodyLines.firstObject hasPrefix:@"> "])
        {
            [senderReplyBodyLines removeObjectAtIndex:0];
        }
        
        // Reply fallback has a blank line after it, so remove it to prevent leading newline
        if (senderReplyBodyLines.firstObject.length == 0)
        {
            [senderReplyBodyLines removeObjectAtIndex:0];
        }
    }
    
    // Build sender message reply body part
    
    // Add user id on first line
    NSString *firstLine = senderReplyBodyLines.firstObject;
    if (firstLine)
    {
        NSString *newFirstLine;
        
        if (isSenderMessageAnEmote)
        {
            newFirstLine = [NSString stringWithFormat:@"* <%@> %@", sender, firstLine];
        }
        else
        {
            newFirstLine = [NSString stringWithFormat:@"<%@> %@", sender, firstLine];
        }
        senderReplyBodyLines[0] = newFirstLine;
    }
    
    NSUInteger messageToReplyBodyLineIndex = 0;
    
    // Add reply `> ` sequence at begining of each line
    for (NSString *messageToReplyBodyLine in [senderReplyBodyLines copy])
    {
        senderReplyBodyLines[messageToReplyBodyLineIndex] = [NSString stringWithFormat:@"> %@",  messageToReplyBodyLine];
        messageToReplyBodyLineIndex++;
    }
    
    // Build final message body with sender message and reply message
    NSMutableString *messageBody = [NSMutableString string];
    [messageBody appendString:[senderReplyBodyLines componentsJoinedByString:@"\n"]];
    [messageBody appendString:@"\n\n"]; // Add separator between sender message and reply message
    [messageBody appendString:replyMessage];
    
    return [messageBody copy];
}

/**
 Build reply formatted body.
 
 Example of reply formatted body:
 `<mx-reply><blockquote><a href=\"https://matrix.to/#/!vjFxDRtZSSdspfTSEr:matrix.org/$15237084491191492ssFoA:matrix.org\">In reply to</a> <a href=\"https://matrix.to/#/@sender:matrix.org\">@sender:matrix.org</a><br>sent an image.</blockquote></mx-reply>Reply message`
 
 @param eventToReply The sender event to reply.
 @param senderMessageFormattedBody The message body of the sender.
 @param isSenderMessageAnEmote Indicate if the sender message is an emote (/me).
 @param isSenderMessageAReplyTo Indicate if the sender message is already a reply to message.
 @param replyFormattedMessage The response for the sender message. HTML formatted string if any otherwise non formatted string as reply formatted body is mandatory.
 @param stringLocalizations string localizations used when building formatted body.
 
 @return reply message body.
 */
- (NSString*)replyMessageFormattedBodyFromEventToReply:(MXEvent*)eventToReply
                            senderMessageFormattedBody:(NSString*)senderMessageFormattedBody
                                isSenderMessageAnEmote:(BOOL)isSenderMessageAnEmote
                               isSenderMessageAReplyTo:(BOOL)isSenderMessageAReplyTo
                                 replyFormattedMessage:(NSString*)replyFormattedMessage
                                   stringLocalizations:(id<MXSendReplyEventStringsLocalizable>)stringLocalizations
{
    NSString *eventId = eventToReply.eventId;
    NSString *roomId = eventToReply.roomId;
    NSString *sender = eventToReply.sender;
    
    if (!eventId || !roomId || !sender)
    {
        NSLog(@"[MXRoom] roomId, eventId and sender cound not be nil");
        return nil;
    }
    
    NSString *replySenderMessageFormattedBody;
    
    // Strip previous reply to, if the event was already a reply
    if (isSenderMessageAReplyTo)
    {
        NSError *error = nil;
        NSRegularExpression *replyRegex = [NSRegularExpression regularExpressionWithPattern:@"^<mx-reply>.*</mx-reply>"
                                                                                    options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                                                                      error:&error];
        NSString *senderMessageFormattedBodyWithoutReply = [replyRegex stringByReplacingMatchesInString:senderMessageFormattedBody options:0 range:NSMakeRange(0, senderMessageFormattedBody.length) withTemplate:@""];
        
        if (error)
        {
            NSLog(@"[MXRoom] Fail to strip previous reply to message");
        }
        
        if (senderMessageFormattedBodyWithoutReply)
        {
            replySenderMessageFormattedBody = senderMessageFormattedBodyWithoutReply;
        }
    }
    else
    {
        replySenderMessageFormattedBody = senderMessageFormattedBody;
    }
    
    // Build reply formatted body
    
    NSString *eventPermalink = [MXTools permalinkToEvent:eventId inRoom:roomId];
    NSString *userPermalink = [MXTools permalinkToUserWithUserId:sender];
    
    NSMutableString *replyMessageFormattedBody = [NSMutableString string];
    
    // Start reply quote
    [replyMessageFormattedBody appendString:@"<mx-reply><blockquote>"];
    
    // Add event link
    [replyMessageFormattedBody appendFormat:@"<a href=\"%@\">%@</a> ", eventPermalink, stringLocalizations.messageToReplyToPrefix];
    
    if (isSenderMessageAnEmote)
    {
        [replyMessageFormattedBody appendString:@"* "];
    }
    
    // Add user link
    [replyMessageFormattedBody appendFormat:@"<a href=\"%@\">%@</a>", userPermalink, sender];
    
    [replyMessageFormattedBody appendString:@"<br>"];
    
    // Add sender message
    [replyMessageFormattedBody appendString:replySenderMessageFormattedBody];
    
    // End reply quote
    [replyMessageFormattedBody appendString:@"</blockquote></mx-reply>"];
    
    // Add reply message
    [replyMessageFormattedBody appendString:replyFormattedMessage];
    
    return replyMessageFormattedBody;
}

- (BOOL)canReplyToEvent:(MXEvent *)eventToReply
{
    if (eventToReply.eventType != MXEventTypeRoomMessage)
    {
        return NO;
    }
    
    BOOL canReplyToEvent = NO;
    
    NSString *messageType = eventToReply.content[@"msgtype"];
    
    if (messageType)
    {
        NSArray *supportedMessageTypes = @[
                                           kMXMessageTypeText,
                                           kMXMessageTypeNotice,
                                           kMXMessageTypeEmote,
                                           kMXMessageTypeImage,
                                           kMXMessageTypeVideo,
                                           kMXMessageTypeAudio,
                                           kMXMessageTypeFile
                                           ];
        
        canReplyToEvent = [supportedMessageTypes containsObject:messageType];
    }
    
    return canReplyToEvent;
}

#pragma mark - Message order preserving
/**
 Make sure that `block` will be called in the order expected by the end user.

 @param localEvent the local echo event corresponding to the event being sent.
 @param block the code block to schedule.
 @return a `MXRoomOperation` object.
 */
- (MXRoomOperation *)preserveOperationOrder:(MXEvent*)localEvent block:(void (^)(void))block
{
    // Queue the operation requests
    MXRoomOperation *roomOperation = [[MXRoomOperation alloc] init];
    roomOperation.localEventId = localEvent.eventId;
    roomOperation.operation = [[MXHTTPOperation alloc] init];
    roomOperation.block = block;

    [orderedOperations addObject:roomOperation];

    // Launch the operation if there is none pending or executing.
    if (orderedOperations.count == 1)
    {
        // Dispatch so that we can return the new`roomOperation` to the caller
        // before calling its block
        dispatch_async(dispatch_get_main_queue(), ^{
            roomOperation.block();
        });
    }

    return roomOperation;
}

/**
 Run the next ordered operation.

 @param roomOperation the operation that has just finished.
 */
- (void)handleNextOperationAfter:(MXRoomOperation*)roomOperation
{
    BOOL isRunningRoomOperation = (orderedOperations.count && roomOperation == orderedOperations[0]);

    [orderedOperations removeObject:roomOperation];

    // Launch the next operation if this is the current one that completes
    if (isRunningRoomOperation && orderedOperations.count)
    {
        MXRoomOperation *nextRoomOperation = orderedOperations[0];

        // Launch it if it was not cancelled
        if (!nextRoomOperation.isCancelled)
        {
            nextRoomOperation.block();
        }
        else
        {
            [self handleNextOperationAfter:nextRoomOperation];
        }
    }
}

/**
 Find the `MXRoomOperation` instance that corresponds to the given HTTP operation.

 @param operation the HTTP operation to retrieve.
 @return the corresponding `MXRoomOperation` object.
 */
- (MXRoomOperation *)roomOperationWithHTTPOperation:(MXHTTPOperation*)operation
{
    MXRoomOperation *theRoomOperation;

    for (MXRoomOperation *roomOperation in orderedOperations)
    {
        if (roomOperation.operation == operation)
        {
            theRoomOperation = roomOperation;
            break;
        }
    }

    return theRoomOperation;
}

/**
 Find the `MXRoomOperation` instance that corresponds to the id of a local echo event.

 @param localEventId the id of the local echo event to retrieve.
 @return the corresponding `MXRoomOperation` object.
 */
- (MXRoomOperation *)roomOperationWithLocalEventId:(NSString*)localEventId
{
    MXRoomOperation *theRoomOperation;

    for (MXRoomOperation *roomOperation in orderedOperations)
    {
        if ([roomOperation.localEventId isEqualToString:localEventId])
        {
            theRoomOperation = roomOperation;
            break;
        }
    }

    return theRoomOperation;
}

/**
 Mutate the `MXRoomOperation` instance into another operation.

 @param roomOperation the operation to mutate.
 @param newRomOperation the other operation to copy data from.
 */
- (void)mutateRoomOperation:(MXRoomOperation*)roomOperation to:(MXRoomOperation*)newRomOperation
{
    if (newRomOperation)
    {
        [roomOperation.operation mutateTo:newRomOperation.operation];
        roomOperation.block = newRomOperation.block;

        // newRoomOperation is now incarned into roomOperation
        // Avoid to execute the same operation twice
        [orderedOperations removeObject:newRomOperation];

        // If roomOperation was running, run newRoomOperation
        // This happens when an ordered operation cascades another one
        if (orderedOperations.count && orderedOperations[0] == roomOperation)
        {
            roomOperation.block();
        }
    }
}


#pragma mark - Events listeners on the live timeline
- (id)listenToEvents:(MXOnRoomEvent)onEvent
{
    // We do not need the live timeline data to be loaded to set a listener
    return [liveTimeline listenToEvents:onEvent];
}

- (id)listenToEventsOfTypes:(NSArray<MXEventTypeString> *)types onEvent:(MXOnRoomEvent)onEvent
{
    return [liveTimeline listenToEventsOfTypes:types onEvent:onEvent];
}

- (void)removeListener:(id)listener
{
    [liveTimeline removeListener:listener];
}

- (void)removeAllListeners
{
    [liveTimeline removeAllListeners];
}


#pragma mark - Events timeline
- (MXEventTimeline*)timelineOnEvent:(NSString*)eventId;
{
    return [[MXEventTimeline alloc] initWithRoom:self andInitialEventId:eventId];
}


#pragma mark - Fake event objects creation
- (MXEvent*)fakeEventWithEventId:(NSString*)eventId eventType:(NSString*)eventType andContent:(NSDictionary*)content
{
    if (!eventId)
    {
        eventId = [NSString stringWithFormat:@"%@%@", kMXEventLocalEventIdPrefix, [[NSProcessInfo processInfo] globallyUniqueString]];
    }
    
    MXEvent *event = [[MXEvent alloc] init];
    event.roomId = _roomId;
    event.eventId = eventId;
    event.wireType = eventType;
    event.originServerTs = (uint64_t) ([[NSDate date] timeIntervalSince1970] * 1000);
    event.sender = mxSession.myUserId;
    event.wireContent = content;
    
    return event;
}

- (MXEvent*)fakeRoomMessageEventWithEventId:(NSString*)eventId andContent:(NSDictionary<NSString*, id>*)content
{
    return [self fakeEventWithEventId:eventId eventType:kMXEventTypeStringRoomMessage andContent:content];
}

#pragma mark - Outgoing events management
- (void)storeOutgoingMessage:(MXEvent*)outgoingMessage
{
    if ([mxSession.store respondsToSelector:@selector(storeOutgoingMessageForRoom:outgoingMessage:)]
        && [mxSession.store respondsToSelector:@selector(commit)])
    {
        [mxSession.store storeOutgoingMessageForRoom:self.roomId outgoingMessage:outgoingMessage];
        [mxSession.store commit];
    }
}

- (void)removeAllOutgoingMessages
{
    if ([mxSession.store respondsToSelector:@selector(removeAllOutgoingMessagesFromRoom:)]
        && [mxSession.store respondsToSelector:@selector(commit)])
    {
        [mxSession.store removeAllOutgoingMessagesFromRoom:self.roomId];
        [mxSession.store commit];
    }

    // If required, update the last message
    MXEvent *lastMessageEvent = self.summary.lastMessageEvent;
    if (lastMessageEvent.sentState != MXEventSentStateSent)
    {
        [self.summary resetLastMessage:nil failure:nil commit:YES];
    }
}

- (void)removeOutgoingMessage:(NSString*)outgoingMessageEventId
{
    if ([mxSession.store respondsToSelector:@selector(removeOutgoingMessageFromRoom:outgoingMessage:)]
        && [mxSession.store respondsToSelector:@selector(commit)])
    {
        [mxSession.store removeOutgoingMessageFromRoom:self.roomId outgoingMessage:outgoingMessageEventId];
        [mxSession.store commit];
    }

    // If required, update the last message
    if ([self.summary.lastMessageEventId isEqualToString:outgoingMessageEventId])
    {
        [self.summary resetLastMessage:nil failure:nil commit:YES];
    }
}

- (void)updateOutgoingMessage:(NSString *)outgoingMessageEventId withOutgoingMessage:(MXEvent *)outgoingMessage
{
    // Do the update by removing the existing one and create a new one
    // Thus, `outgoingMessage` will go at the end of the outgoing messages list
    if ([mxSession.store respondsToSelector:@selector(removeOutgoingMessageFromRoom:outgoingMessage:)])
    {
        [mxSession.store removeOutgoingMessageFromRoom:self.roomId outgoingMessage:outgoingMessageEventId];
    }
    if ([mxSession.store respondsToSelector:@selector(storeOutgoingMessageForRoom:outgoingMessage:)])
    {
        [mxSession.store storeOutgoingMessageForRoom:self.roomId outgoingMessage:outgoingMessage];
    }

    if ([mxSession.store respondsToSelector:@selector(commit)])
    {
        [mxSession.store commit];
    }
}

- (NSArray<MXEvent*>*)outgoingMessages
{
    if ([mxSession.store respondsToSelector:@selector(outgoingMessagesInRoom:)])
    {
        NSArray<MXEvent*> *outgoingMessages = [mxSession.store outgoingMessagesInRoom:self.roomId];
        
        for (MXEvent *event in outgoingMessages)
        {
            // Decrypt event if necessary
            if (event.eventType == MXEventTypeRoomEncrypted)
            {
                if (![self.mxSession decryptEvent:event inTimeline:nil])
                {
                    NSLog(@"[MXRoom] outgoingMessages: Warning: Unable to decrypt outgoing event: %@", event.decryptionError);
                }
            }
        }
        
        return outgoingMessages;
    }
    else
    {
        return nil;
    }
}

- (void)refreshOutgoingMessages
{
    // Update the stored outgoing messages, by removing the sent messages and tagging as failed the others.
    NSArray<MXEvent*>* outgoingMessages = self.outgoingMessages;
    
    if (outgoingMessages.count && [mxSession.store respondsToSelector:@selector(commit)])
    {
        for (NSInteger index = 0; index < outgoingMessages.count;)
        {
            MXEvent *outgoingMessage = [outgoingMessages objectAtIndex:index];
            
            // Remove successfully sent messages
            if (outgoingMessage.isLocalEvent == NO)
            {
                if ([mxSession.store respondsToSelector:@selector(removeOutgoingMessageFromRoom:outgoingMessage:)])
                {
                    [mxSession.store removeOutgoingMessageFromRoom:_roomId outgoingMessage:outgoingMessage.eventId];
                    continue;
                }
            }
            else
            {
                // Here the message sending has failed
                outgoingMessage.sentState = MXEventSentStateFailed;
                
                // Erase the timestamp
                outgoingMessage.originServerTs = kMXUndefinedTimestamp;
            }
            
            index++;
        }
        
        [mxSession.store commit];
    }
}

#pragma mark - Local echo handling

- (MXEvent*)addLocalEchoForMessageContent:(NSDictionary*)msgContent eventType:(MXEventTypeString)eventType withState:(MXEventSentState)eventState
{
    // Create a room message event.
    MXEvent *localEcho = [self fakeEventWithEventId:nil eventType:eventType andContent:msgContent];
    localEcho.sentState = eventState;

    // Register the echo as pending for its future deletion
    [self storeOutgoingMessage:localEcho];

    // Update the room summary
    [self.summary handleEvent:localEcho];

    return localEcho;
}

- (MXEvent*)pendingLocalEchoRelatedToEvent:(MXEvent*)event
{
    // Note: event is supposed here to be an outgoing event received from the server sync.
    MXEvent *localEcho = nil;

    NSString *msgtype;
    MXJSONModelSetString(msgtype, event.content[@"msgtype"]);

    if (msgtype)
    {
        // We look first for a pending event with the same event id (This happens when server response is received before server sync).
        NSArray<MXEvent*>* pendingLocalEchoes = self.outgoingMessages;
        for (NSInteger index = 0; index < pendingLocalEchoes.count; index++)
        {
            localEcho = [pendingLocalEchoes objectAtIndex:index];
            if ([localEcho.eventId isEqualToString:event.eventId])
            {
                break;
            }
            localEcho = nil;
        }

        // If none, we return the pending event (if any) whose content matches with received event content.
        if (!localEcho)
        {
            for (NSInteger index = 0; index < pendingLocalEchoes.count; index++)
            {
                localEcho = [pendingLocalEchoes objectAtIndex:index];
                NSString *pendingEventType = localEcho.content[@"msgtype"];

                if ([msgtype isEqualToString:pendingEventType])
                {
                    if ([msgtype isEqualToString:kMXMessageTypeText] || [msgtype isEqualToString:kMXMessageTypeEmote])
                    {
                        // Compare content body
                        if ([event.content[@"body"] isEqualToString:localEcho.content[@"body"]])
                        {
                            break;
                        }
                    }
                    else if ([msgtype isEqualToString:kMXMessageTypeLocation])
                    {
                        // Compare geo uri
                        if ([event.content[@"geo_uri"] isEqualToString:localEcho.content[@"geo_uri"]])
                        {
                            break;
                        }
                    }
                    else
                    {
                        // Here the type is kMXMessageTypeImage, kMXMessageTypeAudio, kMXMessageTypeVideo or kMXMessageTypeFile
                        if (event.content[@"file"])
                        {
                            // This is an encrypted attachment
                            if (localEcho.content[@"file"] && [event.content[@"file"][@"url"] isEqualToString:localEcho.content[@"file"][@"url"]])
                            {
                                break;
                            }
                        }
                        else if ([event.content[@"url"] isEqualToString:localEcho.content[@"url"]])
                        {
                            break;
                        }
                    }
                }
                localEcho = nil;
            }
        }
    }

    return localEcho;
}

- (void)removePendingLocalEcho:(NSString*)localEchoEventId
{
    [self removeOutgoingMessage:localEchoEventId];
}


#pragma mark - Room tags operations
- (MXHTTPOperation*)addTag:(NSString*)tag
                 withOrder:(NSString*)order
                   success:(void (^)(void))success
                   failure:(void (^)(NSError *error))failure
{
    // _accountData.tags will be updated by the live streams
    return [mxSession.matrixRestClient addTag:tag withOrder:order toRoom:self.roomId success:success failure:failure];
}

- (MXHTTPOperation*)removeTag:(NSString*)tag
                      success:(void (^)(void))success
                      failure:(void (^)(NSError *error))failure
{
    // _accountData.tags will be updated by the live streams
    return [mxSession.matrixRestClient removeTag:tag fromRoom:self.roomId success:success failure:failure];
}

- (MXHTTPOperation*)replaceTag:(NSString*)oldTag
                         byTag:(NSString*)newTag
                     withOrder:(NSString*)newTagOrder
                       success:(void (^)(void))success
                       failure:(void (^)(NSError *error))failure
{
    MXHTTPOperation *operation;
    
    // remove tag
    if (oldTag && !newTag)
    {
        operation = [self removeTag:oldTag success:success failure:failure];
    }
    // define a tag or define a new order
    else if ((!oldTag && newTag) || [oldTag isEqualToString:newTag])
    {
        operation = [self addTag:newTag withOrder:newTagOrder success:success failure:failure];
    }
    else
    {
        // the tag is not the same
        // weird, but the tag must be removed and defined again
        // so combine remove and add tag operations
        operation = [self removeTag:oldTag success:^{
            
            MXHTTPOperation *addTagHttpOperation = [self addTag:newTag withOrder:newTagOrder success:success failure:failure];
            
            // Transfer the new AFHTTPRequestOperation to the returned MXHTTPOperation
            // So that user has hand on it
            operation.operation = addTagHttpOperation.operation;
            
        } failure:failure];
    }
    
    return operation;
}


#pragma mark - Voice over IP
- (void)placeCallWithVideo:(BOOL)video
                   success:(void (^)(MXCall *call))success
                   failure:(void (^)(NSError *error))failure
{
    if (mxSession.callManager)
    {
        [mxSession.callManager placeCallInRoom:self.roomId withVideo:video success:success failure:failure];
    }
    else if (failure)
    {
        failure(nil);
    }
}

#pragma mark - Read receipts management

- (BOOL)handleReceiptEvent:(MXEvent *)event direction:(MXTimelineDirection)direction
{
    BOOL managedEvents = false;
    
    for (NSString* eventId in event.content)
    {
        NSDictionary *eventDict, *readDict;
        MXJSONModelSetDictionary(eventDict, event.content[eventId]);
        MXJSONModelSetDictionary(readDict, eventDict[kMXEventTypeStringRead]);

        if (readDict)
        {
            for (NSString* userId in readDict)
            {
                NSDictionary<NSString*, id>* params;
                MXJSONModelSetDictionary(params, readDict[userId]);

                NSNumber *ts;
                MXJSONModelSetNumber(ts, params[@"ts"]);
                if (ts)
                {
                    MXReceiptData *data = [[MXReceiptData alloc] init];
                    data.userId = userId;
                    data.eventId = eventId;
                    data.ts = ts.longLongValue;
                    
                    managedEvents |= [mxSession.store storeReceipt:data inRoom:self.roomId];
                }
            }
        }
    }
    
    // warn only if the receipts are not duplicated ones.
    if (managedEvents)
    {
        // Notify listeners
        [self liveTimeline:^(MXEventTimeline *theLiveTimeline) {
            [theLiveTimeline notifyListeners:event direction:direction];
        }];
    }
    
    return managedEvents;
}

- (void)acknowledgeEvent:(MXEvent*)event andUpdateReadMarker:(BOOL)updateReadMarker
{
    // Sanity check
    if (!event.eventId)
    {
        return;
    }
    
    MXEvent *updatedReadReceiptEvent = nil;
    NSString *readMarkerEventId = nil;
    
    // Prepare read receipt update.
    // Retrieve the current read receipt event id
    NSString *currentReadReceiptEventId;
    NSString *myUserId = mxSession.myUserId;
    MXReceiptData* currentData = [mxSession.store getReceiptInRoom:self.roomId forUserId:myUserId];
    if (currentData)
    {
        currentReadReceiptEventId = currentData.eventId;
    }
    
    // Check whether the provided event is acknowledgeable
    BOOL isAcknowledgeable = (![event.eventId hasPrefix:kMXEventLocalEventIdPrefix] && [mxSession.acknowledgableEventTypes indexOfObject:event.type] != NSNotFound);
    
    // Check whether the event is posterior to the current position (if any).
    // Look for an acknowledgeable event if the event type is not acknowledgeable.
    if (currentReadReceiptEventId || !isAcknowledgeable)
    {
        @autoreleasepool
        {
            // Enumerate all the acknowledgeable events of the room
            id<MXEventsEnumerator> messagesEnumerator = [mxSession.store messagesEnumeratorForRoom:self.roomId withTypeIn:mxSession.acknowledgableEventTypes];

            MXEvent *nextEvent;
            while ((nextEvent = messagesEnumerator.nextEvent))
            {
                // Check whether the current acknowledged event is posterior to the provided event.
                if (currentReadReceiptEventId && [nextEvent.eventId isEqualToString:currentReadReceiptEventId])
                {
                    // No change is required
                    break;
                }
                
                // Look for the first acknowledgeable event prior the event timestamp
                if (nextEvent.originServerTs <= event.originServerTs && nextEvent.eventId)
                {
                    updatedReadReceiptEvent = nextEvent;

                    // Here we find the right event to acknowledge, and it is posterior to the current position (if any).
                    break;
                }                
            }
        }
    }
    else
    {
        updatedReadReceiptEvent = event;
    }
    
    // Sanity check: Do not send read receipt on a fake event id
    if ([updatedReadReceiptEvent.eventId hasPrefix:kMXRoomInviteStateEventIdPrefix])
    {
        updatedReadReceiptEvent = nil;
    }
    
    if (updatedReadReceiptEvent)
    {
        // Update the oneself receipts
        if ([self storeLocalReceipt:kMXEventTypeStringRead eventId:updatedReadReceiptEvent.eventId userId:myUserId ts:(uint64_t) ([[NSDate date] timeIntervalSince1970] * 1000)]
            && [mxSession.store respondsToSelector:@selector(commit)])
        {
            [mxSession.store commit];
        }
    }
    
    // Prepare read marker update
    if (updateReadMarker)
    {
        MXEvent *updatedReadMarkerEvent = nil;
        
        // Sanity check: Do not send read marker on a fake event id
        if (![event.eventId hasPrefix:kMXEventLocalEventIdPrefix] && ![event.eventId hasPrefix:kMXRoomInviteStateEventIdPrefix])
        {
            updatedReadMarkerEvent = event;
        }
        else
        {
            // Use by default the read receipt event.
            updatedReadMarkerEvent = updatedReadReceiptEvent;
        }
        
        
        if (updatedReadMarkerEvent && ![_accountData.readMarkerEventId isEqualToString:updatedReadMarkerEvent.eventId])
        {
            readMarkerEventId = updatedReadMarkerEvent.eventId;
        }
    }
    
    if (readMarkerEventId)
    {
        [self setReadMarker:readMarkerEventId withReadReceipt:updatedReadReceiptEvent.eventId];
    }
    else if (updatedReadReceiptEvent)
    {
        [mxSession.matrixRestClient sendReadReceipt:self.roomId
                                            eventId:updatedReadReceiptEvent.eventId
                                            success:nil
                                            failure:nil];
    }
}

- (void)markAllAsRead
{
    NSString *readMarkerEventId = nil;
    MXReceiptData *updatedReceiptData = nil;
    
    // Retrieve the most recent event of the room.
    MXEvent *lastEvent = [mxSession.store messagesEnumeratorForRoom:self.roomId].nextEvent;
    NSString *lastMessageEventId = lastEvent.eventId;
    
    // Sanity check: Do not send read marker on event without id.
    if (!lastMessageEventId || [lastMessageEventId hasPrefix:kMXRoomInviteStateEventIdPrefix])
    {
        return;
    }
    
    // Prepare updated read marker
    if (![_accountData.readMarkerEventId isEqualToString:lastMessageEventId])
    {
        readMarkerEventId = lastMessageEventId;
    }

    MXEvent *event;
    NSString* myUserId = mxSession.myUserId;
    MXReceiptData *currentReceiptData = [mxSession.store getReceiptInRoom:self.roomId forUserId:myUserId];

    // Prepare updated read receipt
    @autoreleasepool
    {
        id<MXEventsEnumerator> messagesEnumerator = [mxSession.store messagesEnumeratorForRoom:self.roomId withTypeIn:mxSession.acknowledgableEventTypes];

        // Acknowledge the lastest valid event
        while ((event = messagesEnumerator.nextEvent))
        {
            // Sanity check on event id: Do not send read receipt on event without id
            if (event.eventId && ([event.eventId hasPrefix:kMXRoomInviteStateEventIdPrefix] == NO))
            {
                // Check whether this is not the current position of the user
                if (!currentReceiptData || ![currentReceiptData.eventId isEqualToString:event.eventId])
                {
                    // Update the oneself receipts
                    updatedReceiptData = [[MXReceiptData alloc] init];
                    
                    updatedReceiptData.userId = myUserId;
                    updatedReceiptData.eventId = event.eventId;
                    updatedReceiptData.ts = (uint64_t) ([[NSDate date] timeIntervalSince1970] * 1000);
                    
                    if ([mxSession.store storeReceipt:updatedReceiptData inRoom:self.roomId])
                    {
                        if ([mxSession.store respondsToSelector:@selector(commit)])
                        {
                            [mxSession.store commit];
                        }
                    }
                }
                
                // Break the loop
                break;
            }
        }
    }
    
    if (readMarkerEventId)
    {
        NSString *readReceiptEventId = updatedReceiptData.eventId;
        if (!readReceiptEventId)
        {
            // A non nil read receipt must be passed in order to not break notifications counters
            // homeserver side
            readReceiptEventId = currentReceiptData.eventId;
        }

        [self setReadMarker:readMarkerEventId withReadReceipt:readReceiptEventId];
    }
    else if (updatedReceiptData)
    {
        [mxSession.matrixRestClient sendReadReceipt:self.roomId
                                            eventId:updatedReceiptData.eventId
                                            success:nil
                                            failure:nil];
    }
}

- (NSArray<MXReceiptData*> *)getEventReceipts:(NSString*)eventId sorted:(BOOL)sort
{
    NSArray *receipts = [mxSession.store getEventReceipts:self.roomId eventId:eventId sorted:sort];
    
    // if some receipts are found
    if (receipts)
    {
        NSString* myUserId = mxSession.myUserId;
        NSMutableArray* res = [[NSMutableArray alloc] init];
        
        // Remove the oneself receipts
        for (MXReceiptData* data in receipts)
        {
            if (![data.userId isEqualToString:myUserId])
            {
                [res addObject:data];
            }
        }
        
        if (res.count > 0)
        {
            receipts = res;
        }
        else
        {
            receipts = nil;
        }
    }
    
    return receipts;
}

- (BOOL)storeLocalReceipt:(NSString *)receiptType eventId:(NSString *)eventId userId:(NSString *)userId ts:(uint64_t)ts
{
    // Sanity check
    if (!userId)
    {
        NSLog(@"[MXRoom] storeLocalReceipt: Error: nil user id");
        return NO;
    }

    BOOL result = NO;

    MXReceiptData* receiptData = [[MXReceiptData alloc] init];
    receiptData.userId = userId;
    receiptData.eventId = eventId;
    receiptData.ts = ts;

    if ([mxSession.store storeReceipt:receiptData inRoom:_roomId])
    {
        result = YES;

        // Notify SDK client about it with a local read receipt
        MXEvent *receiptEvent = [MXEvent modelFromJSON:
                                 @{
                                   @"type": kMXEventTypeStringReceipt,
                                   @"room_id": _roomId,
                                   @"content" : @{
                                           receiptData.eventId : @{
                                                   kMXEventTypeStringRead: @{
                                                           receiptData.userId: @{
                                                                   @"ts": @(receiptData.ts)
                                                                   }
                                                           }

                                                   }
                                           }
                                   }];

        [self liveTimeline:^(MXEventTimeline *theLiveTimeline) {
            [theLiveTimeline notifyListeners:receiptEvent direction:MXTimelineDirectionForwards];
        }];
    }

    return YES;
}

#pragma mark - Read marker handling

- (void)moveReadMarkerToEventId:(NSString*)eventId
{
    // Sanity check on event id: Do not send read marker on event without id
    if (eventId && ![eventId hasPrefix:kMXEventLocalEventIdPrefix] && ![eventId hasPrefix:kMXRoomInviteStateEventIdPrefix])
    {
        [self setReadMarker:eventId withReadReceipt:nil];
    }
}

- (void)forgetReadMarker
{
    // Retrieve the current position
    NSString *myUserId = mxSession.myUserId;
    MXReceiptData* currentData = [mxSession.store getReceiptInRoom:self.roomId forUserId:myUserId];
    if (currentData)
    {
        [self setReadMarker:currentData.eventId withReadReceipt:nil];
    }
}

- (void)setReadMarker:(NSString*)eventId withReadReceipt:(NSString*)receiptEventId
{
    _accountData.readMarkerEventId = eventId;
    
    // Update the store
    if ([mxSession.store respondsToSelector:@selector(storeAccountDataForRoom:userData:)])
    {
        [mxSession.store storeAccountDataForRoom:self.roomId userData:_accountData];
        
        if ([mxSession.store respondsToSelector:@selector(commit)])
        {
            [mxSession.store commit];
        }
    }
    
    // Update data on the homeserver side
    [mxSession.matrixRestClient sendReadMarker:self.roomId readMarkerEventId:eventId readReceiptEventId:receiptEventId success:nil failure:nil];
}

#pragma mark - Direct chats handling

- (BOOL)isDirect
{
    // Check whether this room is tagged as direct for one of the room members.
    return (self.directUserId != nil);
}

- (NSString *)directUserId
{
    // Get the information from the user account data that is managed by MXSession
    return [self.mxSession directUserIdInRoom:_roomId];
}

- (MXHTTPOperation*)setIsDirect:(BOOL)isDirect
                     withUserId:(NSString*)userId
                        success:(void (^)(void))success
                        failure:(void (^)(NSError *error))failure
{
    MXHTTPOperation *operation;

    if (isDirect)
    {
        if (userId)
        {
            operation = [self.mxSession setRoom:_roomId directWithUserId:userId success:success failure:failure];
        }
        else
        {
            // If there is no provided user id, find one
            MXWeakify(self);
            operation = [self members:^(MXRoomMembers *roomMembers) {
                MXStrongifyAndReturnIfNil(self);

                NSString *myUserId = self.mxSession.myUserId;

                // By default mark as direct this room for the oldest joined member.
                NSArray<MXRoomMember *> *members = roomMembers.joinedMembers;
                MXRoomMember *oldestJoinedMember;

                for (MXRoomMember *member in members)
                {
                    if (![member.userId isEqualToString:myUserId])
                    {
                        if (!oldestJoinedMember)
                        {
                            oldestJoinedMember = member;
                        }
                        else if (member.originalEvent.originServerTs < oldestJoinedMember.originalEvent.originServerTs)
                        {
                            oldestJoinedMember = member;
                        }
                    }
                }

                NSString * newDirectUserId = oldestJoinedMember.userId;
                if (!newDirectUserId)
                {
                    // Consider the first invited member if none has joined
                    members = [roomMembers membersWithMembership:MXMembershipInvite];

                    MXRoomMember *oldestInvitedMember;
                    for (MXRoomMember *member in members)
                    {
                        if (![member.userId isEqualToString:myUserId])
                        {
                            if (!oldestInvitedMember)
                            {
                                oldestInvitedMember = member;
                            }
                            else if (member.originalEvent.originServerTs < oldestInvitedMember.originalEvent.originServerTs)
                            {
                                oldestInvitedMember = member;
                            }
                        }
                    }

                    newDirectUserId = oldestInvitedMember.userId;
                }

                if (!newDirectUserId)
                {
                    // Use the current user by default
                    newDirectUserId = myUserId;
                }

                // Retry the operation with a user id
                MXHTTPOperation *operation2 =  [self setIsDirect:isDirect withUserId:newDirectUserId success:success failure:failure];
                [operation mutateTo:operation2];
            } failure:failure];
        }
    }
    else
    {
        // Remove the direct user id
        operation = [self.mxSession setRoom:_roomId directWithUserId:nil success:success failure:failure];
    }

    return operation;
}


#pragma mark - Crypto

- (MXHTTPOperation *)enableEncryptionWithAlgorithm:(NSString *)algorithm
                                           success:(void (^)(void))success failure:(void (^)(NSError *))failure
{
    MXHTTPOperation *operation;

    if (mxSession.crypto)
    {
        // Send the information to the homeserver
        operation = [self sendStateEventOfType:kMXEventTypeStringRoomEncryption
                                       content:@{
                                                 @"algorithm": algorithm
                                                 }
                                      stateKey:nil
                                       success:nil
                                       failure:failure];

        // Wait for the event coming back from the hs
        __block id eventBackListener;
        eventBackListener = [self listenToEventsOfTypes:@[kMXEventTypeStringRoomEncryption] onEvent:^(MXEvent *event, MXTimelineDirection direction, MXRoomState *roomState) {
            
            [self removeListener:eventBackListener];

            // Dispatch to let time to MXCrypto to digest the m.room.encryption event
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success)
                {
                    success();
                }
            });
        }];
    }
    else
    {
        failure([NSError errorWithDomain:MXDecryptingErrorDomain
                                    code:MXDecryptingErrorEncryptionNotEnabledCode
                                userInfo:@{
                                           NSLocalizedDescriptionKey: MXDecryptingErrorEncryptionNotEnabledReason
                                           }]);
    }

    return operation;
}

/**
 Check if we need to encrypt event with a given type.

 @param eventType the event type
 @return YES to event.
 */
- (BOOL)isEncryptionRequiredForEventType:(MXEventTypeString)eventType
{
    BOOL isEncryptionRequired = YES;

    if ([eventType isEqualToString:kMXEventTypeStringReaction])
    {
        // Do not encrypt reaction for the moment
        isEncryptionRequired = NO;
    }

    return isEncryptionRequired;
}

- (void)membersTrustLevelSummaryWithForceDownload:(BOOL)forceDownload success:(void (^)(MXUsersTrustLevelSummary *usersTrustLevelSummary))success failure:(void (^)(NSError *error))failure
{
    MXCrypto *crypto = mxSession.crypto;
    
    if (crypto && self.summary.isEncrypted)
    {
        [self members:^(MXRoomMembers *roomMembers) {
            
            NSArray<MXRoomMember*> *members = roomMembers.members;
            
            NSMutableArray<NSString*> *memberIds = [[NSMutableArray alloc] initWithCapacity:members.count];
            
            for (MXRoomMember *member in members)
            {
                [memberIds addObject:member.userId];
            }
            
            if (forceDownload)
            {
                [crypto trustLevelSummaryForUserIds:memberIds success:success failure:failure];
            }
            else
            {
                [crypto trustLevelSummaryForUserIds:memberIds onComplete:^(MXUsersTrustLevelSummary *trustLevelSummary) {
                    success(trustLevelSummary);
                }];
            }
            
        } failure:failure];
    }
    else
    {
        NSError *error = [NSError errorWithDomain:MXDecryptingErrorDomain
                                             code:MXDecryptingErrorEncryptionNotEnabledCode
                                         userInfo:@{
                                                    NSLocalizedDescriptionKey: MXDecryptingErrorEncryptionNotEnabledReason
                                                    }];
        failure(error);
    }
}

#pragma mark - Utils

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MXRoom: %p> %@: %@ - %@", self, self.roomId, self.summary.displayname, self.summary.topic];
}

- (NSComparisonResult)compareLastMessageEventOriginServerTs:(MXRoom *)otherRoom
{
    return [self.summary.lastMessageEvent compareOriginServerTs:otherRoom.summary.lastMessageEvent];
}

@end
