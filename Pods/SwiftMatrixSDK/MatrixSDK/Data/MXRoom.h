/*
 Copyright 2014 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2018 New Vector Ltd
 Copyright 2019 The Matrix.org Foundation C.I.C

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

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#elif TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#endif

#import "MXEvent.h"
#import "MXJSONModels.h"
#import "MXRoomSummary.h"
#import "MXRoomMember.h"
#import "MXReceiptData.h"
#import "MXEventListener.h"
#import "MXRoomState.h"
#import "MXRoomAccountData.h"
#import "MXHTTPOperation.h"
#import "MXCall.h"
#import "MXEventTimeline.h"
#import "MXEventsEnumerator.h"
#import "MXCryptoConstants.h"
#import "MXSendReplyEventStringsLocalizable.h"

@class MXRoom;
@class MXSession;
@class MXUsersTrustLevelSummary;

#pragma mark - Notifications

/**
 Posted when a room initial sync is completed.
 
 The notification object is the concerned room (MXRoom instance).
 */
FOUNDATION_EXPORT NSString *const kMXRoomInitialSyncNotification;

/**
 Posted when the messages of an existing room has been flushed during server sync.
 This flush may be due to a limited timeline in the room sync, or the redaction of a state event.
 The token where to start back pagination has been updated.
 
 The notification object is the concerned room (MXRoom instance).
 */
FOUNDATION_EXPORT NSString *const kMXRoomDidFlushDataNotification;

/**
 `MXRoom` is the class
 */
@interface MXRoom : NSObject

/**
 The Matrix id of the room.
 */
@property (nonatomic, readonly) NSString *roomId;

/**
 Shortcut to the room summary.
 */
@property (nonatomic, readonly) MXRoomSummary *summary;

/**
 The related matrix session.
 */
@property (nonatomic, readonly) MXSession *mxSession;

/**
 The live events timeline.
 */
- (void)liveTimeline:(void (^)(MXEventTimeline *liveTimeline))onComplete;

/**
 The current state of the room.

 This getter method is a shortcut to `liveTimeline.state`.
 */
- (void)state:(void (^)(MXRoomState *roomState))onComplete;

/**
 The current list of members of the room.

 It may require a request to the homeserver if the client has not fetched yet all
 data like in case of members lazy loading.

 @param success A block object called when the operation succeeds. It returns
                the MXRoomMembers object.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)members:(void (^)(MXRoomMembers *roomMembers))success
                    failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Same as `[MXRoom members:]` but it returns already lazy-loaded members if an
 HTTP request to the homeserver is requested.

 @param success A block object called when the operation succeeds. It returns
                all members of the room.
 @param lazyLoadedMembers A block object called when an HTTP request is required. It returns
                          already lazy-loaded members.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)members:(void (^)(MXRoomMembers *members))success
          lazyLoadedMembers:(void (^)(MXRoomMembers *lazyLoadedMembers))lazyLoadedMembers
                    failure:(void (^)(NSError *error))failure;

/**
 The private user data for this room.
 */
@property (nonatomic, readonly) MXRoomAccountData *accountData;

/**
 The text message partially typed by the user but not yet sent.
 The value is stored by the session store. Thus, it can be retrieved
 when the application restarts.
 */
// @TODO(summary): Move to MXRoomSummary
@property (nonatomic) NSString *partialTextMessage;

/**
 The list of ids of users currently typing in this room.
 This array is updated on each received m.typing event (MXEventTypeTypingNotification).
 */
@property (nonatomic, readonly) NSArray<NSString *> *typingUsers;

/**
 Indicate if the room is tagged as a direct chat.
 */
@property (nonatomic, readonly) BOOL isDirect;

/**
 The user identifier for whom this room is tagged as direct (if any).
 nil if the room is not a direct chat.
 */
@property (nonatomic, readonly) NSString *directUserId;

/**
 Tag this room as a direct one, or remove the direct tag.

 @discussion: When a room is tagged as direct without mentioning the concerned userId,
 the room becomes a direct chat with the oldest joined member. If no member has joined yet,
 the room becomes direct with the oldest invited member.

 @param isDirect Tell whether the room is direct or not.
 @param userId (optional) the identifier of the user for whom the room becomes direct.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (MXHTTPOperation*)setIsDirect:(BOOL)isDirect
                     withUserId:(NSString*)userId
                        success:(void (^)(void))success
                        failure:(void (^)(NSError *error))failure;

/**
 Create a `MXRoom` instance.

 @param roomId the id of the room.
 @param mxSession the session to use.
 @return the new instance.
 */
- (id)initWithRoomId:(NSString*)roomId andMatrixSession:(MXSession*)mxSession;

/**
 Create a `MXRoom` instance by specifying the store the live timeline must use.

 @param roomId the id of the room.
 @param mxSession the session to use.
 @param store the store to use to store live timeline events.
 @return the new instance.
 */
- (id)initWithRoomId:(NSString *)roomId matrixSession:(MXSession *)mxSession andStore:(id<MXStore>)store;

/**
 Load a `MXRoom` instance from the store.

 @param store the store to mount data from and to store live data to.
 @param roomId the id of the room.
 @param matrixSession the session to use.
 @return the new instance.
 */
+ (id)loadRoomFromStore:(id<MXStore>)store withRoomId:(NSString *)roomId matrixSession:(MXSession *)matrixSession;

- (void)close;

#pragma mark - Server sync

/**
 Update room data according to the provided sync response.
 
 @param roomSync information to sync the room with the home server data
 */
- (void)handleJoinedRoomSync:(MXRoomSync*)roomSync;

/**
 Update the invited room state according to the provided data.
 
 @param invitedRoomSync information to update the room state.
 */
- (void)handleInvitedRoomSync:(MXInvitedRoomSync *)invitedRoomSync;


#pragma mark - Stored messages enumerator
/**
 Get an enumerator on all messages of the room downloaded so far.
 */
@property (nonatomic, readonly) id<MXEventsEnumerator> enumeratorForStoredMessages;

/**
 Get an events enumerator on messages of the room with a filter on the events types.

 An optional array of event types may be provided to filter room events. When this array is not nil,
 the type of the returned last event should match with one of the provided types.

 @param types an array of event types strings (MXEventTypeString).
 @return the events enumerator.
 */
- (id<MXEventsEnumerator>)enumeratorForStoredMessagesWithTypeIn:(NSArray<MXEventTypeString> *)types;

/**
 The count of stored messages for this room.
 */
@property (nonatomic, readonly) NSUInteger storedMessagesCount;


#pragma mark - Room operations
/**
 Send a generic non state event to a room.

 @param eventTypeString the type of the event. @see MXEventType.
 @param content the content that will be sent to the server as a JSON object.
 @param localEcho a pointer to a MXEvent object.
                  When the event type is `kMXEventTypeStringRoomMessage`, this pointer
                  is set to an actual MXEvent object containing the local created event which should be used
                  to echo the message in the messages list until the resulting event come through the server sync.
                  For information, the identifier of the created local event has the prefix: `kMXEventLocalEventIdPrefix`.
                  You may specify nil for this parameter if you do not want this information.
                  You may provide your own MXEvent object, in this case only its send state is updated.
                  When the event type is `kMXEventTypeStringRoomEncrypted`, no local event is created.

 @param success A block object called when the operation succeeds. It returns
                the event id of the event generated on the home server
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)sendEventOfType:(MXEventTypeString)eventTypeString
                            content:(NSDictionary<NSString*, id>*)content
                          localEcho:(MXEvent**)localEcho
                            success:(void (^)(NSString *eventId))success
                            failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Send a generic state event to a room.

 @param eventTypeString the type of the event. @see MXEventType.
 @param content the content that will be sent to the server as a JSON object.
 @param stateKey the optional state key.
 @param success A block object called when the operation succeeds. It returns
 the event id of the event generated on the home server
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)sendStateEventOfType:(MXEventTypeString)eventTypeString
                                 content:(NSDictionary<NSString*, id>*)content
                                stateKey:(NSString*)stateKey
                                 success:(void (^)(NSString *eventId))success
                                 failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Send a room message to a room.

 @param content the message content that will be sent to the server as a JSON object.
 @param localEcho a pointer to a MXEvent object. This pointer is set to an actual MXEvent object
                  containing the local created event which should be used to echo the message in
                  the messages list until the resulting event come through the server sync.
                  For information, the identifier of the created local event has the prefix: `kMXEventLocalEventIdPrefix`.
                  You may specify nil for this parameter if you do not want this information.
                  You may provide your own MXEvent object, in this case only its send state is updated.
 @param success A block object called when the operation succeeds. It returns
                the event id of the event generated on the home server
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)sendMessageWithContent:(NSDictionary<NSString*, id>*)content
                                 localEcho:(MXEvent**)localEcho
                                   success:(void (^)(NSString *eventId))success
                                   failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Send a text message to the room.
 
 @param text the text to send.
 @param formattedText the optional HTML formatted string of the text to send.
 @param localEcho a pointer to a MXEvent object (@see sendMessageWithContent: for details).
 @param success A block object called when the operation succeeds. It returns
                the event id of the event generated on the home server
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)sendTextMessage:(NSString*)text
                      formattedText:(NSString*)formattedText
                          localEcho:(MXEvent**)localEcho
                            success:(void (^)(NSString *eventId))success
                            failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Send a text message to the room.

 @param text the text to send.
 @param success A block object called when the operation succeeds. It returns
 the event id of the event generated on the home server
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)sendTextMessage:(NSString*)text
                            success:(void (^)(NSString *eventId))success
                            failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Send an emote message to the room.
 
 @param emoteBody the emote body to send.
 @param formattedBody the optional HTML formatted string of the emote.
 @param localEcho a pointer to a MXEvent object (@see sendMessageWithContent: for details).
 @param success A block object called when the operation succeeds. It returns
                the event id of the event generated on the home server
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)sendEmote:(NSString*)emoteBody
                formattedText:(NSString*)formattedBody
                    localEcho:(MXEvent**)localEcho
                      success:(void (^)(NSString *eventId))success
                      failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Send an image to the room.
 
 @param imageData the data of the image to send.
 @param imageSize the original size of the image.
 @param mimetype  the image mimetype.
 @param thumbnail optional thumbnail image (may be nil).
 @param localEcho a pointer to a MXEvent object (@see sendMessageWithContent: for details).
 @param success A block object called when the operation succeeds. It returns
                the event id of the event generated on the home server
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)sendImage:(NSData*)imageData
                withImageSize:(CGSize)imageSize
                     mimeType:(NSString*)mimetype
#if TARGET_OS_IPHONE
                 andThumbnail:(UIImage*)thumbnail
#elif TARGET_OS_OSX
                 andThumbnail:(NSImage*)thumbnail
#endif
                    localEcho:(MXEvent**)localEcho
                      success:(void (^)(NSString *eventId))success
                      failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Send an video to the room.
 
 @param videoLocalURL the local filesystem path of the video to send.
 @param videoThumbnail the UIImage hosting a video thumbnail.
 @param localEcho a pointer to a MXEvent object (@see sendMessageWithContent: for details).
 @param success A block object called when the operation succeeds. It returns
                the event id of the event generated on the home server
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)sendVideo:(NSURL*)videoLocalURL
#if TARGET_OS_IPHONE
                withThumbnail:(UIImage*)videoThumbnail
#elif TARGET_OS_OSX
                withThumbnail:(NSImage*)videoThumbnail
#endif
                    localEcho:(MXEvent**)localEcho
                      success:(void (^)(NSString *eventId))success
                      failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Send a file to the room.
 
 @param fileLocalURL the local filesystem path of the file to send.
 @param mimeType the mime type of the file.
 @param localEcho a pointer to a MXEvent object (@see sendMessageWithContent: for details).
 @param success A block object called when the operation succeeds. It returns
                the event id of the event generated on the home server
 @param failure A block object called when the operation fails.
 @param keepActualName if YES, the filename in the local storage will be kept while sending.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)sendFile:(NSURL*)fileLocalURL
                    mimeType:(NSString*)mimeType
                   localEcho:(MXEvent**)localEcho
                     success:(void (^)(NSString *eventId))success
                     failure:(void (^)(NSError *error))failure
          keepActualFilename:(BOOL)keepActualName NS_REFINED_FOR_SWIFT;

/**
 Send a file to a room (see above) without keeping the local storage filename
 */
- (MXHTTPOperation*)sendFile:(NSURL*)fileLocalURL
                    mimeType:(NSString*)mimeType
                   localEcho:(MXEvent**)localEcho
                     success:(void (^)(NSString *eventId))success
                     failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Send an audio file to the room.
 
 @param fileLocalURL the local filesystem path of the file to send.
 @param mimeType the mime type of the file.
 @param localEcho a pointer to a MXEvent object (@see sendMessageWithContent: for details).
 @param success A block object called when the operation succeeds. It returns
 the event id of the event generated on the home server
 @param failure A block object called when the operation fails.
 @param keepActualName if YES, the filename in the local storage will be kept while sending.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)sendAudioFile:(NSURL*)fileLocalURL
                    mimeType:(NSString*)mimeType
                   localEcho:(MXEvent**)localEcho
                     success:(void (^)(NSString *eventId))success
                     failure:(void (^)(NSError *error))failure
          keepActualFilename:(BOOL)keepActualName NS_REFINED_FOR_SWIFT;

/**
 Cancel a sending operation.

 Note that the local echo event will be not removed from the outgoing message queue.
 `removeOutgoingMessage` must be called for that.

 @param localEchoEventId the id of the local echo event created by the sending
        operation to cancel.
 */
- (void)cancelSendingOperation:(NSString*)localEchoEventId;

/**
 Determine if an event has a local echo.
 
 @param event the concerned event.
 @return a local echo event corresponding to the event. Nil if there is no match.
 */
- (MXEvent*)pendingLocalEchoRelatedToEvent:(MXEvent*)event;

/**
 Remove a local echo event from the pending queue.
 
 @discussion
 It can be removed from the list because we received the true event from the event stream
 or the corresponding request has failed.
 
 @param localEchoEventId the local echo event id.
 */
- (void)removePendingLocalEcho:(NSString*)localEchoEventId;

/**
 Set the topic of the room.

 @param topic the topic to set.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)setTopic:(NSString*)topic
                     success:(void (^)(void))success
                     failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Set the avatar of the room.

 @param avatar the avatar url to set.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)setAvatar:(NSString*)avatar
                      success:(void (^)(void))success
                      failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Set the name of the room.

 @param name the name to set.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)setName:(NSString*)name
                    success:(void (^)(void))success
                    failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Set the history visibility of the room.

 @param historyVisibility the history visibility to set.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)setHistoryVisibility:(MXRoomHistoryVisibility)historyVisibility
                                 success:(void (^)(void))success
                                 failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Set the join rule of the room.

 @param joinRule the join rule to set.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)setJoinRule:(MXRoomJoinRule)joinRule
                        success:(void (^)(void))success
                        failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Set the guest access of the room.

 @param guestAccess the guest access to set.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)setGuestAccess:(MXRoomGuestAccess)guestAccess
                           success:(void (^)(void))success
                           failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Set the visbility of the room in the current HS's room directory.

 @param directoryVisibility the directory visibility to set.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)setDirectoryVisibility:(MXRoomDirectoryVisibility)directoryVisibility
                                   success:(void (^)(void))success
                                   failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Add a room alias
 
 @param roomAlias the room alias to add.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)addAlias:(NSString *)roomAlias
                     success:(void (^)(void))success
                     failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Remove a room alias
 
 @param roomAlias the room alias to remove.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)removeAlias:(NSString *)roomAlias
                        success:(void (^)(void))success
                        failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Set the canonical alias of the room.
 
 @param canonicalAlias the canonical alias to set.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)setCanonicalAlias:(NSString *)canonicalAlias
                              success:(void (^)(void))success
                              failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Get the visibility of the room in the current HS's room directory.
 
 Note: This information is not part of the room state because it is related
 to the current homeserver.
 There is currently no way to be updated on directory visibility change. That's why a
 request must be issued everytime.

 @param success A block object called when the operation succeeds. It provides the room directory visibility.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)directoryVisibility:(void (^)(MXRoomDirectoryVisibility directoryVisibility))success
                                failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Join this room where the user has been invited.

 @param success A block object called when the operation is complete.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)join:(void (^)(void))success
                 failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Leave this room.
 
 @param success A block object called when the operation is complete.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)leave:(void (^)(void))success
                  failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Invite a user to this room.

 @param userId the user id.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)inviteUser:(NSString*)userId
                       success:(void (^)(void))success
                       failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Invite a user to a room based on their email address to this room.

 @param email the user email.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)inviteUserByEmail:(NSString*)email
                              success:(void (^)(void))success
                              failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Kick a user from this room.

 @param userId the user id.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)kickUser:(NSString*)userId
                      reason:(NSString*)reason
                     success:(void (^)(void))success
                     failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Ban a user in this room.

 @param userId the user id.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)banUser:(NSString*)userId
                     reason:(NSString*)reason
                    success:(void (^)(void))success
                    failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Unban a user in this room.

 @param userId the user id.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)unbanUser:(NSString*)userId
                      success:(void (^)(void))success
                      failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Set the power level of a member of the room.

 @param userId the id of the user.
 @param powerLevel the value to set.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)setPowerLevelOfUserWithUserID:(NSString*)userId powerLevel:(NSInteger)powerLevel
                                          success:(void (^)(void))success
                                          failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Inform the home server that the user is typing (or not) in this room.

 @param typing Use YES if the user is currently typing.
 @param timeout the length of time until the user should be treated as no longer typing,
                in milliseconds. Can be ommited (set to -1) if they are no longer typing.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)sendTypingNotification:(BOOL)typing
                                   timeout:(NSUInteger)timeout
                                   success:(void (^)(void))success
                                   failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Redact an event in this room.
 
 @param eventId the id of the redacted event.
 @param reason the redaction reason (optional).
 
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)redactEvent:(NSString*)eventId
                         reason:(NSString*)reason
                        success:(void (^)(void))success
                        failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Report an event in this room.

 @param eventId the id of the event event.
 @param score the metric to let the user rate the severity of the abuse.
              It ranges from -100 “most offensive” to 0 “inoffensive”.
 @param reason the redaction reason (optional).

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)reportEvent:(NSString*)eventId
                          score:(NSInteger)score
                         reason:(NSString*)reason
                        success:(void (^)(void))success
                        failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Set the related groups of the room.
 
 @param relatedGroups the list of the identifiers of the related groups to set.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)setRelatedGroups:(NSArray<NSString *>*)relatedGroups
                             success:(void (^)(void))success
                             failure:(void (^)(NSError *error))failure;

/**
 Indicate if replying to the provided event is supported.
 Only event of type 'MXEventTypeRoomMessage' are supported for the moment, and for certain msgtype.
 
 @param eventToReply the event to reply to
 @return YES if it is possible to reply to this event
 */
- (BOOL)canReplyToEvent:(MXEvent *)eventToReply;

/**
 Send a reply to an event with text message to the room.
 
 It's only supported to reply to event with 'm.room.message' event type and following message types: 'm.text', 'm.text', 'm.emote', 'm.notice', 'm.image', 'm.file', 'm.video', 'm.audio'.
 
 @param eventToReply The event to reply.
 @param textMessage the text to send.
 @param formattedTextMessage the optional HTML formatted string of the text to send.
 @param stringLocalizations string localizations used when building reply message.
 @param localEcho a pointer to a MXEvent object (@see sendMessageWithContent: for details).
 @param success A block object called when the operation succeeds. It returns
 the event id of the event generated on the home server
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)sendReplyToEvent:(MXEvent*)eventToReply
                     withTextMessage:(NSString*)textMessage
                formattedTextMessage:(NSString*)formattedTextMessage
                 stringLocalizations:(id<MXSendReplyEventStringsLocalizable>)stringLocalizations
                           localEcho:(MXEvent**)localEcho
                             success:(void (^)(NSString *eventId))success
                             failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;


#pragma mark - Events listeners on the live timeline
/**
 Register a listener to events of the room live timeline.

 @param onEvent the block that will called once a new event has been handled.
 @return a reference to use to unregister the listener
 */
- (id)listenToEvents:(MXOnRoomEvent)onEvent;

/**
 Register a listener for some types of events on the room live timeline.

 @param types an array of event types strings (MXEventTypeString) to listen to.
 @param onEvent the block that will called once a new event has been handled.
 @return a reference to use to unregister the listener
 */
- (id)listenToEventsOfTypes:(NSArray<MXEventTypeString> *)types onEvent:(MXOnRoomEvent)onEvent;

/**
 Unregister a listener from the room live timeline.

 @param listener the reference of the listener to remove.
 */
- (void)removeListener:(id)listener;

/**
 Unregister all listeners from the room live timeline.
 */
- (void)removeAllListeners;


#pragma mark - Events timeline
/**
 Open a new `MXEventTimeline` instance around the passed event.

 @param eventId the id of the event.
 @return a new `MXEventTimeline` instance.
 */
- (MXEventTimeline*)timelineOnEvent:(NSString*)eventId;


#pragma mark - Fake event objects creation
/**
 Create a temporary event for the room.

 @param eventId the event id. A globally unique string with kMXEventLocalEventIdPrefix prefix is defined when this param is nil.
 @param eventType the type of the event. @see MXEventType.
 @param content the event content.
 @return the created event.
 */
- (MXEvent*)fakeEventWithEventId:(NSString*)eventId eventType:(MXEventTypeString)eventType andContent:(NSDictionary<NSString*, id>*)content;

/**
 Create a temporary message event for the room.

 @param eventId the event id. A globally unique string with kMXEventLocalEventIdPrefix prefix is defined when this param is nil.
 @param content the event content.
 @return the created event.
 */
- (MXEvent*)fakeRoomMessageEventWithEventId:(NSString*)eventId andContent:(NSDictionary<NSString*, id>*)content;

#pragma mark - Outgoing events management
/**
 Store into the store an outgoing message event being sent in the room.
 
 If the store used by the MXSession is based on a permanent storage, the application
 will be able to retrieve messages that failed to be sent in a previous app session.

 @param outgoingMessage the MXEvent object of the message.
 */
- (void)storeOutgoingMessage:(MXEvent*)outgoingMessage;

/**
 Remove all outgoing messages from the room.
 */
- (void)removeAllOutgoingMessages;

/**
 Remove an outgoing message from the room.

 @param outgoingMessageEventId the id of the message to remove.
 */
- (void)removeOutgoingMessage:(NSString*)outgoingMessageEventId;

/**
 Update an outgoing message.

 @param outgoingMessageEventId the id of the message to update.
 @param outgoingMessage the new outgoing message content.
 */
- (void)updateOutgoingMessage:(NSString*)outgoingMessageEventId withOutgoingMessage:(MXEvent*)outgoingMessage;

/**
 All outgoing messages pending in the room.
 */
- (NSArray<MXEvent*>*)outgoingMessages;


#pragma mark - Room tags operations
/**
 Add a tag to a room.

 Use this method to update the order of an existing tag.

 @param tag the new tag to add to the room.
 @param order the order. @see MXRoomTag.order.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)addTag:(NSString*)tag
                 withOrder:(NSString*)order
                   success:(void (^)(void))success
                   failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;
/**
 Remove a tag from a room.

 @param tag the tag to remove.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)removeTag:(NSString*)tag
                      success:(void (^)(void))success
                      failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Remove a tag and add another one.

 @param oldTag the tag to remove.
 @param newTag the new tag to add. Nil can be used. Then, no new tag will be added.
 @param newTagOrder the order of the new tag.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)replaceTag:(NSString*)oldTag
                         byTag:(NSString*)newTag
                     withOrder:(NSString*)newTagOrder
                       success:(void (^)(void))success
                       failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;


#pragma mark - Voice over IP

/**
 Place a voice or a video call into the room.

 @param video YES to make a video call.
 @param success A block object called when the operation succeeds. It provides the created MXCall instance.
 @param failure A block object called when the operation fails.
 */
- (void)placeCallWithVideo:(BOOL)video
                   success:(void (^)(MXCall *call))success
                   failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

#pragma mark - Read receipts management

/**
 Handle a receipt event.
 
 @param event the event to handle.
 @param direction the timeline direction.
 */
- (BOOL)handleReceiptEvent:(MXEvent *)event direction:(MXTimelineDirection)direction;

/**
 If the event was not acknowledged yet, this method acknowlegdes it by sending a receipt event.
 This will indicate to the homeserver that the user has read this event.
 Set YES the boolean updateReadMarker to let know the homeserver the user has read up to this event.
 
 @warning Because the event related to the current read marker may not be in the local storage, no check
 is performed before updating the read marker. The caller should check whether the provided event
 is posterior to the current read marker position.
 
 @discussion If the type of the provided event is not defined in MXSession.acknowledgableEventTypes,
 this method acknowlegdes the first prior event of type defined in MXSession.acknowledgableEventTypes.
 The read marker (if its update is requested) will refer to the provided event.
 
 @param event the event to acknowlegde.
 @param updateReadMarker tell whether the read marker should be moved to this event.
 */
- (void)acknowledgeEvent:(MXEvent*)event andUpdateReadMarker:(BOOL)updateReadMarker;

/**
 Move the read marker to the latest event.
 Update the read receipt by acknowledging the latest event of type defined in MXSession.acknowledgableEventTypes.
 This is will indicate to the homeserver that the user has read all the events.
 */
- (void)markAllAsRead;

/**
 Returns the read receipts list for an event, excluding the read receipt from the current user.

 @param eventId The event Id.
 @param sort YES to sort them from the latest to the oldest.
 @return the receipts for an event in a dedicated room.
 */
- (NSArray<MXReceiptData*> *)getEventReceipts:(NSString*)eventId sorted:(BOOL)sort;

/**
 Store a receipt.

 Use this method to store implicit receipt data that does not come from the events stream.

 @param receiptType the receipt type (like kMXEventTypeStringRead).
 @param eventId the id of the event.
 @param userId the user who generates the receipt.
 @param ts the receipt timestamp in ms since Epoch.
 @return YES if the receipt data is valid and has been stored.
 */
- (BOOL)storeLocalReceipt:(NSString*)receiptType eventId:(NSString*)eventId userId:(NSString*)userId ts:(uint64_t)ts;


#pragma mark - Read marker handling

/**
 This will indicate to the homeserver that the user has read up to this event.
 
 @param eventId the last read event identifier.
 */
- (void)moveReadMarkerToEventId:(NSString*)eventId;

/**
 Update the read-up-to marker to match the read receipt.
 */
- (void)forgetReadMarker;

#pragma mark - Crypto

/**
 Enable encryption in this room.
 
 You can check if a room is encrypted via its state (MXRoomState.isEncrypted)
 
 @param algorithm the crypto algorithm to use.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
*/
- (MXHTTPOperation*)enableEncryptionWithAlgorithm:(NSString*)algorithm
                                          success:(void (^)(void))success
                                          failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Comparator to use to order array of rooms by their last message event.
 
 Arrays are then sorting so that the room with the most recent message will be positionned at index 0.
 
 @param otherRoom the MXRoom object to compare with self.
 @return a NSComparisonResult value: NSOrderedDescending if otherRoom is more recent than self.
 */
- (NSComparisonResult)compareLastMessageEventOriginServerTs:(MXRoom *)otherRoom;

/**
 Provides a summary of members trust level for an encrypted room.

 @param forceDownload YES to fetch data from the homeserver. NO to retrieve stored data.
 @param success A block object called when the operation succeeds. It provides a summary of members trust level for an encrypted room..
 @param failure A block object called when the operation fails.
 */
- (void)membersTrustLevelSummaryWithForceDownload:(BOOL)forceDownload success:(void (^)(MXUsersTrustLevelSummary *usersTrustLevelSummary))success failure:(void (^)(NSError *error))failure;

@end
