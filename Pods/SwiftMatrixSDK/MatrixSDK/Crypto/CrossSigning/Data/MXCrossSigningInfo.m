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

#import "MXCrossSigningInfo_Private.h"

#pragma mark - Constants

NSString *const MXCrossSigningInfoTrustLevelDidChangeNotification = @"MXCrossSigningInfoTrustLevelDidChangeNotification";

@implementation MXCrossSigningInfo

- (MXCrossSigningKey *)masterKeys
{
    return _keys[MXCrossSigningKeyType.master];
}

- (MXCrossSigningKey *)selfSignedKeys
{
    return _keys[MXCrossSigningKeyType.selfSigning];
}

- (MXCrossSigningKey *)userSignedKeys
{
    return _keys[MXCrossSigningKeyType.userSigning];
}

- (BOOL)hasSameKeysAsCrossSigningInfo:(MXCrossSigningInfo*)otherCrossSigningInfo
{
    if (![self.userId isEqualToString:otherCrossSigningInfo.userId])
    {
        return NO;
    }
    
    BOOL hasSameKeys = YES;
    for (NSString *key in _keys)
    {
        if (![self.keys[key].keys isEqualToString:otherCrossSigningInfo.keys[key].keys])
        {
            hasSameKeys = NO;
            break;
        }
    }
    
    return hasSameKeys;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [self init];
    if (self)
    {
        _userId = [aDecoder decodeObjectForKey:@"userId"];
        _keys = [aDecoder decodeObjectForKey:@"keys"];
        _trustLevel = [aDecoder decodeObjectForKey:@"trustLevel"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_userId forKey:@"userId"];
    [aCoder encodeObject:_keys forKey:@"keys"];
    [aCoder encodeObject:_trustLevel forKey:@"trustLevel"];
}


#pragma mark - SDK-Private methods -

- (instancetype)initWithUserId:(NSString *)userId
{
    self = [self init];
    if (self)
    {
        _userId = userId;
        _trustLevel = [MXUserTrustLevel new];
    }
    return self;
}

- (void)setTrustLevel:(MXUserTrustLevel*)trustLevel
{
    _trustLevel = trustLevel;
}

- (BOOL)updateTrustLevel:(MXUserTrustLevel*)trustLevel
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
        [[NSNotificationCenter defaultCenter] postNotificationName:MXCrossSigningInfoTrustLevelDidChangeNotification object:self userInfo:nil];
    });
}

- (void)addCrossSigningKey:(MXCrossSigningKey*)crossSigningKey type:(NSString*)type
{
    NSMutableDictionary<NSString*, MXCrossSigningKey*> *keys = [_keys mutableCopy];
    if (!keys)
    {
        keys = [NSMutableDictionary dictionary];
    }
    keys[type] = crossSigningKey;

    _keys = keys;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MXCrossSigningInfo: %p> Trusted: %@\nMSK: %@\nSSK: %@\nUSK: %@", self, @(self.trustLevel.isCrossSigningVerified), self.masterKeys, self.selfSignedKeys, self.userSignedKeys];
}

@end
