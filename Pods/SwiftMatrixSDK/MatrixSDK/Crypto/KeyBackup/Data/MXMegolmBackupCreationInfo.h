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

#import "MXMegolmBackupAuthData.h"

NS_ASSUME_NONNULL_BEGIN

/**
 `MXMegolmBackupCreationInfo` represents data to create a megolm keys backup on
 the homeserver.
 */
@interface MXMegolmBackupCreationInfo : NSObject

/**
 The algorithm used for storing backups (kMXCryptoMegolmBackupAlgorithm).
 */
@property (nonatomic) NSString *algorithm;

/**
 Authentication data.
 */
@property (nonatomic) MXMegolmBackupAuthData *authData;

/**
 The Base58 recovery key.
 */
@property (nonatomic) NSString *recoveryKey;

@end

NS_ASSUME_NONNULL_END
