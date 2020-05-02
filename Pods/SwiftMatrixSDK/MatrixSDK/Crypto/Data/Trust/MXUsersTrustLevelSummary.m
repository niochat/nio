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

#import "MXUsersTrustLevelSummary.h"

@interface MXUsersTrustLevelSummary()

@property (nonatomic, strong, readwrite) NSProgress *trustedUsersProgress;
@property (nonatomic, strong, readwrite) NSProgress *trustedDevicesProgress;

@end

@implementation MXUsersTrustLevelSummary

- (instancetype)initWithTrustedUsersProgress:(NSProgress*)trustedUsersProgress andTrustedDevicesProgress:(NSProgress*)trustedDevicesProgress
{
    self = [super init];
    if (self)
    {
        self.trustedUsersProgress = trustedUsersProgress;
        self.trustedDevicesProgress = trustedDevicesProgress;
    }
    return self;
}


#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [self init];
    if (self)
    {
        NSUInteger usersCount = [aDecoder decodeIntegerForKey:@"usersCount"];
        NSUInteger trustedUsersCount = [aDecoder decodeIntegerForKey:@"trustedUsersCount"];
        NSUInteger devicesCount = [aDecoder decodeIntegerForKey:@"devicesCount"];
        NSUInteger trustedDevicesCount = [aDecoder decodeIntegerForKey:@"trustedDevicesCount"];
        
        self.trustedUsersProgress = [NSProgress progressWithTotalUnitCount:usersCount];
        self.trustedUsersProgress.completedUnitCount = trustedUsersCount;
        
        self.trustedDevicesProgress = [NSProgress progressWithTotalUnitCount:devicesCount];
        self.trustedDevicesProgress.completedUnitCount = trustedDevicesCount;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInteger:self.trustedUsersProgress.totalUnitCount forKey:@"usersCount"];
    [aCoder encodeInteger:self.trustedUsersProgress.completedUnitCount forKey:@"trustedUsersCount"];
    [aCoder encodeInteger:self.trustedDevicesProgress.totalUnitCount forKey:@"devicesCount"];
    [aCoder encodeInteger:self.trustedDevicesProgress.completedUnitCount forKey:@"trustedDevicesCount"];
}


@end
