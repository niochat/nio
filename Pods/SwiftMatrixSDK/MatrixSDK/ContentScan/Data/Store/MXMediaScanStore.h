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
#import "MXMediaScan.h"
#import "MXMediaScanStoreDelegate.h"

/**
 The `MXMediaScanStore` protocol defines an interface that must be implemented to manipulate media scans data.
 */
@protocol MXMediaScanStore <NSObject>

/**
 Delegate used to inform changes in the store.
 */
@property (nonatomic, weak, nullable) id<MXMediaScanStoreDelegate> delegate;

/**
 Find or create an `MXMediaScan` with media URL.

 @param url The media URL.
 @return Found or created `MXMediaScan`.
 */
- (nonnull MXMediaScan*)findOrCreateWithURL:(nonnull NSString*)url;

/**
 Find or create an `MXMediaScan` with media URL and set an initial `antivirusScanStatus` .

 @param url The media URL.
 @param initialAntivirusStatus The antivirus scan status to set when media scan is created for the first time.
 @return Found or created `MXMediaScan`.
 */
- (nonnull MXMediaScan*)findOrCreateWithURL:(nonnull NSString*)url initialAntivirusStatus:(MXAntivirusScanStatus)initialAntivirusStatus;

/**
 Find an `MXMediaScan` from media URL.

 @param url The mdeia URL of the searched media scan.
 @return `MXMediaScan` associated to the media URL if exists or nil.
 */
- (nullable MXMediaScan*)findWithURL:(nonnull NSString*)url;

/**
 Update antivirus scan status of an `MXMediaScan`.

 @param antivirusScanStatus Updated antivirus scan status.
 @param url The media URL of the `MXMediaScan` to update.
 @return true if the `MXMediaScan` has been updated.
 */
- (BOOL)updateAntivirusScanStatus:(MXAntivirusScanStatus)antivirusScanStatus forURL:(nonnull NSString*)url;

/**
 Update an `MXMediaScan`.

 @param antivirusScanStatus Updated antivirus scan status.
 @param antivirusScanInfo Updated antivirus scan information.
 @param antivirusScanDate The last antivirus scan date.
 @param url The media URL of the `MXMediaScan` to update.
 @return true if the `MXMediaScan` has been updated.
 */
- (BOOL)updateAntivirusScanStatus:(MXAntivirusScanStatus)antivirusScanStatus
                antivirusScanInfo:(nullable NSString*)antivirusScanInfo
                antivirusScanDate:(nonnull NSDate*)antivirusScanDate
                           forURL:(nonnull NSString*)url;

/**
 Reset all `MXMediaScan` in `MXAntivirusScanStatusInProgress` status to `MXAntivirusScanStatusUnknown` status.
 */
- (void)resetAllAntivirusScanStatusInProgressToUnknown;

/**
 Delete all `MXMediaScan` from the store.
 */
- (void)deleteAll;

@end
