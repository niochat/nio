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

#import "MXSecretShareSend.h"

@implementation MXSecretShareSend

#pragma mark - MXJSONModel

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    NSString *requestId, *secret;
    
    MXJSONModelSetString(requestId, JSONDictionary[@"request_id"]);
    MXJSONModelSetString(secret, JSONDictionary[@"secret"]);

    // Sanitiy check
    if (!requestId
        || !secret)
    {
        return nil;
    }
    
    MXSecretShareSend *model = [MXSecretShareSend new];
    model.requestId = requestId;
    model.secret = secret;

    return model;
}

- (NSDictionary *)JSONDictionary
{
    return @{
             @"request_id": _requestId,
             @"secret": _secret,
             };
}

@end
