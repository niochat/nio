/*
 Copyright 2015 OpenMarket Ltd
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

#import "MXCallManager.h"

#import "MXCall.h"
#import "MXCallKitAdapter.h"
#import "MXCallStack.h"
#import "MXJSONModels.h"
#import "MXRoom.h"
#import "MXSession.h"
#import "MXTools.h"

#pragma mark - Constants definitions
NSString *const kMXCallManagerNewCall            = @"kMXCallManagerNewCall";
NSString *const kMXCallManagerConferenceStarted  = @"kMXCallManagerConferenceStarted";
NSString *const kMXCallManagerConferenceFinished = @"kMXCallManagerConferenceFinished";


@interface MXCallManager ()
{
    /**
     Calls being handled.
     */
    NSMutableArray<MXCall *> *calls;

    /**
     Listener to Matrix call-related events.
     */
    id callEventsListener;

    /**
     Timer to periodically refresh the TURN server config.
     */
    NSTimer *refreshTURNServerTimer;
    
    /**
     Observer for changes of MXSession's state
     */
    id sessionStateObserver;
}
@end


@implementation MXCallManager

- (instancetype)initWithMatrixSession:(MXSession *)mxSession andCallStack:(id<MXCallStack>)callstack
{
    self = [super init];
    if (self)
    {
        _mxSession = mxSession;
        calls = [NSMutableArray array];
        _inviteLifetime = 30000;

        _callStack = callstack;
        
        // Listen to call events
        callEventsListener = [mxSession listenToEventsOfTypes:@[
                                                                kMXEventTypeStringCallInvite,
                                                                kMXEventTypeStringCallCandidates,
                                                                kMXEventTypeStringCallAnswer,
                                                                kMXEventTypeStringCallHangup
                                                                ]
                                                      onEvent:^(MXEvent *event, MXTimelineDirection direction, id customObject) {

            if (MXTimelineDirectionForwards == direction)
            {
                switch (event.eventType)
                {
                    case MXEventTypeCallInvite:
                        [self handleCallInvite:event];
                        break;

                    case MXEventTypeCallAnswer:
                        [self handleCallAnswer:event];
                        break;

                    case MXEventTypeCallHangup:
                        [self handleCallHangup:event];
                        break;

                    case MXEventTypeCallCandidates:
                        [self handleCallCandidates:event];
                        break;
                    default:
                        break;
                }
            }
        }];

        // Listen to call state changes
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleCallStateDidChangeNotification:)
                                                     name:kMXCallStateDidChange
                                                   object:nil];
        
        [self refreshTURNServer];
    }
    return self;
}

- (void)dealloc
{
    [self unregisterFromNotifications];
}

- (void)close
{
    [_mxSession removeListener:callEventsListener];
    callEventsListener = nil;

    // Hang up all calls
    for (MXCall *call in calls)
    {
        [call hangup];
    }
    [calls removeAllObjects];
    calls = nil;

    // Do not refresh TURN servers config anymore
    [refreshTURNServerTimer invalidate];
    refreshTURNServerTimer = nil;
    
    // Unregister from any possible notifications
    [self unregisterFromNotifications];
}

- (MXCall *)callWithCallId:(NSString *)callId
{
    MXCall *theCall;
    for (MXCall *call in calls)
    {
        if ([call.callId isEqualToString:callId])
        {
            theCall = call;
            break;
        }
    }
    return theCall;
}

- (MXCall *)callInRoom:(NSString *)roomId
{
    MXCall *theCall;
    for (MXCall *call in calls)
    {
        if ([call.room.roomId isEqualToString:roomId])
        {
            theCall = call;
            break;
        }
    }
    return theCall;
}

- (void)placeCallInRoom:(NSString *)roomId withVideo:(BOOL)video
                success:(void (^)(MXCall *call))success
                failure:(void (^)(NSError * _Nullable error))failure
{
    // If consumers of our API decide to use SiriKit or CallKit, they will face with application:continueUserActivity:restorationHandler:
    // and since the state of MXSession can be different from MXSessionStateRunning for the moment when this method will be executing
    // we must track session's state to become MXSessionStateRunning for performing outgoing call
    if (_mxSession.state != MXSessionStateRunning)
    {
        MXWeakify(self);
        __weak NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        sessionStateObserver = [center addObserverForName:kMXSessionStateDidChangeNotification
                                                   object:_mxSession
                                                    queue:[NSOperationQueue mainQueue]
                                               usingBlock:^(NSNotification * _Nonnull note) {
                                                   MXStrongifyAndReturnIfNil(self);
                                                   
                                                   if (self.mxSession.state == MXSessionStateRunning)
                                                   {
                                                       [self placeCallInRoom:roomId
                                                                         withVideo:video
                                                                           success:success
                                                                           failure:failure];
                                                       
                                                       [center removeObserver:self->sessionStateObserver];
                                                       self->sessionStateObserver = nil;
                                                   }
                                               }];
        return;
    }
    
    MXRoom *room = [_mxSession roomWithRoomId:roomId];

    if (room && 1 < room.summary.membersCount.joined)
    {
        if (2 == room.summary.membersCount.joined)
        {
            // Do a peer to peer, one to one call
            MXCall *call = [[MXCall alloc] initWithRoomId:roomId andCallManager:self];
            if (call)
            {
                [calls addObject:call];

                [call callWithVideo:video];

                // Broadcast the new outgoing call
                [[NSNotificationCenter defaultCenter] postNotificationName:kMXCallManagerNewCall object:call userInfo:nil];

                if (success)
                {
                    success(call);
                }
            }
            else
            {
                if (failure)
                {
                    failure(nil);
                }
            }
        }
        else
        {
            // Use the conference server bot to manage the conf call
            // There are 2 steps:
            //    - invite the conference user (the bot) into the room
            //    - set up a separated private room with the conference user to manage
            //      the conf call in 'room'
            MXWeakify(self);
            [self inviteConferenceUserToRoom:room success:^{
                MXStrongifyAndReturnIfNil(self);

                MXWeakify(self);
                [self conferenceUserRoomForRoom:roomId success:^(MXRoom *conferenceUserRoom) {
                    MXStrongifyAndReturnIfNil(self);

                    // The call can now be created
                    MXCall *call = [[MXCall alloc] initWithRoomId:roomId callSignalingRoomId:conferenceUserRoom.roomId andCallManager:self];
                    if (call)
                    {
                        [self->calls addObject:call];

                        [call callWithVideo:video];

                        // Broadcast the new outgoing call
                        [[NSNotificationCenter defaultCenter] postNotificationName:kMXCallManagerNewCall object:call userInfo:nil];
                    }

                    if (success)
                    {
                        success(call);
                    }
                } failure:failure];

            } failure:failure];
        }
    }
    else
    {
        NSLog(@"[MXCallManager] placeCallInRoom: ERROR: Cannot place call in %@. Members count: %tu", roomId, room.summary.membersCount.joined);

        if (failure)
        {
            // @TODO: Provide an error
            failure(nil);
        }
    }
}

- (void)removeCall:(MXCall *)call
{
    [calls removeObject:call];
}


#pragma mark - Private methods
- (void)refreshTURNServer
{
    MXWeakify(self);
    [_mxSession.matrixRestClient turnServer:^(MXTurnServerResponse *turnServerResponse) {
        MXStrongifyAndReturnIfNil(self);

        NSLog(@"[MXCallManager] refreshTURNServer: TTL:%tu URIs: %@", turnServerResponse.ttl, turnServerResponse.uris);

        if (turnServerResponse.uris)
        {
            self->_turnServers = turnServerResponse;

            // Re-new when we're about to reach the TTL
            self->refreshTURNServerTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:turnServerResponse.ttl * 0.9]
                                                                    interval:0
                                                                      target:self
                                                                    selector:@selector(refreshTURNServer)
                                                                    userInfo:nil
                                                                     repeats:NO];
            [[NSRunLoop mainRunLoop] addTimer:self->refreshTURNServerTimer forMode:NSDefaultRunLoopMode];
        }
        else
        {
            NSLog(@"No TURN server: using fallback STUN server: %@", self->_fallbackSTUNServer);
            self->_turnServers = nil;
        }

    } failure:^(NSError *error) {
        MXStrongifyAndReturnIfNil(self);

        NSLog(@"[MXCallManager] refreshTURNServer: Failed to get TURN URIs.\n");
        NSLog(@"Retry in 60s");
        self->refreshTURNServerTimer = [NSTimer timerWithTimeInterval:60 target:self selector:@selector(refreshTURNServer) userInfo:nil repeats:NO];
        [[NSRunLoop mainRunLoop] addTimer:self->refreshTURNServerTimer forMode:NSDefaultRunLoopMode];
    }];
}

- (void)handleCallInvite:(MXEvent *)event
{
    MXCallInviteEventContent *content = [MXCallInviteEventContent modelFromJSON:event.content];

    // Check expiration (usefull filter when receiving load of events when resuming the event stream)
    if (event.age < content.lifetime)
    {
        // If it is an invite from the peer, we need to create the MXCall
        if (![event.sender isEqualToString:_mxSession.myUserId])
        {
            MXCall *call = [self callWithCallId:content.callId];
            if (!call)
            {
                call = [[MXCall alloc] initWithRoomId:event.roomId andCallManager:self];
                if (call)
                {
                    [calls addObject:call];

                    [call handleCallEvent:event];

                    // Broadcast the incoming call
                    [self notifyCallInvite:call.callId];
                }
            }
            else
            {
                [call handleCallEvent:event];
            }
        }
    }
}

- (void)notifyCallInvite:(NSString *)callId
{
    MXCall *call = [self callWithCallId:callId];

    if (call)
    {
        // If the app is resuming, wait for the complete end of the session resume in order
        // to check if the invite is still valid
        if (_mxSession.state == MXSessionStateSyncInProgress || _mxSession.state == MXSessionStateBackgroundSyncInProgress)
        {
            // The dispatch  on the main thread should be enough.
            // It means that the sync response that contained the invite (and possibly its end
            // of validity) has been fully parsed.
            MXWeakify(self);
            dispatch_async(dispatch_get_main_queue(), ^{
                MXStrongifyAndReturnIfNil(self);
                [self notifyCallInvite:callId];
            });
        }
        else if (call.state < MXCallStateConnected)
        {
            // If the call is still in ringing state, notify the app
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXCallManagerNewCall object:call userInfo:nil];
        }
    }
}

- (void)handleCallAnswer:(MXEvent *)event
{
    MXCallAnswerEventContent *content = [MXCallAnswerEventContent modelFromJSON:event.content];

    MXCall *call = [self callWithCallId:content.callId];
    if (call)
    {
        [call handleCallEvent:event];
    }
}

- (void)handleCallHangup:(MXEvent *)event
{
    MXCallHangupEventContent *content = [MXCallHangupEventContent modelFromJSON:event.content];

    // Forward the event to the MXCall object
    MXCall *call = [self callWithCallId:content.callId];
    if (call)
    {
        [call handleCallEvent:event];
    }

    // Forget this call. It is no more in progress
    [calls removeObject:call];
}

- (void)handleCallCandidates:(MXEvent *)event
{
    MXCallCandidatesEventContent *content = [MXCallCandidatesEventContent modelFromJSON:event.content];

    // Forward the event to the MXCall object
    MXCall *call = [self callWithCallId:content.callId];
    if (call)
    {
        [call handleCallEvent:event];
    }
}

- (void)handleCallStateDidChangeNotification:(NSNotification *)notification
{
#if TARGET_OS_IPHONE
    MXCall *call = notification.object;
    
    switch (call.state) {
        case MXCallStateCreateOffer:
            [self.callKitAdapter startCall:call];
            break;
        case MXCallStateRinging:
            [self.callKitAdapter reportIncomingCall:call];
            break;
        case MXCallStateConnecting:
            [self.callKitAdapter reportCall:call startedConnectingAtDate:nil];
            break;
        case MXCallStateConnected:
            [self.callKitAdapter reportCall:call connectedAtDate:nil];
            break;
        case MXCallStateEnded:
            [self.callKitAdapter endCall:call];
            break;
        default:
            break;
    }
#endif
}

- (void)unregisterFromNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    // Do not handle any call state change notifications
    [notificationCenter removeObserver:self name:kMXCallStateDidChange object:nil];
    
    // Don't track MXSession's state
    if (sessionStateObserver)
    {
        [notificationCenter removeObserver:sessionStateObserver name:kMXSessionStateDidChangeNotification object:_mxSession];
        sessionStateObserver = nil;
    }
}

#pragma mark - Conference call

// Copied from vector-web:
// FIXME: This currently forces Vector to try to hit the matrix.org AS for conferencing.
// This is bad because it prevents people running their own ASes from being used.
// This isn't permanent and will be customisable in the future: see the proposal
// at docs/conferencing.md for more info.
NSString *const kMXCallManagerConferenceUserPrefix  = @"@fs_";
NSString *const kMXCallManagerConferenceUserDomain  = @"matrix.org";

- (void)handleConferenceUserUpdate:(MXRoomMember *)conferenceUserMember inRoom:(NSString *)roomId
{
    if (_mxSession.state == MXSessionStateRunning)
    {
        if (conferenceUserMember.membership == MXMembershipJoin)
        {
            // Broadcast the ongoing conference call
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXCallManagerConferenceStarted object:roomId userInfo:nil];
        }
        else if (conferenceUserMember.membership == MXMembershipLeave)
        {
            // Broadcast the end of the ongoing conference call
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXCallManagerConferenceFinished object:roomId userInfo:nil];
        }
    }
}

+ (NSString *)conferenceUserIdForRoom:(NSString *)roomId
{
    // Apply the same algo as other matrix clients
    NSString *base64RoomId = [[roomId dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    base64RoomId = [base64RoomId stringByReplacingOccurrencesOfString:@"=" withString:@""];

    return [NSString stringWithFormat:@"%@%@:%@", kMXCallManagerConferenceUserPrefix, base64RoomId, kMXCallManagerConferenceUserDomain];
}

+ (BOOL)isConferenceUser:(NSString *)userId
{
    BOOL isConferenceUser = NO;

    if ([userId hasPrefix:kMXCallManagerConferenceUserPrefix])
    {
        NSString *base64part = [userId substringWithRange:NSMakeRange(4, [userId rangeOfString:@":"].location - 4)];
        if (base64part)
        {
            NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:base64part options:0];
            if (decodedData)
            {
                NSString *decoded = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
                if (decoded)
                {
                    isConferenceUser = [MXTools isMatrixRoomIdentifier:decoded];
                }
            }
        }
    }

    return isConferenceUser;
}

+ (BOOL)canPlaceConferenceCallInRoom:(MXRoom *)room roomState:(MXRoomState *)roomState
{
    BOOL canPlaceConferenceCallInRoom = NO;

    if (roomState.isOngoingConferenceCall)
    {
        // All room members can join an existing conference call
        canPlaceConferenceCallInRoom = YES;
    }
    else
    {
        MXRoomPowerLevels *powerLevels = roomState.powerLevels;
        NSInteger oneSelfPowerLevel = [powerLevels powerLevelOfUserWithUserID:room.mxSession.myUserId];

        // Only member with invite power level can create a conference call
        if (oneSelfPowerLevel >= powerLevels.invite)
        {
            canPlaceConferenceCallInRoom = YES;
        }
    }

    return canPlaceConferenceCallInRoom;
}

/**
 Make sure the conference user is in the passed room.

 It is mandatory before starting the conference call.

 @param room the room.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (void)inviteConferenceUserToRoom:(MXRoom *)room
                           success:(void (^)(void))success
                           failure:(void (^)(NSError *error))failure
{
    NSString *conferenceUserId = [MXCallManager conferenceUserIdForRoom:room.roomId];

    [room members:^(MXRoomMembers *roomMembers) {
        MXRoomMember *conferenceUserMember = [roomMembers memberWithUserId:conferenceUserId];
        if (conferenceUserMember && conferenceUserMember.membership == MXMembershipJoin)
        {
            success();
        }
        else
        {
            [room inviteUser:conferenceUserId success:success failure:failure];
        }
    } failure:failure];
}

/**
 Get the room with the conference user dedicated for the passed room.

 @param roomId the room id.
 @param success A block object called when the operation succeeds. 
                It returns the private room with conference user.
 @param failure A block object called when the operation fails.
 */
- (void)conferenceUserRoomForRoom:(NSString*)roomId
                          success:(void (^)(MXRoom *conferenceUserRoom))success
                          failure:(void (^)(NSError *error))failure
{
    NSString *conferenceUserId = [MXCallManager conferenceUserIdForRoom:roomId];

    // Use an existing 1:1 with the conference user; else make one
    __block MXRoom *conferenceUserRoom;

    dispatch_group_t group = dispatch_group_create();
    for (MXRoomSummary *roomSummary in _mxSession.roomsSummaries)
    {
        if (roomSummary.isConferenceUserRoom)
        {
            dispatch_group_enter(group);
            MXRoom *room = [_mxSession roomWithRoomId:roomSummary.roomId];

            [room state:^(MXRoomState *roomState) {
                if ([roomState.members memberWithUserId:conferenceUserId])
                {
                    conferenceUserRoom = room;
                }

                dispatch_group_leave(group);
            }];
        }
    }

    MXWeakify(self);
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        MXStrongifyAndReturnIfNil(self);

        if (conferenceUserRoom)
        {
            success(conferenceUserRoom);
        }
        else
        {
            [self.mxSession createRoom:@{
                                         @"preset": @"private_chat",
                                         @"invite": @[conferenceUserId]
                                         } success:^(MXRoom *room) {

                                             success(room);

                                         } failure:failure];
        }
    });
}

@end
