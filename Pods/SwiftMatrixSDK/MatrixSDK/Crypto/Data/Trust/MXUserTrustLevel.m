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

#import "MXUserTrustLevel.h"

@implementation MXUserTrustLevel

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _isCrossSigningVerified = NO;
        _isLocallyVerified = NO;
    }
    return self;
}

+ (MXUserTrustLevel *)trustLevelWithCrossSigningVerified:(BOOL)crossSigningVerified locallyVerified:(BOOL)locallyVerified
{
    MXUserTrustLevel *trustLevel = [MXUserTrustLevel new];
    trustLevel->_isCrossSigningVerified = crossSigningVerified;
    trustLevel->_isLocallyVerified = locallyVerified;

    return trustLevel;
}


- (BOOL)isVerified
{
    return _isCrossSigningVerified || _isLocallyVerified;
}


- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }

    BOOL isEqual = NO;

    if ([object isKindOfClass:MXUserTrustLevel.class])
    {
        MXUserTrustLevel *other = object;
        isEqual = other.isCrossSigningVerified == self.isCrossSigningVerified;
        isEqual &= other.isLocallyVerified == self.isLocallyVerified;
    }

    return isEqual;
}


#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _isCrossSigningVerified = [aDecoder decodeBoolForKey:@"isCrossSigningVerified"];
        _isLocallyVerified = [aDecoder decodeBoolForKey:@"isLocallyVerified"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeBool:_isCrossSigningVerified forKey:@"isCrossSigningVerified"];
    [aCoder encodeBool:_isLocallyVerified forKey:@"isLocallyVerified"];
}

@end
