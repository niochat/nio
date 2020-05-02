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

#import <Foundation/Foundation.h>

#import "MXRestClient.h"
#import "MXMediaManager.h"
#import "MXRoom.h"
#import "MXPeekingRoom.h"
#import "MXFilterJSONModel.h"
#import "MXMyUser.h"
#import "MXAccountData.h"
#import "MXSessionEventListener.h"
#import "MXStore.h"
#import "MXNotificationCenter.h"
#import "MXCallManager.h"
#import "MXCrypto.h"
#import "MXGroup.h"
#import "MXError.h"
#import "MXScanManager.h"
#import "MXAggregations.h"
#import "MXIdentityService.h"
#import "MX3PidAddManager.h"

/**
 `MXSessionState` represents the states in the life cycle of a MXSession instance.
 */
typedef enum : NSUInteger
{
    /**
     The session is closed (or not initialized yet).
     */
    MXSessionStateClosed,
    
    /**
     The session has just been created.
     */
    MXSessionStateInitialised,

    /**
     Data from the MXStore has been loaded.
     */
    MXSessionStateStoreDataReady,

    /**
     The session is syncing with the server.
     
     @discussion
     It is either doing a global initialSync or restarting the events stream from the previous
     known position. This position is provided by the store for a cold start or by the `MXSession`
     itself when [MXSession resume:] is called.
     */
    MXSessionStateSyncInProgress,
    
    /**
     The session is catching up in background
     */
    MXSessionStateBackgroundSyncInProgress,
        
    /**
     The session data is synchronised with the server and session keeps it synchronised
     thanks to the events stream, which is now running.
     */
    MXSessionStateRunning,

    /**
     The connection to the homeserver is temporary lost.
     
     @discussion
     The Matrix session will automatically establish it again. Once back, the state will move to
     MXSessionStateRunning.
     */
    MXSessionStateHomeserverNotReachable,

    /**
     The homeserver returned a temporary error when trying to sync.
     Check `MXSession.syncError` to get this error.

     @discussion
     The Matrix session will automatically go back MXSessionStateRunning once possible.
     */
    MXSessionStateSyncError,

    /**
     The session has been paused.
     */
    MXSessionStatePaused,
    
    /**
     The session has been requested to pause but some services requested the session to
     continue to run even if the application is in background (@see retainPreventPause).
     The session will be actually paused when those services declare they have finished
     (@see releasePreventPause).
     */
    MXSessionStatePauseRequested,

    /**
     The initial sync failed.
     
     @discussion
     The Matrix session will stay in this state until a new call of [MXSession start:failure:].
     */
    MXSessionStateInitialSyncFailed,

    /**
     The access token is no more valid.

     @discussion
     This can happen when the user made a forget password request for example.
     The Matrix session is no more usable. The user must log in again.
     */
    MXSessionStateUnknownToken,

    /**
     The user is logged out (invalid token) but they still have their local storage.
     The user should log back in to rehydrate the client.

     @discussion
     This happens when the homeserver admin has signed the user out.
     */
    MXSessionStateSoftLogout

} MXSessionState;


#pragma mark - Notifications
/**
 Posted when the state of the MXSession instance changes.
 */
FOUNDATION_EXPORT NSString *const kMXSessionStateDidChangeNotification;

/**
 Posted when MXSession has detected a new room coming from the event stream.

 The passed userInfo dictionary contains:
     - `kMXSessionNotificationRoomIdKey` the roomId of the room is passed in the userInfo dictionary.
 */
FOUNDATION_EXPORT NSString *const kMXSessionNewRoomNotification;

/**
 Posted when MXSession has detected a room is going to be left.

 The passed userInfo dictionary contains:
     - `kMXSessionNotificationRoomIdKey` the roomId of the room is passed in the userInfo dictionary.
     - `kMXSessionNotificationEventKey` the MXEvent responsible for the leaving.
 */
FOUNDATION_EXPORT NSString *const kMXSessionWillLeaveRoomNotification;

/**
 Posted when MXSession has detected a room has been left.

 The passed userInfo dictionary contains:
     - `kMXSessionNotificationRoomIdKey` the roomId of the room is passed in the userInfo dictionary.
 */
FOUNDATION_EXPORT NSString *const kMXSessionDidLeaveRoomNotification;

/**
 Posted when MXSession has performed a server sync.

 The passed userInfo dictionary contains:
 - `kMXSessionNotificationSyncResponseKey` the server response, a `MXSyncResponse` object.
 - `kMXSessionNotificationErrorKey` the error if any.
 */
FOUNDATION_EXPORT NSString *const kMXSessionDidSyncNotification;

/**
 Posted when MXSession has detected a change in the `invitedRooms` property.
 
 The user has received a room invitation or he has accepted or rejected one.
 Note this notification is sent only when the `invitedRooms` method has been called.

 The passed userInfo dictionary contains:
 - `kMXSessionNotificationRoomIdKey` the roomId of the room concerned by the changed
 - `kMXSessionNotificationEventKey` the MXEvent responsible for the change.
 */
FOUNDATION_EXPORT NSString *const kMXSessionInvitedRoomsDidChangeNotification;

/**
 Posted when MXSession has receive a new to-device event.

 The passed userInfo dictionary contains:
 - `kMXSessionNotificationEventKey` the to-device MXEvent.
 */
FOUNDATION_EXPORT NSString *const kMXSessionOnToDeviceEventNotification;

/**
 Posted when MXSession has detected a change in the `ignoredUsers` property.
 
 The notification object is the concerned session (MXSession instance).
 */
FOUNDATION_EXPORT NSString *const kMXSessionIgnoredUsersDidChangeNotification;

/**
 Posted when the `directRooms` property is updated from homeserver.
 
 The notification object is the concerned session (MXSession instance).
 */
FOUNDATION_EXPORT NSString *const kMXSessionDirectRoomsDidChangeNotification;

/**
 Posted when the matrix account data are updated from homeserver.
 
 The notification object is the concerned session (MXSession instance).
 */
FOUNDATION_EXPORT NSString *const kMXSessionAccountDataDidChangeNotification;

/**
 Posted when the identity server in the user account data has changed.

 The notification object is the concerned session (MXSession instance).
 */
FOUNDATION_EXPORT NSString *const kMXSessionAccountDataDidChangeIdentityServerNotification;

/**
 Posted when MXSession data have been corrupted. The listener must reload the session data with a full server sync.
 
 The notification object is the concerned session (MXSession instance).
 */
FOUNDATION_EXPORT NSString *const kMXSessionDidCorruptDataNotification;

/**
 Posted when crypto data have been corrupted. User's device keys may be no
 more valid. The listener must make the user login out and in in order to be able
 to read and send readable crypted messages.

 The notification object is the id of the concerned user.
 */
FOUNDATION_EXPORT NSString *const kMXSessionCryptoDidCorruptDataNotification;

/**
 Posted when MXSession has detected a new invite to a group from the event stream.
 A request is triggered to refresh the summary of this group before posting this notification.
 Listen to kMXSessionDidUpdateGroupSummaryNotification to be notified in case of summary change.
 
 The passed userInfo dictionary contains:
 - `kMXSessionNotificationGroupKey` the new group instance.
 */
FOUNDATION_EXPORT NSString *const kMXSessionNewGroupInviteNotification;

/**
 Posted when MXSession has detected a new joined group from the event stream.
 A request is triggered to refresh the summary of this group before posting this notification.
 Listen to kMXSessionDidUpdateGroupSummaryNotification to be notified in case of summary change.
 
 The passed userInfo dictionary contains:
 - `kMXSessionNotificationGroupKey` the new joined group.
 */
FOUNDATION_EXPORT NSString *const kMXSessionDidJoinGroupNotification;

/**
 Posted when MXSession has detected a group has been left.
 
 The passed userInfo dictionary contains:
 - `kMXSessionNotificationGroupIdKey` the groupId of the left group.
 */
FOUNDATION_EXPORT NSString *const kMXSessionDidLeaveGroupNotification;

/**
 Posted when MXSession has updated the summary (or only the profile) of a stored group.
 
 The passed userInfo dictionary contains:
 - `kMXSessionNotificationGroupKey` the updated group.
 */
FOUNDATION_EXPORT NSString *const kMXSessionDidUpdateGroupSummaryNotification;

/**
 Posted when MXSession has updated the rooms list of a stored group.
 
 The passed userInfo dictionary contains:
 - `kMXSessionNotificationGroupKey` the updated group.
 */
FOUNDATION_EXPORT NSString *const kMXSessionDidUpdateGroupRoomsNotification;

/**
 Posted when MXSession has updated the members list of a stored group.
 
 The passed userInfo dictionary contains:
 - `kMXSessionNotificationGroupKey` the updated group.
 */
FOUNDATION_EXPORT NSString *const kMXSessionDidUpdateGroupUsersNotification;

/**
 Posted when MXSession has updated the publicised groups of some matrix users.
 
 The passed userInfo dictionary contains:
 - `kMXSessionNotificationUserIdsArrayKey` the list of the user ids who's the publicised groups are updated.
 */
FOUNDATION_EXPORT NSString *const kMXSessionDidUpdatePublicisedGroupsForUsersNotification;

#pragma mark - Notifications keys
/**
 The key in notification userInfo dictionary representating the roomId.
 */
FOUNDATION_EXPORT NSString *const kMXSessionNotificationRoomIdKey;

/**
 The key in notification userInfo dictionary representating the group.
 */
FOUNDATION_EXPORT NSString *const kMXSessionNotificationGroupKey;

/**
 The key in notification userInfo dictionary representating the groupId.
 */
FOUNDATION_EXPORT NSString *const kMXSessionNotificationGroupIdKey;

/**
 The key in notification userInfo dictionary representating the event.
 */
FOUNDATION_EXPORT NSString *const kMXSessionNotificationEventKey;

/**
 The key in notification userInfo dictionary representating the matrix homeserver
 response (MXSyncResponse instance) to /sync.
 */
FOUNDATION_EXPORT NSString *const kMXSessionNotificationSyncResponseKey;

/**
 The key in notification userInfo dictionary representating the error.
 */
FOUNDATION_EXPORT NSString *const kMXSessionNotificationErrorKey;

/**
 The key in notification userInfo dictionary representating a list of user ids.
 */
FOUNDATION_EXPORT NSString *const kMXSessionNotificationUserIdsArrayKey;


#pragma mark - Other constants
/**
 Fake tag used to identify rooms that do not have tags in `roomsWithTag` and `roomsByTags` methods.
 */
FOUNDATION_EXPORT NSString *const kMXSessionNoRoomTag;


#pragma mark - MXSession
/**
 `MXSession` manages data and events from the home server
 It is responsible for:
    - retrieving events from the home server
    - storing them
    - serving them to the app
 
 `MXRoom` maintains an array of messages per room. The term message designates either
  a non-state or a state event that is intended to be displayed in a room chat history.
 */
@interface MXSession : NSObject

/**
 Shortcuts to the credentials this session is using
 */
@property (nonatomic, readonly) MXCredentials *credentials;
@property (nonatomic, readonly) NSString *myUserId;
@property (nonatomic, readonly) NSString *myDeviceId;

/**
 The matrix REST Client used to make Matrix API requests.
 */
@property (nonatomic, readonly) MXRestClient *matrixRestClient;

/**
 The identity service used to handle Matrix identity server requests. Can be nil.
 */
@property (nonatomic, readonly) MXIdentityService *identityService;

/**
 The module that manages add of third party identifiers.
 */
@property (nonatomic, readonly)  MX3PidAddManager *threePidAddManager;

/**
 The media manager used to handle the media stored on the Matrix Content repository.
 */
@property (nonatomic, readonly) MXMediaManager *mediaManager;

/**
 The current state of the session.
 */
@property (nonatomic, readonly) MXSessionState state;

/**
 The current state of the session.
 */
@property (nonatomic, readonly) MXError *syncError;

/**
 The flag indicating whether the initial sync has been done.
 */
@property (nonatomic, readonly) BOOL isEventStreamInitialised;

/**
 The flag indicating that we are trying to establish the event streams (/sync)
 as quick as possible, even if there are no events queued. This is required in
 some situations:
    - When the connection dies, we want to know asap when it comes back (We don't
      want to have to wait for an event or a timeout).
    - We want to know if the server has any to-device messages queued up for us.
 */
@property (nonatomic, readonly) BOOL catchingUp;

/**
 The id of the filter being used in /sync requests.
 */
@property (nonatomic, readonly) NSString *syncFilterId;

/**
 True when the filter used for /sync requests enables lazy loading of room members.
 */
@property (nonatomic, readonly) BOOL syncWithLazyLoadOfRoomMembers;

/**
 The profile of the current user.
 It is available only after the `onStoreDataReady` callback of `start` is called.
 */
@property (nonatomic, readonly) MXMyUser *myUser;

/**
 The user's matrix account data.
 */
@property (nonatomic, readonly) MXAccountData *accountData;

/**
 The store used to store user's Matrix data.
 */
@property (nonatomic, readonly) id<MXStore> store;

/**
 The module that manages push notifications.
 */
@property (nonatomic, readonly) MXNotificationCenter *notificationCenter;

/**
 The module that manages incoming and outgoing calls.
 Nil by default. It is created when [self enableVoIPWithCallStack:] is called
 */
@property (nonatomic, readonly) MXCallManager *callManager;

/**
 The module that manages E2E encryption.
 Nil if the feature is not enabled ('cryptoEnabled' property).
 */
@property (nonatomic, readonly) MXCrypto *crypto;

/**
 Antivirus scanner used to scan medias.
 Nil if `antivirusServerURL` is nil.
 */
@property (nonatomic, readonly) MXScanManager *scanManager;

/**
 The module that manages aggregations (reactions, edition, ...).
 */
@property (nonatomic, readonly) MXAggregations *aggregations;

#pragma mark - Class methods

/**
 Create a MXSession instance.
 This instance will use the passed MXRestClient to make requests to the home server.
 
 @param mxRestClient The MXRestClient to the home server.
 
 @return The newly-initialized MXSession.
 */
- (id)initWithMatrixRestClient:(MXRestClient*)mxRestClient;

/**
 Start fetching events from the home server.
 
 If the attached MXStore does not cache data permanently, the function will begin by making
 an initialSync request to the home server to get information about the rooms the user has
 interactions with.
 Then, it will start the events streaming, a long polling connection to the home server to
 listen to new coming events.
 
 If the attached MXStore caches data permanently, the function will do an initialSync only at
 the first launch. Then, for next app launches, the SDK will load events from the MXStore and
 will resume the events streaming from where it had been stopped the time before.

 @param onServerSyncDone A block object called when the data is up-to-date with the server.
 @param failure A block object called when the operation fails. In case of failure during the
 initial sync the session state is MXSessionStateInitialSyncFailed.
 */
- (void)start:(void (^)(void))onServerSyncDone
      failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Start the session like `[MXSession start]` but with using a filter in /sync requests.

 @param syncFilter the filter to use.
 @param onServerSyncDone A block object called when the data is up-to-date with the server.
 @param failure A block object called when the operation fails.
 */
- (void)startWithSyncFilter:(MXFilterJSONModel*)syncFilter
           onServerSyncDone:(void (^)(void))onServerSyncDone
                    failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Start the session like `[MXSession startWithSyncFilter]` but with a filter id.

 @param syncFilterId the id of the filter to use.
 @param onServerSyncDone A block object called when the data is up-to-date with the server.
 @param failure A block object called when the operation fails.
 */
- (void)startWithSyncFilterId:(NSString*)syncFilterId
             onServerSyncDone:(void (^)(void))onServerSyncDone
                      failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Pause the session events stream.
 This action may be delayed by using `retainPreventPause`.
 
 Caution: this action is ignored if the session state is not MXSessionStateRunning
 or MXSessionStateBackgroundSyncInProgress.
 
 No more live events will be received by the listeners.
 */
- (void)pause;

/**
 Resume the session events stream.
 
 @param resumeDone A block called when the SDK has been successfully resumed and the app
                   has received uptodate data/events. The live event listening
                   (long polling) is not launched yet.
                   CAUTION The session state is updated (to MXSessionStateRunning) after
                   calling this block. It SHOULD not be modified by this block.
 */
- (void)resume:(void (^)(void))resumeDone;

typedef void (^MXOnBackgroundSyncDone)(void);
typedef void (^MXOnBackgroundSyncFail)(NSError *error);

/**
 Perform an events stream catchup in background (by keeping user offline).
 
 @param timeout the max time in milliseconds to perform the catchup
 @param backgroundSyncDone A block called when the SDK has been successfully performed a catchup
 @param backgroundSyncfails A block called when the catchup fails.
 */
- (void)backgroundSync:(unsigned int)timeout
               success:(MXOnBackgroundSyncDone)backgroundSyncDone
               failure:(MXOnBackgroundSyncFail)backgroundSyncfails NS_REFINED_FOR_SWIFT;

/**
 Restart the session events stream.
 @return YES if the operation succeeds
 */
- (BOOL)reconnect;

/**
 Close the session.
 
 All data (rooms, users, ...) is reset.
 No more data is retrieved from the home server.
 */
- (void)close;

/**
 Invalidate the access token, so that it can no longer be used for authorization.
 
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)logout:(void (^)(void))success
                   failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Deactivate the user's account, removing all ability for the user to login again.
 
 @discussion This API endpoint uses the User-Interactive Authentication API.
 
 @note An access token should be submitted to this endpoint if the client has an active session.
 The homeserver may change the flows available depending on whether a valid access token is provided.
 
 @param authParameters The additional authentication information for the user-interactive authentication API.
 @param eraseAccount Indicating whether the account should be erased.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)deactivateAccountWithAuthParameters:(NSDictionary*)authParameters
                                           eraseAccount:(BOOL)eraseAccount
                                                success:(void (^)(void))success
                                                failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;


#pragma mark - MXSession pause prevention
/**
 Add a token to prevent the session events stream from being paused.

 @discussion
 The pause method is basically called when the application goes in background.
 However, the SDK or the application may want to continue so sync Matrix events while
 the app is in background.

 This method prevents the /sync from being paused so that the session continues to receive
 and process Matrix events.

 Note that the events stream continues on a UIBackgroundTask which can be terminated
 by the system at anytime.
 
 @warning This request is ignored if no background mode handler has been set in the
 MXSDKOptions sharedInstance (see `backgroundModeHandler`).
 */
- (void)retainPreventPause;

/**
 Release a prevent pause token.

 @discussion
 When the prevent pause tokens count is back to 0, the session is actually paused if still
 requested.
 */
- (void)releasePreventPause;


#pragma mark - Options
/*
 Define the Matrix storage component to use.

 It must be set before calling [MXSession start].
 Else, by default, the MXSession instance will use MXNoStore as storage.

 @param store the store to use for the session.
 @param onStoreDataReady A block object called when the SDK has loaded the data from the `MXStore`.
 The SDK is then able to serve this data to its client. Note the data may not
 be up-to-date. You need to call [MXSession start] to ensure the sync with
 the home server.
 @param failure A block object called when the operation fails.
 */
- (void)setStore:(id<MXStore>)store success:(void (^)(void))onStoreDataReady
         failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Set a new identity server.

 The method updates underlaying services.

 @param identityServer the new identityServer. Nil for no IS
 @param accessToken the access token of the IS. Can be nil.
 */
- (void)setIdentityServer:(NSString*)identityServer andAccessToken:(NSString*)accessToken;

/**
 An array of event types for which read receipts are sent.
 By default any event type except the typing, the read receipt and the presence ones.
 */
@property (nonatomic) NSArray<MXEventTypeString> *acknowledgableEventTypes;

/**
 The list of event types considered for counting unread messages returned by MXRoom.localUnreadEventCount.
 By default [m.room.name, m.room.topic, m.room.message, m.call.invite, m.room.encrypted, m.sticker].
 */
@property (nonatomic) NSArray<MXEventTypeString> *unreadEventTypes;

/**
 Enable VoIP by setting the external VoIP stack to use.
 
 @param callStack the VoIP call stack to use.
 */
- (void)enableVoIPWithCallStack:(id<MXCallStack>)callStack;

/**
 Enable End-to-End encryption.
 
 In case of enabling, the operation will complete when the session will be ready
 to make encrytion with other users devices

 @param enableCrypto NO stops crypto and erases crypto data.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (void)enableCrypto:(BOOL)enableCrypto success:(void (^)(void))success failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Get the versions of the specification supported by the server.

 @param success A block object called when the operation succeeds. It provides
                the supported spec versions.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)supportedMatrixVersions:(void (^)(MXMatrixVersions *matrixVersions))success failure:(void (^)(NSError *error))failure;

/**
 The antivirus server URL (nil by default).
 Set a non-null url to configure the antivirus scanner use.
 */
@property (nonatomic) NSString *antivirusServerURL;

#pragma mark - Rooms operations
/**
 Create a room.
 
 @param name (optional) the room name.
 @param visibility (optional) the visibility of the room in the current HS's room directory.
 @param roomAlias (optional) the room alias on the home server the room will be created.
 @param topic (optional) the room topic.
 
 @param success A block object called when the operation succeeds. It provides the MXRoom
 instance of the joined room.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)createRoom:(NSString*)name
                    visibility:(MXRoomDirectoryVisibility)visibility
                     roomAlias:(NSString*)roomAlias
                         topic:(NSString*)topic
                       success:(void (^)(MXRoom *room))success
                       failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Create a room.

 @param parameters the parameters.

 @param success A block object called when the operation succeeds. It provides the MXRoom
                instance of the joined room.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)createRoomWithParameters:(MXRoomCreationParameters*)parameters
                                     success:(void (^)(MXRoom *room))success
                                     failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Create a room.

 @param parameters the parameters. Refer to the matrix specification for details.

 @param success A block object called when the operation succeeds. It provides the MXRoom
                instance of the joined room.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)createRoom:(NSDictionary*)parameters
                       success:(void (^)(MXRoom *room))success
                       failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Join a room.
 
 @param roomIdOrAlias the id or an alias of the room to join.
 @param viaServers The server names to try and join through in addition to those
        that are automatically chosen. Can be nil.
 @param success A block object called when the operation succeeds. It provides the MXRoom 
        instance of the joined room.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)joinRoom:(NSString*)roomIdOrAlias
                  viaServers:(NSArray<NSString*>*)viaServers
                     success:(void (^)(MXRoom *room))success
                     failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Join a room where the user has been invited by a 3PID invitation.

 @param roomIdOrAlias the id or an alias of the room to join.
 @param viaServers The server names to try and join through in addition to those
        that are automatically chosen. Can be nil.
 @param signUrl the url provided in the invitation.
 @param success A block object called when the operation succeeds. It provides the MXRoom
        instance of the joined room.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)joinRoom:(NSString*)roomIdOrAlias
                  viaServers:(NSArray<NSString*>*)viaServers
                 withSignUrl:(NSString*)signUrl
                     success:(void (^)(MXRoom *room))success
                     failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Leave a room.
 
 The room will be removed from the rooms list.
 
 @param roomId the id of the room to join.
 @param success A block object called when the operation is complete.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)leaveRoom:(NSString*)roomId
                      success:(void (^)(void))success
                      failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Determine if E2E can be enabled in a new room with a list users.
 
 E2E will be adviced if all users have at least one device that supports
 encryption.
 
 @param userIds the list of users;
 
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)canEnableE2EByDefaultInNewRoomWithUsers:(NSArray<NSString*>*)userIds
                                                    success:(void (^)(BOOL canEnableE2E))success
                                                    failure:(void (^)(NSError *error))failure;


#pragma mark - The user's rooms
/**
 Check if the user is in a room

 @param roomId The room id to the room.

 @return YES if they are.
 */
- (BOOL)hasRoomWithRoomId:(NSString*)roomId;

/**
 Get the MXRoom instance of a room.
 
 @param roomId The room id to the room.

 @return the MXRoom instance.
 */
- (MXRoom *)roomWithRoomId:(NSString*)roomId;

/**
 Get the MXRoom instance of the room that owns the passed room alias.

 @param alias The room alias to look for.

 @return the MXRoom instance.
 */
- (MXRoom *)roomWithAlias:(NSString*)alias;

/**
 Get the list of all rooms data.
 
 @return an array of MXRooms.
 */
- (NSArray<MXRoom*>*)rooms NS_REFINED_FOR_SWIFT;


#pragma mark - The user's direct rooms
/**
 The list of the direct rooms by user identifiers.
 
 A dictionary where the keys are the user IDs and values are lists of room ID strings.
 */
@property (nonatomic, readonly) NSDictionary<NSString*, NSArray<NSString*>*> *directRooms;

/**
 Return the first joined direct chat listed in account data for this user.

 @return the MXRoom instance (nil if no room exists yet).
 */
- (MXRoom *)directJoinedRoomWithUserId:(NSString*)userId;

/**
 Get the direct user id of a room.

 @param roomId the id of the room.
 @return the id of user with whom the room is direct to.
 */
- (NSString *)directUserIdInRoom:(NSString*)roomId;

/**
 Set a room as direct with a user.

 @param roomId the id of the room.
 @param userId the id of user with whom the room will be direct to. Nil removes existing direct user.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)setRoom:(NSString*)roomId
           directWithUserId:(NSString*)userId
                    success:(void (^)(void))success
                    failure:(void (^)(NSError *error))failure;

/**
 Use this method to run or queue any other actions on the direct rooms to avoid race conditions.
 Run only one HTTP request in a block. If there is a pending action, the change will be applied
 on the updated direct rooms data.
 
 @param directRoomOperation A block object (use `[uploadDirectRoomsInOperationsQueue:success:failure:]`
 in this block if you need to upload the direct rooms dictionary).
 */
- (void)runOrQueueDirectRoomOperation:(dispatch_block_t)directRoomOperation;

/**
 Update the direct rooms list on homeserver side.
 This method must be called in a block run by using `[runOrQueueDirectRoomOperation:]`
 
 @param directRooms the new direct rooms list (user id -> [room ids]).
 
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)uploadDirectRoomsInOperationsQueue:(NSDictionary<NSString *,NSArray<NSString *> *> *)directRooms
                                               success:(void (^)(void))success
                                               failure:(void (^)(NSError *))failure;

/**
 Make sure that the `MXRoom` internal data for a list of rooms is preloaded.

 Thus, next async calls to their internal data (like [MXRoom liveTimeline:])
 will behave synchronously.

 @param roomIds ids of rooms to preload data.
 @param onComplete block called once done.
 */
- (void)preloadRoomsData:(NSArray<NSString*> *)roomIds onComplete:(dispatch_block_t)onComplete;


#pragma mark - Matrix Events
/**
 Retrieve an event from its event id.

 @param eventId the id of the event to retrieve.
 @param roomId (optional) the id of the room.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)eventWithEventId:(NSString*)eventId
                              inRoom:(NSString *)roomId
                             success:(void (^)(MXEvent *event))success
                             failure:(void (^)(NSError *error))failure;


#pragma mark - Rooms summaries
/**
 Get the MXRoomSummary instance of a room.

 @param roomId The room id to the room.

 @return the MXRoomSummary instance.
 */
- (MXRoomSummary *)roomSummaryWithRoomId:(NSString*)roomId;

/**
 Get the list of all rooms summaries.

 @return an array of MXRoomSummary.
 */
- (NSArray<MXRoomSummary*>*)roomsSummaries;

/**
 Recompute all room summaries last message.

 This may lead to pagination requests to the homeserver. Updated room summaries will be
 notified by `kMXRoomSummaryDidChangeNotification`.
 */
- (void)resetRoomsSummariesLastMessage;

/**
 Make sure that all room summaries have a last message.
 
 This may lead to pagination requests to the homeserver. Updated room summaries will be 
 notified by `kMXRoomSummaryDidChangeNotification`.
 */
- (void)fixRoomsSummariesLastMessage;

/**
 Delegate for updating room summaries.
 By default, it is the one returned by [MXRoomSummaryUpdater roomSummaryUpdaterForSession:].
 */
@property id<MXRoomSummaryUpdating> roomSummaryUpdateDelegate;

#pragma mark - The user's groups
/**
 Get the MXGroup instance of a user's group.
 
 @param groupId The identifier to the group.
 
 @return the MXGroup instance. Nil if the current user does not belong to this group.
 */
- (MXGroup *)groupWithGroupId:(NSString*)groupId;

/**
 Get the list of all the user's groups.
 
 @return an array of MXGroup.
 */
- (NSArray<MXGroup*>*)groups;

/**
 Accept the invitation to join a group.
 
 @param groupId the group id
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)acceptGroupInvite:(NSString*)groupId
                              success:(void (^)(void))success
                              failure:(void (^)(NSError *error))failure;

/**
 Leave a group.
 
 @param groupId the group id
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)leaveGroup:(NSString*)groupId
                        success:(void (^)(void))success
                        failure:(void (^)(NSError *error))failure;

/**
 Update the group publicity for the current user.
 
 @param group the group.
 @param isPublicised tell whether the user published this community on his profile
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (MXHTTPOperation*)updateGroupPublicity:(MXGroup*)group
                            isPublicised:(BOOL)isPublicised
                                 success:(void (^)(void))success
                                 failure:(void (^)(NSError *error))failure;

/**
 Update the profile of the provided group.
 Apply this update to the corresponding group stored in this session (if any).
 
 @param group the group.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)updateGroupProfile:(MXGroup*)group
                               success:(void (^)(void))success
                               failure:(void (^)(NSError *error))failure;

/**
 Update the summary of the provided group.
 Apply this update to the corresponding group stored in this session (if any).
 
 @param group the group.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)updateGroupSummary:(MXGroup*)group
                               success:(void (^)(void))success
                               failure:(void (^)(NSError *error))failure;

/**
 Update the users of the provided group.
 Apply this update to the corresponding group stored in this session (if any).
 
 @param group the group.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)updateGroupUsers:(MXGroup*)group
                             success:(void (^)(void))success
                             failure:(void (^)(NSError *error))failure;

/**
 Update the invited users of the provided group.
 Apply this update to the corresponding group stored in this session (if any).
 
 @param group the group.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)updateGroupInvitedUsers:(MXGroup*)group
                                    success:(void (^)(void))success
                                    failure:(void (^)(NSError *error))failure;

/**
 Update the rooms of the provided group.
 Apply this update to the corresponding group stored in this session (if any).
 
 @param group the group.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)updateGroupRooms:(MXGroup*)group
                             success:(void (^)(void))success
                             failure:(void (^)(NSError *error))failure;


#pragma mark - Missed notifications

/**
 The total number of the missed notifications in this session.
 */
- (NSUInteger)missedNotificationsCount;

/**
 The current number of the rooms with some missed notifications.
 Note: the invites are not taken into account in the returned count.
 */
- (NSUInteger)missedDiscussionsCount;

/**
 The current number of the rooms with some unread highlighted messages.
 */
- (NSUInteger)missedHighlightDiscussionsCount;

/**
 Mark all messages as read.
 */
- (void)markAllMessagesAsRead;


#pragma mark - Room peeking
/**
 Start peeking a room.

 The operation succeeds only if the history visibility for the room is world_readable.

 @param roomId The room id to the room.
 @param success A block object called when the operation succeeds. It provides the
                MXPeekingRoom instance to be used to get the room data.
 @param failure A block object called when the operation fails.
 */
- (void)peekInRoomWithRoomId:(NSString*)roomId
                     success:(void (^)(MXPeekingRoom *peekingRoom))success
                     failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Stop peeking a room.
 */
- (void)stopPeeking:(MXPeekingRoom*)peekingRoom;

/**
 Check if there is a peeking in progress in a room.

 @param roomId The id of the room.

 @return YES if there is.
 */
- (BOOL)isPeekingInRoomWithRoomId:(NSString*)roomId;

/**
 Get the `MXPeekingRoom` object to a room if any.

 @param roomId The id of the room.

 @return the MXPeekingRoom instance.
 */
- (MXPeekingRoom *)peekingRoomWithRoomId:(NSString*)roomId;


#pragma mark - Matrix users
/**
 Get the MXUser instance of a user.
 
 @param userId The id to the user.
 
 @return the MXUser instance.
 */
- (MXUser*)userWithUserId:(NSString*)userId;

/**
 Get the MXUser instance of a user.
 Create it if does not exist yet.
 
 @param userId The id to the user.
 
 @return the MXUser instance.
 */
- (MXUser*)getOrCreateUser:(NSString*)userId;

/**
 Get the list of all users.
 
 @return an array of MXUsers.
 */
- (NSArray<MXUser*> *)users;

/**
 The list of ignored users.

 @return an array of user ids. nil if the list has not been yet fetched from the homeserver.
 */
@property (nonatomic, readonly) NSArray<NSString*> *ignoredUsers;

/**
 Indicate if a user is in the ignored list
 
 @param userId the id of the user.
 @return YES if the user is ignored.
 */
- (BOOL)isUserIgnored:(NSString*)userId;

/**
 Ignore a list of users.

 @param userIds a list of users ids
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)ignoreUsers:(NSArray<NSString*>*)userIds
                        success:(void (^)(void))success
                        failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Unignore a list of users.

 @param userIds a list of users ids
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)unIgnoreUsers:(NSArray<NSString*>*)userIds
                        success:(void (^)(void))success
                        failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;


#pragma mark - User's special rooms
/**
 Get the list of rooms where the user has a pending invitation.
 
 The `kMXSessionInvitedRoomsDidChangeNotification` will be sent when a change is detected by the SDK.
 
 @return an array where rooms are ordered.
 */
- (NSArray<MXRoom*>*)invitedRooms;


#pragma mark - User's rooms tags
/**
 Get the list of rooms that are tagged the specified tag.
 The returned array is ordered according to the room tag order.
 
 @param tag the tag to look for. Use the fake `kMXSessionNoRoomTag` tag to get rooms with no tags.
 @return an ordered list of room having the tag.
 */
- (NSArray<MXRoom*>*)roomsWithTag:(NSString*)tag;

/**
 Get all tags and the tagged rooms defined by the user.
 
 Note: rooms with no tags are returned under the fake tag. The corresponding returned
 array is not ordered.

 @return a dictionary where the key is the tag name and the value is an array of
         room tagged with this tag. The array order is the same as [MXSession roomsWithTag:]
 */
- (NSDictionary<NSString*, NSArray<MXRoom*>*>*)roomsByTags;

/**
 Comparator used to sort the list of rooms with the same tag name, according to their tag order.
 
 @param tag the tag for which the tag order must be compared for these 2 rooms.
 */
- (NSComparisonResult)compareRoomsByTag:(NSString*)tag room1:(MXRoom*)room1 room2:(MXRoom*)room2;

/**
 Compute the tag order to use for a room tag so that the room will appear in the expected position
 in the list of rooms stamped with this tag.

 @param index the targeted index of the room in the list of rooms with the tag `tag`.
 @param originIndex the origin index. NSNotFound if there is none.
 @param tag the tag.
 @return the tag order to apply to get the expected position.
 */
- (NSString*)tagOrderToBeAtIndex:(NSUInteger)index from:(NSUInteger)originIndex withTag:(NSString *)tag;


#pragma mark - User's account data
/**
 Set some account data for the user.

 @param data the new data to set for this event type.
 @param type The event type of the account_data to set (@see kMXAccountDataType* strings)
             Custom types should be namespaced to avoid clashes.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)setAccountData:(NSDictionary*)data
                           forType:(NSString*)type
                           success:(void (^)(void))success
                           failure:(void (^)(NSError *error))failure;

/**
 Set the identity server in the user's account data.

 `kMXSessionAccountDataDidChangeIdentityServerNotification` will be sent once the
 user's account data is updated with the new value.

 @param identityServer the base url of the identity server (ex: "https://vector.im"). Nil to indicate no IS.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)setAccountDataIdentityServer:(NSString*)identityServer
                                         success:(void (^)(void))success
                                         failure:(void (^)(NSError *error))failure;
/**
 Indicate if user has set an identity server value in their account data.
 This value (returned by accountDataIdentityServer) can be nil if the user does
 not want to use an identity server.

 @return YES if YES.
 */
- (BOOL)hasAccountDataIdentityServerValue;

/**
 The IS set in the user's account data.

 @return the identity server. Nil means either the user have not set yet a IS
         or they do not want to use an IS. Use [self hasAccountDataIdentityServer]
         to differentiate the 2 options.
 */
- (NSString*)accountDataIdentityServer;


#pragma mark - Homeserver information

/**
 The homeserver .well-known data.
 */
@property (nonatomic, readonly) MXWellKnown *homeserverWellknown;

/**
 Refresh self.homeserverWellknown.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)refreshHomeserverWellknown:(void (^)(MXWellKnown *homeserverWellknown))success
                                       failure:(void (^)(NSError *error))failure;


#pragma mark - Matrix filters
/**
 Set a Matrix filter.

 If the filter has been already created, this will return the stored filter id.

 @param filter the Matrix filter.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)setFilter:(MXFilterJSONModel*)filter
                      success:(void (^)(NSString *filterId))success
                      failure:(void (^)(NSError *error))failure;

/**
 Retrieve a Matrix filter either from the store of from the homeserver.

 @param filterId the id of the Matrix filter to retrieve.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)filterWithFilterId:(NSString*)filterId
                               success:(void (^)(MXFilterJSONModel *filter))success
                               failure:(void (^)(NSError *error))failure;


#pragma mark - Crypto
/**
 Decrypt an event and update its data.

 @param event the event to decrypt.
 @param timeline the id of the timeline where the event is decrypted. It is used
        to prevent replay attack.
 @return YES if decryption is successful.
 */
- (BOOL)decryptEvent:(MXEvent*)event inTimeline:(NSString*)timeline;

/**
 Reset replay attack data for the given timeline.

 @param timeline the id of the timeline.
 */
- (void)resetReplayAttackCheckInTimeline:(NSString*)timeline;


#pragma mark - Global events listeners
/**
 Register a global listener to events related to the current session.
 
 The listener will receive all events including all events of all rooms.
 
 @param onEvent the block that will called once a new event has been handled.
 @return a reference to use to unregister the listener
 */
- (id)listenToEvents:(MXOnSessionEvent)onEvent NS_REFINED_FOR_SWIFT;

/**
 Register a global listener for some types of events.
 
 @param types an array of event types strings (MXEventTypeString) to listen to.
 @param onEvent the block that will called once a new event has been handled.
 @return a reference to use to unregister the listener
 */
- (id)listenToEventsOfTypes:(NSArray*)types onEvent:(MXOnSessionEvent)onEvent NS_REFINED_FOR_SWIFT;

/**
 Unregister a listener.
 
 @param listener the reference of the listener to remove.
 */
- (void)removeListener:(id)listener;

/**
 Unregister all listeners.
 */
- (void)removeAllListeners;

#pragma mark - Publicised groups

/**
 Force the matrix session to refresh the cached data related to the publicised groups of the users.
 */
- (void)markOutdatedPublicisedGroupsByUserData;

/**
 Get the current publicised groups for a matrix user.
 If this information is not available or marked as outdated, this method returns the current
 value and triggers a server request to retrieve the actual publicised groups of this user.
 Listen to `kMXSessionDidUpdatePublicisedGroupsForUsersNotification` to be notified in case of update.
 
 There is no new request if there is already one in progress for the provided userId.
 
 @param userId the user identifiers.
 @return the current publicised groups for the provided user.
 */
- (NSArray<NSString *> *)publicisedGroupsForUser:(NSString*)userId;

@end
