/*
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

#import "MXEvent.h"
#import "MXRoomMember.h"

@class MXRoomState, MXSession;

/**
 `MXRoomMembers` holds room members of a given room.

 Room members are part of room state events but, for performance reason (they can
 be very very numerous), they are store aside other room state events.
 */
@interface MXRoomMembers : NSObject <NSCopying>

/**
 Create a `MXRoomMembers` instance.

 @paran state the room state it depends on.
 @param matrixSession the session to the home server.

 @return The newly-initialized MXRoomMembers.
 */
- (instancetype)initWithRoomState:(MXRoomState*)state andMatrixSession:(MXSession*)matrixSession;

/**
 A copy of the list of room members.
 */
@property (nonatomic, readonly) NSArray<MXRoomMember*> *members;

/**
 A copy of the list of joined room members.
 */
@property (nonatomic, readonly) NSArray<MXRoomMember*> *joinedMembers;

/**
 A copy of the list of members we should be encrypting for in this room.
 
 @param historyVisibility the current history visibility of the room.
 @return the list of members we should be encrypting for.
 */
- (NSArray<MXRoomMember *> *)encryptionTargetMembers:(MXRoomHistoryVisibility)historyVisibility;

/**
 Return the member with the given user id.

 @param userId the id of the member to retrieve.
 @return the room member.
 */
- (MXRoomMember*)memberWithUserId:(NSString*)userId;

/**
 Return a display name for a member.
 It is his displayname member or, if nil, his userId.
 Disambiguate members who have the same displayname in the room by adding his userId.
 */
- (NSString*)memberName:(NSString*)userId;

/**
 Return a display name for a member suitable to compare and sort members list
 */
- (NSString*)memberSortedName:(NSString*)userId;

/**
 Return the list of members with a given membership.

 @param membership the membership to look for.
 @return an array of MXRoomMember objects.
 */
- (NSArray<MXRoomMember*>*)membersWithMembership:(MXMembership)membership;

/**
 A copy of the list of room members excluding the conference user.
 */
- (NSArray<MXRoomMember*>*)membersWithoutConferenceUser;

/**
 Return the list of members with a given membership with or without the conference user.

 @param membership the membership to look for.
 @param includeConferenceUser NO to filter the conference user.
 @return an array of MXRoomMember objects.
 */
- (NSArray<MXRoomMember*>*)membersWithMembership:(MXMembership)membership includeConferenceUser:(BOOL)includeConferenceUser;


#pragma mark - State events handling

/**
 Process state events in order to update room members.

 @param stateEvents an array of state events.
 @return YES if there was a change in MXRoomMembers.
 */
- (BOOL)handleStateEvents:(NSArray<MXEvent *> *)stateEvents;

@end
