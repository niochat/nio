/*
 Copyright 2017 OpenMarket Ltd

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

#import "MXIncomingRoomKeyRequest.h"

@interface MXIncomingRoomKeyRequest ()
{
    void (^shareBock)(void);
}
@end

@implementation MXIncomingRoomKeyRequest

- (instancetype)initWithMXEvent:(MXEvent *)event
{
    self = [super init];
    if (self)
    {
        NSDictionary *content = event.content;

        _userId = event.sender;
        _deviceId = content[@"requesting_device_id"];
        _requestId = content[@"request_id"];
        _requestBody = content[@"body"] ? content[@"body"] : [NSDictionary dictionary];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MXIncomingRoomKeyRequest: %p> requestId %@: from %@:%@", self, _requestId, _userId, _deviceId];
}

@end
