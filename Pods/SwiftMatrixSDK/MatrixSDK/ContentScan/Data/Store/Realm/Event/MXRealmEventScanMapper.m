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

#import "MXRealmEventScanMapper.h"

#import "MXRealmMediaScanMapper.h"

@interface MXRealmEventScanMapper ()

@property (nonatomic, strong) MXRealmMediaScanMapper *realmMediaScanMapper;

@end

@implementation MXRealmEventScanMapper

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _realmMediaScanMapper = [MXRealmMediaScanMapper new];
    }
    return self;
}

- (nonnull MXEventScan*)eventScanFromRealmEventScan:(nonnull MXRealmEventScan*)realmEventScan
{
    MXEventScan *eventScan = [MXEventScan new];
    eventScan.eventId = realmEventScan.eventId;
    eventScan.antivirusScanStatus = realmEventScan.antivirusScanStatus;
    eventScan.antivirusScanDate = realmEventScan.antivirusScanDate;
    
    NSMutableArray<MXMediaScan*> *mediaScans = [NSMutableArray new];
    
    for (MXRealmMediaScan *realmMediaScan in realmEventScan.mediaScans)
    {
        MXMediaScan *mediaScan = [self.realmMediaScanMapper mediaScanFromRealmMediaScan:realmMediaScan];
        [mediaScans addObject:mediaScan];
    }
    
    eventScan.mediaScans = mediaScans;
    
    return eventScan;
}

@end
