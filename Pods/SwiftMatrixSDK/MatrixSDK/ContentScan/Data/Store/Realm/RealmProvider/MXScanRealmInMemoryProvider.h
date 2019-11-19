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

#import "MXScanRealmProvider.h"

/**
 `MXScanRealmInMemoryProvider` defines a Realm provider conforming to `MXScanRealmProvider` and using in memory data storage.
 */
@interface MXScanRealmInMemoryProvider : NSObject <MXScanRealmProvider>

- (nullable instancetype)initWithAntivirusServerDomain:(nonnull NSString*)antivirusServerDomain NS_DESIGNATED_INITIALIZER;

#pragma mark - Unavailable Methods

/**
 Unavailable initializer.
 */
+ (nonnull instancetype)new NS_UNAVAILABLE;

/**
 Unavailable initializer.
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

@end
