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

#import <Foundation/Foundation.h>

#import "MXCrossSigningKey.h"
#import "MXUserTrustLevel.h"


NS_ASSUME_NONNULL_BEGIN

/**
 Notification sent when the user trust level has been updated.
 */
extern NSString *const MXCrossSigningInfoTrustLevelDidChangeNotification;

/**
 `MXCrossSigningInfo` gathers information about a user's cross-signing keys.
 */
@interface MXCrossSigningInfo : NSObject <NSCoding>

/**
 The user's id.
 */
@property (nonatomic, readonly) NSString *userId;

// All cross signing keys
// key type (MXCrossSigningKeyType) -> keys
@property (nonatomic, readonly) NSDictionary<NSString*, MXCrossSigningKey*> *keys;

// Shorcuts to a specific key
@property (nonatomic, nullable, readonly) MXCrossSigningKey *masterKeys;
@property (nonatomic, nullable, readonly) MXCrossSigningKey *selfSignedKeys;
@property (nonatomic, nullable, readonly) MXCrossSigningKey *userSignedKeys;

- (BOOL)hasSameKeysAsCrossSigningInfo:(MXCrossSigningInfo*)otherCrossSigningInfo;

#pragma mark - Additional information

@property (nonatomic, readonly) MXUserTrustLevel *trustLevel;

@end

NS_ASSUME_NONNULL_END
