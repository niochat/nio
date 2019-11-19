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

#import <Foundation/Foundation.h>

@class MXEventScanStore, MXEventScan;

/**
 `MXEventScanStoreDelegate` is used to inform changes in the `MXEventScanStore`.
 */
@protocol MXEventScanStoreDelegate <NSObject>

/**
 Inform of `MXEventScan` changes in a `MXEventScanStore`.

 @param eventScanStore The `MXEventScanStore` having changes.
 @param insertions `MXEventScan`s inserted.
 @param modifications `MXEventScan`s modified.
 @param deletions `MXEventScan`s deleted.
 */
- (void)eventScanStore:(nonnull MXEventScanStore*)eventScanStore didObserveChangesWithInsertions:(nonnull NSArray<MXEventScan*>*)insertions modifications:(nonnull NSArray<MXEventScan*>*)modifications deletions:(nonnull NSArray<MXEventScan*>*)deletions;

@end
