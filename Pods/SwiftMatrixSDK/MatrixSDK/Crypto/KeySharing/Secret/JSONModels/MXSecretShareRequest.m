/*
 Copyright 2020 The Matrix.org Foundation C.I.C
 
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

#import "MXSecretShareRequest.h"


#pragma mark - Constants

const struct MXSecretShareRequestAction MXSecretShareRequestAction = {
    .request = @"request",
    .requestCancellation = @"request_cancellation"
};


@implementation MXSecretShareRequest

#pragma mark - MXJSONModel

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    NSString *name, *action, *requestingDeviceId, *requestId;
    
    MXJSONModelSetString(name, JSONDictionary[@"name"]);
    MXJSONModelSetString(action, JSONDictionary[@"action"]);
    MXJSONModelSetString(requestingDeviceId, JSONDictionary[@"requesting_device_id"]);
    MXJSONModelSetString(requestId, JSONDictionary[@"request_id"]);
    
    // Sanitiy check
    if (!action
        || !requestingDeviceId
        || !requestId)
    {
        return nil;
    }
    
    MXSecretShareRequest *model = [MXSecretShareRequest new];
    model.name = name;
    model.action = action;
    model.requestingDeviceId = requestingDeviceId;
    model.requestId = requestId;

    return model;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [@{
                                             @"action": _action,
                                             @"requesting_device_id": _requestingDeviceId,
                                             @"request_id": _requestId,
                                             } mutableCopy];
    
    if (_name)
    {
        JSONDictionary[@"name"] = _name;
    }
    
    return JSONDictionary;
}

@end
