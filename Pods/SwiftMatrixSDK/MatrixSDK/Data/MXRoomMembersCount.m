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

#import "MXRoomMembersCount.h"


@implementation MXRoomMembersCount


- (BOOL)isEqual:(id)object
{
    BOOL isEqual = NO;

    if ([object isKindOfClass:MXRoomMembersCount.class])
    {
        MXRoomMembersCount *other = object;
        isEqual = _members == other.members
        && _joined == other.joined
        && _invited == other.invited;
    }

    return isEqual;
}


#pragma mark - NSCopying
- (id)copyWithZone:(NSZone *)zone
{
    MXRoomMembersCount *roomMembersCount = [[MXRoomMembersCount allocWithZone:zone] init];

    roomMembersCount.members = self.members;
    roomMembersCount.joined = self.joined;
    roomMembersCount.invited = self.invited;

    return roomMembersCount;
}


#pragma mark - NSCoding
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [self init];
    if (self)
    {
        _members = (NSUInteger)[aDecoder decodeIntegerForKey:@"members"];
        _joined = (NSUInteger)[aDecoder decodeIntegerForKey:@"joined"];
        _invited = (NSUInteger)[aDecoder decodeIntegerForKey:@"invited"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInteger:(NSInteger)_members forKey:@"members"];
    [aCoder encodeInteger:(NSInteger)_joined forKey:@"joined"];
    [aCoder encodeInteger:(NSInteger)_invited forKey:@"invited"];
}

@end
