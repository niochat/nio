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

/**
 The device verification state.
 */
typedef NS_ENUM(NSInteger, MXDeviceVerification)
{
    /**
     The user has not yet verified this device.
     */
    MXDeviceUnverified,

    /**
     The user has verified this device.
     */
    MXDeviceVerified,

    /**
     The user has blocked the device.
     */
    MXDeviceBlocked,

    /**
     This is the first time the user sees the device.

     Note: The position of this value in the enum does not reflect the life cycle of the verification
     state. It is at the end because it was added afterwards and we need to stay compatible
     with what was stored in the crypto store.
     */
    MXDeviceUnknown

};


/**
 `MXDeviceTrustLevel` represents the ways in which we trust a device.
 */
@interface MXDeviceTrustLevel : NSObject <NSCoding>

/**
 YES if this device is verified via any means.
 */
@property (nonatomic, readonly) BOOL isVerified;

/**
 YES if this device is verified via cross signing.
 */
@property (nonatomic, readonly) BOOL isCrossSigningVerified;

/**
 Local device verication state
 */
@property (nonatomic, readonly) MXDeviceVerification localVerificationStatus;
@property (nonatomic, readonly) BOOL isLocallyVerified;

@end


#pragma mark - Factory

@interface MXDeviceTrustLevel()

+ (MXDeviceTrustLevel*)trustLevelWithLocalVerificationStatus:(MXDeviceVerification)localVerificationStatus
                                        crossSigningVerified:(BOOL)crossSigningVerified;

@end

NS_ASSUME_NONNULL_END
