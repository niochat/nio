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

#import "MXGroup.h"

#import "MXSession.h"
#import "MXTools.h"

@implementation MXGroup

- (instancetype)initWithGroupId:(NSString*)groupId
{
    self = [super init];
    if (self)
    {
        _groupId = groupId;
        _membership = MXMembershipUnknown;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@: %@ %@ (inviter: %@)", _groupId, _summary.profile.name, _summary.profile.shortDescription, _inviter];
}

- (BOOL)updateProfile:(MXGroupProfile*)profile
{
    if (!_summary)
    {
        _summary = [[MXGroupSummary alloc] init];
    }
    
    if (![_summary.profile isEqual:profile])
    {
        _summary.profile = profile;
        return YES;
    }
    
    return NO;
}

- (BOOL)updateSummary:(MXGroupSummary*)summary
{
    if (![_summary isEqual:summary])
    {
        _summary = summary;
        return YES;
    }
    
    return NO;
}

- (BOOL)updateRooms:(MXGroupRooms*)rooms
{
    if (![_rooms isEqual:rooms])
    {
        _rooms = rooms;
        return YES;
    }
    
    return NO;
}

- (BOOL)updateUsers:(MXGroupUsers*)users
{
    if (![_users isEqual:users])
    {
        _users = users;
        return YES;
    }
    
    return NO;
}

- (BOOL)updateInvitedUsers:(MXGroupUsers*)invitedUsers
{
    if (![_invitedUsers isEqual:invitedUsers])
    {
        _invitedUsers = invitedUsers;
        return YES;
    }
    
    return NO;
}

#pragma mark -

- (MXGroupProfile*)profile
{
    return _summary.profile;
}

- (void)setMembership:(MXMembership)membership
{
    _membership = membership;
    
    // Report this value in the summary if any.
    if (_summary.user)
    {
        _summary.user.membership = [MXTools membershipString:membership];
    }
}

- (void)setSummary:(MXGroupSummary *)summary
{
    _summary = summary;
    
    if (_summary.user)
    {
        // Update membership property.
        _membership = [MXTools membership:_summary.user.membership];
    }
}

#pragma mark - NSCoding
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _groupId = [aDecoder decodeObjectForKey:@"groupId"];
        _summary = [aDecoder decodeObjectForKey:@"summary"];
        _rooms = [aDecoder decodeObjectForKey:@"rooms"];
        _users = [aDecoder decodeObjectForKey:@"users"];
        _invitedUsers = [aDecoder decodeObjectForKey:@"invitedUsers"];
        _membership = [(NSNumber*)[aDecoder decodeObjectForKey:@"membership"] unsignedIntegerValue];
        _inviter = [aDecoder decodeObjectForKey:@"inviter"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (_groupId)
    {
        [aCoder encodeObject:_groupId forKey:@"groupId"];
        [aCoder encodeObject:@(_membership) forKey:@"membership"];
        [aCoder encodeObject:_inviter forKey:@"inviter"];
        
        if (_summary)
        {
            [aCoder encodeObject:_summary forKey:@"summary"];
        }
        if (_rooms)
        {
            [aCoder encodeObject:_rooms forKey:@"rooms"];
        }
        if (_users)
        {
            [aCoder encodeObject:_users forKey:@"users"];;
        }
        if (_invitedUsers)
        {
            [aCoder encodeObject:_invitedUsers forKey:@"invitedUsers"];;
        }
    }
}

#pragma mark - NSCopying
- (id)copyWithZone:(NSZone *)zone
{
    MXGroup *group = [[[self class] allocWithZone:zone] init];
    
    group->_groupId = [_groupId copyWithZone:zone];
    group.membership = _membership;
    group.summary = [_summary copyWithZone:zone];
    group.rooms = [_rooms copyWithZone:zone];
    group.users = [_users copyWithZone:zone];
    group.invitedUsers = [_invitedUsers copyWithZone:zone];
    group.inviter = [_inviter copyWithZone:zone];
    
    return group;
}

@end
