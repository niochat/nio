/*
 Copyright 2015 OpenMarket Ltd
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

NS_ASSUME_NONNULL_BEGIN

@class MXCall;
@class MXCallKitAdapter;
@class MXRoom, MXRoomState;
@class MXRoomMember;
@class MXSession;
@class MXTurnServerResponse;

@protocol MXCallStack;

/**
 Posted when a new `MXCall` instance has been created. It happens on an incoming
 or a new outgoing call.
 The notification object is the `MXKCall` object representing the call.
 */
extern NSString *const kMXCallManagerNewCall;

/**
 Posted when a call conference has been started.
 The notification object is the id of the room where call conference occurs.
 */
extern NSString *const kMXCallManagerConferenceStarted;

/**
 Posted when a call conference has been finished.
 The notification object is the id of the room where call conference occurs.
 */
extern NSString *const kMXCallManagerConferenceFinished;

/**
 The `MXCallManager` object manages calls for a given Matrix session.
 It manages call signaling over Matrix (@see http://matrix.org/docs/spec/#id9) and then opens
 a stream between peers devices using a third party VoIP library.
 */
@interface MXCallManager : NSObject

/**
 Create the `MXCallManager` instance.

 @param mxSession the mxSession to the home server.
 @return the newly created MXCallManager instance.
 */
- (instancetype)initWithMatrixSession:(MXSession *)mxSession andCallStack:(id<MXCallStack>)callstack NS_DESIGNATED_INITIALIZER;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

/**
 Stop the call manager.
 Call in progress will be interupted.
 */
- (void)close;

/**
 Retrieve the `MXCall` instance with the given call id.
 
 @param callId the id of the call to retrieve.
 @result the `MXCall` object. Nil if not found.
 */
- (nullable MXCall *)callWithCallId:(NSString *)callId;

/**
 Retrieve the `MXCall` instance that is in progress in a given room.
 
 @param roomId the id of the room to look up.
 @result the `MXCall` object. Nil if there is no call in progress in the room.
 */
- (nullable MXCall *)callInRoom:(NSString *)roomId;

/**
 Place a voice or a video call into a room.
 
 @param roomId the room id where to place the call.
 @param video YES to make a video call.
 @param success A block object called when the operation succeeds. It provides the created MXCall instance.
 @param failure A block object called when the operation fails.
 */
- (void)placeCallInRoom:(NSString *)roomId withVideo:(BOOL)video
                success:(void (^)(MXCall *call))success
                failure:(void (^)(NSError * _Nullable error))failure;

/**
 Make the call manager forget a call.
 
 @param call the `MXCall` instance reference to forget.
 */
- (void)removeCall:(MXCall *)call;

/**
 The related matrix session.
 */
@property (nonatomic, readonly) MXSession *mxSession;

/**
 The call stack layer.
 */
@property (nonatomic) id<MXCallStack> callStack;

/**
 The CallKit adapter.
 Provide it if you want to add CallKit support.
 */
#if TARGET_OS_IPHONE
@property (nonatomic, nullable) MXCallKitAdapter *callKitAdapter;
#endif

/**
 The time in milliseconds that an incoming or outgoing call invite is valid for.
 Default is 30s.
 */
@property (nonatomic) NSUInteger inviteLifetime;

/**
 The list of TURN/STUN servers advertised by the user's homeserver.
 Can be nil. In this case, use `fallbackSTUNServer`.
 */
@property (nonatomic, nullable, readonly) MXTurnServerResponse *turnServers;

/**
 STUN server used if the homeserver does not provide TURN/STUN servers.
 */
@property (nonatomic) NSString *fallbackSTUNServer;


#pragma mark - Conference call

/**
 Handle a membership change of conference user in a room where there is conference call.

 @param conferenceUserMember the member object of the conference user.
 @param roomId the room where there is conference call.
 */
- (void)handleConferenceUserUpdate:(MXRoomMember *)conferenceUserMember inRoom:(NSString *)roomId;

/**
 Return the id of the conference user dedicated for the passed room.

 @param roomId the room id.
 @return the conference user id.
 */
+ (NSString *)conferenceUserIdForRoom:(NSString *)roomId;

/**
 Check if the passed user id corresponds to the a conference user.
 
 @param userId the user id to check.
 @return YES if the id is reserved to a conference user.
 */
+ (BOOL)isConferenceUser:(NSString *)userId;

/**
 Check if the user can place a conference call in a given room.
 
 All room members can join an existing conference call but only member with
 invite power level can create a conference call.

 @param room the room to check.
 @param roomState the state of the room.
 @return YES if the user can.
 */
+ (BOOL)canPlaceConferenceCallInRoom:(MXRoom *)room  roomState:(MXRoomState *)roomState;

@end

NS_ASSUME_NONNULL_END
