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

#import "MXOlmSessionResult.h"

@implementation MXOlmSessionResult

- (instancetype)initWithDevice:(MXDeviceInfo *)device andOlmSession:(NSString *)sessionId
{
    self = [self init];
    if (self)
    {
        _device = device;
        _sessionId = sessionId;
    }

    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MXOlmSessionResult> %@: %@", _device.deviceId, _sessionId];
}

@end
