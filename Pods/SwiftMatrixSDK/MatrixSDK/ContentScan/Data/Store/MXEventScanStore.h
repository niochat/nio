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
#import "MXEventScanStoreDelegate.h"

@class MXEventScan;

/**
 The `MXEventScanStore` protocol defines an interface that must be implemented to manipulate event scans data.
 */
@protocol MXEventScanStore <NSObject>

/**
 Delegate used to inform changes in the store.
 */
@property (nonatomic, weak, nullable) id<MXEventScanStoreDelegate> delegate;

/**
 Find `MXEventScan` from event id.

 @param eventId The event id of the searched event scan.
 @return `MXEventScan` associated to event id if exists or nil.
 */
- (nullable MXEventScan*)findWithId:(nonnull NSString*)eventId;

/**
 Create or update an `MXEventScan` with initial `antivirusScanStatus` value set to MXAntivirusScanStatusUnknown.

 @param eventId The event id.
 @param mediaURLs The media URLs contained in the event.
 @return Created or updated MXEventScan.
 */
- (nonnull MXEventScan*)createOrUpdateWithId:(nonnull NSString*)eventId andMediaURLs:(nonnull NSArray<NSString*>*)mediaURLs;

/**
 Create or update an `MXEventScan`.

 @param eventId The event id of `MXEventScan` to create or update.
 @param antivirusScanStatus The antivirus scan status to set when event scan is created for the first time.
 @param mediaURLs The media URLs contained in the event.
 @return Created or updated `MXEventScan`.
 */
- (nonnull MXEventScan*)createOrUpdateWithId:(nonnull NSString*)eventId initialAntivirusStatus:(MXAntivirusScanStatus)antivirusScanStatus andMediaURLs:(nonnull NSArray<NSString*>*)mediaURLs;

/**
 Update antivirus scan status of an `MXEventScan`.

 @param antivirusScanStatus Updated antivirus scan status.
 @param eventId The event id of the `MXEventScan` to update.
 @return true if the `MXEventScan` has been updated.
 */
- (BOOL)updateAntivirusScanStatus:(MXAntivirusScanStatus)antivirusScanStatus forId:(nonnull NSString*)eventId;

/**
 Update antivirus scan status of an `MXEventScan` from associated media scans antivirus statuses and update antivirus scan date.

 @param antivirusScanDate The last antivirus scan date.
 @param eventId The event id of the `MXEventScan` to update.
 @return true if the `MXEventScan` has been updated.
 */
- (BOOL)updateAntivirusScanStatusFromMediaScansAntivirusScanStatusesAndAntivirusScanDate:(nonnull NSDate*)antivirusScanDate forId:(nonnull NSString*)eventId;

/**
 Reset all `MXEventScan` in `MXAntivirusScanStatusInProgress` status to `MXAntivirusScanStatusUnknown` status.
 */
- (void)resetAllAntivirusScanStatusInProgressToUnknown;

/**
 Delete all `MXEventScan` from the store.
 */
- (void)deleteAll;

@end
