/*
 Copyright 2016 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2019 New Vector Ltd

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
 Matrix algorithm tag for olm.
 */
FOUNDATION_EXPORT NSString *const kMXCryptoOlmAlgorithm;

/**
 Matrix algorithm tag for megolm.
 */
FOUNDATION_EXPORT NSString *const kMXCryptoMegolmAlgorithm;

/**
 Matrix algorithm tag for megolm keys backup.
 */
FOUNDATION_EXPORT NSString *const kMXCryptoMegolmBackupAlgorithm;


#pragma mark - Encrypting error

FOUNDATION_EXPORT NSString *const MXEncryptingErrorDomain;

typedef enum : NSUInteger
{
    // Note: The list of unknown devices is passed into the MXEncryptingErrorUnknownDeviceDevicesKey key in userInfo
    MXEncryptingErrorUnknownDeviceCode
} MXEncryptingErrorCode;

FOUNDATION_EXPORT NSString* const MXEncryptingErrorUnknownDeviceReason;

/**
 In case of MXEncryptingErrorUnknownDeviceCode error, the key in the notification userInfo
 dictionary for the list of unknown devices.
 There are provided as a MXUsersDevicesMap<MXDeviceInfo*> instance.
 */
FOUNDATION_EXPORT NSString *const MXEncryptingErrorUnknownDeviceDevicesKey;


#pragma mark - Backup error

FOUNDATION_EXPORT NSString *const MXKeyBackupErrorDomain;

typedef enum : NSUInteger
{
    MXKeyBackupErrorInvalidStateCode,
    MXKeyBackupErrorInvalidParametersCode,
    MXKeyBackupErrorCannotDeriveKeyCode,
    MXKeyBackupErrorInvalidRecoveryKeyCode,
    MXKeyBackupErrorMissingPrivateKeySaltCode,
    MXKeyBackupErrorMissingAuthDataCode,
    MXKeyBackupErrorInvalidOrMissingLocalPrivateKey,

} MXKeyBackupErrorCode;
