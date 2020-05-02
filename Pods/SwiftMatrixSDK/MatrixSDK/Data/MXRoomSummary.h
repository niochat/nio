/*
 Copyright 2017 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
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

#import <Foundation/Foundation.h>

#import "MXJSONModels.h"
#import "MXHTTPOperation.h"
#import "MXRoomMembersCount.h"
#import "MXEnumConstants.h"
#import "MXUsersTrustLevelSummary.h"

@class MXSession, MXRoom, MXRoomState, MXEvent;
@protocol MXStore;


/**
 Posted when a room summary has changed.
 
 Note that MXRoom.summary data is handled after MXRoom.liveTimeline and MXRoom.state.
 That means that MXRoom.summary may not be up-to-date on events forecasted by 
 [MXRoom.liveTimeline listenToEvents] blocks.
 
 You must check for `kMXRoomSummaryDidChangeNotification` to get up-to-date MXRoom.summary.
 
 The notification object is the concerned room summary, nil when the change concerns all the room summaries.
 */
FOUNDATION_EXPORT NSString *const kMXRoomSummaryDidChangeNotification;


/**
 `MXRoomSummary` exposes and caches data for a room.

 Data is updated on every incoming events in the room through the
 roomSummaryUpdateDelegate object of the MXSession instance.

 By default MXSession uses a default implementation of MXRoomSummaryUpdating, MXRoomSummaryUpdater.
 But the application is free to provide its own so that, for example, in the case
 where the room has no displayname, the app can format the display name with a
 different manner.

 At any time, the application can also change the value as long as it is done on the
 main thread.
 
 `MXRoomSummary` contains several kinds of data:

     * Room state data:
       This is data provided by room state events but it is cached to avoid to 
       recompute everything everytime from the state events.
       Ex: the displayname of the room.

     * Last message data:
       This is lastMessageEventId plus the string or/and attributed string computed for
       this last message event.

     * Business logic data:
       This is data that is used internally by the sdk.
 
     * Other data:
       Other information shared between the sdk and sdk user.
 */
@interface MXRoomSummary : NSObject <NSCoding>

/**
 The Matrix id of the room.
 */
@property (nonatomic, readonly) NSString *roomId;

/**
 The related matrix session.
 */
@property (nonatomic, readonly) MXSession *mxSession;

/**
 Shortcut to the corresponding room.
 */
@property (nonatomic, readonly) MXRoom *room;

/**
 Create a `MXRoomSummary` instance.

 @param roomId the id of the room.
 @param mxSession the session to use.
 @return the new instance.
 */
- (instancetype)initWithRoomId:(NSString*)roomId andMatrixSession:(MXSession*)mxSession;

/**
 Create a `MXRoomSummary` instance by specifying the store to use.

 @param roomId the id of the room.
 @param mxSession the session to use.
 @param store the store to use to store data.
 @return the new instance.
 */
- (instancetype)initWithRoomId:(NSString *)roomId matrixSession:(MXSession *)mxSession andStore:(id<MXStore>)store;

/**
 Dispose any resources and listener.
 */
- (void)destroy;

/**
 Set the Matrix session.

 Must be used for MXRoomSummary instance loaded from the store.

 @param mxSession the session to use.
 */
- (void)setMatrixSession:(MXSession*)mxSession;

/**
 Save room summary data.
 
 This method must be called when data is modified outside the `MXRoomSummaryUpdating` callbacks.
 It will generate a `kMXRoomSummaryDidChangeNotification`.
 
 @param commit YES to force flush it to the store. Use NO when a more
                global [MXStore commit] will happen. This optimises IO.
 */
- (void)save:(BOOL)commit;

#pragma mark - Data related to room state

/**
 The Matrix content URI of the room avatar.
 */
@property (nonatomic) NSString *avatar;

/**
 The computed display name of the room.
 */
@property (nonatomic) NSString *displayname;

/**
 The topic of the room.
 */
@property (nonatomic) NSString *topic;

/**
 The aliases of this room.
 */
@property (nonatomic) NSArray<NSString *> *aliases;

/**
 The membership state of the logged in user for this room.
 */
@property (nonatomic) MXMembership membership NS_REFINED_FOR_SWIFT;

/**
 Room members counts.
 */
@property (nonatomic) MXRoomMembersCount *membersCount;

/**
 Flag indicating if the room is a 1:1 room with a call conference user.
 In this case, the room is used as a call signaling room and does not need to be
 displayed to the end user.
 */
@property (nonatomic) BOOL isConferenceUserRoom;

/**
 Indicate whether this room should be hidden from the user.
 */
@property (nonatomic) BOOL hiddenFromUser;

/**
 Reset data related to room state.
 
 It recomputes every data related to the room state from the current room state.
 */
- (void)resetRoomStateData;


#pragma mark - Data related to the last message

/**
 The last message event id.
 */
@property (nonatomic, readonly) NSString *lastMessageEventId;

/**
 The last message server timestamp.
 */
@property (nonatomic, readonly) uint64_t lastMessageOriginServerTs;

/**
 Indicates if the last message is encrypted.
 
 @discussion
 An unencrypted message can be sent to an encrypted room.
 When the last message is encrypted, its summary data (lastMessageString, lastMessageAttributedString,
 lastMessageOthers) is stored encrypted in the room summary cache.
 */
@property (nonatomic, readonly) BOOL isLastMessageEncrypted;

/**
 String representation of this last message.
 */
@property (nonatomic) NSString *lastMessageString;
@property (nonatomic) NSAttributedString *lastMessageAttributedString;

/**
 Placeholder to store more information about the last message.
 */
@property (nonatomic) NSMutableDictionary<NSString*, id<NSCoding>> *lastMessageOthers;

/**
 The shortcut to the last message event.
 */
@property (nonatomic) MXEvent *lastMessageEvent;

/**
 Reset the last message.
 
 The operation is asynchronous as it may require pagination from the homeserver.
 
 @param complete A block object called when the operation completes.
 @param failure A block object called when the operation fails.
 @param commit  Tell whether the updated room summary must be committed to the store. Use NO when a more
 global [MXStore commit] will happen. This optimises IO.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)resetLastMessage:(void (^)(void))complete failure:(void (^)(NSError *))failure commit:(BOOL)commit;


#pragma mark - Data related to business logic
// @TODO(summary): paginationToken, hasReachedHomeServerPaginationEnd, etc


#pragma mark - Other data

/**
 Indicate whether encryption is enabled for this room.
 */
@property (nonatomic) BOOL isEncrypted;

/**
 If the room is E2E encrypted, indicate global trust in other users and devices in the room.
 Nil if not yet computed or if cross-signing is not set up on the account or not trusted by this device.
 */
@property (nonatomic) MXUsersTrustLevelSummary *trust;

/**
 The number of unread events wrote in the store which have their type listed in the MXSession.unreadEventType.

 @discussion: The returned count is relative to the local storage. The actual unread messages
 for a room may be higher than the returned value.
 */
@property (nonatomic, readonly) NSUInteger localUnreadEventCount;

/**
 The number of unread messages that match the push notification rules.
 It is based on the notificationCount field in /sync response.
 */
@property (nonatomic, readonly) NSUInteger notificationCount;

/**
 The number of highlighted unread messages (subset of notifications).
 It is based on the notificationCount field in /sync response.
 */
@property (nonatomic, readonly) NSUInteger highlightCount;

/**
 Indicate if the room is tagged as a direct chat.
 */
@property (nonatomic, readonly) BOOL isDirect;

/**
 The user identifier for whom this room is tagged as direct (if any).
 nil if the room is not a direct chat.
 */
@property (nonatomic) NSString *directUserId;

/**
 Placeholder to store more information in the room summary.
 */
@property (nonatomic) NSMutableDictionary<NSString*, id<NSCoding>> *others;

/**
 Mark all messages as read.
 */
- (void)markAllAsRead;

#pragma mark - Server sync

/**
 Process state events in order to update the room state.
 
 @param stateEvents an array of state events.
 */
- (void)handleStateEvents:(NSArray<MXEvent *> *)stateEvents;

/**
 Update room summary data according to the provided sync response.

 Note: state events have been previously sent to `handleStateEvents`.

 @param roomSync information to sync the room with the home server data.
 */
- (void)handleJoinedRoomSync:(MXRoomSync*)roomSync;

/**
 Update the invited room state according to the provided data.

 Note: state events have been previously sent to `handleStateEvents`.

 @param invitedRoomSync information to update the room state.
 */
- (void)handleInvitedRoomSync:(MXInvitedRoomSync*)invitedRoomSync;


#pragma mark - Single update

/**
 Update room summary with this event.

 @param event an candidate for the last message.
 */
- (void)handleEvent:(MXEvent*)event;

@end


/**
 The `MXRoomSummaryUpdating` allows delegation of the update of room summaries.
 */
@protocol MXRoomSummaryUpdating <NSObject>

/**
 Called to update the last message of the room summary.

 @param session the session the room belongs to.
 @param summary the room summary.
 @param event the candidate event for the room last message event.
 @param eventState the room state when the event occured.
 @param roomState the current state of the room.
 @return YES if the delegate accepted the event as last message.
         Returning NO can lead to a new call of this method with another candidate event.
 */
- (BOOL)session:(MXSession*)session updateRoomSummary:(MXRoomSummary*)summary withLastEvent:(MXEvent*)event eventState:(MXRoomState*)eventState roomState:(MXRoomState*)roomState;

/**
 Called to update the room summary on received state events.

 @param session the session the room belongs to.
 @param summary the room summary.
 @param stateEvents state events that may change the room summary.
 @param roomState the current state of the room.
 @return YES if the room summary has changed.
 */
- (BOOL)session:(MXSession*)session updateRoomSummary:(MXRoomSummary*)summary withStateEvents:(NSArray<MXEvent*>*)stateEvents roomState:(MXRoomState*)roomState;

/**
 Called to update the room summary on received summary update.

 @param session the session the room belongs to.
 @param summary the room summary.
 @param serverRoomSummary the homeserver side room summary.
 @param roomState the current state of the room.
 @return YES if the room summary has changed.
 */
- (BOOL)session:(MXSession*)session updateRoomSummary:(MXRoomSummary*)summary withServerRoomSummary:(MXRoomSyncSummary*)serverRoomSummary roomState:(MXRoomState*)roomState;

@end
