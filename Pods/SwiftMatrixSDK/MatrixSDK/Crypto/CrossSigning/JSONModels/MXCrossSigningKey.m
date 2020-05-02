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

#import "MXCrossSigningKey.h"

#import "MXKey.h"


#pragma mark - Constants

const struct MXCrossSigningKeyType MXCrossSigningKeyType = {
    .master = @"master",
    .selfSigning = @"self_signing",
    .userSigning = @"user_signing"
};


@implementation MXCrossSigningKey

- (instancetype)initWithUserId:(NSString*)userId usage:(NSArray<NSString*>*)usage keys:(NSString*)keys
{
    self = [super init];
    if (self)
    {
        _userId = userId;
        _usage = usage;
        _keys = keys;
    }
    return self;
}

- (void)addSignatureFromUserId:(NSString*)userId publicKey:(NSString*)publicKey signature:(NSString*)signature
{
    if (!_signatures)
    {
        _signatures = [MXUsersDevicesMap new];
    }

    [_signatures setObject:signature
                   forUser:userId
                 andDevice:[NSString stringWithFormat:@"%@:%@", kMXKeyEd25519Type, publicKey]];
}

- (NSString *)signatureFromUserId:(NSString *)userId withPublicKey:(NSString *)publicKey
{
    NSString *keyId = [NSString stringWithFormat:@"%@:%@", kMXKeyEd25519Type, publicKey];
    return [_signatures objectForDevice:keyId forUser:userId];
}

- (NSDictionary *)signalableJSONDictionary
{
    NSMutableDictionary *signalableJSONDictionary = [self.JSONDictionary mutableCopy];
    [signalableJSONDictionary removeObjectForKey:@"signatures"];
    return signalableJSONDictionary;
}


#pragma mark - MXJSONModel

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    NSString *userId, *keys;
    NSArray<NSString*> *usage;
    MXUsersDevicesMap<NSString*> *signatures;

    MXJSONModelSetString(userId, JSONDictionary[@"user_id"]);
    MXJSONModelSetArray(usage, JSONDictionary[@"usage"]);

    NSDictionary *signaturesDict;
    MXJSONModelSetDictionary(signaturesDict, JSONDictionary[@"signatures"]);
    if (signaturesDict)
    {
        signatures = [[MXUsersDevicesMap<NSString*> alloc] initWithMap:signaturesDict];
    }
    else
    {
        signatures  = [MXUsersDevicesMap<NSString*> new];
    }

    NSDictionary<NSString*, NSString*> *keysDict;
    MXJSONModelSetDictionary(keysDict, JSONDictionary[@"keys"]);
    keys = keysDict.allValues.firstObject;

    // Sanitiy check
    if (!userId
        || !usage.count
        || !keys)
    {
        return nil;
    }

    MXCrossSigningKey *model = [[self alloc] initWithUserId:userId usage:usage keys:keys];
    model->_signatures = signatures;

    return model;
}

- (NSDictionary *)JSONDictionary
{
    NSString *keysId = [NSString stringWithFormat:@"%@:%@", kMXKeyEd25519Type, _keys];
    
    NSMutableDictionary *JSONDictionary = [@{
                                             @"user_id": _userId,
                                             @"usage": _usage,
                                             @"keys": @{
                                                     keysId: _keys
                                                     }
                                             } mutableCopy];

    if (_signatures)
    {
        JSONDictionary[@"signatures"] = _signatures.map;
    }

    return JSONDictionary;
}


#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _userId = [aDecoder decodeObjectForKey:@"userId"];
        _usage = [aDecoder decodeObjectForKey:@"usage"];
        _keys = [aDecoder decodeObjectForKey:@"keys"];
        _signatures = [aDecoder decodeObjectForKey:@"signatures"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_userId forKey:@"userId"];
    [aCoder encodeObject:_usage forKey:@"usage"];
    [aCoder encodeObject:_keys forKey:@"keys"];
    [aCoder encodeObject:_signatures forKey:@"signatures"];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MXCrossSigningKey: %p> Keys: %@. Signatures: %@", self, self.keys, self.signatures];
}

@end
