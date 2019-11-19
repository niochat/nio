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

@import Foundation;
#import "MXAntivirusScanStatus.h"

@class MXMediaScan;

/**
 `MXEventScan` represents event scan information based on media content scans.
 */
@interface MXEventScan : NSObject

/**
 The event id of the associated event.
 */
@property (nonatomic, nonnull) NSString *eventId;

/**
 The scan status of event. Composed by mediaScans status.
 */
@property (nonatomic) MXAntivirusScanStatus antivirusScanStatus;

/**
 The media scans of event. An event may contain multiple medias like media url and thumbnail url.
 */
@property (nonatomic, strong, nonnull) NSArray<MXMediaScan*> *mediaScans;

/**
 The last scan date.
 */
@property (nonatomic, strong, nullable) NSDate *antivirusScanDate;

@end
