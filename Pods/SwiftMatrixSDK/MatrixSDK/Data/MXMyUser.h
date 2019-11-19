/*
 Copyright 2014 OpenMarket Ltd

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

#import "MXUser.h"

/**
 `MXMyUser` is a MXUser derivated object that represents the profile of the currently logged in user.
 It brings helper methods to update the user profile
 */
@interface MXMyUser : MXUser

/**
 Create an instance for an user ID.

 @param userId The id to the user.

 @return the newly created MXUser instance.
 */
- (instancetype)initWithUserId:(NSString*)userId andDisplayname:(NSString*)displayname andAvatarUrl:(NSString*)avatarUrl;

/**
 The mxSession to the home server. 
 It must be set in order to update user's profile to the home server.
 */
@property (nonatomic) MXSession *mxSession;

/**
 Set the display name.

 @param displayname the new display name.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (void)setDisplayName:(NSString*)displayname
               success:(void (^)(void))success
               failure:(void (^)(NSError *error))failure;


/**
 Set the avatar url.

 @param avatarUrl the new avatar url.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (void)setAvatarUrl:(NSString*)avatarUrl
             success:(void (^)(void))success
             failure:(void (^)(NSError *error))failure;

/**
 Set the presence status.

 @param presence the new presence status.
 @param statusMessage the new message status.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (void)setPresence:(MXPresence)presence andStatusMessage:(NSString*)statusMessage
            success:(void (^)(void))success
            failure:(void (^)(NSError *error))failure;

@end
