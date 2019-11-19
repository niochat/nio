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

#import <Foundation/Foundation.h>

#import "MXEvent.h"
#import "MXJSONModels.h"
#import "MXRoomMembers.h"
#import "MXRoomThirdPartyInvite.h"
#import "MXRoomPowerLevels.h"
#import "MXEnumConstants.h"
#import "MXRoomMembersCount.h"
#import "MXStore.h"
#import "MXRoomTombStoneContent.h"
#import "MXRoomCreateContent.h"

@class MXSession;

/**
 `MXRoomState` holds the state of a room at a given instant.
 
 The room state is a combination of information obtained from state events received so far.
 
 If the current membership state is `invite`, the room state will contain only few information.
 Join the room with [MXRoom join] to get full information about the room.
 */
@interface MXRoomState : NSObject <NSCopying>

/**
 The room id.
 */
@property (nonatomic, readonly) NSString *roomId;

/**
 Indicate if this instance is used to store the live state of the room or
 the state of the room in the history.
 */
@property (nonatomic) BOOL isLive;

/**
 A copy of the list of state events (actually MXEvent instances).
 */
@property (nonatomic, readonly) NSArray<MXEvent *> *stateEvents;

/**
 Room members of the room.

 In case of lazy-loading of room members (@see MXSession.syncWithLazyLoadOfRoomMembers),
 `MXRoomState.members` contains only a subset of all actual room members. This subset
 is enough to render the events timeline owning the `MXRoomState` instance.

 Use [MXRoom members:] to get the full list of room members.
 */
@property (nonatomic, readonly) MXRoomMembers *members;

/**
 Cache counts for MXRoomState.members`.
 */
@property (nonatomic, readonly) MXRoomMembersCount *membersCount;

/**
A copy of the list of third party invites (actually MXRoomThirdPartyInvite instances).
*/
@property (nonatomic, readonly) NSArray<MXRoomThirdPartyInvite*> *thirdPartyInvites;

/**
 The list of the groups associated to the room.
 */
@property (nonatomic, readonly) NSArray<NSString *> *relatedGroups;

/**
 The power level of room members
 */
@property (nonatomic, readonly) MXRoomPowerLevels *powerLevels;

/**
 The aliases of this room.
 */
@property (nonatomic, readonly) NSArray<NSString *> *aliases;

/**
 Informs which alias is the canonical one.
 */
@property (nonatomic, readonly) NSString *canonicalAlias;

/**
 The name of the room as provided by the home server.

Use MXRoomSummary.displayname to get a computed room display name.
 */
@property (nonatomic, readonly) NSString *name;

/**
 The topic of the room.
 */
@property (nonatomic, readonly) NSString *topic;

/**
 The avatar url of the room.
 */
@property (nonatomic, readonly) NSString *avatar;

/**
 The history visibility of the room.
 */
@property (nonatomic, readonly) MXRoomHistoryVisibility historyVisibility NS_REFINED_FOR_SWIFT;

/**
 The join rule of the room.
 */
@property (nonatomic, readonly) MXRoomJoinRule joinRule NS_REFINED_FOR_SWIFT;

/**
 Shortcut to check if the self.joinRule is public.
 */
@property (nonatomic, readonly) BOOL isJoinRulePublic;

/**
 The guest access of the room.
 */
@property (nonatomic, readonly) MXRoomGuestAccess guestAccess NS_REFINED_FOR_SWIFT;

/**
 The membership state of the logged in user for this room
 
 If the membership is `invite`, the room state contains few information.
 Join the room with [MXRoom join] to get full information about the room.
 */
@property (nonatomic, readonly) MXMembership membership NS_REFINED_FOR_SWIFT;

/**
 Room pinned events.
 */
@property (nonatomic, readonly) NSArray<NSString*> *pinnedEvents;

/**
 Indicate whether encryption is enabled for this room.
 */
@property (nonatomic, readonly) BOOL isEncrypted;

/**
 If any the encryption algorithm used in this room.
 */
@property (nonatomic, readonly) NSString *encryptionAlgorithm;

/**
 Indicate whether this room is obsolete (had a `m.room.tombstone` state event type).
 */
@property (nonatomic, readonly) BOOL isObsolete;

/**
 If any the state event content for event type `m.room.tombstone`
 */
@property (nonatomic, strong, readonly) MXRoomTombStoneContent *tombStoneContent;

/**
 Create a `MXRoomState` instance.
 
 @param roomId the room id to the room.
 @param matrixSession the session to the home server. It is used to get information about the user
 currently connected to the home server.
 @paran isLive the direction in which this `MXRoomState` instance will be updated.
 
 @return The newly-initialized MXRoomState.
 */
- (id)initWithRoomId:(NSString*)roomId
    andMatrixSession:(MXSession*)matrixSession
        andDirection:(BOOL)isLive;

/**
 Create a `MXRoomState` instance during initial server sync based on C-S API v1.
 
 @param roomId the room id to the room.
 @param matrixSession the mxSession to the home server. It is used to get information about the user
                  currently connected to the home server.
 @param initialSync the description obtained at the initialSync of the room. It is used to store 
                  additional metadata coming outside state events.
 @paran isLive the direction in which this `MXRoomState` instance will be updated.
 
 @return The newly-initialized MXRoomState.
 */
- (id)initWithRoomId:(NSString*)roomId
    andMatrixSession:(MXSession*)matrixSession
      andInitialSync:(MXRoomInitialSync*)initialSync
        andDirection:(BOOL)isLive;

/**
 Load a `MXRoomState` instance from the store.

 @param store the store to mount data from and to store live data to.
 @param roomId the id of the room.
 @param matrixSession the session to use.
 @param onComplete the block providing the new instance.
 */
+ (void)loadRoomStateFromStore:(id<MXStore>)store
                  withRoomId:(NSString *)roomId
               matrixSession:(MXSession *)matrixSession
                  onComplete:(void (^)(MXRoomState *roomState))onComplete;

/**
 Create a `MXRoomState` instance used as a back state of a room.
 Such instance holds the state of a room at a given time in the room history.
 
 @param state the uptodate state of the room (MXRoom.state)
 @return The newly-initialized MXRoomState.
 */
- (id)initBackStateWith:(MXRoomState*)state;

/**
 Process state events in order to update the room state.
 
 @param stateEvents an array of state events.
 */
- (void)handleStateEvents:(NSArray<MXEvent *> *)stateEvents;

/**
 Return the state events with the given type.
 
 @param eventType the type of event.
 @return the state events. Can be nil.
 */
- (NSArray<MXEvent*> *)stateEventsWithType:(MXEventTypeString)eventType NS_REFINED_FOR_SWIFT;

/**
 According to the direction of the instance, we are interested either by
 the content of the event or its prev_content.

 @param event the event to get the content from.

 @return content or prev_content dictionary.
 */
- (NSDictionary<NSString *, id> *)contentOfEvent:(MXEvent*)event;

/**
 Return the member who was invited by a 3pid medium with the given token.
 
 When invited by a 3pid medium like email, the not-yet-registered-to-matrix user is indicated
 in the room state by a m.room.third_party_invite event.
 Once he registers, the homeserver adds a m.room.membership event to the room state.
 This event then contains the token of the previous m.room.third_party_invite event.

 @param thirdPartyInviteToken the m.room.third_party_invite token to look for.
 @return the room member.
 */
- (MXRoomMember*)memberWithThirdPartyInviteToken:(NSString*)thirdPartyInviteToken;

/**
 Return 3pid invite with the given token.

 @param thirdPartyInviteToken the m.room.third_party_invite token to look for.
 @return the 3pid invite.
 */
- (MXRoomThirdPartyInvite*)thirdPartyInviteWithToken:(NSString*)thirdPartyInviteToken;

/**
 Normalize (between 0 and 1) the power level of a member compared to other members.
 
 @param userId the id of the member to consider.
 @return power level in [0, 1] interval.
 */
- (float)memberNormalizedPowerLevel:(NSString*)userId;


# pragma mark - Conference call
/**
 Flag indicating there is conference call ongoing in the room.
 */
@property (nonatomic, readonly) BOOL isOngoingConferenceCall;

/**
 Flag indicating if the room is a 1:1 room with a call conference user.
 In this case, the room is used as a call signaling room and does not need to be
 */
@property (nonatomic, readonly) BOOL isConferenceUserRoom;

/**
 The id of the conference user responsible for handling the conference call in this room.
 */
@property (nonatomic, readonly) NSString *conferenceUserId;

@end
