/*
 Copyright 2016 OpenMarket Ltd

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

#import "MXRoomThirdPartyInvite.h"

#import "MXJSONModels.h"

@implementation MXRoomThirdPartyInvite

- (instancetype)initWithMXEvent:(MXEvent *)roomThirdPartyInviteEvent
{
    self = [super init];
    if (self)
    {
        MXJSONModelSetString(_displayname, roomThirdPartyInviteEvent.content[@"display_name"]);
        MXJSONModelSetString(_token, roomThirdPartyInviteEvent.stateKey);
        _originalEvent = roomThirdPartyInviteEvent;
    }
    return self;
}

@end
