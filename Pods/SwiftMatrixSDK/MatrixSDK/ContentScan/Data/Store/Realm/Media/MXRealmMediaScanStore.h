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
#import "MXMediaScanStore.h"
#import "MXRealmMediaScan.h"
#import "MXScanRealmProvider.h"

/**
 The `MXRealmMediaScanStore` is a Realm implementation of `MXMediaScanStore`.
 */
@interface MXRealmMediaScanStore : NSObject <MXMediaScanStore>

@property (nonatomic, weak, nullable) id<MXMediaScanStoreDelegate> delegate;

- (nullable instancetype)initWithRealmProvider:(nonnull id<MXScanRealmProvider>)realmProvider;

- (nonnull NSArray<MXRealmMediaScan*>*)findOrCreateRealmMediaScansWithURLs:(nonnull NSArray<NSString*>*)urls initialAntivirusStatus:(MXAntivirusScanStatus)antivirusScanStatus inRealm:(nonnull RLMRealm*)realm useTransaction:(BOOL)useTransaction;

@end
