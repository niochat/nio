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

#import "MXEnumConstants.h"
#import "MXInvite3PID.h"


NS_ASSUME_NONNULL_BEGIN


/**
 Parameters to create a room.
 */
@interface MXRoomCreationParameters : NSObject

// The room name.
@property (nonatomic, nullable) NSString *name;

// The visibility of the room in the current HS's room directory.
@property (nonatomic, nullable) MXRoomDirectoryVisibility visibility;

// The room alias on the home server the room will be created.
@property (nonatomic, nullable) NSString *roomAlias;

// The room topic.
@property (nonatomic, nullable) NSString *topic;

// A list of user IDs to invite to the room. This will tell the server to invite
// everyone in the list to the newly created room.
@property (nonatomic, nullable) NSArray<NSString*> *inviteArray;

// A list of objects representing third party IDs to invite into the room.
@property (nonatomic, nullable) NSArray<MXInvite3PID*> *invite3PIDArray;

// This flag makes the server set the is_direct flag on the m.room.member events
// sent to the users in invite and invite_3pid. NO by default.
@property (nonatomic) BOOL isDirect;

// Convenience parameter for setting various default state events based on a preset.
@property (nonatomic, nullable) MXRoomPreset preset;

// A list of state events to set in the new room.
@property (nonatomic, nullable) NSArray<NSDictionary*> *initialStateEvents;


/**
 Return the data as a JSON dictionary.

 @return a JSON dictionary.
 */
- (NSDictionary*)JSONDictionary;

@end


#pragma mark - Factory

@interface MXRoomCreationParameters ()

+ (instancetype)parametersForDirectRoomWithUser:(NSString*)userId;

+ (NSDictionary*)initialStateEventForEncryptionWithAlgorithm:(NSString*)algorithm;

@end

NS_ASSUME_NONNULL_END
