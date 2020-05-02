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

#import "MXKeyVerificationKey.h"


@implementation MXKeyVerificationKey

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXKeyVerificationKey *model = [[MXKeyVerificationKey alloc] initWithJSONDictionary:JSONDictionary];
    if (model)
    {
        MXJSONModelSetString(model.key, JSONDictionary[@"key"]);
    }

    return model;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = self.JSONDictionaryWithTransactionId;
    
    if (_key)
    {
        JSONDictionary[@"key"] = _key;
    }

    return JSONDictionary;
}

- (BOOL)isValid
{
    BOOL isValid = YES;

    if (_key.length == 0)
    {
        NSLog(@"[MXKeyVerification] Invalid MXKeyVerificationKey: %@", self);
        isValid = NO;
    }

    return isValid;
}

@end
