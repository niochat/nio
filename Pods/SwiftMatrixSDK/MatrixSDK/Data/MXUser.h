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

#import <Foundation/Foundation.h>

#import "MXJSONModels.h"

@class MXSession;
@class MXEvent;
@class MXRoomMember;

/**
 `MXUser` represents a user in Matrix.
 */
@interface MXUser : MXJSONModel <NSCoding, NSCopying>
{
    // Let property members accessible to children classes
    NSString *_displayname;
    NSString *_avatarUrl;
    MXPresence _presence;
    NSString *_statusMsg;
}

/**
 The user id.
 */
@property (nonatomic, readonly) NSString *userId;

/**
 The user display name.
 */
@property (nonatomic, readonly) NSString *displayname;

/**
 The url of the user of the avatar.
 */
@property (nonatomic, readonly) NSString *avatarUrl;

/**
 The presence status.
 */
@property (nonatomic, readonly) MXPresence presence;

/**
 The user status.
 */
@property (nonatomic, readonly) NSString *statusMsg;

/**
 The time since the last activity by the user.
 This value in milliseconds is recomputed at each property reading.
 It is NOT accurate if currentlyActive is YES.
 Zero means unknown.
 */
@property (nonatomic, readonly) NSUInteger lastActiveAgo;

/**
 Whether the user is currently active.
 If YES, lastActiveAgo is an approximation and "Now" should be shown instead.
 */
@property (nonatomic, readonly) BOOL currentlyActive;

/**
 Create an instance for an user ID.
 
 @param userId The id to the user.

 @return the newly created MXUser instance.
 */
- (instancetype)initWithUserId:(NSString*)userId;

/**
 Update the MXUser data with a m.room.member event.
 
 @param roomMemberEvent The event.
 @param roomMember The already decoded room member.
 @param mxSession the mxSession to the home server.
 */
- (void)updateWithRoomMemberEvent:(MXEvent*)roomMemberEvent roomMember:(MXRoomMember *)roomMember inMatrixSession:(MXSession*)mxSession;

/**
 Update the MXUser data with a m.presence event.
 
 @param presenceEvent the presence event.
 @param mxSession the mxSession to the home server.
 */
- (void)updateWithPresenceEvent:(MXEvent*)presenceEvent inMatrixSession:(MXSession*)mxSession;

/**
 Make a request to the homeserver to update the MXUser.

 @param mxSession the mxSession to the home server.
 @param success a block when the operation succeeds.
 @param failure a block when the operation fails.
 */
- (void)updateFromHomeserverOfMatrixSession:(MXSession*)mxSession success:(void (^)(void))success failure:(void (^)(NSError *error))failure;


#pragma mark - Events listeners
/**
 Block called when an event has modified the MXUser data.

 @param event the event that modified the user data.
 */
typedef void (^MXOnUserUpdate)(MXEvent *event);

/**
 Register a listener to be notified on change of this user data.
 
 @param onUserUpdate the block that will called once a new event has been handled.
 @return a reference to use to unregister the listener
 */
- (id)listenToUserUpdate:(MXOnUserUpdate)onUserUpdate;

/**
 Unregister a listener.
 
 @param listener the reference of the listener to remove.
 */
- (void)removeListener:(id)listener;

/**
 Unregister all listeners.
 */
- (void)removeAllListeners;

@end
