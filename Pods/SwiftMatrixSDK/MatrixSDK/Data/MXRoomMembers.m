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

#import "MXRoomMembers.h"

#import "MXRoomState.h"
#import "MXSession.h"
#import "MXSDKOptions.h"

@interface MXRoomMembers ()
{
    MXSession *mxSession;
    MXRoomState *state;

    /**
     Members ordered by userId.
     */
    NSMutableDictionary<NSString*, MXRoomMember*> *members;

    /**
     Track the usage of members displaynames in order to disambiguate them if necessary,
     ie if the same displayname is used by several users, we have to update their displaynames.
     displayname -> count (= how many members of the room uses this displayname)
     */
    NSMutableDictionary<NSString*, NSNumber*> *membersNamesInUse;
}
@end

@implementation MXRoomMembers

- (instancetype)initWithRoomState:(MXRoomState *)roomState andMatrixSession:(MXSession*)matrixSession
{
    self = [super init];
    if (self)
    {
        mxSession = matrixSession;
        state = roomState;

        members = [NSMutableDictionary dictionary];
        membersNamesInUse = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSArray<MXRoomMember *> *)members
{
    return [members allValues];
}

- (NSArray<MXRoomMember *> *)joinedMembers
{
    return [self membersWithMembership:MXMembershipJoin];
}

- (NSArray<MXRoomMember *> *)encryptionTargetMembers:(MXRoomHistoryVisibility)historyVisibility
{
    // Retrieve first the joined members
    NSMutableArray *encryptionTargetMembers = [NSMutableArray arrayWithArray:[self membersWithMembership:MXMembershipJoin]];
    // Check whether we should encrypt for the invited members too
    if (![historyVisibility isEqualToString:kMXRoomHistoryVisibilityJoined])
    {
        [encryptionTargetMembers addObjectsFromArray:[self membersWithMembership:MXMembershipInvite]];
    }
    return encryptionTargetMembers;
}

#pragma mark - Memberships
- (MXRoomMember*)memberWithUserId:(NSString *)userId
{
    return members[userId];
}

- (NSString*)memberName:(NSString*)userId
{
    // Sanity check (ignore the request if the room state is not initialized yet)
    if (!userId.length || !membersNamesInUse)
    {
        return nil;
    }

    NSString *displayName;

    // Get the user display name from the member list of the room
    MXRoomMember *member = [self memberWithUserId:userId];
    if (member && member.displayname.length)
    {
        displayName = member.displayname;
    }

    if (displayName)
    {
        // Do we need to disambiguate it?
        NSNumber *memberNameCount = membersNamesInUse[displayName];
        if (memberNameCount && [memberNameCount unsignedIntegerValue] > 1)
        {
            // There are more than one member that uses the same displayname, so, yes, disambiguate it
            displayName = [NSString stringWithFormat:@"%@ (%@)", displayName, userId];
        }
    }
    else
    {
        // By default, use the user ID
        displayName = userId;
    }

    return displayName;
}

- (NSString*)memberSortedName:(NSString*)userId
{
    // Get the user display name from the member list of the room
    MXRoomMember *member = [self memberWithUserId:userId];
    NSString *displayName = member.displayname;

    // Do not disambiguate here members who have the same displayname in the room (see memberName:).

    if (!displayName)
    {
        // By default, use the user ID
        displayName = userId;
    }

    return displayName;
}

- (NSArray<MXRoomMember*>*)membersWithMembership:(MXMembership)theMembership
{
    NSMutableArray *membersWithMembership = [NSMutableArray array];
    for (MXRoomMember *roomMember in members.allValues)
    {
        if (roomMember.membership == theMembership)
        {
            [membersWithMembership addObject:roomMember];
        }
    }
    return membersWithMembership;
}

- (NSArray<MXRoomMember *> *)membersWithoutConferenceUser
{
    NSArray<MXRoomMember *> *membersWithoutConferenceUser;

    if (state.isConferenceUserRoom)
    {
        // Show everyone in a 1:1 room with a conference user
        membersWithoutConferenceUser = self.members;
    }
    else if (![self memberWithUserId:state.conferenceUserId])
    {
        // There is no conference user. No need to filter
        membersWithoutConferenceUser = self.members;
    }
    else
    {
        // Filter the conference user from the list
        NSMutableDictionary<NSString*, MXRoomMember*> *membersWithoutConferenceUserDict = [NSMutableDictionary dictionaryWithDictionary:members];
        [membersWithoutConferenceUserDict removeObjectForKey:state.conferenceUserId];
        membersWithoutConferenceUser = membersWithoutConferenceUserDict.allValues;
    }

    return membersWithoutConferenceUser;
}

- (NSArray<MXRoomMember *> *)membersWithMembership:(MXMembership)theMembership includeConferenceUser:(BOOL)includeConferenceUser
{
    NSArray<MXRoomMember *> *membersWithMembership;

    if (includeConferenceUser || state.isConferenceUserRoom)
    {
        // Show everyone in a 1:1 room with a conference user
        membersWithMembership = [self membersWithMembership:theMembership];
    }
    else
    {
        MXRoomMember *conferenceUserMember = [self memberWithUserId:state.conferenceUserId];
        if (!conferenceUserMember || conferenceUserMember.membership != theMembership)
        {
            // The conference user is not in list of members with the passed  membership
            membersWithMembership = [self membersWithMembership:theMembership];
        }
        else
        {
            NSMutableDictionary *membersWithMembershipDict = [NSMutableDictionary dictionaryWithCapacity:members.count];
            for (MXRoomMember *roomMember in members.allValues)
            {
                if (roomMember.membership == theMembership)
                {
                    membersWithMembershipDict[roomMember.userId] = roomMember;
                }
            }

            [membersWithMembershipDict removeObjectForKey:state.conferenceUserId];
            membersWithMembership = membersWithMembershipDict.allValues;
        }
    }

    return membersWithMembership;
}

#pragma mark - State events handling
- (BOOL)handleStateEvents:(NSArray<MXEvent *> *)stateEvents;
{
    BOOL hasRoomMemberEvent = NO;

    @autoreleasepool
    {
        for (MXEvent *event in stateEvents)
        {
            switch (event.eventType)
            {
                case MXEventTypeRoomMember:
                {
                    hasRoomMemberEvent = YES;

                    // Remove the previous MXRoomMember of this user from membersNamesInUse
                    NSString *userId = event.stateKey;
                    MXRoomMember *oldRoomMember = members[userId];
                    if (oldRoomMember && oldRoomMember.displayname)
                    {
                        NSNumber *memberNameCount = membersNamesInUse[oldRoomMember.displayname];
                        if (memberNameCount)
                        {
                            NSUInteger count = [memberNameCount unsignedIntegerValue];
                            if (count)
                            {
                                count--;
                            }

                            if (count)
                            {
                                membersNamesInUse[oldRoomMember.displayname] = @(count);
                            }
                            else
                            {
                                [membersNamesInUse removeObjectForKey:oldRoomMember.displayname];
                            }
                        }
                    }

                    MXRoomMember *roomMember = [[MXRoomMember alloc] initWithMXEvent:event andEventContent:[state contentOfEvent:event]];
                    if (roomMember)
                    {
                        /// Update membersNamesInUse
                        if (roomMember.displayname)
                        {
                            NSUInteger count = 1;

                            NSNumber *memberNameCount = membersNamesInUse[roomMember.displayname];
                            if (memberNameCount)
                            {
                                // We have several users using the same displayname
                                count = [memberNameCount unsignedIntegerValue];
                                count++;
                            }

                            membersNamesInUse[roomMember.displayname] = @(count);
                        }

                        members[roomMember.userId] = roomMember;

                        // Handle here the case where the member has no defined avatar.
                        if (nil == roomMember.avatarUrl && ![MXSDKOptions sharedInstance].disableIdenticonUseForUserAvatar)
                        {
                            // Force to use an identicon url
                            roomMember.avatarUrl = [mxSession.mediaManager urlOfIdenticon:roomMember.userId];
                        }
                    }
                    else
                    {
                        // The user is no more part of the room. Remove him.
                        // This case happens during back pagination: we remove here users when they are not in the room yet.
                        [members removeObjectForKey:event.stateKey];
                    }

                    // Special handling for presence: update MXUser data in case of membership event.
                    // CAUTION: ignore here redacted state event, the redaction concerns only the context of the event room.
                    if (state.isLive && !event.isRedactedEvent && roomMember.membership == MXMembershipJoin)
                    {
                        MXUser *user = [mxSession getOrCreateUser:event.sender];
                        [user updateWithRoomMemberEvent:event roomMember:roomMember inMatrixSession:mxSession];

                        [mxSession.store storeUser:user];
                    }

                    break;
                }

                default:
                    break;
            }
        }
    }
    
    return hasRoomMemberEvent;
}

#pragma mark - NSCopying
- (id)copyWithZone:(NSZone *)zone
{
    MXRoomMembers *membersCopy = [[MXRoomMembers allocWithZone:zone] init];

    membersCopy->mxSession = mxSession;
    membersCopy->state = state;

    // MXRoomMember objects in members are immutable. A new instance of it is created each time
    // the sdk receives room member event, even if it is an update of an existing member like a
    // membership change (ex: "invited" -> "joined")
    membersCopy->members = [members mutableCopyWithZone:zone];

    membersCopy->membersNamesInUse = [membersNamesInUse mutableCopyWithZone:zone];

    return membersCopy;
}
@end
