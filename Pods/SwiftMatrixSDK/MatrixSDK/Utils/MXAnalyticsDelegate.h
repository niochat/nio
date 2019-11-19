/*
 Copyright 2017 Avery Pierce
 
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

/**
 The MXAnalyticsDelegate protocol is used to capture analytics events.
 If you want to capture these analytics events for your own metrics, you
 should create a class that implements this protocol and set it to the
 MXSDKOptions singleton's analyticsDelegate property.
 
 @code
 MyAnalyticsDelegate *delegate = [[MyAnalyticsDelegate alloc] init];
 [MXSDKOptions shared].analyticsDelegate = delegate;
 @endcode

 You can use the sub-pod `MatrixSDK/GoogleAnalytics` to use a default implementation
 based on Google Analytics. It will send timing events in milliseconds.
 */
@protocol MXAnalyticsDelegate <NSObject>

/**
 Capture an analytics event to track how long it takes for the store to preload.
 */
- (void)trackStartupStorePreloadDuration: (NSTimeInterval)seconds;

/**
 Capture an analytics event for mount data duration
 */
- (void)trackStartupMountDataDuration: (NSTimeInterval)seconds;

/**
 Capture an analytics event for the startup sync time.
 */
- (void)trackStartupSyncDuration: (NSTimeInterval)seconds isInitial: (BOOL)isInitial;

/**
 Capture how many rooms a user is a member of.
 */
- (void)trackRoomCount: (NSUInteger)roomCount;

@end


