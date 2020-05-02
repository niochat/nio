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

NS_ASSUME_NONNULL_BEGIN

@interface MXUserTrustLevel : NSObject <NSCoding>

/**
 YES if this user is verified via any means.
 */
@property (nonatomic, readonly) BOOL isVerified;

/**
 YES if this user is verified via cross signing.
 */
@property (nonatomic, readonly) BOOL isCrossSigningVerified;

/**
 YES if this user is verified locally.
 */
@property (nonatomic, readonly) BOOL isLocallyVerified;

@end


#pragma mark - Factory

@interface MXUserTrustLevel()

+ (MXUserTrustLevel*)trustLevelWithCrossSigningVerified:(BOOL)crossSigningVerified locallyVerified:(BOOL)locallyVerified;

@end

NS_ASSUME_NONNULL_END
