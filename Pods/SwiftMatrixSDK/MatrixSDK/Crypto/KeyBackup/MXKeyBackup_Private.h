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

#import "MXKeyBackup.h"

@class MXCrypto;

NS_ASSUME_NONNULL_BEGIN

/**
 The `MXKeyBackup_Private` extension exposes internal operations.
 */
@interface MXKeyBackup ()

/**
 Constructor.

 @param crypto the related 'MXCrypto'.
 */
- (instancetype)initWithCrypto:(MXCrypto *)crypto;

/**
 Check the server for an active key backup.

 If one is present and has a valid signature from one of the user's verified
 devices, start backing up to it.
 */
- (void)checkAndStartKeyBackup;

/**
 * Reset all local key backup data.
 */
- (void)resetKeyBackupData;

/**
 Do a backup if there are new keys.
 */
- (void)maybeSendKeyBackup;

@end

NS_ASSUME_NONNULL_END
