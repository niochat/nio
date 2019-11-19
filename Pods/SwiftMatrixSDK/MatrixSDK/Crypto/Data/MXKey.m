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

#import "MXKey.h"

NSString *const kMXKeyCurve25519Type = @"curve25519";
NSString *const kMXKeySignedCurve25519Type = @"signed_curve25519";
NSString *const kMXKeyEd25519Type = @"ed25519";

@implementation MXKey

- (instancetype)initWithType:(NSString *)type keyId:(NSString *)keyId value:(NSString *)value
{
    self = [self init];
    if (self)
    {
        _type = type;
        _keyId = keyId;
        _value = value;
    }

    return self;
}

- (NSString *)keyFullId
{
    return [NSString stringWithFormat:@"%@:%@", _type, _keyId];
}

- (void)setKeyFullId:(NSString *)keyFullId
{
    NSArray<NSString *> *components = [keyFullId componentsSeparatedByString:@":"];

    if (components.count == 2)
    {
        _type = components[0];
        _keyId = components[1];
    }
    else
    {
        NSLog(@"[MXKey] setKeyFullId: ERROR: cannot process keyFullId: %@", keyFullId);
    }
}


#pragma mark - MXJSONModel
+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXKey *key = [[MXKey alloc] init];
    if (key)
    {
        MXJSONModelSetString(key.keyFullId, JSONDictionary.allKeys[0]);
        MXJSONModelSetString(key.value, JSONDictionary[key.keyFullId][@"key"]);
        key.signatures = [[MXUsersDevicesMap<NSString*> alloc] initWithMap:JSONDictionary[key.keyFullId][@"signatures"]];
    }

    return key;
}

- (NSDictionary *)JSONDictionary
{
    NSDictionary *JSONDictionary;

    NSString *keyFullId = self.keyFullId;
    if (keyFullId && _value)
    {
        JSONDictionary = @{
                           keyFullId: _value
                           };
    }
    return JSONDictionary;
}

- (NSDictionary *)signalableJSONDictionary
{
    return @{
             @"key": _value
             };
}

- (NSString *)description
{
    return self.JSONDictionary.description;
}

@end
