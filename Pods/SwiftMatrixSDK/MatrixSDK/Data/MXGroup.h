/*
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

#import "MXJSONModels.h"
#import "MXEnumConstants.h"

@class MXSession;

/**
 `MXGroup` represents a community in Matrix.
 */
@interface MXGroup : NSObject <NSCoding, NSCopying>

/**
 The group id.
 */
@property (nonatomic, readonly) NSString *groupId;

/**
 The community summary.
 */
@property (nonatomic) MXGroupSummary *summary;

/**
 The community profile.
 */
@property (nonatomic, readonly) MXGroupProfile *profile;

/**
 The rooms of the community.
 */
@property (nonatomic) MXGroupRooms *rooms;

/**
 The community members.
 */
@property (nonatomic) MXGroupUsers *users;

/**
 The invited members.
 */
@property (nonatomic) MXGroupUsers *invitedUsers;

/**
 The user membership.
 */
@property (nonatomic) MXMembership membership;

/**
 The identifier of the potential inviter (tells wether an invite is pending for this group).
 */
@property (nonatomic) NSString *inviter;

/**
 Create an instance with a group id.
 
 @param groupId the identifier.
 
 @return the MXGroup instance.
 */
- (instancetype)initWithGroupId:(NSString*)groupId;

/**
 Update the group profile.
 
 @param profile the group profile.
 @return YES if the group profile has actually changed.
 */
- (BOOL)updateProfile:(MXGroupProfile*)profile;

/**
 Update the group summary.
 
 @param summary the group summary.
 @return YES if the group summary has actually changed.
 */
- (BOOL)updateSummary:(MXGroupSummary*)summary;

/**
 Update the group rooms.
 
 @param rooms the group rooms.
 @return YES if the group rooms has actually changed.
 */
- (BOOL)updateRooms:(MXGroupRooms*)rooms;

/**
 Update the group users.
 
 @param users the group users.
 @return YES if the group users has actually changed.
 */
- (BOOL)updateUsers:(MXGroupUsers*)users;

/**
 Update the group invited users.
 
 @param invitedUsers the group users.
 @return YES if the group users has actually changed.
 */
- (BOOL)updateInvitedUsers:(MXGroupUsers*)invitedUsers;

@end
