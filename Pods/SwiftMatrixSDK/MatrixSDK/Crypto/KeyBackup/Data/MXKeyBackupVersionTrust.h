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

#import "MXDeviceInfo.h"

NS_ASSUME_NONNULL_BEGIN

@class MXKeyBackupVersionTrustSignature;


/**
 Data model for response to [MXKeyBackup trustForKeyBackupVersion:].
 */
@interface MXKeyBackupVersionTrust : NSObject

/**
 Flag to indicate if the backup is trusted.
 YES if there is a signature that is valid & from a trusted device.
 */
@property (nonatomic) BOOL usable;

/**
 Signatures found in the backup version.
 */
@property (nonatomic) NSArray<MXKeyBackupVersionTrustSignature*> *signatures;

@end


/**
 A signature in a the `MXKeyBackupVersionTrust` object.
 */
@interface MXKeyBackupVersionTrustSignature : NSObject

/**
 The id of the device that signed the backup version.
 */
@property (nonatomic) NSString *deviceId;

/**
 The device that signed the backup version.
 Can be nil if the device is not known.
 */
@property (nonatomic, nullable) MXDeviceInfo *device;

/**
 Flag to indicate the signature from this device is valid.
 */
@property (nonatomic) BOOL valid;

@end

NS_ASSUME_NONNULL_END
