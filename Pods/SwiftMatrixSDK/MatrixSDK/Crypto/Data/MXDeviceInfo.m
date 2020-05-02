/*
 Copyright 2016 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd

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

#import "MXDeviceInfo_Private.h"

#pragma mark - Constants

NSString *const MXDeviceInfoTrustLevelDidChangeNotification = @"MXDeviceInfoTrustLevelDidChangeNotification";

@implementation MXDeviceInfo

- (instancetype)initWithDeviceId:(NSString *)deviceId
{
    self = [super init];
    if (self)
    {
        _deviceId = deviceId;
        _trustLevel = [MXDeviceTrustLevel new];
    }
    return self;
}

- (NSString *)fingerprint
{
    return _keys[[NSString stringWithFormat:@"ed25519:%@", _deviceId]];
}

- (NSString *)identityKey
{
    return _keys[[NSString stringWithFormat:@"curve25519:%@", _deviceId]];

}

- (NSString *)displayName
{
    return _unsignedData[@"device_display_name"];
}

- (MXDeviceVerification)verified
{
    return self.trustLevel.localVerificationStatus;
}


#pragma mark - SDK-Private methods

- (void)setTrustLevel:(MXDeviceTrustLevel *)trustLevel
{
    _trustLevel = trustLevel;
}

- (BOOL)updateTrustLevel:(MXDeviceTrustLevel*)trustLevel
{
    BOOL updated = NO;

    if (![_trustLevel isEqual:trustLevel])
    {
        _trustLevel = trustLevel;
        updated = YES;
        [self didUpdateTrustLevel];
    }

    return updated;
}

- (void)didUpdateTrustLevel
{
    dispatch_async(dispatch_get_main_queue(),^{
        [[NSNotificationCenter defaultCenter] postNotificationName:MXDeviceInfoTrustLevelDidChangeNotification object:self userInfo:nil];
    });
}

#pragma mark - MXJSONModel
+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXDeviceInfo *deviceInfo = [[MXDeviceInfo alloc] initWithDeviceId:JSONDictionary[@"device_id"]];
    if (deviceInfo)
    {
        MXJSONModelSetString(deviceInfo.userId, JSONDictionary[@"user_id"]);
        MXJSONModelSetArray(deviceInfo.algorithms, JSONDictionary[@"algorithms"]);
        MXJSONModelSetDictionary(deviceInfo.keys, JSONDictionary[@"keys"]);
        MXJSONModelSetDictionary(deviceInfo.signatures, JSONDictionary[@"signatures"]);
        MXJSONModelSetDictionary(deviceInfo.unsignedData, JSONDictionary[@"unsigned"]);
    }

    return deviceInfo;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];

    JSONDictionary[@"device_id"] = _deviceId;
    if (_userId)
    {
        JSONDictionary[@"user_id"] = _userId;
    }
    if (_algorithms)
    {
        JSONDictionary[@"algorithms"] = _algorithms;
    }
    if (_keys)
    {
        JSONDictionary[@"keys"] = _keys;
    }
    if (_signatures)
    {
        JSONDictionary[@"signatures"] = _signatures;
    }
    if (_unsignedData)
    {
        JSONDictionary[@"unsigned"] = _unsignedData;
    }

    return JSONDictionary;
}

- (NSDictionary *)signalableJSONDictionary
{
    NSMutableDictionary *signalableJSONDictionary = [NSMutableDictionary dictionary];

    signalableJSONDictionary[@"device_id"] = _deviceId;
    if (_userId)
    {
        signalableJSONDictionary[@"user_id"] = _userId;
    }
    if (_algorithms)
    {
        signalableJSONDictionary[@"algorithms"] = _algorithms;
    }
    if (_keys)
    {
        signalableJSONDictionary[@"keys"] = _keys;
    }

    return signalableJSONDictionary;
}


#pragma mark - NSCoding
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _deviceId = [aDecoder decodeObjectForKey:@"deviceId"];
        _userId = [aDecoder decodeObjectForKey:@"userId"];
        _algorithms = [aDecoder decodeObjectForKey:@"algorithms"];
        _keys = [aDecoder decodeObjectForKey:@"keys"];
        _signatures = [aDecoder decodeObjectForKey:@"signatures"];
        _unsignedData = [aDecoder decodeObjectForKey:@"unsignedData"];
        _trustLevel = [aDecoder decodeObjectForKey:@"trustLevel"];
        if (!_trustLevel)
        {
            // Manage migration from old data schema
            MXDeviceVerification verified = [(NSNumber*)[aDecoder decodeObjectForKey:@"verified"] unsignedIntegerValue];

            _trustLevel = [MXDeviceTrustLevel trustLevelWithLocalVerificationStatus:verified
                                                               crossSigningVerified:NO];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_deviceId forKey:@"deviceId"];
    if (_userId)
    {
        [aCoder encodeObject:_userId forKey:@"userId"];
    }
    if (_algorithms)
    {
        [aCoder encodeObject:_algorithms forKey:@"algorithms"];
    }
    if (_keys)
    {
        [aCoder encodeObject:_keys forKey:@"keys"];
    }
    if (_signatures)
    {
        [aCoder encodeObject:_signatures forKey:@"signatures"];
    }
    if (_unsignedData)
    {
        [aCoder encodeObject:_unsignedData forKey:@"unsignedData"];
    }
    [aCoder encodeObject:_trustLevel forKey:@"trustLevel"];
}

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }

    if (![object isKindOfClass:MXDeviceInfo.class])
    {
        return NO;
    }
    
    return [self isEqualToDeviceInfo:(MXDeviceInfo *)object];
}

- (BOOL)isEqualToDeviceInfo:(MXDeviceInfo *)other
{
    return
    [_deviceId isEqualToString:other.deviceId]
    && [_userId isEqualToString:other.userId]
    && [_algorithms isEqualToArray:other.algorithms]
    && [_keys isEqualToDictionary:other.keys]
    && [_signatures isEqualToDictionary:other.signatures]
    && [_unsignedData isEqualToDictionary:other.unsignedData]
    && [_trustLevel isEqual:other.trustLevel];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@:%@ - curve25519: %@ (trustLevel: %@)", _userId, _deviceId, self.identityKey, _trustLevel];
}

@end
