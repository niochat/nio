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

#import "MXQRCodeKeyVerificationStart.h"

#import "MXQRCodeTransaction.h"

@implementation MXQRCodeKeyVerificationStart

- (instancetype)initWithJSONDictionary:(NSDictionary *)JSONDictionary
{
    self = [super initWithJSONDictionary:JSONDictionary];
    if (self)
    {
        MXJSONModelSetString(_sharedSecret, JSONDictionary[@"secret"]);
    }    
    
    if (!self.isValid)
    {
        return nil;
    }
    
    return self;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [[super JSONDictionary] mutableCopy];
    
    JSONDictionary[@"secret"] = _sharedSecret;
    
    [JSONDictionary addEntriesFromDictionary:self.JSONDictionaryWithTransactionId];
    
    return JSONDictionary;
}

- (BOOL)isValid
{
    if (self.fromDevice.length == 0
        || self.method.length == 0
        || ![self.method isEqualToString:MXKeyVerificationMethodReciprocate]
        || self.sharedSecret.length == 0)
    {
        NSLog(@"[MXKeyVerification] Invalid MXQRCodeKeyVerificationStart: %@", self);
        return NO;
    }
    
    return YES;
}

@end
