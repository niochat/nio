/*
 Copyright 2019 New Vector Ltd

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

#import "MXKeyVerificationMac.h"


@implementation MXKeyVerificationMac

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXKeyVerificationMac *model = [[MXKeyVerificationMac alloc] initWithJSONDictionary:JSONDictionary];
    if (model)
    {
        MXJSONModelSetDictionary(model.mac, JSONDictionary[@"mac"]);
        MXJSONModelSetString(model.keys, JSONDictionary[@"keys"]);
    }

    return model;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = self.JSONDictionaryWithTransactionId;

    if (_keys)
    {
        JSONDictionary[@"mac"] = _mac;
    }
    if (_mac)
    {
        JSONDictionary[@"keys"] = _keys;
    }

    return JSONDictionary;
}

- (BOOL)isValid
{
    BOOL isValid = YES;

    if (_mac.count == 0 || _keys.length == 0)
    {
        NSLog(@"[MXKeyVerification] Invalid MXKeyVerificationMac: %@", self);
        isValid = NO;
    }

    return isValid;
}

@end
