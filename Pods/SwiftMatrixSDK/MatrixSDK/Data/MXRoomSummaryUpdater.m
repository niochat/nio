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

#import "MXRoomSummaryUpdater.h"

#import "MXSession.h"
#import "MXRoom.h"
#import "MXSession.h"
#import "MXRoomNameDefaultStringLocalizations.h"

@implementation MXRoomSummaryUpdater

+ (instancetype)roomSummaryUpdaterForSession:(MXSession *)mxSession
{
    static NSMapTable<MXSession*, MXRoomSummaryUpdater*> *updaterPerSession;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        updaterPerSession = [[NSMapTable alloc] init];
    });

    MXRoomSummaryUpdater *updater = [updaterPerSession objectForKey:mxSession];
    if (!updater)
    {
        updater = [[MXRoomSummaryUpdater alloc] init];
        [updaterPerSession setObject:updater forKey:mxSession];
    }

    return updater;
}


#pragma mark - MXRoomSummaryUpdating

- (BOOL)session:(MXSession *)session updateRoomSummary:(MXRoomSummary *)summary withLastEvent:(MXEvent *)event eventState:(MXRoomState *)eventState roomState:(MXRoomState *)roomState
{
    // Do not show redaction events
    if (event.eventType == MXEventTypeRoomRedaction)
    {
        if ([event.redacts isEqualToString:summary.lastMessageEventId])
        {
            [summary resetLastMessage:nil failure:^(NSError *error) {
                NSLog(@"[MXRoomSummaryUpdater] updateRoomSummary: Cannot reset last message after redaction. Room: %@", summary.roomId);
            } commit:YES];
        }
        return NO;
    }
    else if (event.isEditEvent)
    {
        // Do not display update events in the summary
        return NO;
    }

    // Accept redacted event only if configured
    if (_ignoreRedactedEvent && event.isRedactedEvent)
    {
        return NO;
    }

    BOOL updated = NO;

    // Accept event which type is in the filter list
    if (event.eventId && (!_eventsFilterForMessages || (NSNotFound != [_eventsFilterForMessages indexOfObject:event.type])))
    {
        // Accept event related to profile change only if the flag is NO
        if (!_ignoreMemberProfileChanges || !event.isUserProfileChange)
        {
            summary.lastMessageEvent = event;
            updated = YES;
        }
    }

    return updated;
}

- (BOOL)session:(MXSession *)session updateRoomSummary:(MXRoomSummary *)summary withStateEvents:(NSArray<MXEvent *> *)stateEvents roomState:(MXRoomState*)roomState
{
    BOOL hasRoomMembersChange = NO;
    BOOL updated = NO;

    for (MXEvent *event in stateEvents)
    {
        switch (event.eventType)
        {
            case MXEventTypeRoomName:
                summary.displayname = roomState.name;
                updated = YES;
                break;

            case MXEventTypeRoomAvatar:
                summary.avatar = roomState.avatar;
                updated = YES;
                break;

            case MXEventTypeRoomTopic:
                summary.topic = roomState.topic;
                updated = YES;
                break;

            case MXEventTypeRoomAliases:
                summary.aliases = roomState.aliases;
                updated = YES;
                break;

            case MXEventTypeRoomCanonicalAlias:
                // If m.room.canonical_alias is set, use it if there is no m.room.name
                if (!roomState.name && roomState.canonicalAlias)
                {
                    summary.displayname = roomState.canonicalAlias;
                    updated = YES;
                }
                break;

            case MXEventTypeRoomMember:
                hasRoomMembersChange = YES;
                break;

            case MXEventTypeRoomEncryption:
                summary.isEncrypted = roomState.isEncrypted;
                updated = YES;
                break;
                
            case MXEventTypeRoomTombStone:
            {
                if ([self checkForTombStoneStateEventAndUpdateRoomSummaryIfNeeded:summary session:session roomState:roomState])
                {
                    updated = YES;
                }
                break;
            }
                
            case MXEventTypeRoomCreate:
                [self checkRoomCreateStateEventPredecessorAndUpdateObsoleteRoomSummaryIfNeededWithCreateEvent:event summary:summary session:session roomState:roomState];
                break;
                
            default:
                break;
        }
    }

    if (hasRoomMembersChange)
    {
        // Check if there was a change on room state cached data

        // In case of lazy-loaded room members, roomState.membersCount is a partial count.
        // The actual count will come with [updateRoomSummary:withServerRoomSummary:...].
        if (!session.syncWithLazyLoadOfRoomMembers && ![summary.membersCount isEqual:roomState.membersCount])
        {
            summary.membersCount = [roomState.membersCount copy];
            updated = YES;
        }

        if (summary.membership != roomState.membership && roomState.membership != MXMembershipUnknown)
        {
            summary.membership = roomState.membership;
            updated = YES;
        }

        if (summary.isConferenceUserRoom != roomState.isConferenceUserRoom)
        {
            summary.isConferenceUserRoom = roomState.isConferenceUserRoom;
            updated = YES;
        }
    }

    if (summary.membership == MXMembershipInvite)
    {
        // The server does not send yet room summary for invited rooms (https://github.com/matrix-org/matrix-doc/issues/1679)
        // but we could reuse same computation algos as joined rooms.
        // Note that leads to a bug in case someone invites us in a non 1:1 room with no avatar.
        // In this case, the summary avatar would be the inviter avatar.
        // We need more information from the homeserver to solve it. The issue above should help to fix it
        // Note: we have this bug since day #1
        updated = [self session:session updateRoomSummary:summary withServerRoomSummary:nil roomState:roomState];
    }

    return updated;
}

#pragma mark - Private

// Hide tombstoned room from user only if the user joined the replacement room
// Important: Room replacement summary could not be present in memory when making this process even if the user joined it,
// in this case it should be processed when checking the room replacement in `checkRoomCreateStateEventPredecessorAndUpdateObsoleteRoomSummaryIfNeeded:session:room:`.
- (BOOL)checkForTombStoneStateEventAndUpdateRoomSummaryIfNeeded:(MXRoomSummary*)summary session:(MXSession*)session roomState:(MXRoomState*)roomState
{
    BOOL updated = NO;
    
    MXRoomTombStoneContent *roomTombStoneContent = roomState.tombStoneContent;
    
    if (roomTombStoneContent)
    {
        MXRoomSummary *replacementRoomSummary = [session roomSummaryWithRoomId:roomTombStoneContent.replacementRoomId];
        
        if (replacementRoomSummary)
        {
            summary.hiddenFromUser = replacementRoomSummary.membership == MXMembershipJoin;
            updated = YES;
        }
    }
    
    return updated;
}

// Hide tombstoned room predecessor from user only if the user joined the current room
// Important: Room predecessor summary could not be present in memory when making this process,
// in this case it should be processed when checking the room predecessor in `checkForTombStoneStateEventAndUpdateRoomSummaryIfNeeded:session:room:`.
- (void)checkRoomCreateStateEventPredecessorAndUpdateObsoleteRoomSummaryIfNeededWithCreateEvent:(MXEvent*)createEvent summary:(MXRoomSummary*)summary session:(MXSession*)session roomState:(MXRoomState*)roomState
{
    MXRoomCreateContent *createContent = [MXRoomCreateContent modelFromJSON:createEvent.content];
    
    if (createContent.roomPredecessorInfo)
    {
        MXRoomSummary *obsoleteRoomSummary = [session roomSummaryWithRoomId:createContent.roomPredecessorInfo.roomId];
     
        BOOL obsoleteRoomHiddenFromUserFormerValue = obsoleteRoomSummary.hiddenFromUser;
        obsoleteRoomSummary.hiddenFromUser = summary.membership == MXMembershipJoin; // Hide room predecessor if user joined the new one
        
        if (obsoleteRoomHiddenFromUserFormerValue != obsoleteRoomSummary.hiddenFromUser)
        {
            [obsoleteRoomSummary save:YES];
        }
    }
}

- (BOOL)session:(MXSession *)session updateRoomSummary:(MXRoomSummary *)summary withServerRoomSummary:(MXRoomSyncSummary *)serverRoomSummary roomState:(MXRoomState *)roomState
{
    BOOL updated = NO;

    updated |= [self updateSummaryMemberCount:summary session:session withServerRoomSummary:serverRoomSummary roomState:roomState];
    updated |= [self updateSummaryDisplayname:summary session:session withServerRoomSummary:serverRoomSummary roomState:roomState];
    updated |= [self updateSummaryAvatar:summary session:session withServerRoomSummary:serverRoomSummary roomState:roomState];

    return updated;
}

- (BOOL)updateSummaryDisplayname:(MXRoomSummary *)summary session:(MXSession *)session withServerRoomSummary:(MXRoomSyncSummary *)serverRoomSummary roomState:(MXRoomState *)roomState
{
    NSString *displayname;

    if (!_roomNameStringLocalizations)
    {
        _roomNameStringLocalizations = [MXRoomNameDefaultStringLocalizations new];
    }

    // Compute a display name according to algorithm provided by Matrix room summaries
    // (https://github.com/matrix-org/matrix-doc/issues/688)

    // If m.room.name is set, use that
    if (roomState.name.length)
    {
        displayname = roomState.name;
    }
    // If m.room.canonical_alias is set, use that
    // Note: a "" for canonicalAlias means the previous one has been removed
    else if (roomState.canonicalAlias.length)
    {
        displayname = roomState.canonicalAlias;
    }
    // If the room has an alias, use that
    else if (roomState.aliases.count)
    {
        displayname = roomState.aliases.firstObject;
    }
    else
    {
        NSUInteger memberCount = 0;
        NSMutableArray<NSString*> *memberNames;

        // Use Matrix room summaries and heroes
        if (serverRoomSummary)
        {
            memberCount = serverRoomSummary.joinedMemberCount + serverRoomSummary.invitedMemberCount;

            if (serverRoomSummary.heroes.count)
            {
                memberNames = [NSMutableArray arrayWithCapacity:serverRoomSummary.heroes.count];
                for (NSString *hero in serverRoomSummary.heroes)
                {
                    NSString *memberName = [roomState.members memberName:hero];
                    if (!memberName)
                    {
                        memberName = hero;
                    }

                    [memberNames addObject:memberName];
                }
            }
        }
        // Or in case of non lazy loading and no server room summary,
        // use the full room state
        else if (roomState.membersCount.members > 1)
        {
            NSArray *otherMembers = [self sortedOtherMembersInRoomState:roomState withMatrixSession:session];

            memberNames = [NSMutableArray arrayWithCapacity:otherMembers.count];
            for (MXRoomMember *member in otherMembers)
            {
                NSString *memberName = [roomState.members memberName:member.userId];
                if (memberName)
                {
                    [memberNames addObject:memberName];
                }
            }

            memberCount = memberNames.count + 1;
        }

        // We display 2 users names max. Then, for larger rooms, we display "Alice and X others"
        switch (memberNames.count)
        {
            case 0:
                displayname = _roomNameStringLocalizations.emptyRoom;
                break;

            case 1:
                displayname = memberNames.firstObject;
                break;

            case 2:
                displayname = [NSString stringWithFormat:_roomNameStringLocalizations.twoMembers,
                                       memberNames[0],
                                       memberNames[1]];
                break;

            default:
                displayname = [NSString stringWithFormat:_roomNameStringLocalizations.moreThanTwoMembers,
                                       memberNames[0],
                                       @(memberCount - 2)];
                break;
        }

        if (memberCount > 1
            && (!displayname || [displayname isEqualToString:_roomNameStringLocalizations.emptyRoom]))
        {
            // Data are missing to compute the display name
            NSLog(@"[MXRoomSummaryUpdater] updateSummaryDisplayname: Warning: Computed an unexpected \"Empty Room\" name. memberCount: %@", @(memberCount));
            displayname = [self fixUnexpectedEmptyRoomDisplayname:memberCount session:session roomState:roomState];
        }
    }

    if (displayname != summary.displayname || ![displayname isEqualToString:summary.displayname])
    {
        summary.displayname = displayname;
        return YES;
    }

    return NO;
}

/**
 Try to fix an unexpected "Empty room" name.

 One known reason is https://github.com/matrix-org/synapse/issues/4194.

 @param memberCount The known member count.
 @param session the session.
 @param roomState the room state to get data from.
 @return The new display name
 */
- (NSString*)fixUnexpectedEmptyRoomDisplayname:(NSUInteger)memberCount session:(MXSession*)session roomState:(MXRoomState*)roomState
{
    NSString *displayname;

    // Try to fix it and to avoid unexpected "Empty room" room name with members already loaded
    NSArray *otherMembers = [self sortedOtherMembersInRoomState:roomState withMatrixSession:session];
    NSMutableArray<NSString*> *memberNames = [NSMutableArray arrayWithCapacity:otherMembers.count];
    for (MXRoomMember *member in otherMembers)
    {
        NSString *memberName = [roomState.members memberName:member.userId];
        if (memberName)
        {
            [memberNames addObject:memberName];
        }
    }

    NSLog(@"[MXRoomSummaryUpdater] fixUnexpectedEmptyRoomDisplayname: Found %@ loaded members for %@ known other members", @(otherMembers.count), @(memberCount - 1));

    switch (memberNames.count)
    {
        case 0:
            NSLog(@"[MXRoomSummaryUpdater] fixUnexpectedEmptyRoomDisplayname: No luck");
            displayname = _roomNameStringLocalizations.emptyRoom;
            break;

        case 1:
            if (memberCount == 2)
            {
                NSLog(@"[MXRoomSummaryUpdater] fixUnexpectedEmptyRoomDisplayname: Fixed 1");
                displayname = memberNames[0];
            }
            else
            {
                NSLog(@"[MXRoomSummaryUpdater] fixUnexpectedEmptyRoomDisplayname: Half fixed 1");
                displayname = [NSString stringWithFormat:_roomNameStringLocalizations.moreThanTwoMembers,
                               memberNames[0],
                               @(memberCount - 1)];
            }
            break;

        case 2:
            if (memberCount == 3)
            {
                NSLog(@"[MXRoomSummaryUpdater] fixUnexpectedEmptyRoomDisplayname: Fixed 2");
                displayname = [NSString stringWithFormat:_roomNameStringLocalizations.twoMembers,
                               memberNames[0],
                               memberNames[1]];
            }
            else
            {
                NSLog(@"[MXRoomSummaryUpdater] fixUnexpectedEmptyRoomDisplayname: Half fixed 2");
                displayname = [NSString stringWithFormat:_roomNameStringLocalizations.moreThanTwoMembers,
                               memberNames[0],
                               @(memberCount - 2)];
            }
            break;

        default:
            NSLog(@"[MXRoomSummaryUpdater] fixUnexpectedEmptyRoomDisplayname: Fixed 3");
            displayname = [NSString stringWithFormat:_roomNameStringLocalizations.moreThanTwoMembers,
                           memberNames[0],
                           @(memberCount - 2)];
            break;
    }

    return displayname;
}

- (BOOL)updateSummaryAvatar:(MXRoomSummary *)summary session:(MXSession *)session withServerRoomSummary:(MXRoomSyncSummary *)serverRoomSummary roomState:(MXRoomState *)roomState
{
    NSString *avatar;

    // If m.room.avatar is set, use that
    if (roomState.avatar)
    {
        avatar = roomState.avatar;
    }
    // Else, use Matrix room summaries and heroes
    else if (serverRoomSummary.heroes.count == 1)
    {
        MXRoomMember *otherMember = [roomState.members memberWithUserId:serverRoomSummary.heroes.firstObject];
        avatar = otherMember.avatarUrl;
    }
    // Or in case of non lazy loading or no server room summary,
    // use the full room state
    else if (roomState.membersCount.members == 2)
    {
        NSArray<MXRoomMember*> *otherMembers = [self sortedOtherMembersInRoomState:roomState withMatrixSession:session];
        avatar = otherMembers.firstObject.avatarUrl;
    }

    if (avatar != summary.avatar || ![avatar isEqualToString:summary.avatar])
    {
        summary.avatar = avatar;
        return YES;
    }

    return NO;
}

- (BOOL)updateSummaryMemberCount:(MXRoomSummary *)summary session:(MXSession *)session withServerRoomSummary:(MXRoomSyncSummary *)serverRoomSummary roomState:(MXRoomState *)roomState
{

    MXRoomMembersCount *membersCount;

    if (serverRoomSummary)
    {
        membersCount = [summary.membersCount copy];
        if (!membersCount)
        {
            membersCount = [MXRoomMembersCount new];
        }

        membersCount.joined = serverRoomSummary.joinedMemberCount;
        membersCount.invited = serverRoomSummary.invitedMemberCount;
        membersCount.members = membersCount.joined + membersCount.invited;
    }
    // Or in case of non lazy loading and no server room summary,
    // use the full room state
    else
    {
        membersCount = roomState.membersCount;
    }

    if (![summary.membersCount isEqual:membersCount])
    {
        summary.membersCount = membersCount;
        return YES;
    }

    return NO;
}

- (NSArray<MXRoomMember*> *)sortedOtherMembersInRoomState:(MXRoomState*)roomState withMatrixSession:(MXSession *)session
{
    // Get all joined and invited members other than my user
    NSMutableArray<MXRoomMember*> *otherMembers = [NSMutableArray array];
    for (MXRoomMember *member in roomState.members.members)
    {
        if ((member.membership == MXMembershipJoin || member.membership == MXMembershipInvite)
            && ![member.userId isEqualToString:session.myUserId])
        {
            [otherMembers addObject:member];
        }
    }

    // Sort members by their creation (oldest first)
    [otherMembers sortUsingComparator:^NSComparisonResult(MXRoomMember *member1, MXRoomMember *member2) {

        uint64_t originServerTs1 = member1.originalEvent.originServerTs;
        uint64_t originServerTs2 = member2.originalEvent.originServerTs;

        if (originServerTs1 == originServerTs2)
        {
            return NSOrderedSame;
        }
        else
        {
            return originServerTs1 > originServerTs2 ? NSOrderedDescending : NSOrderedAscending;
        }
    }];

    return otherMembers;
}

@end
