/*
 Copyright 2018 New Vector Ltd
 
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

#import "MXRealmEventScan.h"

const struct MXRealmEventScanAttributes MXRealmEventScanAttributes = {
    .eventId = @"eventId",
    .antivirusScanStatusRawValue = @"antivirusScanStatusRawValue",
    .antivirusScanDate = @"antivirusScanDate"
};

const struct MXRealmEventScanRelationships MXRealmEventScanRelationships = {
    .mediaScans = @"mediaScans"
};

@implementation MXRealmEventScan

#pragma mark - Realm override

+ (NSString *)primaryKey
{
    return MXRealmEventScanAttributes.eventId;
}

+ (NSArray *)requiredProperties
{
    return @[MXRealmEventScanAttributes.eventId,
             MXRealmEventScanAttributes.antivirusScanStatusRawValue];
}

+ (NSDictionary *)defaultPropertyValues
{
    return @{ MXRealmEventScanAttributes.antivirusScanStatusRawValue: @(MXAntivirusScanStatusUnknown) };
}

#pragma mark - Public

- (MXAntivirusScanStatus)antivirusScanStatus
{
    return (MXAntivirusScanStatus)self.antivirusScanStatusRawValue;
}

@end
