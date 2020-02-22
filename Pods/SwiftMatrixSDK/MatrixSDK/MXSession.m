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

#import "MXSession.h"
#import "MatrixSDK.h"

#import <AFNetworking/AFNetworking.h>

#import "MXSessionEventListener.h"

#import "MXTools.h"
#import "MXHTTPClient.h"

#import "MXNoStore.h"
#import "MXMemoryStore.h"
#import "MXFileStore.h"

#import "MXDecryptionResult.h"

#import "MXAccountData.h"
#import "MXSDKOptions.h"
#import "MXBackgroundModeHandler.h"

#import "MXRoomSummaryUpdater.h"

#import "MXRoomFilter.h"

#import "MXScanManager.h"

#import "MXAggregations_Private.h"

#pragma mark - Constants definitions

const NSString *MatrixSDKVersion = @"0.15.2";
NSString *const kMXSessionStateDidChangeNotification = @"kMXSessionStateDidChangeNotification";
NSString *const kMXSessionNewRoomNotification = @"kMXSessionNewRoomNotification";
NSString *const kMXSessionWillLeaveRoomNotification = @"kMXSessionWillLeaveRoomNotification";
NSString *const kMXSessionDidLeaveRoomNotification = @"kMXSessionDidLeaveRoomNotification";
NSString *const kMXSessionDidSyncNotification = @"kMXSessionDidSyncNotification";
NSString *const kMXSessionInvitedRoomsDidChangeNotification = @"kMXSessionInvitedRoomsDidChangeNotification";
NSString *const kMXSessionOnToDeviceEventNotification = @"kMXSessionOnToDeviceEventNotification";
NSString *const kMXSessionIgnoredUsersDidChangeNotification = @"kMXSessionIgnoredUsersDidChangeNotification";
NSString *const kMXSessionDirectRoomsDidChangeNotification = @"kMXSessionDirectRoomsDidChangeNotification";
NSString *const kMXSessionAccountDataDidChangeNotification = @"kMXSessionAccountDataDidChangeNotification";
NSString *const kMXSessionAccountDataDidChangeIdentityServerNotification = @"kMXSessionAccountDataDidChangeIdentityServerNotification";
NSString *const kMXSessionDidCorruptDataNotification = @"kMXSessionDidCorruptDataNotification";
NSString *const kMXSessionCryptoDidCorruptDataNotification = @"kMXSessionCryptoDidCorruptDataNotification";
NSString *const kMXSessionNewGroupInviteNotification = @"kMXSessionNewGroupInviteNotification";
NSString *const kMXSessionDidJoinGroupNotification = @"kMXSessionDidJoinGroupNotification";
NSString *const kMXSessionDidLeaveGroupNotification = @"kMXSessionDidLeaveGroupNotification";
NSString *const kMXSessionDidUpdateGroupSummaryNotification = @"kMXSessionDidUpdateGroupSummaryNotification";
NSString *const kMXSessionDidUpdateGroupRoomsNotification = @"kMXSessionDidUpdateGroupRoomsNotification";
NSString *const kMXSessionDidUpdateGroupUsersNotification = @"kMXSessionDidUpdateGroupUsersNotification";
NSString *const kMXSessionDidUpdatePublicisedGroupsForUsersNotification = @"kMXSessionDidUpdatePublicisedGroupsForUsersNotification";

NSString *const kMXSessionNotificationRoomIdKey = @"roomId";
NSString *const kMXSessionNotificationGroupKey = @"group";
NSString *const kMXSessionNotificationGroupIdKey = @"groupId";
NSString *const kMXSessionNotificationEventKey = @"event";
NSString *const kMXSessionNotificationSyncResponseKey = @"syncResponse";
NSString *const kMXSessionNotificationErrorKey = @"error";
NSString *const kMXSessionNotificationUserIdsArrayKey = @"userIds";

NSString *const kMXSessionNoRoomTag = @"m.recent";  // Use the same value as matrix-react-sdk

/**
 Default timeouts used by the events streams.
 */
#define SERVER_TIMEOUT_MS 30000
#define CLIENT_TIMEOUT_MS 120000

/**
 Time before retrying in case of `MXSessionStateSyncError`.
 */
#define RETRY_SYNC_AFTER_MXERROR_MS 5000


// Block called when MSSession resume is complete
typedef void (^MXOnResumeDone)(void);

@interface MXSession ()
{
    /**
     Rooms data
     Each key is a room id. Each value, the MXRoom instance.
     */
    NSMutableDictionary<NSString*, MXRoom*> *rooms;

    /**
     Rooms summaries
     Each key is a room id. Each value, the MXRoomSummary instance.
     */
    NSMutableDictionary<NSString*, MXRoomSummary*> *roomsSummaries;

    /**
     The current request of the event stream.
     */
    MXHTTPOperation *eventStreamRequest;

    /**
     The list of global events listeners (`MXSessionEventListener`).
     */
    NSMutableArray *globalEventListeners;

    /** 
     The block to call when MSSession resume is complete.
     */
    MXOnResumeDone onResumeDone;
    
    /**
     The block to call when MSSession backgroundSync is successfully done.
     */
    MXOnBackgroundSyncDone onBackgroundSyncDone;
    
    /**
     The block to call when MSSession backgroundSync fails.
     */
    MXOnBackgroundSyncFail onBackgroundSyncFail;

    /**
     The maintained list of rooms where the user has a pending invitation.
     */
    NSMutableArray<MXRoom *> *invitedRooms;

    /**
     The rooms being peeked.
     */
    NSMutableArray<MXPeekingRoom *> *peekingRooms;

    /**
     For debug, indicate if the first sync after the MXSession startup is done.
     */
    BOOL firstSyncDone;

    /**
     The tool to refresh the homeserver wellknown data.
     */
    MXAutoDiscovery *autoDiscovery;
    
    /**
     Queue of requested direct room change operations ([MXSession setRoom:directWithUserId:]
     or [MXSession uploadDirectRooms:])
     */
    NSMutableArray<dispatch_block_t> *directRoomsOperationsQueue;
   
    /**
     The current publicised groups list by userId dictionary.
     The key is the user id; the value, the list of the group ids that the user enabled in his profile.
     */
    NSMutableDictionary <NSString*, NSArray<NSString*>*> *publicisedGroupsByUserId;
    
    /**
     The list of users for who a publicised groups list is available but outdated.
     */
    NSMutableArray <NSString*> *userIdsWithOutdatedPublicisedGroups;
}

/**
 The count of prevent pause tokens.
 */
@property (nonatomic) NSUInteger preventPauseCount;

@property (nonatomic, readwrite) MXScanManager *scanManager;

/**
 The background task used when the session continue to run the events stream when
 the app goes in background.
 */
@property (nonatomic, strong) id<MXBackgroundTask> backgroundTask;

@end

@implementation MXSession
@synthesize matrixRestClient, mediaManager;

- (id)initWithMatrixRestClient:(MXRestClient*)mxRestClient
{
    self = [super init];
    if (self)
    {
        matrixRestClient = mxRestClient;
        _threePidAddManager = [[MX3PidAddManager alloc] initWithMatrixSession:self];
        mediaManager = [[MXMediaManager alloc] initWithHomeServer:matrixRestClient.homeserver];
        rooms = [NSMutableDictionary dictionary];
        roomsSummaries = [NSMutableDictionary dictionary];
        _roomSummaryUpdateDelegate = [MXRoomSummaryUpdater roomSummaryUpdaterForSession:self];
        globalEventListeners = [NSMutableArray array];
        _notificationCenter = [[MXNotificationCenter alloc] initWithMatrixSession:self];
        _accountData = [[MXAccountData alloc] init];
        peekingRooms = [NSMutableArray array];
        _preventPauseCount = 0;
        directRoomsOperationsQueue = [NSMutableArray array];
        publicisedGroupsByUserId = [[NSMutableDictionary alloc] init];

        [self setIdentityServer:mxRestClient.identityServer andAccessToken:mxRestClient.credentials.identityServerAccessToken];
        
        firstSyncDone = NO;

        _acknowledgableEventTypes = @[kMXEventTypeStringRoomName,
                                      kMXEventTypeStringRoomTopic,
                                      kMXEventTypeStringRoomAvatar,
                                      kMXEventTypeStringRoomMember,
                                      kMXEventTypeStringRoomCreate,
                                      kMXEventTypeStringRoomEncrypted,
                                      kMXEventTypeStringRoomJoinRules,
                                      kMXEventTypeStringRoomPowerLevels,
                                      kMXEventTypeStringRoomAliases,
                                      kMXEventTypeStringRoomCanonicalAlias,
                                      kMXEventTypeStringRoomGuestAccess,
                                      kMXEventTypeStringRoomHistoryVisibility,
                                      kMXEventTypeStringRoomMessage,
                                      kMXEventTypeStringRoomMessageFeedback,
                                      kMXEventTypeStringRoomRedaction,
                                      kMXEventTypeStringRoomThirdPartyInvite,
                                      kMXEventTypeStringRoomRelatedGroups,
                                      kMXEventTypeStringReaction,
                                      kMXEventTypeStringCallInvite,
                                      kMXEventTypeStringCallCandidates,
                                      kMXEventTypeStringCallAnswer,
                                      kMXEventTypeStringCallHangup,
                                      kMXEventTypeStringSticker
                                      ];

        _unreadEventTypes = @[kMXEventTypeStringRoomName,
                              kMXEventTypeStringRoomTopic,
                              kMXEventTypeStringRoomMessage,
                              kMXEventTypeStringCallInvite,
                              kMXEventTypeStringRoomEncrypted,
                              kMXEventTypeStringSticker
                              ];

        _catchingUp = NO;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDidDecryptEvent:) name:kMXEventDidDecryptNotification object:nil];

        [self setState:MXSessionStateInitialised];
    }
    return self;
}

- (void)setState:(MXSessionState)state
{
    if (_state != state)
    {
        _state = state;

        if (_state != MXSessionStateSyncError)
        {
            // Reset the sync error
            _syncError = nil;
        }
        
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter postNotificationName:kMXSessionStateDidChangeNotification object:self userInfo:nil];
    }
}

-(void)setStore:(id<MXStore>)store success:(void (^)(void))onStoreDataReady failure:(void (^)(NSError *))failure
{
    NSAssert(MXSessionStateInitialised == _state, @"Store can be set only just after initialisation");
    NSParameterAssert(store);

    _store = store;

    // Validate the permanent implementation
    if (_store.isPermanent)
    {
        // A permanent MXStore must implement these methods:
        NSParameterAssert([_store respondsToSelector:@selector(rooms)]);
        NSParameterAssert([_store respondsToSelector:@selector(storeStateForRoom:stateEvents:)]);
        NSParameterAssert([_store respondsToSelector:@selector(stateOfRoom:success:failure:)]);
        NSParameterAssert([_store respondsToSelector:@selector(summaryOfRoom:)]);
    }

    NSDate *startDate = [NSDate date];

    MXWeakify(self);
    [_store openWithCredentials:matrixRestClient.credentials onComplete:^{
        MXStrongifyAndReturnIfNil(self);
        
        // Sanity check: The session may be closed before the end of store opening.
        if (!self->matrixRestClient)
        {
            return;
        }

        self->_aggregations = [[MXAggregations alloc] initWithMatrixSession:self];

        // Check if the user has enabled crypto
        MXWeakify(self);
        [MXCrypto checkCryptoWithMatrixSession:self complete:^(MXCrypto *crypto) {
            MXStrongifyAndReturnIfNil(self);
            
            self->_crypto = crypto;

            // Sanity check: The session may be closed before the end of this operation.
            if (!self->matrixRestClient)
            {
                return;
            }

            // Can we start on data from the MXStore?
            if (self.store.isPermanent && self.isEventStreamInitialised)
            {
                // Mount data from the permanent store
                NSLog(@"[MXSession] Loading room state events to build MXRoom objects...");

                // Create myUser from the store
                MXUser *myUser = [self.store userWithUserId:self->matrixRestClient.credentials.userId];

                // My user is a MXMyUser object
                self->_myUser = (MXMyUser*)myUser;
                self->_myUser.mxSession = self;

                // Load user account data
                [self handleAccountData:self.store.userAccountData];

                // Load MXRoomSummaries from the store
                NSDate *startDate2 = [NSDate date];
                for (NSString *roomId in self.store.rooms)
                {
                    @autoreleasepool
                    {
                        MXRoomSummary *summary = [self.store summaryOfRoom:roomId];
                        [summary setMatrixSession:self];
                        self->roomsSummaries[roomId] = summary;
                    }
                }

                NSLog(@"[MXSession] Built %lu MXRoomSummaries in %.0fms", (unsigned long)self->roomsSummaries.allKeys.count, [[NSDate date] timeIntervalSinceDate:startDate2] * 1000);

                // Create MXRooms from their states stored in the store
                NSDate *startDate3 = [NSDate date];
                for (NSString *roomId in self.store.rooms)
                {
                    [self loadRoom:roomId];
                }

                NSLog(@"[MXSession] Built %lu MXRooms in %.0fms", (unsigned long)self->rooms.allKeys.count, [[NSDate date] timeIntervalSinceDate:startDate3] * 1000);

                NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:startDate];
                NSLog(@"[MXSession] Total time to mount SDK data from MXStore: %.0fms", duration * 1000);

                [[MXSDKOptions sharedInstance].analyticsDelegate trackStartupMountDataDuration:duration];
                
                [self setState:MXSessionStateStoreDataReady];

                // The SDK client can use this data
                onStoreDataReady();
            }
            else
            {
                // Create self.myUser instance to expose the user id as soon as possible
                self->_myUser = [[MXMyUser alloc] initWithUserId:self->matrixRestClient.credentials.userId];
                self->_myUser.mxSession = self;
                
                NSLog(@"[MXSession] Total time to mount SDK data from MXStore: %.0fms", [[NSDate date] timeIntervalSinceDate:startDate] * 1000);
                
                [self setState:MXSessionStateStoreDataReady];
                
                // The SDK client can use this data
                onStoreDataReady();
            }
        }];

    } failure:^(NSError *error) {
        [self setState:MXSessionStateInitialised];

        if (failure)
        {
            failure(error);
        }
    }];
}

- (void)setIdentityServer:(NSString *)identityServer andAccessToken:(NSString *)accessToken
{
    NSLog(@"[MXSession] setIdentityServer: %@", identityServer);
    
    matrixRestClient.identityServer = identityServer;

    if (identityServer)
    {
        _identityService = [[MXIdentityService alloc] initWithIdentityServer:identityServer accessToken:accessToken andHomeserverRestClient:matrixRestClient];
    }
    else
    {
        _identityService = nil;
    }

    MXWeakify(self);
    matrixRestClient.identityServerAccessTokenHandler = ^MXHTTPOperation *(void (^success)(NSString *accessToken), void (^failure)(NSError *error)) {
        MXStrongifyAndReturnValueIfNil(self, nil);
        return [self.identityService accessTokenWithSuccess:success failure:failure];
    };
}

- (void)start:(void (^)(void))onServerSyncDone
      failure:(void (^)(NSError *error))failure
{
    [self startWithSyncFilter:nil onServerSyncDone:onServerSyncDone failure:failure];
}

- (void)startWithSyncFilter:(MXFilterJSONModel*)syncFilter
           onServerSyncDone:(void (^)(void))onServerSyncDone
                    failure:(void (^)(NSError *error))failure;
{
    NSLog(@"[MXSession] startWithSyncFilter: %@", syncFilter);

    if (syncFilter)
    {
        // Build or retrieve the filter before launching the event stream
        MXWeakify(self);
        [self setFilter:syncFilter success:^(NSString *filterId) {
            MXStrongifyAndReturnIfNil(self);

            [self startWithSyncFilterId:filterId onServerSyncDone:onServerSyncDone failure:failure];

        } failure:^(NSError *error) {
            MXStrongifyAndReturnIfNil(self);

            NSLog(@"[MXSession] startWithSyncFilter: WARNING: Impossible to create the filter. Use no filter in /sync");
            [self startWithSyncFilterId:nil onServerSyncDone:onServerSyncDone failure:failure];
        }];
    }
    else
    {
        [self startWithSyncFilterId:nil onServerSyncDone:onServerSyncDone failure:failure];
    }
}

- (void)startWithSyncFilterId:(NSString *)syncFilterId onServerSyncDone:(void (^)(void))onServerSyncDone failure:(void (^)(NSError *))failure
{
    if (nil == _store)
    {
        // The user did not set a MXStore, use MXNoStore as default
        MXNoStore *store = [[MXNoStore alloc] init];

        // Set the store before going further
        MXWeakify(self);
        [self setStore:store success:^{
            MXStrongifyAndReturnIfNil(self);

            // Then, start again
            [self startWithSyncFilterId:syncFilterId onServerSyncDone:onServerSyncDone failure:failure];

        } failure:^(NSError *error) {
            MXStrongifyAndReturnIfNil(self);

            [self setState:MXSessionStateInitialSyncFailed];
            failure(error);
            
        }];
        return;
    }

    [self setState:MXSessionStateSyncInProgress];

    // Check update of the filter used for /sync requests
    if (_store.syncFilterId != syncFilterId
        && ![_store.syncFilterId isEqualToString:syncFilterId])
    {
        if (_store.eventStreamToken)
        {
            NSLog(@"[MXSesssion] startWithSyncFilterId: WARNING: Changing the sync filter while there is existing data in the store is not recommended");
        }

        // Store the passed filter id
        _store.syncFilterId = syncFilterId;
    }

    // Determine if this filter implies lazy loading of room members
    if (syncFilterId)
    {
        MXWeakify(self);
        [self filterWithFilterId:syncFilterId success:^(MXFilterJSONModel *filter) {
            MXStrongifyAndReturnIfNil(self);

            if (filter.room.state.lazyLoadMembers)
            {
                self->_syncWithLazyLoadOfRoomMembers = YES;
            }
        } failure:nil];
    }

    // Can we resume from data available in the cache
    if (_store.isPermanent && self.isEventStreamInitialised && 0 < _store.rooms.count)
    {
        // Resume the stream (presence will be retrieved during server sync)
        NSLog(@"[MXSession] Resuming the events stream from %@...", self.store.eventStreamToken);
        NSDate *startDate2 = [NSDate date];
        [self resume:^{
            NSLog(@"[MXSession] Events stream resumed in %.0fms", [[NSDate date] timeIntervalSinceDate:startDate2] * 1000);

            onServerSyncDone();
        }];

        // Start crypto if enabled
        [self startCrypto:^{
            NSLog(@"[MXSession] Crypto has been started");
        }  failure:^(NSError *error) {
            NSLog(@"[MXSession] Crypto failed to start. Error: %@", error);
        }];
    }
    else
    {
        // Get data from the home server
        // First of all, retrieve the user's profile information
        MXWeakify(self);
        [_myUser updateFromHomeserverOfMatrixSession:self success:^{
            MXStrongifyAndReturnIfNil(self);
            
            // Stop here if [MXSession close] has been triggered.
            if (nil == self.myUser)
            {
                return;
            }

            // And store him as a common MXUser
            [self.store storeUser:self.myUser];

            // Start crypto if enabled
            [self startCrypto:^{

                NSLog(@"[MXSession] Do an initial /sync");

                // Initial server sync
                [self serverSyncWithServerTimeout:0 success:onServerSyncDone failure:^(NSError *error) {

                    [self setState:MXSessionStateInitialSyncFailed];
                    failure(error);

                } clientTimeout:CLIENT_TIMEOUT_MS setPresence:nil];

            } failure:^(NSError *error) {

                NSLog(@"[MXSession] Crypto failed to start. Error: %@", error);
                
                // Check whether the token is valid
                if ([self isUnknownTokenError:error])
                {
                    // Do nothing more because without a valid access_token, the session is useless
                    return;
                }

                [self setState:MXSessionStateInitialSyncFailed];
                failure(error);

            }];

        } failure:^(NSError *error) {
            
            NSLog(@"[MXSession] Get the user's profile information failed");
            
            // Check whether the token is valid
            if ([self isUnknownTokenError:error])
            {
                // Do nothing more because without a valid access_token, the session is useless
                return;
            }
            [self setState:MXSessionStateInitialSyncFailed];
            failure(error);
            
        }];
    }

    // Get wellknown data only at the login time
    if (!self.homeserverWellknown)
    {
        [self refreshHomeserverWellknown:nil failure:nil];
    }
}

- (NSString *)syncFilterId
{
    return _store.syncFilterId;
}

- (void)pause
{
    NSLog(@"[MXSession] pause the event stream in state %tu", _state);

    if (_state == MXSessionStateRunning || _state == MXSessionStateBackgroundSyncInProgress || _state == MXSessionStatePauseRequested)
    {
        // Check that none required the session to keep running even if the app goes in
        // background
        if (_preventPauseCount)
        {
            NSLog(@"[MXSession pause] Prevent the session from being paused. preventPauseCount: %tu", _preventPauseCount);
            
            id<MXBackgroundModeHandler> handler = [MXSDKOptions sharedInstance].backgroundModeHandler;
            
            if (handler && !self.backgroundTask.isRunning)
            {
                MXWeakify(self);
                
                self.backgroundTask = [handler startBackgroundTaskWithName:@"[MXSession] pause" expirationHandler:^{
                    MXStrongifyAndReturnIfNil(self);
                    
                    // We cannot continue to run in background. Pause the session for real
                    self.preventPauseCount = 0;
                }];
            }
            
            [self setState:MXSessionStatePauseRequested];
            
            return;
        }
        
        // reset the callback
        onResumeDone = nil;
        onBackgroundSyncDone = nil;
        onBackgroundSyncFail = nil;
        
        // Cancel the current request managing the event stream
        [eventStreamRequest cancel];
        eventStreamRequest = nil;

        for (MXPeekingRoom *peekingRoom in peekingRooms)
        {
            [peekingRoom pause];
        }

        [self setState:MXSessionStatePaused];
    }
    else
    {
        NSLog(@"[MXSession] pause skipped because of wrong state of MXSession");
    }
}

- (void)resume:(void (^)(void))resumeDone
{
    NSLog(@"[MXSession] resume the event stream from state %tu", _state);
    
    if (self.backgroundTask.isRunning)
    {
        [self.backgroundTask stop];
        self.backgroundTask = nil;
    }

    // Check whether no request is already in progress
    if (!eventStreamRequest ||
        (_state == MXSessionStateBackgroundSyncInProgress || _state == MXSessionStatePauseRequested))
    {
        [self setState:MXSessionStateSyncInProgress];
        
        // Resume from the last known token
        onResumeDone = resumeDone;
        
        if (!eventStreamRequest)
        {
            // Relaunch live events stream (long polling)
            [self serverSyncWithServerTimeout:0 success:nil failure:nil clientTimeout:CLIENT_TIMEOUT_MS setPresence:nil];
        }
    }

    for (MXPeekingRoom *peekingRoom in peekingRooms)
    {
        [peekingRoom resume];
    }
}

- (void)backgroundSync:(unsigned int)timeout success:(MXOnBackgroundSyncDone)backgroundSyncDone failure:(MXOnBackgroundSyncFail)backgroundSyncfails
{
    // Check whether no request is already in progress
    if (!eventStreamRequest)
    {
        if (MXSessionStatePaused != _state)
        {
            NSLog(@"[MXSession] background Sync cannot be done in the current state %tu", _state);
            dispatch_async(dispatch_get_main_queue(), ^{
                backgroundSyncfails(nil);
            });
        }
        else
        {
            NSLog(@"[MXSession] start a background Sync");
            [self setState:MXSessionStateBackgroundSyncInProgress];
            
            // BackgroundSync from the latest known token
            onBackgroundSyncDone = backgroundSyncDone;
            onBackgroundSyncFail = backgroundSyncfails;

            [self serverSyncWithServerTimeout:0 success:nil failure:nil clientTimeout:timeout setPresence:@"offline"];
        }
    }
}

- (BOOL)reconnect
{
    if (eventStreamRequest)
    {
        NSLog(@"[MXSession] Reconnect starts");
        [eventStreamRequest cancel];
        eventStreamRequest = nil;
        
        // retrieve the available data asap
        // disable the long poll to get the available data asap
        [self serverSyncWithServerTimeout:0 success:nil failure:nil clientTimeout:10 setPresence:nil];
        
        return YES;
    }
    else
    {
        NSLog(@"[MXSession] Reconnect fails.");
    }
    
    return NO;
}

- (void)close
{
    // Cancel the current server request (if any)
    [eventStreamRequest cancel];
    eventStreamRequest = nil;

    // Flush pending direct room operations
    [directRoomsOperationsQueue removeAllObjects];
    directRoomsOperationsQueue = nil;

    // Clean MXUsers
    for (MXUser *user in self.users)
    {
        [user removeAllListeners];
    }
    
    // Flush the store
    if ([_store respondsToSelector:@selector(close)])
    {
        [_store close];
    }
    
    [self removeAllListeners];

    // Clean MXRooms
    for (MXRoom *room in rooms.allValues)
    {
        [room close];
    }
    [rooms removeAllObjects];

    // Clean peeking rooms
    for (MXPeekingRoom *peekingRoom in peekingRooms)
    {
        [peekingRoom close];
    }
    [peekingRooms removeAllObjects];

    // Clean summaries
    for (MXRoomSummary *summary in roomsSummaries.allValues)
    {
        [summary destroy];
    }
    [roomsSummaries removeAllObjects];

    // Clean notification center
    [_notificationCenter removeAllListeners];
    _notificationCenter = nil;

    // Stop calls
    if (_callManager)
    {
        [_callManager close];
        _callManager = nil;
    }
    
    // Stop crypto
    if (_crypto)
    {
        [_crypto close:NO];
        _crypto = nil;
    }
    
    publicisedGroupsByUserId = nil;
    userIdsWithOutdatedPublicisedGroups = nil;

    // Stop background task
    if (self.backgroundTask.isRunning)
    {
        [self.backgroundTask stop];
        self.backgroundTask = nil;
    }

    _myUser = nil;
    mediaManager = nil;
    matrixRestClient = nil;

    [self setState:MXSessionStateClosed];
}

- (MXHTTPOperation*)logout:(void (^)(void))success
                   failure:(void (^)(NSError *error))failure
{
    // Create an empty operation that will be mutated later
    MXHTTPOperation *operation = [[MXHTTPOperation alloc] init];

    // Clear crypto data
    // For security and because it will be no more useful as we will get a new device id
    // on the next log in
    MXWeakify(self);
    [self enableCrypto:NO success:^{
        MXStrongifyAndReturnIfNil(self);

        if (!operation.isCancelled)
        {
            MXHTTPOperation *operation2 = [self.matrixRestClient logout:success failure:failure];
            [operation mutateTo:operation2];
        }

    } failure:nil];

    return operation;
}

- (MXHTTPOperation*)deactivateAccountWithAuthParameters:(NSDictionary*)authParameters
                                           eraseAccount:(BOOL)eraseAccount
                                                success:(void (^)(void))success
                                                failure:(void (^)(NSError *error))failure
{
    return [self.matrixRestClient deactivateAccountWithAuthParameters:authParameters
                                                         eraseAccount:eraseAccount
                                                              success:success
                                                              failure:failure];
}

- (BOOL)isEventStreamInitialised
{
    return (_store.eventStreamToken != nil);
}

#pragma mark - Invalid Token handling

- (BOOL)isUnknownTokenError:(NSError *)error
{
    // Detect invalidated access token
    // This can happen when the user made a forget password request for example
    if ([MXError isMXError:error])
    {
        MXError *mxError = [[MXError alloc] initWithNSError:error];
        if ([mxError.errcode isEqualToString:kMXErrCodeStringUnknownToken])
        {
            NSLog(@"[MXSession] isUnknownTokenError: The access token is no more valid.");

            if (mxError.httpResponse.statusCode == 401
                && [mxError.userInfo[kMXErrorSoftLogoutKey] isEqual:@(YES)])
            {
                NSLog(@"[MXSession] isUnknownTokenError: Go to MXSessionStateSoftLogout state.");
                [self setState:MXSessionStateSoftLogout];
            }
            else
            {
                NSLog(@"[MXSession] isUnknownTokenError: Go to MXSessionStateUnknownToken state.");
                [self setState:MXSessionStateUnknownToken];
            }

            return YES;
        }
    }
    return NO;
}

#pragma mark - MXSession pause prevention
- (void)retainPreventPause
{
    // Check whether a background mode handler has been set.
    if ([MXSDKOptions sharedInstance].backgroundModeHandler)
    {
        self.preventPauseCount++;
    }
}

- (void)releasePreventPause
{
    if (self.preventPauseCount > 0)
    {
        self.preventPauseCount--;
    }
}

- (void)setPreventPauseCount:(NSUInteger)preventPauseCount
{
    _preventPauseCount = preventPauseCount;

    NSLog(@"[MXSession] setPreventPauseCount: %tu. MXSession state: %tu", _preventPauseCount, _state);

    if (_preventPauseCount == 0)
    {
        // The background task can be released
        if (self.backgroundTask.isRunning)
        {
            NSLog(@"[MXSession pause] Stop background task %@", self.backgroundTask);
            [self.backgroundTask stop];
            self.backgroundTask = nil;
        }

        // And the session can be paused for real if it was not resumed before
        if (_state == MXSessionStatePauseRequested)
        {
            NSLog(@"[MXSession] setPreventPauseCount: Actually pause the session");
            [self pause];
        }
    }
}


#pragma mark - Server sync

- (void)serverSyncWithServerTimeout:(NSUInteger)serverTimeout
                            success:(void (^)(void))success
                            failure:(void (^)(NSError *error))failure
                      clientTimeout:(NSUInteger)clientTimeout
                        setPresence:(NSString*)setPresence
{
    NSDate *startDate = [NSDate date];

    // Determine if we are catching up
    _catchingUp = (0 == serverTimeout);

    NSString * streamToken = _store.eventStreamToken;
    NSLog(@"[MXSession] Do a server sync%@: %@", _catchingUp ? @" (catching up)" : @"", streamToken);

    MXWeakify(self);
    eventStreamRequest = [matrixRestClient syncFromToken:streamToken serverTimeout:serverTimeout clientTimeout:clientTimeout setPresence:setPresence filter:self.syncFilterId success:^(MXSyncResponse *syncResponse) {
        MXStrongifyAndReturnIfNil(self);

        // Make sure [MXSession close] or [MXSession pause] has not been called before the server response
        if (!self->eventStreamRequest)
        {
            return;
        }

        // By default, the next sync will be a long polling (with the default server timeout value)
        NSUInteger nextServerTimeout = SERVER_TIMEOUT_MS;

        NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:startDate];
        NSLog(@"[MXSession] Received %tu joined rooms, %tu invited rooms, %tu left rooms, %tu toDevice events in %.0fms", syncResponse.rooms.join.count, syncResponse.rooms.invite.count, syncResponse.rooms.leave.count, syncResponse.toDevice.events.count, duration * 1000);

        // Check whether this is the initial sync
        BOOL isInitialSync = !self.isEventStreamInitialised;

        BOOL wasfirstSync = NO;
        if (!self->firstSyncDone)
        {
            wasfirstSync = YES;
            self->firstSyncDone = YES;
            [[MXSDKOptions sharedInstance].analyticsDelegate trackStartupSyncDuration:duration isInitial:isInitialSync];
        }

        // Handle the to device events before the room ones
        // to ensure to decrypt them properly
        for (MXEvent *toDeviceEvent in syncResponse.toDevice.events)
        {
            [self handleToDeviceEvent:toDeviceEvent];
        }

        if (self.catchingUp && syncResponse.toDevice.events.count)
        {
            // We may have not received all to-device events in a single /sync response
            // Pursue /sync with short timeout
            NSLog(@"[MXSession] Continue /sync with short timeout to get all to-device events (%@)", self.myUser.userId);
            nextServerTimeout = 0;
        }

        // Handle top-level account data
        if (syncResponse.accountData)
        {
            [self handleAccountData:syncResponse.accountData];
        }

        // Handle first joined rooms
        for (NSString *roomId in syncResponse.rooms.join)
        {
            MXRoomSync *roomSync = syncResponse.rooms.join[roomId];

            @autoreleasepool {

                // Retrieve existing room or create a new one
                MXRoom *room = [self getOrCreateRoom:roomId notify:!isInitialSync];

                // Sync room
                [room liveTimeline:^(MXEventTimeline *liveTimeline) {
                    [room handleJoinedRoomSync:roomSync];
                    [room.summary handleJoinedRoomSync:roomSync];
                }];
            }
        }

        // Handle invited rooms
        for (NSString *roomId in syncResponse.rooms.invite)
        {
            MXInvitedRoomSync *invitedRoomSync = syncResponse.rooms.invite[roomId];

            @autoreleasepool {

                // Retrieve existing room or create a new one
                MXRoom *room = [self getOrCreateRoom:roomId notify:!isInitialSync];

                // Prepare invited room
                [room liveTimeline:^(MXEventTimeline *liveTimeline) {
                    [room handleInvitedRoomSync:invitedRoomSync];
                    [room.summary handleInvitedRoomSync:invitedRoomSync];
                }];
            }
        }

        // Handle archived rooms
        for (NSString *roomId in syncResponse.rooms.leave)
        {
            MXRoomSync *leftRoomSync = syncResponse.rooms.leave[roomId];

            @autoreleasepool {

                // Presently we remove the existing room from the rooms list.
                // FIXME SYNCV2 Archive/Display the left rooms!
                // For that create 'handleArchivedRoomSync' method

                // Retrieve existing room
                MXRoom *room = [self roomWithRoomId:roomId];
                if (room)
                {
                    // FIXME SYNCV2: While 'handleArchivedRoomSync' is not available,
                    // use 'handleJoinedRoomSync' to pass the last events to the room before leaving it.
                    // The room will then able to notify its listeners.
                    [room liveTimeline:^(MXEventTimeline *liveTimeline) {
                        [room handleJoinedRoomSync:leftRoomSync];
                        [room.summary handleJoinedRoomSync:leftRoomSync];

                        // Look for the last room member event
                        MXEvent *roomMemberEvent;
                        NSInteger index = leftRoomSync.timeline.events.count;
                        while (index--)
                        {
                            MXEvent *event = leftRoomSync.timeline.events[index];

                            if ([event.type isEqualToString:kMXEventTypeStringRoomMember])
                            {
                                roomMemberEvent = event;
                                break;
                            }
                        }

                        // Notify the room is going to disappear
                        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:room.roomId forKey:kMXSessionNotificationRoomIdKey];
                        if (roomMemberEvent)
                        {
                            userInfo[kMXSessionNotificationEventKey] = roomMemberEvent;
                        }
                        [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionWillLeaveRoomNotification
                                                                            object:self
                                                                          userInfo:userInfo];
                        // Remove the room from the rooms list
                        [self removeRoom:room.roomId];
                    }];
                }
            }
        }

        // Check the conditions to update summaries direct user ids for retrieved rooms (We have to do it
        // when we receive some invites to handle correctly a new invite to a direct chat that the user has left).
        if (isInitialSync || syncResponse.rooms.invite.count)
        {
            [self updateSummaryDirectUserIdForRooms:[self directRoomIds]];
        }

        // Handle invited groups
        for (NSString *groupId in syncResponse.groups.invite)
        {
            // Create a new group for each invite
            MXInvitedGroupSync *invitedGroupSync = syncResponse.groups.invite[groupId];
            [self createGroupInviteWithId:groupId profile:invitedGroupSync.profile andInviter:invitedGroupSync.inviter notify:!isInitialSync];
        }

        // Handle joined groups
        for (NSString *groupId in syncResponse.groups.join)
        {
            // Join an existing group or create a new one
            [self didJoinGroupWithId:groupId notify:!isInitialSync];
        }

        // Handle left groups
        for (NSString *groupId in syncResponse.groups.leave)
        {
            // Remove the group from the group list
            [self removeGroup:groupId];
        }

        // Handle presence of other users
        for (MXEvent *presenceEvent in syncResponse.presence.events)
        {
            [self handlePresenceEvent:presenceEvent direction:MXTimelineDirectionForwards];
        }

        // Sync point: wait that all rooms in the /sync response have been loaded
        // and their /sync response has been processed
        [self preloadRoomsData:[self roomsInSyncResponse:syncResponse] onComplete:^{

            if (self.crypto)
            {
                // Handle device list updates
                if (syncResponse.deviceLists)
                {
                    [self.crypto handleDeviceListsChanges:syncResponse.deviceLists];
                }

                // Handle one_time_keys_count
                if (syncResponse.deviceOneTimeKeysCount)
                {
                    [self.crypto handleDeviceOneTimeKeysCount:syncResponse.deviceOneTimeKeysCount];
                }

                // Tell the crypto module to do its processing
                [self.crypto onSyncCompleted:self.store.eventStreamToken
                               nextSyncToken:syncResponse.nextBatch
                                  catchingUp:self.catchingUp];
            }


            // Update live event stream token
            self.store.eventStreamToken = syncResponse.nextBatch;

            // Commit store changes done in [room handleMessages]
            if ([self.store respondsToSelector:@selector(commit)])
            {
                [self.store commit];
            }

            // Do a loop of /syncs until catching up is done
            if (nextServerTimeout == 0)
            {
                [self serverSyncWithServerTimeout:nextServerTimeout success:success failure:failure clientTimeout:CLIENT_TIMEOUT_MS setPresence:nil];
                return;
            }

            // there is a pending backgroundSync
            if (self->onBackgroundSyncDone)
            {
                NSLog(@"[MXSession] Events stream background Sync succeeded");

                // Operations on session may occur during this block. For example, [MXSession close] may be triggered.
                // We run a copy of the block to prevent app from crashing if the block is released by one of these operations.
                MXOnBackgroundSyncDone onBackgroundSyncDoneCpy = [self->onBackgroundSyncDone copy];
                onBackgroundSyncDoneCpy();
                self->onBackgroundSyncDone = nil;

                // check that the application was not resumed while catching up in background
                if (self.state == MXSessionStateBackgroundSyncInProgress)
                {
                    // Check that none required the session to keep running
                    if (self.preventPauseCount)
                    {
                        // Delay the pause by calling the reliable `pause` method.
                        [self pause];
                    }
                    else
                    {
                        NSLog(@"[MXSession] go to paused ");
                        self->eventStreamRequest = nil;
                        [self setState:MXSessionStatePaused];
                        return;
                    }
                }
                else
                {
                    NSLog(@"[MXSession] resume after a background Sync");
                }
            }

            // If we are resuming inform the app that it received the last uptodate data
            if (self->onResumeDone)
            {
                NSLog(@"[MXSession] Events stream resumed");

                // Operations on session may occur during this block. For example, [MXSession close] or [MXSession pause] may be triggered.
                // We run a copy of the block to prevent app from crashing if the block is released by one of these operations.
                MXOnResumeDone onResumeDoneCpy = [self->onResumeDone copy];
                onResumeDoneCpy();
                self->onResumeDone = nil;

                // Stop here if [MXSession close] or [MXSession pause] has been triggered during onResumeDone block.
                if (nil == self.myUser || self.state == MXSessionStatePaused)
                {
                    return;
                }
            }

            if (self.state != MXSessionStatePauseRequested)
            {
                // The event stream is running by now
                [self setState:MXSessionStateRunning];
            }

            // Check SDK user did not called [MXSession close] or [MXSession pause] during the session state change notification handling.
            if (nil == self.myUser || self.state == MXSessionStatePaused)
            {
                return;
            }

            // Pursue live events listening
            [self serverSyncWithServerTimeout:nextServerTimeout success:nil failure:nil clientTimeout:CLIENT_TIMEOUT_MS setPresence:nil];

            if (wasfirstSync)
            {
                [[MXSDKOptions sharedInstance].analyticsDelegate trackRoomCount:self->rooms.count];
            }

            // Broadcast that a server sync has been processed.
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionDidSyncNotification
                                                                object:self
                                                              userInfo:@{
                                                                         kMXSessionNotificationSyncResponseKey: syncResponse
                                                                         }];

            if (success)
            {
                success();
            }
        }];

    } failure:^(NSError *error) {
        [self handleServerSyncError:error forRequestWithServerTimeout:serverTimeout success:success failure:failure];
    }];
}

- (void)handleServerSyncError:(NSError*)error forRequestWithServerTimeout:(NSUInteger)serverTimeout success:(void (^)(void))success failure:(void (^)(NSError *error))failure
{
    // Make sure [MXSession close] or [MXSession pause] has not been called before the server response
    if (!self->eventStreamRequest)
    {
        return;
    }

    // Check whether the token is valid
    if ([self isUnknownTokenError:error])
    {
        // Do nothing more because without a valid access_token, the session is useless
        return;
    }

    // Handle failure during catch up first
    if (self->onBackgroundSyncFail)
    {
        NSLog(@"[MXSession] background Sync fails %@", error);

        // Operations on session may occur during this block. For example, [MXSession close] may be triggered.
        // We run a copy of the block to prevent app from crashing if the block is released by one of these operations.
        MXOnBackgroundSyncFail onBackgroundSyncFailCpy = [self->onBackgroundSyncFail copy];
        onBackgroundSyncFailCpy(error);
        self->onBackgroundSyncFail = nil;

        // check that the application was not resumed while catching up in background
        if (self.state == MXSessionStateBackgroundSyncInProgress)
        {
            // Check that none required the session to keep running
            if (self.preventPauseCount)
            {
                // Delay the pause by calling the reliable `pause` method.
                [self pause];
            }
            else
            {
                NSLog(@"[MXSession] go to paused ");
                self->eventStreamRequest = nil;
                [self setState:MXSessionStatePaused];
                return;
            }
        }
        else
        {
            NSLog(@"[MXSession] resume after a background Sync");
        }
    }

    // Check whether the caller wants to handle error himself
    if (failure)
    {
        failure(error);
    }
    else
    {
        // Handle error here
        // on 64 bits devices, the error codes are huge integers.
        int32_t code = (int32_t)error.code;

        if ([error.domain isEqualToString:NSURLErrorDomain]
            && code == kCFURLErrorCancelled)
        {
            NSLog(@"[MXSession] The connection has been cancelled.");
        }
        else if ([error.domain isEqualToString:NSURLErrorDomain]
                 && code == kCFURLErrorTimedOut && serverTimeout == 0)
        {
            NSLog(@"[MXSession] The connection has been timeout.");
            // The reconnection attempt failed on timeout: there is no data to retrieve from server
            [self->eventStreamRequest cancel];
            self->eventStreamRequest = nil;

            // Notify the reconnection attempt has been done.
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionDidSyncNotification
                                                                object:self
                                                              userInfo:@{
                                                                         kMXSessionNotificationErrorKey: error
                                                                         }];

            // Switch back to the long poll management
            [self serverSyncWithServerTimeout:SERVER_TIMEOUT_MS success:nil failure:nil clientTimeout:CLIENT_TIMEOUT_MS setPresence:nil];
        }
        else
        {
            MXError *mxError = [[MXError alloc] initWithNSError:error];
            if (mxError)
            {
                _syncError = mxError;
                [self setState:MXSessionStateSyncError];

                // Retry later
                dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, RETRY_SYNC_AFTER_MXERROR_MS * NSEC_PER_MSEC);
                dispatch_after(delayTime, dispatch_get_main_queue(), ^(void) {

                    if (self->eventStreamRequest)
                    {
                        NSLog(@"[MXSession] Retry resuming events stream after error %@", mxError.errcode);
                        [self serverSyncWithServerTimeout:0 success:success failure:failure clientTimeout:CLIENT_TIMEOUT_MS setPresence:nil];
                    }
                });
            }
            else
            {
                // Inform the app there is a problem with the connection to the homeserver
                [self setState:MXSessionStateHomeserverNotReachable];

                // Check if it is a network connectivity issue
                AFNetworkReachabilityManager *networkReachabilityManager = [AFNetworkReachabilityManager sharedManager];
                NSLog(@"[MXSession] events stream broken. Network reachability: %d", networkReachabilityManager.isReachable);

                if (networkReachabilityManager.isReachable)
                {
                    // The problem is not the network
                    // Relaunch the request in a random near futur.
                    // Random time it used to avoid all Matrix clients to retry all in the same time
                    // if there is server side issue like server restart
                    dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, [MXHTTPClient timeForRetry:self->eventStreamRequest] * NSEC_PER_MSEC);
                    dispatch_after(delayTime, dispatch_get_main_queue(), ^(void) {

                        if (self->eventStreamRequest)
                        {
                            NSLog(@"[MXSession] Retry resuming events stream");
                            [self setState:MXSessionStateSyncInProgress];
                            [self serverSyncWithServerTimeout:0 success:success failure:nil clientTimeout:CLIENT_TIMEOUT_MS setPresence:nil];
                        }
                    });
                }
                else
                {
                    // The device is not connected to the internet, wait for the connection to be up again before retrying
                    __block __weak id reachabilityObserver =
                    [[NSNotificationCenter defaultCenter] addObserverForName:AFNetworkingReachabilityDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {

                        if (networkReachabilityManager.isReachable && self->eventStreamRequest)
                        {
                            [[NSNotificationCenter defaultCenter] removeObserver:reachabilityObserver];

                            NSLog(@"[MXSession] Retry resuming events stream");
                            [self setState:MXSessionStateSyncInProgress];
                            [self serverSyncWithServerTimeout:0 success:success failure:nil clientTimeout:CLIENT_TIMEOUT_MS setPresence:nil];
                        }
                    }];
                }
            }
        }
    }
}

- (void)handlePresenceEvent:(MXEvent *)event direction:(MXTimelineDirection)direction
{
    // Update MXUser with presence data
    NSString *userId = event.sender;
    if (userId)
    {
        MXUser *user = [self getOrCreateUser:userId];
        [user updateWithPresenceEvent:event inMatrixSession:self];

        [_store storeUser:user];
    }

    [self notifyListeners:event direction:direction];
}

- (void)handleAccountData:(NSDictionary*)accountDataUpdate
{
    if (accountDataUpdate && accountDataUpdate[@"events"] && ((NSArray*)accountDataUpdate[@"events"]).count)
    {
        BOOL isInitialSync = !self.isEventStreamInitialised || _state == MXSessionStateInitialised;

        for (NSDictionary *event in accountDataUpdate[@"events"])
        {
            if ([event[@"type"] isEqualToString:kMXAccountDataTypePushRules])
            {
                // Handle push rules
                MXPushRulesResponse *pushRules = [MXPushRulesResponse modelFromJSON:event[@"content"]];

                if (![_notificationCenter.rules.JSONDictionary isEqualToDictionary:event[@"content"]])
                {
                    [_notificationCenter handlePushRulesResponse:pushRules];

                    // Report the change
                    if (!isInitialSync)
                    {
                        [[NSNotificationCenter defaultCenter] postNotificationName:kMXNotificationCenterDidUpdateRules
                                                                            object:_notificationCenter
                                                                          userInfo:nil];
                    }
                }
            }
            else if ([event[@"type"] isEqualToString:kMXAccountDataTypeIgnoredUserList])
            {
                // Handle the ignored users list
                NSArray *newIgnoredUsers = [event[@"content"][kMXAccountDataKeyIgnoredUser] allKeys];
                if (newIgnoredUsers)
                {
                    // Check the array changes whatever the order
                    NSCountedSet *set1 = [NSCountedSet setWithArray:_ignoredUsers];
                    NSCountedSet *set2 = [NSCountedSet setWithArray:newIgnoredUsers];

                    // Do not notify for the first /sync
                    BOOL notify = !isInitialSync && ![set1 isEqualToSet:set2];

                    _ignoredUsers = newIgnoredUsers;

                    // Report the change
                    if (notify)
                    {
                        [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionIgnoredUsersDidChangeNotification
                                                                            object:self
                                                                          userInfo:nil];
                    }
                }
            }
            else if ([event[@"type"] isEqualToString:kMXAccountDataTypeDirect])
            {
                NSDictionary<NSString*, NSArray<NSString*>*> *directRooms;
                MXJSONModelSetDictionary(directRooms, event[@"content"]);

                if (directRooms != _directRooms
                    && ![directRooms isEqualToDictionary:_directRooms])
                {
                    // Collect previous direct rooms ids
                    NSMutableSet<NSString*> *directRoomIds = [NSMutableSet set];
                    [directRoomIds unionSet:[self directRoomIds]];

                    _directRooms = directRooms;

                    // And collect current ones
                    [directRoomIds unionSet:[self directRoomIds]];

                    // In order to update room summaries
                    [self updateSummaryDirectUserIdForRooms:directRoomIds];

                    // Update the information of the direct rooms.
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionDirectRoomsDidChangeNotification
                                                                        object:self
                                                                      userInfo:nil];
                }
            }

            // Update the corresponding part of account data
            [_accountData updateWithEvent:event];

            if ([event[@"type"] isEqualToString:kMXAccountDataTypeIdentityServer])
            {
                NSString *identityServer = self.accountDataIdentityServer;
                if (identityServer != self.identityService.identityServer
                    && ![identityServer isEqualToString:self.identityService.identityServer])
                {
                    NSLog(@"[MXSession] handleAccountData: Update identity server: %@ -> %@", self.identityService.identityServer, identityServer);

                    // Use the IS from the account data
                    [self setIdentityServer:identityServer andAccessToken:nil];
                }

                [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionAccountDataDidChangeIdentityServerNotification
                                                                    object:self
                                                                  userInfo:nil];
            }
        }

        _store.userAccountData = _accountData.accountData;
        
        // Trigger a global notification for the account data update
        if (!isInitialSync)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionAccountDataDidChangeNotification
                                                                object:self
                                                              userInfo:nil];
        }
    }
}

- (void)updateSummaryDirectUserIdForRooms:(NSSet<NSString*> *)roomIds
{
    // If the initial sync response is not processed enough, rooms is not yet mounted.
    // updateSummaryDirectUserIdForRooms will be called once the initial sync is done.
    if (rooms.count)
    {
        for (NSString *roomId in roomIds)
        {
            MXRoomSummary *summary = [self roomSummaryWithRoomId:roomId];

            NSString *directUserId = [self directUserIdInRoom:roomId];
            NSString *summaryDirectUserId = summary.directUserId;

            // Update the summary if necessary
            if (directUserId != summaryDirectUserId
                && ![directUserId isEqualToString:summaryDirectUserId])
            {
                summary.directUserId = directUserId;
                [summary save:YES];
            }
        }
    }
}

- (void)handleToDeviceEvent:(MXEvent *)event
{
    // Decrypt event if necessary
    if (event.eventType == MXEventTypeRoomEncrypted)
    {
        if (![self decryptEvent:event inTimeline:nil])
        {
            NSLog(@"[MXSession] handleToDeviceEvent: Warning: Unable to decrypt to-device event: %@\nError: %@", event.wireContent[@"body"], event.decryptionError);
            return;
        }
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionOnToDeviceEventNotification
                                                        object:self
                                                      userInfo:@{
                                                                 kMXSessionNotificationEventKey: event
                                                                 }];
}

/**
 Get rooms implied in a /sync response.

 @param syncResponse the /sync response to parse.
 @return ids of rooms found in the /sync response.
 */
- (NSArray<NSString*> *)roomsInSyncResponse:(MXSyncResponse *)syncResponse
{
    NSMutableArray<NSString *> *roomsInSyncResponse = [NSMutableArray array];
    [roomsInSyncResponse addObjectsFromArray:syncResponse.rooms.join.allKeys];
    [roomsInSyncResponse addObjectsFromArray:syncResponse.rooms.invite.allKeys];
    [roomsInSyncResponse addObjectsFromArray:syncResponse.rooms.leave.allKeys];

    return roomsInSyncResponse;
}


#pragma mark - Options
- (void)enableVoIPWithCallStack:(id<MXCallStack>)callStack
{
    // A call stack is defined for life
    NSParameterAssert(!_callManager);

    _callManager = [[MXCallManager alloc] initWithMatrixSession:self andCallStack:callStack];
}

- (void)enableCrypto:(BOOL)enableCrypto success:(void (^)(void))success failure:(void (^)(NSError *))failure
{
    NSLog(@"[MXSesion] enableCrypto: %@", @(enableCrypto));

    if (enableCrypto && !_crypto)
    {
        _crypto = [MXCrypto createCryptoWithMatrixSession:self];

        if (_state == MXSessionStateRunning)
        {
            [_crypto start:success failure:failure];
        }
        else
        {
            NSLog(@"[MXSesion] enableCrypto: crypto module will be start later (MXSession.state: %@)", @(_state));

            if (success)
            {
                success();
            }
        }
    }
    else if (!enableCrypto && _crypto)
    {
        // Erase all crypto data of this user
        [_crypto close:YES];
        _crypto = nil;

        if (success)
        {
            success();
        }
    }
    else
    {
        if (success)
        {
            success();
        }
    }
}

- (MXHTTPOperation*)supportedMatrixVersions:(void (^)(MXMatrixVersions *))success failure:(void (^)(NSError *))failure
{
    return [matrixRestClient supportedMatrixVersions:success failure:failure];
}

- (void)setAntivirusServerURL:(NSString *)antivirusServerURL
{
    _antivirusServerURL = antivirusServerURL;
    
    // Update the current restClient
    [matrixRestClient setAntivirusServer:antivirusServerURL];
    
    // Configure scan manager if antivirusServerURL is set
    if (antivirusServerURL)
    {
        _scanManager = [[MXScanManager alloc] initWithRestClient:matrixRestClient];
        [_scanManager resetAllAntivirusScanStatusInProgressToUnknown];
    }
    else
    {
        _scanManager = nil;
    }
    
    // Update the media manager
    [mediaManager setScanManager:_scanManager];
}

#pragma mark - Rooms operations

- (void)onCreatedRoom:(MXCreateRoomResponse*)response success:(void (^)(MXRoom *room))success
{
    // Wait to receive data from /sync about this room before returning
    if (success)
    {
        MXRoom *room = [self roomWithRoomId:response.roomId];
        if (room)
        {
            // Initialise notification counters homeserver side
            [room markAllAsRead];

            // The first /sync response for this room may have happened before the
            // homeserver answer to the createRoom request.
            success(room);
        }
        else
        {
            // Else, just wait for the corresponding kMXRoomInitialSyncNotification
            // that will be fired from MXRoom.
            __block id initialSyncObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXRoomInitialSyncNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
                
                MXRoom *room = note.object;
                
                if ([room.roomId isEqualToString:response.roomId])
                {
                    // Initialise notification counters homeserver side
                    [room markAllAsRead];
                    
                    success(room);
                    [[NSNotificationCenter defaultCenter] removeObserver:initialSyncObserver];
                }
            }];
        }
    }
}

- (void)onCreatedDirectChat:(MXCreateRoomResponse*)response withUserId:(NSString*)userId success:(void (^)(MXRoom *room))success
{
    void (^tagRoomAsDirectChat)(MXRoom *) = ^(MXRoom *room) {
        
        MXWeakify(room);
        
        // Tag the room as direct
        [room setIsDirect:YES withUserId:userId success:^{
            
            MXStrongifyAndReturnIfNil(room);
            
            if (success)
            {
                success(room);
            }
            
        } failure:^(NSError *error) {
            
            MXStrongifyAndReturnIfNil(room);
            
            // TODO: Find a way to handle direct tag failure and report this error in room creation failure block.
            
            NSLog(@"[MXSession] Failed to tag the room (%@) as a direct chat", response.roomId);
            
            if (success)
            {
                success(room);
            }
        }];
    };
    
    // Wait to receive data from /sync about this room before returning
    // CAUTION: The initial sync may not contain the invited member, they may be received later during the next sync.
    MXRoom *room = [self roomWithRoomId:response.roomId];
    if (room)
    {
        // Initialise notification counters homeserver side
        [room markAllAsRead];

        // The first /sync response for this room may have happened before the
        // homeserver answer to the createRoom request.
        
        // Tag the room as direct
        tagRoomAsDirectChat(room);
    }
    else
    {
        // Else, just wait for the corresponding kMXRoomInitialSyncNotification
        // that will be fired from MXRoom.
        
        __block id initialSyncObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXRoomInitialSyncNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            
            MXRoom *room = note.object;
            
            if ([room.roomId isEqualToString:response.roomId])
            {
                // Initialise notification counters homeserver side
                [room markAllAsRead];
                
                // Tag the room as direct
                tagRoomAsDirectChat(room);
                
                [[NSNotificationCenter defaultCenter] removeObserver:initialSyncObserver];
            }
        }];
    }
}

- (MXHTTPOperation*)createRoom:(NSString*)name
                    visibility:(MXRoomDirectoryVisibility)visibility
                     roomAlias:(NSString*)roomAlias
                         topic:(NSString*)topic
                       success:(void (^)(MXRoom *room))success
                       failure:(void (^)(NSError *error))failure
{
    return [matrixRestClient createRoom:name visibility:visibility roomAlias:roomAlias topic:topic success:^(MXCreateRoomResponse *response) {
        
        [self onCreatedRoom:response success:success];
        
    } failure:failure];
}

- (MXHTTPOperation*)createRoom:(NSString*)name
                    visibility:(MXRoomDirectoryVisibility)visibility
                     roomAlias:(NSString*)roomAlias
                         topic:(NSString*)topic
                        invite:(NSArray<NSString*>*)inviteArray
                    invite3PID:(NSArray<MXInvite3PID*>*)invite3PIDArray
                      isDirect:(BOOL)isDirect
                        preset:(MXRoomPreset)preset
                       success:(void (^)(MXRoom *room))success
                       failure:(void (^)(NSError *error))failure
{
    return [matrixRestClient createRoom:name visibility:visibility roomAlias:roomAlias topic:topic invite:inviteArray invite3PID:invite3PIDArray isDirect:isDirect preset:preset success:^(MXCreateRoomResponse *response) {

        if (isDirect)
        {
            // When the flag isDirect is turned on, only one user id is expected in the inviteArray.
            // The room is considered as direct only for the first mentioned user in case of several user ids.
            // Note: It is not possible FTM to mark as direct a room with an invited third party.
            NSString *directUserId = (inviteArray.count ? inviteArray.firstObject : nil);
            [self onCreatedDirectChat:response withUserId:directUserId success:success];
        }
        else
        {
            [self onCreatedRoom:response success:success];
        }

    } failure:failure];
}

- (MXHTTPOperation*)createRoom:(NSDictionary*)parameters
                       success:(void (^)(MXRoom *room))success
                       failure:(void (^)(NSError *error))failure
{
    return [matrixRestClient createRoom:parameters success:^(MXCreateRoomResponse *response) {

        BOOL isDirect = NO;
        if ([parameters[@"is_direct"] isKindOfClass:NSNumber.class])
        {
            isDirect = ((NSNumber*)parameters[@"is_direct"]).boolValue;
        }
        
        if (isDirect)
        {
            // When the flag isDirect is turned on, only one user id is expected in the inviteArray.
            // The room is considered as direct only for the first mentioned user in case of several user ids.
            // Note: It is not possible FTM to mark as direct a room with an invited third party.
            NSString *directUserId = nil;
            if ([parameters[@"invite"] isKindOfClass:NSArray.class])
            {
                NSArray *inviteArray = parameters[@"invite"];
                directUserId = (inviteArray.count ? inviteArray.firstObject : nil);
            }
            [self onCreatedDirectChat:response withUserId:directUserId success:success];
        }
        else
        {
            [self onCreatedRoom:response success:success];
        }

    } failure:failure];
}

- (void)onJoinedRoom:(NSString*)roomId success:(void (^)(MXRoom *room))success
{
    MXRoom *room = [self getOrCreateRoom:roomId notify:YES];

    // check if the room is in the invited rooms list
    if ([self removeInvitedRoom:room])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionInvitedRoomsDidChangeNotification
                                                            object:self
                                                          userInfo:@{
                                                                     kMXSessionNotificationRoomIdKey: room.roomId,
                                                                     }];
    }

    // Wait to receive data from /sync about this room before returning
    if (success)
    {
        if (room.summary.membership == MXMembershipJoin)
        {
            // The /sync corresponding to this join may have happened before the
            // homeserver answer to the joinRoom request.
            success(room);
        }
        else
        {
            // Else, just wait for the corresponding kMXRoomInitialSyncNotification
            // that will be fired from MXRoom.
            __block id initialSyncObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXRoomInitialSyncNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {

                MXRoom *syncedRoom = note.object;

                if (syncedRoom == room)
                {
                    success(room);
                    [[NSNotificationCenter defaultCenter] removeObserver:initialSyncObserver];
                }
            }];
        }
    }

}

- (MXHTTPOperation*)joinRoom:(NSString*)roomIdOrAlias
                  viaServers:(NSArray<NSString*>*)viaServers
                     success:(void (^)(MXRoom *room))success
                     failure:(void (^)(NSError *error))failure
{
    return [matrixRestClient joinRoom:roomIdOrAlias viaServers:viaServers withThirdPartySigned:nil success:^(NSString *theRoomId) {

        [self onJoinedRoom:theRoomId success:success];

    } failure:failure];
}

- (MXHTTPOperation*)joinRoom:(NSString*)roomIdOrAlias
                  viaServers:(NSArray<NSString*>*)viaServers
                 withSignUrl:(NSString*)signUrl
                     success:(void (^)(MXRoom *room))success
                     failure:(void (^)(NSError *error))failure
{
    if (!self.identityService)
    {
        NSLog(@"[MXSession] Missing identity service");
        failure([NSError errorWithDomain:kMXNSErrorDomain code:0 userInfo:@{
                                                                            NSLocalizedDescriptionKey: @"Missing identity service"
                                                                            }]);
        return nil;
    }
    
    MXHTTPOperation *httpOperation;
    
    MXWeakify(self);
    httpOperation = [self.identityService signUrl:signUrl success:^(NSDictionary *thirdPartySigned) {
        MXStrongifyAndReturnIfNil(self);
        
        MXHTTPOperation *httpOperation2 = [self->matrixRestClient joinRoom:roomIdOrAlias viaServers:viaServers withThirdPartySigned:thirdPartySigned success:^(NSString *theRoomId) {
            
            [self onJoinedRoom:theRoomId success:success];
            
        } failure:failure];
        
        // Transfer the new AFHTTPRequestOperation to the returned MXHTTPOperation
        // So that user has hand on it
        if (httpOperation)
        {
            httpOperation.operation = httpOperation2.operation;
        }
        
    } failure:failure];
    
    return httpOperation;
}

- (MXHTTPOperation*)leaveRoom:(NSString*)roomId
                      success:(void (^)(void))success
                      failure:(void (^)(NSError *error))failure
{
    return [matrixRestClient leaveRoom:roomId success:^{

        // Check the room has been removed before calling the success callback
        // This is automatically done when the homeserver sends the MXMembershipLeave event.
        if ([self roomWithRoomId:roomId])
        {
            // The room is stil here, wait for the MXMembershipLeave event
            __block __weak id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionDidLeaveRoomNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {

                if ([roomId isEqualToString:note.userInfo[kMXSessionNotificationRoomIdKey]])
                {
                    [[NSNotificationCenter defaultCenter] removeObserver:observer];
                    if (success)
                    {
                        success();
                    }
                }
            }];
        }
        else
        {
            if (success)
            {
                success();
            }
        }

    } failure:failure];
}


#pragma mark - The user's rooms
- (BOOL)hasRoomWithRoomId:(NSString*)roomId
{
    return (rooms[roomId] != nil);
}

- (MXRoom *)roomWithRoomId:(NSString *)roomId
{
    // sanity check
    if (roomId)
    {
        return [rooms objectForKey:roomId];
    }
    else
    {
        return nil;
    }
}

- (MXRoom *)roomWithAlias:(NSString *)alias
{
    MXRoom *theRoom;

    if (alias)
    {
        for (MXRoomSummary *summary in roomsSummaries.allValues)
        {
            if (summary.aliases && NSNotFound != [summary.aliases indexOfObject:alias])
            {
                theRoom = [self roomWithRoomId:summary.roomId];
                break;
            }
        }
    }
    return theRoom;
}

- (NSArray *)rooms
{
    return [rooms allValues];
}


#pragma mark - The user's direct rooms

- (MXRoom *)directJoinedRoomWithUserId:(NSString*)userId
{
    // Retrieve the existing direct chats
    NSArray *directRoomIds = self.directRooms[userId];
    
    // Check whether the room is still existing
    for (NSString* directRoomId in directRoomIds)
    {
        MXRoom *directRoom = [self roomWithRoomId:directRoomId];
        if (directRoom)
        {
            // Check whether the user membership is joined
            if (directRoom.summary.membership == MXMembershipJoin)
            {
                return directRoom;
            }
        }
    }
    
    return nil;
}

// Return ids of all current direct rooms
- (NSSet<NSString*> *)directRoomIds
{
    NSMutableSet<NSString*> *roomIds = [NSMutableSet set];
    for (NSArray *array in _directRooms.allValues)
    {
        [roomIds addObjectsFromArray:array];
    }

    return roomIds;
}

- (NSString *)directUserIdInRoom:(NSString*)roomId
{
    NSString *directUserId;

    for (NSString *userId in _directRooms)
    {
        if ([_directRooms[userId] containsObject:roomId])
        {
            directUserId = userId;
            break;
        }
    }

    return directUserId;
}

- (MXHTTPOperation*)setRoom:(NSString*)roomId
           directWithUserId:(NSString*)userId
                    success:(void (^)(void))success
                    failure:(void (^)(NSError *error))failure
{
    MXHTTPOperation *operation = [MXHTTPOperation new];

    MXWeakify(self);
    [self runOrQueueDirectRoomOperation:^{
        MXStrongifyAndReturnIfNil(self);

        NSMutableDictionary<NSString *,NSArray<NSString *> *> *newDirectRooms = [self.directRooms mutableCopy];
        if (!newDirectRooms)
        {
            newDirectRooms = [NSMutableDictionary dictionary];
        }

        // Remove the current direct user id
        MXRoom *room = [self roomWithRoomId:roomId];
        NSString *currentDirectUserId = room.directUserId;
        if (currentDirectUserId)
        {
            NSMutableArray *roomIds = [NSMutableArray arrayWithArray:newDirectRooms[currentDirectUserId]];
            [roomIds removeObject:roomId];

            if (roomIds.count)
            {
                newDirectRooms[currentDirectUserId] = roomIds;
            }
            else
            {
                [newDirectRooms removeObjectForKey:currentDirectUserId];
            }
        }

        // Update with the new one
        if (userId)
        {
            if (![newDirectRooms[userId] containsObject:roomId])
            {
                NSMutableArray *roomIds = (newDirectRooms[userId] ? [NSMutableArray arrayWithArray:newDirectRooms[userId]] : [NSMutableArray array]);
                [roomIds addObject:roomId];
                newDirectRooms[userId] = roomIds;
            }
        }

        MXHTTPOperation *operation2 = [self uploadDirectRoomsInOperationsQueue:newDirectRooms success:success failure:failure];
        [operation mutateTo:operation2];
    }];

    return operation;
}

- (MXHTTPOperation*)uploadDirectRooms:(NSDictionary<NSString *,NSArray<NSString *> *> *)directRooms
                              success:(void (^)(void))success
                              failure:(void (^)(NSError *))failure
{
    MXHTTPOperation *operation = [MXHTTPOperation new];

    MXWeakify(self);
    [self runOrQueueDirectRoomOperation:^{
        MXStrongifyAndReturnIfNil(self);

        MXHTTPOperation *operation2 = [self uploadDirectRoomsInOperationsQueue:directRooms success:success failure:failure];
        [operation mutateTo:operation2];
    }];

    return operation;
}

- (MXHTTPOperation*)uploadDirectRoomsInOperationsQueue:(NSDictionary<NSString *,NSArray<NSString *> *> *)directRooms
                                               success:(void (^)(void))success
                                               failure:(void (^)(NSError *))failure
{
    // If there is no change, do nothing
    if (_directRooms == directRooms
        || [_directRooms isEqualToDictionary:directRooms]
        || (_directRooms == nil && directRooms.count == 0))
    {
        if (success)
        {
            success();
        }

        [self runNextDirectRoomOperation];
        return nil;
    }

    // Wait that the response comes back down the event stream
    MXWeakify(self);
    __block id directRoomsDidChangeObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionDirectRoomsDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        MXStrongifyAndReturnIfNil(self);

        if ([self.directRooms isEqualToDictionary:directRooms])
        {
            [[NSNotificationCenter defaultCenter] removeObserver:directRoomsDidChangeObserver];

            if (success)
            {
                success();
            }

            [self runNextDirectRoomOperation];
        }
    }];

    // Push the current direct rooms dictionary to the homeserver
    return [self setAccountData:directRooms forType:kMXAccountDataTypeDirect success:nil failure:^(NSError *error) {
        MXStrongifyAndReturnIfNil(self);

        if (failure)
        {
            failure(error);
        }
        
        [self runNextDirectRoomOperation];
    }];
}

- (void)runOrQueueDirectRoomOperation:(dispatch_block_t)directRoomOperation
{
    // If there is a pending HTTP request, the change will be applied on the updated direct rooms data
    [directRoomsOperationsQueue addObject:[directRoomOperation copy]];
    if (directRoomsOperationsQueue.count == 1)
    {
        directRoomsOperationsQueue.firstObject();
    }
    else
    {
        NSLog(@"[MXSession] runOrQueueDirectRoomOperation: Queue operation %p", directRoomsOperationsQueue.lastObject);
    }
}

- (void)runNextDirectRoomOperation
{
    // Dequeue the completed operation
    [directRoomsOperationsQueue removeObjectAtIndex:0];

    // And run the next one if any
    if (directRoomsOperationsQueue.firstObject)
    {
        NSLog(@"[MXSession] runOrQueueDirectRoomOperation: Execute queued operation %p", directRoomsOperationsQueue.firstObject);
        directRoomsOperationsQueue.firstObject();
    }
}

- (MXRoom *)getOrCreateRoom:(NSString *)roomId notify:(BOOL)notify
{
    MXRoom *room = [self roomWithRoomId:roomId];
    if (nil == room)
    {
        room = [self createRoom:roomId notify:notify];
    }
    return room;
}

- (MXRoom *)createRoom:(NSString *)roomId notify:(BOOL)notify
{
    MXRoom *room = [[MXRoom alloc] initWithRoomId:roomId andMatrixSession:self];
    
    [self addRoom:room notify:notify];
    return room;
}

- (void)addRoom:(MXRoom*)room notify:(BOOL)notify
{
    // Register global listeners for this room
    for (MXSessionEventListener *listener in globalEventListeners)
    {
        [listener addRoomToSpy:room];
    }

    [rooms setObject:room forKey:room.roomId];

    // Create the room summary if does not exist yet
    MXRoomSummary *summary = roomsSummaries[room.roomId];
    if (!summary)
    {
        summary = [[MXRoomSummary alloc] initWithRoomId:room.roomId andMatrixSession:self];
        roomsSummaries[room.roomId] = summary;
    }

    if (notify)
    {
        // Broadcast the new room available in the MXSession.rooms array
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionNewRoomNotification
                                                            object:self
                                                          userInfo:@{
                                                                     kMXSessionNotificationRoomIdKey: room.roomId
                                                                     }];
    }
}

- (void)removeRoom:(NSString *)roomId
{
    MXRoom *room = [self roomWithRoomId:roomId];

    if (room)
    {
        // Unregister global listeners for this room
        for (MXSessionEventListener *listener in globalEventListeners)
        {
            [listener removeSpiedRoom:room];
        }

        // Clean the store
        [_store deleteRoom:roomId];
        [_aggregations resetDataInRoom:roomId];

        // And remove the room and its summary from the list
        [rooms removeObjectForKey:roomId];
        [roomsSummaries removeObjectForKey:roomId];

        // Broadcast the left room
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionDidLeaveRoomNotification
                                                            object:self
                                                          userInfo:@{
                                                                     kMXSessionNotificationRoomIdKey: roomId
                                                                     }];
    }
}


#pragma mark - Rooms loading
/**
 Load a `MXRoom` object from the store.

 @param roomId the id of the room to load.
 @return the loaded `MXRoom` object.
 */
- (MXRoom *)loadRoom:(NSString *)roomId
{
    MXRoom *room = [MXRoom loadRoomFromStore:_store withRoomId:roomId matrixSession:self];

    if (room)
    {
        [self addRoom:room notify:NO];
    }
    return room;
}

- (void)preloadRoomsData:(NSArray<NSString*> *)roomIds onComplete:(dispatch_block_t)onComplete
{
    NSLog(@"[MXSession] preloadRooms: %@ rooms", @(roomIds.count));

    dispatch_group_t group = dispatch_group_create();
    for (NSString *roomId in roomIds)
    {
        MXRoom *room = [self roomWithRoomId:roomId];
        if (room)
        {
            dispatch_group_enter(group);
            [room liveTimeline:^(MXEventTimeline *liveTimeline) {
                dispatch_group_leave(group);
            }];
        }
        else
        {
            NSLog(@"[MXSession] preloadRoomsData: Unkown room id: %@", roomId);
        }
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"[MXSession] preloadRoomsForSyncResponse: DONE");
        onComplete();
    });
}


#pragma mark - Matrix Events
- (MXHTTPOperation*)eventWithEventId:(NSString*)eventId
                              inRoom:(NSString *)roomId
                             success:(void (^)(MXEvent *event))success
                             failure:(void (^)(NSError *error))failure
{
    MXHTTPOperation *operation;

    if (roomId)
    {
        // Try to find it from the store first
        // (this operation requires a roomId for the moment)
        MXEvent *event = [_store eventWithEventId:eventId inRoom:roomId];

        if (event)
        {
            if (success)
            {
                success(event);
            }
        }
        else
        {
            operation = [matrixRestClient eventWithEventId:eventId inRoom:roomId success:success failure:failure];
        }
    }
    else
    {
        operation = [matrixRestClient eventWithEventId:eventId success:success failure:failure];
    }

    return operation;
}


#pragma mark - Rooms summaries
- (MXRoomSummary *)roomSummaryWithRoomId:(NSString*)roomId
{
    MXRoomSummary *roomSummary;

    if (roomId)
    {
        roomSummary =  roomsSummaries[roomId];
    }

    return roomSummary;
}

- (NSArray<MXRoomSummary*>*)roomsSummaries
{
    return [roomsSummaries allValues];
}

-(void)resetRoomsSummariesLastMessage
{
    NSLog(@"[MXSession] resetRoomsSummariesLastMessage");

    for (MXRoomSummary *summary in self.roomsSummaries)
    {
        [summary resetLastMessage:nil failure:^(NSError *error) {
            NSLog(@"[MXSession] Cannot reset last message for room %@", summary.roomId);
        } commit:NO];
    }
    
    // Commit store changes done
    if ([_store respondsToSelector:@selector(commit)])
    {
        [_store commit];
    }
}

- (void)fixRoomsSummariesLastMessage
{
    for (MXRoomSummary *summary in self.roomsSummaries)
    {
        if (!summary.lastMessageEventId)
        {
            NSLog(@"[MXSession] Fixing last message for room %@", summary.roomId);
            
            [summary resetLastMessage:^{
                NSLog(@"[MXSession] Fixing last message operation for room %@ has complete. lastMessageEventId: %@", summary.roomId, summary.lastMessageEventId);
            } failure:^(NSError *error) {
                NSLog(@"[MXSession] Cannot fix last message for room %@", summary.roomId);
            }
                               commit:NO];
        }
    }
    
    // Commit store changes done
    if ([_store respondsToSelector:@selector(commit)])
    {
        [_store commit];
    }
}

#pragma mark - The user's groups

- (MXGroup *)groupWithGroupId:(NSString*)groupId
{
    return [_store groupWithGroupId:groupId];
}

- (NSArray<MXGroup*>*)groups
{
    return _store.groups;
}

- (MXHTTPOperation*)acceptGroupInvite:(NSString*)groupId
                              success:(void (^)(void))success
                              failure:(void (^)(NSError *error))failure
{
    NSLog(@"[MXSession] acceptGroupInvite %@", groupId);
    
    MXWeakify(self);
    return [matrixRestClient acceptGroupInvite:groupId success:^{
        MXStrongifyAndReturnIfNil(self);

        [self didJoinGroupWithId:groupId notify:YES];
        if (success)
        {
            success();
        }

    } failure:failure];
}

- (MXHTTPOperation*)leaveGroup:(NSString*)groupId
                       success:(void (^)(void))success
                       failure:(void (^)(NSError *error))failure
{
    NSLog(@"[MXSession] leaveGroup %@", groupId);
    
    MXWeakify(self);
    return [matrixRestClient leaveGroup:groupId success:^{
        MXStrongifyAndReturnIfNil(self);

        // Check the group has been removed before calling the success callback
        // This may be already done during a server sync.
        if ([self groupWithGroupId:groupId])
        {
            [self removeGroup:groupId];
        }

        if (success)
        {
            success();
        }

    } failure:failure];
}

- (MXHTTPOperation*)updateGroupPublicity:(MXGroup*)group
                            isPublicised:(BOOL)isPublicised
                                 success:(void (^)(void))success
                                 failure:(void (^)(NSError *error))failure
{
    if (!group.groupId.length)
    {
        if (failure)
        {
            failure ([NSError errorWithDomain:kMXNSErrorDomain code:0 userInfo:nil]);
        }
        return nil;
    }
    
    NSLog(@"[MXSession] updateGroupPublicity %@", group.groupId);
    
    MXWeakify(self);
    return [matrixRestClient updateGroupPublicity:group.groupId isPublicised:isPublicised success:^(void) {
        MXStrongifyAndReturnIfNil(self);

        MXGroup *storedGroup = [self groupWithGroupId:group.groupId];

        if (storedGroup != group)
        {
            // Update the provided group instance
            group.summary.user.isPublicised = isPublicised;
        }

        if (storedGroup && storedGroup.summary.user.isPublicised != isPublicised)
        {
            storedGroup.summary.user.isPublicised = isPublicised;
            [self.store storeGroup:storedGroup];
            // Commit store changes done
            if ([self.store respondsToSelector:@selector(commit)])
            {
                [self.store commit];
            }

            // Broadcast the new joined group.
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionDidUpdateGroupSummaryNotification
                                                                object:self
                                                              userInfo:@{
                                                                         kMXSessionNotificationGroupKey: storedGroup
                                                                         }];
        }

        // Refresh the cached publicised groups for the current user.
        if (!self->userIdsWithOutdatedPublicisedGroups)
        {
            self->userIdsWithOutdatedPublicisedGroups = [NSMutableArray array];
        }
        [self->userIdsWithOutdatedPublicisedGroups addObject:self->matrixRestClient.credentials.userId];
        [self publicisedGroupsForUser:self->matrixRestClient.credentials.userId];

        if (success)
        {
            success();
        }
        
    } failure:failure];
}

- (MXHTTPOperation*)updateGroupProfile:(MXGroup*)group
                            success:(void (^)(void))success
                            failure:(void (^)(NSError *error))failure
{
    if (!group.groupId.length)
    {
        if (failure)
        {
            failure ([NSError errorWithDomain:kMXNSErrorDomain code:0 userInfo:nil]);
        }
        return nil;
    }
    
    NSLog(@"[MXSession] updateGroupProfile %@", group.groupId);

    MXWeakify(self);
    return [matrixRestClient getGroupProfile:group.groupId success:^(MXGroupProfile *groupProfile) {
        MXStrongifyAndReturnIfNil(self);

        MXGroup *storedGroup = [self groupWithGroupId:group.groupId];

        if (storedGroup != group)
        {
            // Update the provided group instance
            [group updateProfile:groupProfile];
        }

        if (storedGroup && [storedGroup updateProfile:groupProfile])
        {
            [self.store storeGroup:storedGroup];
            // Commit store changes done
            if ([self.store respondsToSelector:@selector(commit)])
            {
                [self.store commit];
            }

            // Broadcast the new joined group.
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionDidUpdateGroupSummaryNotification
                                                                object:self
                                                              userInfo:@{
                                                                         kMXSessionNotificationGroupKey: storedGroup
                                                                         }];
        }

        if (success)
        {
            success();
        }
        
    } failure:failure];
}

- (MXHTTPOperation*)updateGroupSummary:(MXGroup*)group
                            success:(void (^)(void))success
                            failure:(void (^)(NSError *error))failure
{
    if (!group.groupId.length)
    {
        if (failure)
        {
            failure ([NSError errorWithDomain:kMXNSErrorDomain code:0 userInfo:nil]);
        }
        return nil;
    }
    
    NSLog(@"[MXSession] updateGroupSummary %@", group.groupId);

    MXWeakify(self);
    return [matrixRestClient getGroupSummary:group.groupId success:^(MXGroupSummary *groupSummary) {
        MXStrongifyAndReturnIfNil(self);

        MXGroup *storedGroup = [self groupWithGroupId:group.groupId];

        if (storedGroup != group)
        {
            // Update the provided group instance
            group.summary = groupSummary;
        }

        if (storedGroup && [storedGroup updateSummary:groupSummary])
        {
            [self.store storeGroup:storedGroup];
            // Commit store changes done
            if ([self.store respondsToSelector:@selector(commit)])
            {
                [self.store commit];
            }

            // Broadcast the new joined group.
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionDidUpdateGroupSummaryNotification
                                                                object:self
                                                              userInfo:@{
                                                                         kMXSessionNotificationGroupKey: storedGroup
                                                                         }];
        }

        if (success)
        {
            success();
        }
        
    } failure:failure];
}

- (MXHTTPOperation*)updateGroupUsers:(MXGroup*)group
                          success:(void (^)(void))success
                          failure:(void (^)(NSError *error))failure
{
    if (!group.groupId.length)
    {
        if (failure)
        {
            failure ([NSError errorWithDomain:kMXNSErrorDomain code:0 userInfo:nil]);
        }
        return nil;
    }
    
    NSLog(@"[MXSession] updateGroupUsers %@", group.groupId);

    MXWeakify(self);
    return [matrixRestClient getGroupUsers:group.groupId success:^(MXGroupUsers *groupUsers) {
        MXStrongifyAndReturnIfNil(self);

        MXGroup *storedGroup = [self groupWithGroupId:group.groupId];

        if (storedGroup != group)
        {
            // Update the provided group instance
            group.users = groupUsers;
        }

        if (storedGroup && [storedGroup updateUsers:groupUsers])
        {
            [self.store storeGroup:storedGroup];
            // Commit store changes done
            if ([self.store respondsToSelector:@selector(commit)])
            {
                [self.store commit];
            }

            // Broadcast the new joined group.
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionDidUpdateGroupUsersNotification
                                                                object:self
                                                              userInfo:@{
                                                                         kMXSessionNotificationGroupKey: storedGroup
                                                                         }];
        }

        if (success)
        {
            success();
        }
        
    } failure:failure];
}

- (MXHTTPOperation*)updateGroupInvitedUsers:(MXGroup*)group
                                    success:(void (^)(void))success
                                    failure:(void (^)(NSError *error))failure
{
    if (!group.groupId.length)
    {
        if (failure)
        {
            failure ([NSError errorWithDomain:kMXNSErrorDomain code:0 userInfo:nil]);
        }
        return nil;
    }
    
    NSLog(@"[MXSession] updateGroupInvitedUsers %@", group.groupId);

    MXWeakify(self);
    return [matrixRestClient getGroupInvitedUsers:group.groupId success:^(MXGroupUsers *invitedUsers) {
        MXStrongifyAndReturnIfNil(self);

        MXGroup *storedGroup = [self groupWithGroupId:group.groupId];

        if (storedGroup != group)
        {
            // Update the provided group instance
            group.invitedUsers = invitedUsers;
        }

        if (storedGroup && [storedGroup updateInvitedUsers:invitedUsers])
        {
            [self.store storeGroup:storedGroup];
            // Commit store changes done
            if ([self.store respondsToSelector:@selector(commit)])
            {
                [self.store commit];
            }

            // Broadcast the new joined group.
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionDidUpdateGroupUsersNotification
                                                                object:self
                                                              userInfo:@{
                                                                         kMXSessionNotificationGroupKey: storedGroup
                                                                         }];
        }

        if (success)
        {
            success();
        }
        
    } failure:failure];
}

- (MXHTTPOperation*)updateGroupRooms:(MXGroup*)group
                          success:(void (^)(void))success
                          failure:(void (^)(NSError *error))failure
{
    if (!group.groupId.length)
    {
        if (failure)
        {
            failure ([NSError errorWithDomain:kMXNSErrorDomain code:0 userInfo:nil]);
        }
        return nil;
    }
    
    NSLog(@"[MXSession] updateGroupRooms %@", group.groupId);

    MXWeakify(self);
    return [matrixRestClient getGroupRooms:group.groupId success:^(MXGroupRooms *groupRooms) {
        MXStrongifyAndReturnIfNil(self);

        MXGroup *storedGroup = [self groupWithGroupId:group.groupId];

        if (storedGroup != group)
        {
            // Update the provided group instance
            group.rooms = groupRooms;
        }

        if (storedGroup && [storedGroup updateRooms:groupRooms])
        {
            [self.store storeGroup:storedGroup];
            // Commit store changes done
            if ([self.store respondsToSelector:@selector(commit)])
            {
                [self.store commit];
            }

            // Broadcast the new joined group.
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionDidUpdateGroupRoomsNotification
                                                                object:self
                                                              userInfo:@{
                                                                         kMXSessionNotificationGroupKey: storedGroup
                                                                         }];
        }

        if (success)
        {
            success();
        }

    } failure:failure];
}

#pragma mark -

- (MXGroup *)didJoinGroupWithId:(NSString *)groupId notify:(BOOL)notify
{
    NSLog(@"[MXSession] didJoinGroupWithId %@", groupId);
    
    MXGroup *group = [self groupWithGroupId:groupId];
    if (nil == group)
    {
        group = [[MXGroup alloc] initWithGroupId:groupId];
    }
    
    // Set/update the user membership.
    group.membership = MXMembershipJoin;
    
    [_store storeGroup:group];
    
    // Update the group summary from server.
    [self updateGroupSummary:group success:nil failure:^(NSError *error) {
        NSLog(@"[MXKSession] didJoinGroupWithId: group summary update failed %@", groupId);
    }];
    
    if (notify)
    {
        // Broadcast the new joined group.
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionDidJoinGroupNotification
                                                            object:self
                                                          userInfo:@{
                                                                     kMXSessionNotificationGroupKey: group
                                                                     }];
    }
    
    return group;
}

- (MXGroup *)createGroupInviteWithId:(NSString *)groupId profile:(MXGroupSyncProfile*)profile andInviter:(NSString*)inviter notify:(BOOL)notify
{
    NSLog(@"[MXSession] createGroupInviteWithId %@", groupId);
    MXGroup *group = [[MXGroup alloc] initWithGroupId:groupId];
    
    MXGroupSummary *summary = [[MXGroupSummary alloc] init];
    MXGroupProfile *groupProfile = [[MXGroupProfile alloc] init];
    groupProfile.name = profile.name;
    groupProfile.avatarUrl = profile.avatarUrl;
    summary.profile = groupProfile;
    
    group.summary = summary;
    group.inviter = inviter;
    
    // Set user membership
    group.membership = MXMembershipInvite;
    
    [_store storeGroup:group];
    
    // Retrieve the group summary from server.
    [self updateGroupSummary:group success:nil failure:^(NSError *error) {
        NSLog(@"[MXKSession] createGroupInviteWithId: group summary update failed %@", group.groupId);
    }];
    
    if (notify)
    {
        // Broadcast the new group
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionNewGroupInviteNotification
                                                            object:self
                                                          userInfo:@{
                                                                     kMXSessionNotificationGroupKey: group
                                                                     }];
    }
    
    return group;
}

- (void)removeGroup:(NSString *)groupId
{
    NSLog(@"[MXSession] removeGroup %@", groupId);
    // Clean the store
    [_store deleteGroup:groupId];
    
    // Broadcast the left group
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionDidLeaveGroupNotification
                                                        object:self
                                                      userInfo:@{
                                                                 kMXSessionNotificationGroupIdKey: groupId
                                                                 }];
}

#pragma  mark - Missed notifications

- (NSUInteger)missedNotificationsCount
{
    NSUInteger notificationCount = 0;
    
    // Sum here all the notification counts from room summaries.
    for (MXRoomSummary *roomSummary in self.roomsSummaries)
    {
        if (roomSummary.notificationCount)
        {
            notificationCount += roomSummary.notificationCount;
        }
    }
    
    return notificationCount;
}

- (NSUInteger)missedDiscussionsCount
{
    NSUInteger roomCount = 0;
    
    // Sum here all the rooms with missed notifications.
    for (MXRoomSummary *roomSummary in self.roomsSummaries)
    {
        if (roomSummary.notificationCount)
        {
            roomCount ++;
        }
    }
    
    return roomCount;
}

- (NSUInteger)missedHighlightDiscussionsCount
{
    NSUInteger roomCount = 0;
    
    // Sum here all the rooms with unread highlighted messages.
    for (MXRoomSummary *roomSummary in self.roomsSummaries)
    {
        if (roomSummary.highlightCount)
        {
            roomCount ++;
        }
    }
    
    return roomCount;
}

- (void)markAllMessagesAsRead
{
    // Reset the unread count in all the existing room summaries.
    for (MXRoomSummary *roomSummary in self.roomsSummaries)
    {
        [roomSummary markAllAsRead];
    }
}

#pragma mark - Room peeking
- (void)peekInRoomWithRoomId:(NSString*)roomId
                     success:(void (^)(MXPeekingRoom *peekingRoom))success
                     failure:(void (^)(NSError *error))failure
{
    MXPeekingRoom *peekingRoom = [[MXPeekingRoom alloc] initWithRoomId:roomId andMatrixSession:self];
    [peekingRooms addObject:peekingRoom];

    MXWeakify(self);
    [peekingRoom start:^{

        if (success)
        {
            success(peekingRoom);
        }

    } failure:^(NSError *error) {
        MXStrongifyAndReturnIfNil(self);

        // The room is not peekable, release the object
        [self->peekingRooms removeObject:peekingRoom];
        [peekingRoom close];
        
        NSLog(@"[MXSession] The room is not peekable");

        if (failure)
        {
            failure(error);
        }
    }];
}

- (void)stopPeeking:(MXPeekingRoom*)peekingRoom
{
    [peekingRooms removeObject:peekingRoom];
    [peekingRoom close];
}

- (BOOL)isPeekingInRoomWithRoomId:(NSString *)roomId
{
   return ([self peekingRoomWithRoomId:roomId] != nil);
}

- (MXPeekingRoom *)peekingRoomWithRoomId:(NSString *)roomId
{
    for (MXPeekingRoom *peekingRoom in peekingRooms)
    {
        if ([peekingRoom.roomId isEqualToString:roomId])
        {
            return peekingRoom;
        }
    }
    return nil;
}


#pragma mark - Matrix users

- (MXUser *)userWithUserId:(NSString *)userId
{
    return [_store userWithUserId:userId];
}

- (NSArray<MXUser*> *)users
{
    return _store.users;
}

- (MXUser *)getOrCreateUser:(NSString *)userId
{
    MXUser *user = [self userWithUserId:userId];
    
    if (nil == user)
    {
        user = [[MXUser alloc] initWithUserId:userId];
    }
    return user;
}

- (BOOL)isUserIgnored:(NSString *)userId
{
    return _ignoredUsers && (NSNotFound != [_ignoredUsers indexOfObject:userId]);
}

- (MXHTTPOperation*)ignoreUsers:(NSArray<NSString*>*)userIds
                       success:(void (^)(void))success
                       failure:(void (^)(NSError *error))failure
{
    // Create the new account data subset for m.ignored_user_list
    // by adding userIds
    NSMutableDictionary *ignoredUsersDict = [NSMutableDictionary dictionary];
    for (NSString *userId in _ignoredUsers)
    {
        ignoredUsersDict[userId] = @{};
    }
    for (NSString *userId in userIds)
    {
        ignoredUsersDict[userId] = @{};
    }

    // And make the request
    NSDictionary *data = @{
                           kMXAccountDataKeyIgnoredUser: ignoredUsersDict
                           };
//    __weak __typeof(self)weakSelf = self;
    return [self setAccountData:data forType:kMXAccountDataTypeIgnoredUserList success:^{

//        __strong __typeof(weakSelf)strongSelf = weakSelf;

        // Update self.ignoredUsers right now
// Commented as it created race condition with /sync response handling
//        NSMutableArray *newIgnoredUsers = [NSMutableArray arrayWithArray:strongSelf->_ignoredUsers];
//        for (NSString *userId in userIds)
//        {
//            if (NSNotFound == [newIgnoredUsers indexOfObject:userId])
//            {
//                [newIgnoredUsers addObject:userId];
//            }
//        }
//        strongSelf->_ignoredUsers = newIgnoredUsers;

        if (success)
        {
            success();
        }

    } failure:failure];
}

- (MXHTTPOperation *)unIgnoreUsers:(NSArray<NSString *> *)userIds success:(void (^)(void))success failure:(void (^)(NSError *))failure
{
    // Create the new account data subset for m.ignored_user_list
    // by substracting userIds
    NSMutableDictionary *ignoredUsersDict = [NSMutableDictionary dictionary];
    for (NSString *userId in _ignoredUsers)
    {
        ignoredUsersDict[userId] = @{};
    }
    for (NSString *userId in userIds)
    {
        [ignoredUsersDict removeObjectForKey:userId];
    }

    // And make the request
    NSDictionary *data = @{
                           kMXAccountDataKeyIgnoredUser: ignoredUsersDict
                           };
//    __weak __typeof(self)weakSelf = self;
    return [self setAccountData:data forType:kMXAccountDataTypeIgnoredUserList success:^{

//        __strong __typeof(weakSelf)strongSelf = weakSelf;

        // Update self.ignoredUsers right now
// Commented as it created race condition with /sync response handling
//        NSMutableArray *newIgnoredUsers = [NSMutableArray arrayWithArray:strongSelf->_ignoredUsers];
//        for (NSString *userId in userIds)
//        {
//            [newIgnoredUsers removeObject:userId];
//        }
//        strongSelf->_ignoredUsers = newIgnoredUsers;

        if (success)
        {
            success();
        }

    } failure:failure];
}


#pragma mark - User's special rooms

- (BOOL)removeInvitedRoom:(MXRoom*)roomToRemove
{
    BOOL hasBeenFound = NO;
    
    // sanity check
    if (invitedRooms.count > 0)
    {
        hasBeenFound =  ([invitedRooms indexOfObject:roomToRemove] != NSNotFound);
        
        // if the room object is not found
        // check if there is a room with the same roomId
        // indeed, during the room initial sync, the room object is deleted to be created again.
        if (!hasBeenFound)
        {
            for(MXRoom* room in invitedRooms)
            {
                if ([room.roomId isEqualToString:roomToRemove.roomId])
                {
                    roomToRemove = room;
                    hasBeenFound = YES;
                    break;
                }
            }
        }
        
        if (hasBeenFound)
        {
            [invitedRooms removeObject:roomToRemove];
        }
    }
    
    return hasBeenFound;
}

- (NSArray<MXRoom *> *)invitedRooms
{
    if (nil == invitedRooms && self.state > MXSessionStateInitialised)
    {
        // On the first call, set up the invitation list and mechanism to update it
        invitedRooms = [NSMutableArray array];

        // Compute the current invitation list
        for (MXRoom *room in rooms.allValues)
        {
            if (room.summary.membership == MXMembershipInvite)
            {
                [invitedRooms addObject:room];
            }
        }

        // Order them by origin_server_ts
        [invitedRooms sortUsingSelector:@selector(compareLastMessageEventOriginServerTs:)];

        // Add a listener in order to update the app about invitation list change
        MXWeakify(self);
        [self listenToEventsOfTypes:@[kMXEventTypeStringRoomMember] onEvent:^(MXEvent *event, MXTimelineDirection direction, id customObject) {
            MXStrongifyAndReturnIfNil(self);

            // in some race conditions the oneself join event is received during the sync instead of MXTimelineDirectionSync
            //
            // standard case
            // 1 - send a join request
            // 2 - receive the join event in the live stream -> call this method
            // 3 - perform an initial sync when the join method call the success callback
            //
            // but, this case also happens
            // 1 - send a join request
            // 2 - perform an initial sync when the join method call the success callback
            // 3 - receive the join event in the live stream -> this method is not called because the event has already been stored in the step 2
            // so, we need to manage the sync direction
            if (MXTimelineDirectionForwards == direction)
            {
                BOOL notify = NO;
                MXRoomState *roomPrevState = (MXRoomState *)customObject;
                MXRoom *room = [self roomWithRoomId:event.roomId];

                if (room.summary.membership == MXMembershipInvite)
                {
                    // check if the room is not yet in the list
                    // must be done in forward and sync direction
                    if ([self->invitedRooms indexOfObject:room] == NSNotFound)
                    {
                        // This is an invite event. Add the room to the invitation list
                        [self->invitedRooms addObject:room];
                        notify = YES;
                    }
                }
                else if (roomPrevState.membership == MXMembershipInvite)
                {
                    // An invitation was pending for this room. A new membership event means the
                    // user has accepted or rejected the invitation.
                    notify = [self removeInvitedRoom:room];
                }

                if (notify)
                {
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionInvitedRoomsDidChangeNotification
                                                                        object:self
                                                                      userInfo:@{
                                                                                 kMXSessionNotificationRoomIdKey: event.roomId,
                                                                                 kMXSessionNotificationEventKey: event
                                                                                 }];
                }
            }
        }];
    }

    return invitedRooms;
}


#pragma mark - User's rooms tags
- (NSArray<MXRoom*>*)roomsWithTag:(NSString*)tag
{
    if (![tag isEqualToString:kMXSessionNoRoomTag])
    {
        // Get all room with the passed tag
        NSMutableArray *roomsWithTag = [NSMutableArray array];
        for (MXRoom *room in rooms.allValues)
        {
            if (room.accountData.tags[tag])
            {
                [roomsWithTag addObject:room];
            }
        }

        // Sort them according to their tag order
        [roomsWithTag sortUsingComparator:^NSComparisonResult(MXRoom *room1, MXRoom *room2) {
            return [self compareRoomsByTag:tag room1:room1 room2:room2];
        }];

        return roomsWithTag;
    }
    else
    {
        // List rooms with no tags
        NSMutableArray *roomsWithNoTag = [NSMutableArray array];
        for (MXRoom *room in rooms.allValues)
        {
            if (0 == room.accountData.tags.count)
            {
                [roomsWithNoTag addObject:room];
            }
        }
        return roomsWithNoTag;
    }
}

- (NSDictionary<NSString*, NSArray<MXRoom*>*>*)roomsByTags
{
    NSMutableDictionary<NSString*, NSMutableArray<MXRoom*>*> *roomsByTags = [NSMutableDictionary dictionary];

    NSMutableArray<MXRoom*> *roomsWithNoTag = [NSMutableArray array];

    // Sort all rooms according to their defined tags
    for (MXRoom *room in rooms.allValues)
    {
        if (0 < room.accountData.tags.count)
        {
            for (NSString *tagName in room.accountData.tags)
            {
                MXRoomTag *tag = room.accountData.tags[tagName];
                if (!roomsByTags[tag.name])
                {
                    roomsByTags[tag.name] = [NSMutableArray array];
                }
                [roomsByTags[tag.name] addObject:room];
            }
        }
        else
        {
            // Put room with no tags in the recent list
            [roomsWithNoTag addObject:room];
        }
    }

    // For each tag, sort rooms according to their tag order
    for (NSString *tag in roomsByTags)
    {
        [roomsByTags[tag] sortUsingComparator:^NSComparisonResult(MXRoom *room1, MXRoom *room2) {
            return [self compareRoomsByTag:tag room1:room1 room2:room2];
        }];
    }

    // roomsWithNoTag can now be added to the result dictionary
    roomsByTags[kMXSessionNoRoomTag] = roomsWithNoTag;

    return roomsByTags;
}

- (NSComparisonResult)compareRoomsByTag:(NSString*)tag room1:(MXRoom*)room1 room2:(MXRoom*)room2
{
    NSComparisonResult result = NSOrderedSame;

    MXRoomTag *tag1 = room1.accountData.tags[tag];
    MXRoomTag *tag2 = room2.accountData.tags[tag];

    if (tag1.order && tag2.order)
    {
        // Do a lexicographic comparison
        result = [tag1.order localizedCompare:tag2.order];
    }
    else if (tag1.order)
    {
        result = NSOrderedDescending;
    }
    else if (tag2.order)
    {
        result = NSOrderedAscending;
    }

    // In case of same order, order rooms by their last event
    if (NSOrderedSame == result)
    {
        result = [room1.summary.lastMessageEvent compareOriginServerTs:room2.summary.lastMessageEvent];
    }

    return result;
}

- (NSString*)tagOrderToBeAtIndex:(NSUInteger)index from:(NSUInteger)originIndex withTag:(NSString *)tag
{
    // Algo (and the [0.0, 1.0] assumption) inspired from matrix-react-sdk:
    // We sort rooms by the lexicographic ordering of the 'order' metadata on their tags.
    // For convenience, we calculate this for now a floating point number between 0.0 and 1.0.

    double orderA = 0.0; // by default we're next to the beginning of the list
    double orderB = 1.0; // by default we're next to the end of the list too

    NSArray<MXRoom*> *roomsWithTag = [self roomsWithTag:tag];
    if (roomsWithTag.count)
    {
        // when an object is moved down, the index must be incremented
        // because the object will be removed from the list to be inserted after its destination
        if ((originIndex != NSNotFound) && (originIndex < index))
        {
            index++;
        }
        
        if (index > 0)
        {
            // Bound max index to the array size
            NSUInteger prevIndex = (index < roomsWithTag.count) ? index : roomsWithTag.count;

            MXRoomTag *prevTag = roomsWithTag[prevIndex - 1].accountData.tags[tag];
            if (!prevTag.order)
            {
                NSLog(@"[MXSession] computeTagOrderForRoom: Previous room in sublist has no ordering metadata. This should never happen.");
            }
            else
            {
                if (prevTag.parsedOrder)
                {
                    orderA = [prevTag.parsedOrder doubleValue];
                }
            }
        }

        if (index <= roomsWithTag.count - 1)
        {
            MXRoomTag *nextTag = roomsWithTag[index ].accountData.tags[tag];
            if (!nextTag.order)
            {
                NSLog(@"[MXSession] computeTagOrderForRoom: Next room in sublist has no ordering metadata. This should never happen.");
            }
            else
            {
                if (nextTag.parsedOrder)
                {
                    orderB = [nextTag.parsedOrder doubleValue];
                }
            }
        }
    }

    double order = (orderA + orderB) / 2.0;

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setGroupingSeparator:@""];
    [formatter setDecimalSeparator:@"."];
    [formatter setMaximumFractionDigits:16];
    [formatter setMinimumFractionDigits:0];
    
    // remove trailing 0
    // in some cases, the order is 0.00000 ("%f" formatter");
    // with this method, it becomes "0".
    return [formatter stringFromNumber:[NSNumber numberWithDouble:order]];
}


#pragma mark - User's account data
- (MXHTTPOperation*)setAccountData:(NSDictionary*)data
                           forType:(NSString*)type
                           success:(void (^)(void))success
                           failure:(void (^)(NSError *error))failure
{
    return [matrixRestClient setAccountData:data forType:type success:success failure:failure];
}

- (MXHTTPOperation *)setAccountDataIdentityServer:(NSString *)identityServer
                                          success:(void (^)(void))success
                                          failure:(void (^)(NSError *))failure
{
    // Sanitise the passed URL
    if (!identityServer.length)
    {
        identityServer = nil;
    }
    if (identityServer)
    {
        if (![identityServer hasPrefix:@"http"])
        {
            identityServer = [NSString stringWithFormat:@"https://%@", identityServer];
        }
        if ([identityServer hasSuffix:@"/"])
        {
            identityServer = [identityServer substringToIndex:identityServer.length - 1];
        }
    }

    NSLog(@"[MXSession] setAccountDataIdentityServer: %@", identityServer);

    MXHTTPOperation *operation;
    if (identityServer)
    {
        // Does the URL point to a true IS
        __block MXIdentityService *identityService = [[MXIdentityService alloc] initWithIdentityServer:identityServer accessToken:nil andHomeserverRestClient:matrixRestClient];

        operation = [identityService pingIdentityServer:^{
            identityService = nil;

            MXHTTPOperation *operation2 = [self setAccountData:@{
                                                                 kMXAccountDataKeyIdentityServer:identityServer
                                                                 }
                                                       forType:kMXAccountDataTypeIdentityServer
                                                       success:success failure:failure];
            
            [operation mutateTo:operation2];

        } failure:^(NSError * _Nonnull error) {
            identityService = nil;

            NSLog(@"[MXSession] setAccountDataIdentityServer: Invalid identity server. Error: %@", error);

            if (failure)
            {
                failure(error);
            }
        }];
    }
    else
    {
        operation = [self setAccountData:@{
                                            kMXAccountDataKeyIdentityServer:NSNull.null
                                            }
                                  forType:kMXAccountDataTypeIdentityServer
                                  success:success failure:failure];
    }

    return operation;
}

- (BOOL)hasAccountDataIdentityServerValue
{
    return ([self.accountData accountDataForEventType:kMXAccountDataTypeIdentityServer] != nil);
}

- (NSString *)accountDataIdentityServer
{
    NSString *accountDataIdentityServer;

    NSDictionary *content = [self.accountData accountDataForEventType:kMXAccountDataTypeIdentityServer];
    MXJSONModelSetString(accountDataIdentityServer, content[kMXAccountDataKeyIdentityServer]);

    return accountDataIdentityServer;
}


#pragma mark - Homeserver information
- (MXWellKnown *)homeserverWellknown
{
    return _store.homeserverWellknown;
}

- (MXHTTPOperation *)refreshHomeserverWellknown:(void (^)(MXWellKnown *))success
                                        failure:(void (^)(NSError *))failure
{
    NSLog(@"[MXSession] refreshHomeserverWellknown");
    if (!autoDiscovery)
    {
        autoDiscovery = [[MXAutoDiscovery alloc] initWithUrl:matrixRestClient.homeserver];
    }

    MXWeakify(self);
    return [autoDiscovery wellKnow:^(MXWellKnown * _Nonnull wellKnown) {
        MXStrongifyAndReturnIfNil(self);

        [self.store storeHomeserverWellknown:wellKnown];

        if (success)
        {
            success(wellKnown);
        }
    } failure:failure];
}


#pragma mark - Matrix filters
- (MXHTTPOperation*)setFilter:(MXFilterJSONModel*)filter
                      success:(void (^)(NSString *filterId))success
                      failure:(void (^)(NSError *error))failure
{
    MXHTTPOperation *operation;

    if (_store)
    {
        // Create an empty operation that will be mutated later
        operation = [[MXHTTPOperation alloc] init];

        // Check if the filter has been already created and cached
        MXWeakify(self);
        [_store filterIdForFilter:filter success:^(NSString * _Nullable filterId) {
            MXStrongifyAndReturnIfNil(self);

            if (filterId)
            {
                success(filterId);
            }
            else
            {
                // Else, create homeserver side
                MXWeakify(self);
                MXHTTPOperation *operation2 = [self.matrixRestClient setFilter:filter success:^(NSString *filterId) {
                    MXStrongifyAndReturnIfNil(self);

                    // And store it
                    [self.store storeFilter:filter withFilterId:filterId];

                    success(filterId);

                } failure:failure];
                
                [operation mutateTo:operation2];
            }

        } failure:failure];
    }
    else
    {
        operation = [self.matrixRestClient setFilter:filter success:success failure:failure];
    }

    return operation;
}

- (MXHTTPOperation*)filterWithFilterId:(NSString*)filterId
                               success:(void (^)(MXFilterJSONModel *filter))success
                               failure:(void (^)(NSError *error))failure
{
    MXHTTPOperation *operation;

    if (_store)
    {
        // Create an empty operation that will be mutated later
        operation = [[MXHTTPOperation alloc] init];
        
        // Check in the store
        MXWeakify(self);
        [_store filterWithFilterId:filterId success:^(MXFilterJSONModel * _Nullable filter) {
            MXStrongifyAndReturnIfNil(self);

            if (filter)
            {
                success(filter);
            }
            else
            {
                // Check on the homeserver
                MXWeakify(self);
                MXHTTPOperation *operation2 = [self.matrixRestClient getFilterWithFilterId:filterId success:^(MXFilterJSONModel *filter) {
                    MXStrongifyAndReturnIfNil(self);

                    if (filter)
                    {
                        // Cache it locally
                        [self.store storeFilter:filter withFilterId:filterId];
                    }

                    success(filter);

                } failure:failure];
                
                [operation mutateTo:operation2];
            }

        } failure:failure];
    }
    else
    {
         operation = [matrixRestClient getFilterWithFilterId:filterId success:success failure:failure];
    }

    return operation;
}


#pragma mark - Crypto

/**
 If any, start the crypto module.

 @param success a block called in any case when the operation completes.
 @param failure a block object called when the operation fails.
 */
- (void)startCrypto:(void (^)(void))success
            failure:(void (^)(NSError *error))failure
{
    NSLog(@"[MXSession] Start crypto");

    if (_crypto)
    {
        [_crypto start:success failure:failure];
    }
    else
    {
        NSLog(@"[MXSession] Start crypto -> No crypto");
        success();
    }
}

- (BOOL)decryptEvent:(MXEvent*)event inTimeline:(NSString*)timeline
{
    MXEventDecryptionResult *result;
    if (event.eventType == MXEventTypeRoomEncrypted)
    {
        NSError *error;
        if (_crypto)
        {
            // TODO: One day, this method will be async
            result = [_crypto decryptEvent:event inTimeline:timeline error:&error];
            if (result)
            {
                [event setClearData:result];
            }
        }
        else
        {
            // Encryption not enabled
            error = [NSError errorWithDomain:MXDecryptingErrorDomain
                                        code:MXDecryptingErrorEncryptionNotEnabledCode
                                    userInfo:@{
                                               NSLocalizedDescriptionKey: MXDecryptingErrorEncryptionNotEnabledReason
                                               }];
        }

        if (error)
        {
            event.decryptionError = error;
        }
    }

    return (result != nil);
}

- (void)resetReplayAttackCheckInTimeline:(NSString*)timeline
{
    if (_crypto)
    {
        [_crypto resetReplayAttackCheckInTimeline:timeline];
    }
}

// Called when an event finally got decrypted after a late room key reception
- (void)onDidDecryptEvent:(NSNotification *)notification
{
    MXEvent *event = notification.object;

    // Check if this event can interest the room summary
    MXRoomSummary *summary = [self roomSummaryWithRoomId:event.roomId];
    if (summary &&
        summary.lastMessageEvent.ageLocalTs <= event.ageLocalTs)
    {
        [summary resetLastMessage:nil failure:nil commit:YES];
    }
}

#pragma mark - Global events listeners
- (id)listenToEvents:(MXOnSessionEvent)onEvent
{
    return [self listenToEventsOfTypes:nil onEvent:onEvent];
}

- (id)listenToEventsOfTypes:(NSArray*)types onEvent:(MXOnSessionEvent)onEvent
{
    MXSessionEventListener *listener = [[MXSessionEventListener alloc] initWithSender:self andEventTypes:types andListenerBlock:onEvent];
    
    // This listener must be listen to all existing rooms
    for (MXRoom *room in rooms.allValues)
    {
        [listener addRoomToSpy:room];
    }
    
    [globalEventListeners addObject:listener];
    
    return listener;
}

- (void)removeListener:(id)listenerId
{
    // Clean the MXSessionEventListener
    MXSessionEventListener *listener = (MXSessionEventListener *)listenerId;
    [listener removeAllSpiedRooms];
    
    // Before removing it
    [globalEventListeners removeObject:listener];
}

- (void)removeAllListeners
{
    // must be done before deleted the listeners to avoid
    // ollection <__NSArrayM: ....> was mutated while being enumerated.'
    NSArray* eventListeners = [globalEventListeners copy];
    
    for (MXSessionEventListener *listener in eventListeners)
    {
        [self removeListener:listener];
    }
}

- (void)notifyListeners:(MXEvent*)event direction:(MXTimelineDirection)direction
{
    // Notify all listeners
    // The SDK client may remove a listener while calling them by enumeration
    // So, use a copy of them
    NSArray *listeners = [globalEventListeners copy];

    for (MXEventListener *listener in listeners)
    {
        // And check the listener still exists before calling it
        if (NSNotFound != [globalEventListeners indexOfObject:listener])
        {
            [listener notify:event direction:direction andCustomObject:nil];
        }
    }
}

#pragma mark - Publicised groups

- (void)markOutdatedPublicisedGroupsByUserData
{
    // Retrieve the current list of users for who a publicised groups list is available.
    // A server request will be triggered only when the publicised groups will be requested again for these users.
    userIdsWithOutdatedPublicisedGroups = [NSMutableArray arrayWithArray:[publicisedGroupsByUserId allKeys]];
}

- (NSArray<NSString *> *)publicisedGroupsForUser:(NSString*)userId
{
    NSArray *publicisedGroups;
    if (userId)
    {
        publicisedGroups = publicisedGroupsByUserId[userId];
        
        BOOL shouldRefresh = NO;
        
        if (!publicisedGroups)
        {
            shouldRefresh = YES;
            
            // In order to prevent multiple request on the same user id, we put a temporary empty array when no value is available yet.
            // This temporary array will be replaced by the value received from the server.
            publicisedGroups = publicisedGroupsByUserId[userId] = @[];
        }
        else if (userIdsWithOutdatedPublicisedGroups.count)
        {
            NSUInteger index = [userIdsWithOutdatedPublicisedGroups indexOfObject:userId];
            if (index != NSNotFound)
            {
                shouldRefresh = YES;
                
                // Remove this user id from the pending list
                [userIdsWithOutdatedPublicisedGroups removeObjectAtIndex:index];
            }
        }
        
        if (shouldRefresh)
        {
            MXWeakify(self);
            [self.matrixRestClient getPublicisedGroupsForUsers:@[userId] success:^(NSDictionary<NSString *,NSArray<NSString *> *> *updatedPublicisedGroupsByUserId) {
                MXStrongifyAndReturnIfNil(self);
                
                // Check whether the publicised groups have been actually modified.
                if (updatedPublicisedGroupsByUserId[userId] && ![self->publicisedGroupsByUserId[userId] isEqualToArray:updatedPublicisedGroupsByUserId[userId]])
                {
                    // refresh the internal dict
                    self->publicisedGroupsByUserId[userId] = updatedPublicisedGroupsByUserId[userId];
                    
                    // Notify the publicised groups for these users have been updated.
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionDidUpdatePublicisedGroupsForUsersNotification
                                                                        object:self
                                                                      userInfo:@{
                                                                                 kMXSessionNotificationUserIdsArrayKey: @[userId]
                                                                                 }];
                }
                
                
            } failure:^(NSError *error) {
                MXStrongifyAndReturnIfNil(self);
                
                // We should trigger a new request for this user if his publicised groups are requested again.
                if (!self->userIdsWithOutdatedPublicisedGroups)
                {
                    self->userIdsWithOutdatedPublicisedGroups = [NSMutableArray array];
                }
                [self->userIdsWithOutdatedPublicisedGroups addObject:userId];
                
            }];
        }
    }
    
    return publicisedGroups;
}

@end
