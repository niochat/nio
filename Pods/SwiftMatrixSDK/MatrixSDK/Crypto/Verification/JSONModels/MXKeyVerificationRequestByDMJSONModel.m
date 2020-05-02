/*
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

#import "MXKeyVerificationRequestByDMJSONModel.h"

#import "MXEvent.h"

@implementation MXKeyVerificationRequestByDMJSONModel

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXKeyVerificationRequestByDMJSONModel *request = [MXKeyVerificationRequestByDMJSONModel new];
    if (request)
    {
        MXJSONModelSetString(request.body, JSONDictionary[@"body"]);
        MXJSONModelSetString(request.msgtype, JSONDictionary[@"msgtype"]);
        MXJSONModelSetArray(request.methods, JSONDictionary[@"methods"]);
        MXJSONModelSetString(request.to, JSONDictionary[@"to"]);
        MXJSONModelSetString(request.fromDevice, JSONDictionary[@"from_device"]);
    }

    // Sanitiy check
    if (![request.msgtype isEqualToString:kMXMessageTypeKeyVerificationRequest]
        || !request.fromDevice.length
        || !request.methods.count)
    {
        request = nil;
    }

    return request;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];
    JSONDictionary[@"body"] = _body;
    JSONDictionary[@"msgtype"] = _msgtype;
    JSONDictionary[@"methods"] = _methods;
    JSONDictionary[@"to"] = _to;
    JSONDictionary[@"from_device"] = _fromDevice;

    return JSONDictionary;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _msgtype = kMXMessageTypeKeyVerificationRequest;
    }
    return self;
}

@end
