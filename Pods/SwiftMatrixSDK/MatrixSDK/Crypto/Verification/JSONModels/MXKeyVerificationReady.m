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

#import "MXKeyVerificationReady.h"

#import "MXSASTransaction.h"


@implementation MXKeyVerificationReady

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXKeyVerificationReady *model = [[MXKeyVerificationReady alloc] initWithJSONDictionary:JSONDictionary];
    if (model)
    {
        MXJSONModelSetArray(model.methods, JSONDictionary[@"methods"]);
        MXJSONModelSetString(model.fromDevice, JSONDictionary[@"from_device"]);
    }

    // Sanitiy check
    if (!model.fromDevice.length)
    {
        model = nil;
    }

    return model;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [@{
                                             @"methods": _methods,
                                             @"from_device": _fromDevice,
                                             } mutableCopy];


    [JSONDictionary addEntriesFromDictionary:self.JSONDictionaryWithTransactionId];

    return JSONDictionary;
}


- (BOOL)isValid
{
    BOOL isValid = YES;

    if (_methods.count == 0)
    {
        NSLog(@"[MXKeyVerification] Invalid MXKeyVerificationReady: %@", self);
        isValid = NO;
    }

    return isValid;
}

@end
