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

#import "MXKeyVerificationStart.h"

@implementation MXKeyVerificationStart

- (instancetype)initWithJSONDictionary:(NSDictionary *)JSONDictionary
{
    self = [super initWithJSONDictionary:JSONDictionary];
    if (self)
    {
        MXJSONModelSetString(_method, JSONDictionary[@"method"]);
        MXJSONModelSetString(_fromDevice, JSONDictionary[@"from_device"]);
    }
    
    return self;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [@{
                                             @"method": _method,
                                             @"from_device": _fromDevice,
                                             } mutableCopy];

    [JSONDictionary addEntriesFromDictionary:self.JSONDictionaryWithTransactionId];

    return JSONDictionary;
}

- (BOOL)isValid
{
    // Must be handled by the specific implementation
    NSAssert(NO, @"%@ does not implement isValid", self.class);
    return NO;
}

@end
