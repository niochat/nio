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

#import "MXRoomState.h"

#import "MXSDKOptions.h"

#import "MXSession.h"
#import "MXTools.h"
#import "MXCallManager.h"

@interface MXRoomState ()
{
    MXSession *mxSession;

    /**
     State events ordered by type.
     */
    NSMutableDictionary<NSString*, NSMutableArray<MXEvent*>*> *stateEvents;

    /**
     The room aliases. The key is the domain.
     */
    NSMutableDictionary<NSString*, MXEvent*> *roomAliases;

    /**
     The third party invites. The key is the token provided by the homeserver.
     */
    NSMutableDictionary<NSString*, MXRoomThirdPartyInvite*> *thirdPartyInvites;
    
    /**
     Maximum power level observed in power level list
     */
    NSInteger maxPowerLevel;

    /**
     Cache for [self memberWithThirdPartyInviteToken].
     The key is the 3pid invite token.
     */
    NSMutableDictionary<NSString*, MXRoomMember*> *membersWithThirdPartyInviteTokenCache;

    /**
     The cache for the conference user id.
     */
    NSString *conferenceUserId;
}
@end

@implementation MXRoomState
@synthesize powerLevels;

- (id)initWithRoomId:(NSString*)roomId
    andMatrixSession:(MXSession*)matrixSession
        andDirection:(BOOL)isLive
{
    self = [super init];
    if (self)
    {
        mxSession = matrixSession;
        _roomId = roomId;
        
        _isLive = isLive;
        
        stateEvents = [NSMutableDictionary dictionary];
        _members = [[MXRoomMembers alloc] initWithRoomState:self andMatrixSession:mxSession];
        _membersCount = [MXRoomMembersCount new];
        roomAliases = [NSMutableDictionary dictionary];
        thirdPartyInvites = [NSMutableDictionary dictionary];
        membersWithThirdPartyInviteTokenCache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (id)initWithRoomId:(NSString*)roomId
    andMatrixSession:(MXSession*)matrixSession
         andInitialSync:(MXRoomInitialSync*)initialSync
        andDirection:(BOOL)isLive
{
    self = [self initWithRoomId:roomId andMatrixSession:matrixSession andDirection:isLive];
    if (self)
    {
        // Store optional metadata
        if (initialSync)
        {
            if (initialSync.membership)
            {
                _membership = [MXTools membership:initialSync.membership];
            }
        }
    }
    return self;
}

+ (void)loadRoomStateFromStore:(id<MXStore>)store
                  withRoomId:(NSString *)roomId
               matrixSession:(MXSession *)matrixSession
                  onComplete:(void (^)(MXRoomState *roomState))onComplete
{
    MXRoomState *roomState = [[MXRoomState alloc] initWithRoomId:roomId andMatrixSession:matrixSession andDirection:YES];
    if (roomState)
    {
        [store stateOfRoom:roomId success:^(NSArray<MXEvent *> * _Nonnull stateEvents) {
            [roomState handleStateEvents:stateEvents];

            onComplete(roomState);
        } failure:nil];
    }
}

- (id)initBackStateWith:(MXRoomState*)state
{
    self = [state copy];
    if (self)
    {
        _isLive = NO;

        // At the beginning of pagination, the back room state must be the same
        // as the current current room state.
        // So, use the same state events content.
        // @TODO: Find another way than modifying the event content.
        for (NSArray<MXEvent*> *events in stateEvents.allValues)
        {
            for (MXEvent *event in events)
            {
                event.prevContent = event.content;
            }
        }
    }
    return self;
}

// According to the direction of the instance, we are interested either by
// the content of the event or its prev_content
- (NSDictionary<NSString *, id> *)contentOfEvent:(MXEvent*)event
{
    NSDictionary<NSString *, id> *content;
    if (event)
    {
        if (_isLive)
        {
            content = event.content;
        }
        else
        {
            content = event.prevContent;
        }
    }
    return content;
}

- (NSArray<MXEvent *> *)stateEvents
{
    NSMutableArray<MXEvent *> *state = [NSMutableArray array];
    for (NSArray<MXEvent*> *events in stateEvents.allValues)
    {
        [state addObjectsFromArray:events];
    }

    // Members are also state events
    for (MXRoomMember *roomMember in self.members.members)
    {
        [state addObject:roomMember.originalEvent];
    }
    
    // Add room aliases stored by domain
    for (MXEvent *event in roomAliases.allValues)
    {
        [state addObject:event];
    }

    // Third party invites are state events too
    for (MXRoomThirdPartyInvite *thirdPartyInvite in self.thirdPartyInvites)
    {
        [state addObject:thirdPartyInvite.originalEvent];
    }

    return state;
}

- (NSArray<MXRoomThirdPartyInvite *> *)thirdPartyInvites
{
    return [thirdPartyInvites allValues];
}

- (NSArray<NSString *> *)relatedGroups
{
    NSArray<NSString *> *relatedGroups;
    
    // Retrieve them from the state events
    MXEvent *event = [stateEvents objectForKey:kMXEventTypeStringRoomRelatedGroups].lastObject;
    if (event && [self contentOfEvent:event])
    {
        MXJSONModelSetArray(relatedGroups, [self contentOfEvent:event][@"groups"]);
        relatedGroups = [relatedGroups copy];
    }
    return relatedGroups;
}

- (NSArray<NSString *> *)aliases
{
    NSMutableArray<NSString *> *aliases = [NSMutableArray array];
    
    // Merge here all the bunches of aliases (one bunch by domain)
    for (MXEvent *event in roomAliases.allValues)
    {
        NSDictionary<NSString *, id> *eventContent = [self contentOfEvent:event];
        NSArray<NSString *> *aliasesBunch = eventContent[@"aliases"];
        
        if (aliasesBunch.count)
        {
            [aliases addObjectsFromArray:aliasesBunch];
        }
    }
    
    return aliases.count ? aliases : nil;
}

- (NSString*)canonicalAlias
{
    NSString *canonicalAlias;
    
    // Check it from the state events
    MXEvent *event = [stateEvents objectForKey:kMXEventTypeStringRoomCanonicalAlias].lastObject;
    if (event && [self contentOfEvent:event])
    {
        MXJSONModelSetString(canonicalAlias, [self contentOfEvent:event][@"alias"]);
        canonicalAlias = [canonicalAlias copy];
    }
    return canonicalAlias;
}

- (NSString *)name
{
    NSString *name;
    
    // Check it from the state events
    MXEvent *event = [stateEvents objectForKey:kMXEventTypeStringRoomName].lastObject;
    if (event && [self contentOfEvent:event])
    {
        MXJSONModelSetString(name, [self contentOfEvent:event][@"name"]);
        name = [name copy];
    }
    return name;
}

- (NSString *)topic
{
    NSString *topic;
    
    // Check it from the state events
    MXEvent *event = [stateEvents objectForKey:kMXEventTypeStringRoomTopic].lastObject;
    if (event && [self contentOfEvent:event])
    {
        MXJSONModelSetString(topic, [self contentOfEvent:event][@"topic"]);
        topic = [topic copy];
    }
    return topic;
}

- (NSString *)avatar
{
    NSString *avatar;

    // Check it from the state events
    MXEvent *event = [stateEvents objectForKey:kMXEventTypeStringRoomAvatar].lastObject;
    if (event && [self contentOfEvent:event])
    {
        MXJSONModelSetString(avatar, [self contentOfEvent:event][@"url"]);
        avatar = [avatar copy];
    }
    return avatar;
}

- (MXRoomHistoryVisibility)historyVisibility
{
    MXRoomHistoryVisibility historyVisibility = kMXRoomHistoryVisibilityShared;

    // Check it from the state events
    MXEvent *event = [stateEvents objectForKey:kMXEventTypeStringRoomHistoryVisibility].lastObject;
    if (event && [self contentOfEvent:event])
    {
        MXJSONModelSetString(historyVisibility, [self contentOfEvent:event][@"history_visibility"]);
        historyVisibility = [historyVisibility copy];
    }
    return historyVisibility;
}

- (MXRoomJoinRule)joinRule
{
    MXRoomJoinRule joinRule = kMXRoomJoinRuleInvite;

    // Check it from the state events
    MXEvent *event = [stateEvents objectForKey:kMXEventTypeStringRoomJoinRules].lastObject;
    if (event && [self contentOfEvent:event])
    {
        MXJSONModelSetString(joinRule, [self contentOfEvent:event][@"join_rule"]);
        joinRule = [joinRule copy];
    }
    return joinRule;
}

- (BOOL)isJoinRulePublic
{
    return [self.joinRule isEqualToString:kMXRoomJoinRulePublic];
}

- (MXRoomGuestAccess)guestAccess
{
    MXRoomGuestAccess guestAccess = kMXRoomGuestAccessForbidden;

    // Check it from the state events
    MXEvent *event = [stateEvents objectForKey:kMXEventTypeStringRoomGuestAccess].lastObject;
    if (event && [self contentOfEvent:event])
    {
        MXJSONModelSetString(guestAccess, [self contentOfEvent:event][@"guest_access"]);
        guestAccess = [guestAccess copy];
    }
    return guestAccess;
}

- (BOOL)isEncrypted
{
    return (0 != self.encryptionAlgorithm.length);
}

- (NSArray<NSString *> *)pinnedEvents
{
    NSArray<NSString *> *pinnedEvents;

    // Check them the m.room.pinned_events event
    MXEvent *event = stateEvents[kMXEventTypeStringRoomPinnedEvents].lastObject;
    MXJSONModelSetArray(pinnedEvents, [self contentOfEvent:event][@"pinned"]);

    return pinnedEvents;
}

- (NSString *)encryptionAlgorithm
{
    return stateEvents[kMXEventTypeStringRoomEncryption].lastObject.content[@"algorithm"];
}

- (BOOL)isObsolete
{
    return self.tombStoneContent != nil;
}

- (MXRoomTombStoneContent*)tombStoneContent
{
    MXRoomTombStoneContent *roomTombStoneContent = nil;
    
    // Check it from the state events
    MXEvent *event = stateEvents[kMXEventTypeStringRoomTombStone].lastObject;
    NSDictionary *eventContent = [self contentOfEvent:event];
    if (eventContent)
    {
        roomTombStoneContent = [MXRoomTombStoneContent modelFromJSON:eventContent];
    }
    
    return roomTombStoneContent;
}

#pragma mark - State events handling
- (void)handleStateEvents:(NSArray<MXEvent *> *)events;
{
    // Process the update on room members
    if ([_members handleStateEvents:events])
    {
        // Update counters for currently known room members
        _membersCount.members = _members.members.count;
        _membersCount.joined = _members.joinedMembers.count;
        _membersCount.invited =  [_members membersWithMembership:MXMembershipInvite].count;
    }

    @autoreleasepool
    {
        for (MXEvent *event in events)
        {
            switch (event.eventType)
            {
                case MXEventTypeRoomMember:
                {
                    // User in this membership event
                    NSString *userId = event.stateKey ? event.stateKey : event.sender;

                    NSDictionary *content = [self contentOfEvent:event];

                    // Compute my user membership indepently from MXRoomMembers
                    if ([userId isEqualToString:mxSession.myUser.userId])
                    {
                        MXRoomMember *roomMember = [[MXRoomMember alloc] initWithMXEvent:event andEventContent:content];
                        _membership = roomMember.membership;
                    }

                    if (content[@"third_party_invite"][@"signed"][@"token"])
                    {
                        // Cache room member event that is successor of a third party invite event
                        MXRoomMember *roomMember = [[MXRoomMember alloc] initWithMXEvent:event andEventContent:content];
                        membersWithThirdPartyInviteTokenCache[roomMember.thirdPartyInviteToken] = roomMember;
                    }

                    // In case of invite, process the provided but incomplete room state
                    if (self.membership == MXMembershipInvite && event.inviteRoomState)
                    {
                        [self handleStateEvents:event.inviteRoomState];
                    }
                    else if (_isLive && self.membership == MXMembershipJoin && _membersCount.members > 2)
                    {
                        if ([userId isEqualToString:self.conferenceUserId])
                        {
                            // Forward the change of the conference user membership to the call manager
                            MXRoomMember *roomMember = [[MXRoomMember alloc] initWithMXEvent:event andEventContent:content];
                            [mxSession.callManager handleConferenceUserUpdate:roomMember inRoom:_roomId];
                        }
                    }

                    break;
                }
                case MXEventTypeRoomThirdPartyInvite:
                {
                    // The content and the prev_content of a m.room.third_party_invite event are the same.
                    // So, use isLive to know if the invite must be added or removed (case of back state).
                    if (_isLive)
                    {
                        MXRoomThirdPartyInvite *thirdPartyInvite = [[MXRoomThirdPartyInvite alloc] initWithMXEvent:event];
                        if (thirdPartyInvite)
                        {
                            thirdPartyInvites[thirdPartyInvite.token] = thirdPartyInvite;
                        }
                    }
                    else
                    {
                        // Note: the 3pid invite token is stored in the event state key
                        [thirdPartyInvites removeObjectForKey:event.stateKey];
                    }
                    break;
                }
                case MXEventTypeRoomAliases:
                {
                    // Sanity check
                    if (event.stateKey.length)
                    {
                        // Store the bunch of aliases for the domain (which is the state_key)
                        roomAliases[event.stateKey] = event;
                    }
                    break;
                }
                case MXEventTypeRoomPowerLevels:
                {
                    powerLevels = [MXRoomPowerLevels modelFromJSON:[self contentOfEvent:event]];
                    // Compute max power level
                    maxPowerLevel = powerLevels.usersDefault;
                    NSArray<NSNumber *> *array = powerLevels.users.allValues;
                    for (NSNumber *powerLevel in array)
                    {
                        NSInteger level = 0;
                        MXJSONModelSetInteger(level, powerLevel);
                        if (level > maxPowerLevel)
                        {
                            maxPowerLevel = level;
                        }
                    }

                    // Do not break here to store the event into the stateEvents dictionary.
                }
                default:
                    // Store other states into the stateEvents dictionary.
                    if (!stateEvents[event.type])
                    {
                        stateEvents[event.type] = [NSMutableArray array];
                    }
                    [stateEvents[event.type] addObject:event];
                    break;
            }
        }
    }

    // Update store with new room state when all state event have been processed
    if (_isLive && [mxSession.store respondsToSelector:@selector(storeStateForRoom:stateEvents:)])
    {
        [mxSession.store storeStateForRoom:_roomId stateEvents:self.stateEvents];
    }
}

- (NSArray<MXEvent*> *)stateEventsWithType:(MXEventTypeString)eventType
{
    return stateEvents[eventType];
}

- (MXRoomMember *)memberWithThirdPartyInviteToken:(NSString *)thirdPartyInviteToken
{
    return membersWithThirdPartyInviteTokenCache[thirdPartyInviteToken];
}

- (MXRoomThirdPartyInvite *)thirdPartyInviteWithToken:(NSString *)thirdPartyInviteToken
{
    return thirdPartyInvites[thirdPartyInviteToken];
}

- (float)memberNormalizedPowerLevel:(NSString*)userId
{
    float powerLevel = 0;
    
    // Get the user from the member list of the room
    // If the app asks for information about a user id, it means that we already
    // have the MXRoomMember data
    MXRoomMember *member = [self.members memberWithUserId:userId];
    
    // Ignore banned and left (kicked) members
    if (member.membership != MXMembershipLeave && member.membership != MXMembershipBan)
    {
        float userPowerLevelFloat = [powerLevels powerLevelOfUserWithUserID:userId];
        powerLevel = maxPowerLevel ? userPowerLevelFloat / maxPowerLevel : 1;
    }
    
    return powerLevel;
}

# pragma mark - Conference call
- (BOOL)isOngoingConferenceCall
{
    BOOL isOngoingConferenceCall = NO;

    MXRoomMember *conferenceUserMember = [self.members memberWithUserId:self.conferenceUserId];
    if (conferenceUserMember)
    {
        isOngoingConferenceCall = (conferenceUserMember.membership == MXMembershipJoin);
    }

    return isOngoingConferenceCall;
}

- (BOOL)isConferenceUserRoom
{
    BOOL isConferenceUserRoom = NO;

    // A conference user room is a 1:1 room with a conference user
    if (_membersCount.members == 2 && [self.members memberWithUserId:self.conferenceUserId])
    {
        isConferenceUserRoom = YES;
    }

    return isConferenceUserRoom;
}

- (NSString *)conferenceUserId
{
    if (!conferenceUserId)
    {
        conferenceUserId = [MXCallManager conferenceUserIdForRoom:_roomId];
    }
    return conferenceUserId;
}

#pragma mark - NSCopying
- (id)copyWithZone:(NSZone *)zone
{
    MXRoomState *stateCopy = [[MXRoomState allocWithZone:zone] init];

    stateCopy->mxSession = mxSession;
    stateCopy->_roomId = [_roomId copyWithZone:zone];

    stateCopy->_isLive = _isLive;

    // Copy the state events. A deep copy of each events array is necessary.
    stateCopy->stateEvents = [[NSMutableDictionary allocWithZone:zone] initWithCapacity:stateEvents.count];
    for (NSString *key in stateEvents)
    {
        // Copy the list of state events pointers. A deep copy is not necessary as MXEvent objects are immutable
        stateCopy->stateEvents[key] = [[NSMutableArray allocWithZone:zone] initWithArray:stateEvents[key]];
    }

    stateCopy->_members = [_members copyWithZone:zone];

    stateCopy->_membersCount = _membersCount;
    
    stateCopy->roomAliases = [[NSMutableDictionary allocWithZone:zone] initWithDictionary:roomAliases];

    stateCopy->thirdPartyInvites = [[NSMutableDictionary allocWithZone:zone] initWithDictionary:thirdPartyInvites];

    stateCopy->membersWithThirdPartyInviteTokenCache= [[NSMutableDictionary allocWithZone:zone] initWithDictionary:membersWithThirdPartyInviteTokenCache];
    
    stateCopy->_membership = _membership;

    stateCopy->powerLevels = [powerLevels copy];
    stateCopy->maxPowerLevel = maxPowerLevel;

    if (conferenceUserId)
    {
        stateCopy->conferenceUserId = [conferenceUserId copyWithZone:zone];
    }

    return stateCopy;
}

@end
