/*
 Copyright 2014 OpenMarket Ltd
 
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

#import "MXRoomMember.h"

#import "MXRestClient.h"

#import "MXJSONModels.h"
#import "MXTools.h"

@implementation MXRoomMember

- (instancetype)initWithMXEvent:(MXEvent*)roomMemberEvent
{
    // Use roomMemberEvent.content by default
    return [self initWithMXEvent:roomMemberEvent andEventContent:roomMemberEvent.content];
}

- (instancetype)initWithMXEvent:(MXEvent*)roomMemberEvent
                andEventContent:(NSDictionary<NSString *, id>*)roomMemberEventContent
{
    self = [super init];
    if (self)
    {
        NSParameterAssert(roomMemberEvent.eventType == MXEventTypeRoomMember);
        
        // Check if there is information about user membership
        if (nil == roomMemberEventContent || 0 == roomMemberEventContent.count)
        {
            // No. The user is not part of the room
            return nil;
        }
        
        // Use MXRoomMemberEventContent to parse the JSON event content
        MXRoomMemberEventContent *roomMemberContent = [MXRoomMemberEventContent modelFromJSON:roomMemberEventContent];
        _displayname = roomMemberContent.displayname;
        // We ignore non mxc avatar url
        _avatarUrl = ([roomMemberContent.avatarUrl hasPrefix:kMXContentUriScheme] ? roomMemberContent.avatarUrl : nil);
        _membership = [MXTools membership:roomMemberContent.membership];
        _thirdPartyInviteToken = roomMemberContent.thirdPartyInviteToken;
        _originalEvent = roomMemberEvent;

        // Set who is this member
        if (roomMemberEvent.stateKey)
        {
            _userId = roomMemberEvent.stateKey;
        }
        else
        {
            _userId = roomMemberEvent.sender;
        }
        
        if (roomMemberEventContent == roomMemberEvent.content)
        {
            // The user who made the last membership change is the event user id
            _originUserId = roomMemberEvent.sender;
            
            // If defined, keep the previous membership information
            if (roomMemberEvent.prevContent)
            {
                MXRoomMemberEventContent *roomMemberPrevContent = [MXRoomMemberEventContent modelFromJSON:roomMemberEvent.prevContent];
                _prevMembership = [MXTools membership:roomMemberPrevContent.membership];
            }
            else
            {
                _prevMembership = MXMembershipUnknown;
            }
        }
        else
        {
            // If roomMemberEventContent was roomMemberEvent.prevContent,
            // The following values have no meaning
            _originUserId = nil;
            _prevMembership = MXMembershipUnknown;
        }
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MXRoomMember: %p> userId: %@ - membership: %@", self, _userId, [MXTools membershipString:self.membership]];
}

@end
