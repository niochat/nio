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

#import "MXJSONModel.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Backup data for one key.
 */
@interface MXKeyBackupData : MXJSONModel

/**
 The index of the first message in the session that the key can decrypt.
 */
@property (nonatomic) NSInteger firstMessageIndex;

/**
 The number of times this key has been forwarded.
 */
@property (nonatomic) NSInteger forwardedCount;

/**
 Whether the device backing up the key has verified the device that the key is from.
 */
@property (nonatomic) BOOL verified;

/**
 Algorithm-dependent data.
 */
@property (nonatomic) NSDictionary *sessionData;

@end

/**
 Backup data for several keys within a room.
 */
@interface MXRoomKeysBackupData : MXJSONModel

/**
 
 sessionId -> MXKeyBackupData
 */
@property (nonatomic) NSDictionary<NSString*, MXKeyBackupData*> *sessions;

@end

/**
 Backup data for several keys in several rooms.
 */
@interface MXKeysBackupData : MXJSONModel

/**
 roomId -> MXRoomKeysBackupData
 */
@property (nonatomic) NSDictionary<NSString*, MXRoomKeysBackupData*> *rooms;

@end

NS_ASSUME_NONNULL_END
