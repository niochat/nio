/*
 Copyright 2014 OpenMarket Ltd
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

#import "MXJSONModel.h"

#import "MXEventUnsignedData.h"
#import "MXEventContentRelatesTo.h"

@class MXEventDecryptionResult, MXEncryptedContentFile;

/**
 Types of Matrix events
 
 Matrix events types are exchanged as strings with the home server. The types
 specified by the Matrix standard are listed here as NSUInteger enum in order
 to ease the type handling.
 
 Custom events types, out of the specification, may exist. In this case, 
 `MXEventTypeString` must be checked.
 */
typedef NS_ENUM(NSInteger, MXEventType)
{
    MXEventTypeRoomName = 0,
    MXEventTypeRoomTopic,
    MXEventTypeRoomAvatar,
    MXEventTypeRoomBotOptions,
    MXEventTypeRoomMember,
    MXEventTypeRoomCreate,
    MXEventTypeRoomJoinRules,
    MXEventTypeRoomPowerLevels,
    MXEventTypeRoomAliases,
    MXEventTypeRoomCanonicalAlias,
    MXEventTypeRoomEncrypted,
    MXEventTypeRoomEncryption,
    MXEventTypeRoomGuestAccess,
    MXEventTypeRoomHistoryVisibility,
    MXEventTypeRoomKey,
    MXEventTypeRoomForwardedKey,
    MXEventTypeRoomKeyRequest,
    MXEventTypeRoomMessage,
    MXEventTypeRoomMessageFeedback,
    MXEventTypeRoomPlumbing,
    MXEventTypeRoomRedaction,
    MXEventTypeRoomThirdPartyInvite,
    MXEventTypeRoomRelatedGroups,
    MXEventTypeRoomPinnedEvents,
    MXEventTypeRoomTag,
    MXEventTypePresence,
    MXEventTypeTypingNotification,
    MXEventTypeReaction,
    MXEventTypeReceipt,
    MXEventTypeRead,
    MXEventTypeReadMarker,
    MXEventTypeCallInvite,
    MXEventTypeCallCandidates,
    MXEventTypeCallAnswer,
    MXEventTypeCallHangup,
    MXEventTypeSticker,
    MXEventTypeRoomTombStone,
    MXEventTypeKeyVerificationRequest,
    MXEventTypeKeyVerificationReady,
    MXEventTypeKeyVerificationStart,
    MXEventTypeKeyVerificationAccept,
    MXEventTypeKeyVerificationKey,
    MXEventTypeKeyVerificationMac,
    MXEventTypeKeyVerificationCancel,
    MXEventTypeKeyVerificationDone,
    MXEventTypeSecretRequest,
    MXEventTypeSecretSend,

    // The event is a custom event. Refer to its `MXEventTypeString` version
    MXEventTypeCustom = 1000
} NS_REFINED_FOR_SWIFT;

/**
 Types of Matrix events - String version
 The event types as described by the Matrix standard.
 */
typedef NSString* MXEventTypeString;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomName;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomTopic;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomAvatar;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomBotOptions;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomMember;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomCreate;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomJoinRules;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomPowerLevels;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomAliases;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomCanonicalAlias;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomEncrypted;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomEncryption;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomGuestAccess;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomHistoryVisibility;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomKey;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomForwardedKey;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomKeyRequest;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomMessage;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomMessageFeedback;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomPlumbing;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomRedaction;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomThirdPartyInvite;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomRelatedGroups;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomPinnedEvents;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomTag;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringPresence;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringTypingNotification;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringReaction;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringReceipt;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRead;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringReadMarker;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringCallInvite;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringCallCandidates;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringCallAnswer;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringCallHangup;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringSticker;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringRoomTombStone;

// Interactive key verification
FOUNDATION_EXPORT NSString *const kMXEventTypeStringKeyVerificationRequest;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringKeyVerificationReady;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringKeyVerificationStart;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringKeyVerificationAccept;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringKeyVerificationKey;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringKeyVerificationMac;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringKeyVerificationCancel;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringKeyVerificationDone;

// Secret sharing
FOUNDATION_EXPORT NSString *const kMXEventTypeStringSecretRequest;
FOUNDATION_EXPORT NSString *const kMXEventTypeStringSecretSend;


/**
 Types of room messages
 */
typedef NSString* MXMessageType NS_REFINED_FOR_SWIFT;
FOUNDATION_EXPORT NSString *const kMXMessageTypeText;
FOUNDATION_EXPORT NSString *const kMXMessageTypeEmote;
FOUNDATION_EXPORT NSString *const kMXMessageTypeNotice;
FOUNDATION_EXPORT NSString *const kMXMessageTypeImage;
FOUNDATION_EXPORT NSString *const kMXMessageTypeAudio;
FOUNDATION_EXPORT NSString *const kMXMessageTypeVideo;
FOUNDATION_EXPORT NSString *const kMXMessageTypeLocation;
FOUNDATION_EXPORT NSString *const kMXMessageTypeFile;
FOUNDATION_EXPORT NSString *const kMXMessageTypeServerNotice;
FOUNDATION_EXPORT NSString *const kMXMessageTypeKeyVerificationRequest;

/**
 Event relations
 */
FOUNDATION_EXPORT NSString *const MXEventRelationTypeAnnotation;    // Reactions
FOUNDATION_EXPORT NSString *const MXEventRelationTypeReference;     // Reply
FOUNDATION_EXPORT NSString *const MXEventRelationTypeReplace;       // Edition

/**
 Prefix used for id of temporary local event.
 */
FOUNDATION_EXPORT NSString *const kMXEventLocalEventIdPrefix;

/**
 The internal event state used to handle the different steps of the event sending.
 */
typedef enum : NSUInteger
{
    /**
     Default state of incoming events.
     The outgoing events switch into this state when their sending succeeds.
     */
    MXEventSentStateSent,
    /**
     The event is an outgoing event which is preparing by converting the data to sent, or uploading additional data.
     */
    MXEventSentStatePreparing,
    /**
     The event is an outgoing event which is encrypting.
     */
    MXEventSentStateEncrypting,
    /**
     The data for the outgoing event is uploading. Once complete, the state will move to `MXEventSentStateSending`.
     */
    MXEventSentStateUploading,
    /**
     The event is an outgoing event in progress.
     */
    MXEventSentStateSending,
    /**
     The event is an outgoing event which failed to be sent.
     See the `sentError` property to check the failure reason.
     */
    MXEventSentStateFailed

} MXEventSentState;

// Timestamp value when the information is not available or not provided by the home server
FOUNDATION_EXPORT uint64_t const kMXUndefinedTimestamp;

/**
 Posted when the MXEvent has updated its sent state.
 
 The notification object is the MXEvent.
 */
FOUNDATION_EXPORT NSString *const kMXEventDidChangeSentStateNotification;

/**
 Posted when the MXEvent has updated its identifier.
 This notification is triggered only for the temporary local events.
 
 The `userInfo` dictionary contains the previous event identifier under the `kMXEventIdentifierKey` key.
 
 The notification object is the MXEvent.
 */
FOUNDATION_EXPORT NSString *const kMXEventDidChangeIdentifierNotification;

/**
 Posted when the MXEvent has been decrypted.
 
 The notification is sent for event that is received before the key to decrypt it.

 The notification object is the MXEvent.
 */
FOUNDATION_EXPORT NSString *const kMXEventDidDecryptNotification;

/**
 Notifications `userInfo` keys
 */
extern NSString *const kMXEventIdentifierKey;


/**
 `MXEvent` is the generic model of events received from the home server.

 It contains all possible keys an event can contain. Thus, all events can be resolved 
 by this model.
 */
@interface MXEvent : MXJSONModel

/**
 The unique id of the event.
 */
@property (nonatomic) NSString *eventId;


/**
 Contains the ID of the room associated with this event.
 */
@property (nonatomic) NSString *roomId;

/**
 Contains the fully-qualified ID of the user who sent this event.
 */
@property (nonatomic) NSString *sender;

/**
 The state of the event sending process (kMXEventDidChangeSentStateNotification is posted in case of change).
 */
@property (nonatomic) MXEventSentState sentState;

/**
 The string event (decrypted, if necessary) type as provided by the homeserver.
 Unlike 'eventType', this field is always filled even for custom events.
 
 @discussion
 If the event is encrypted and the decryption failed (check 'decryptionError' property),
  'type' will remain kMXEventTypeStringRoomEncrypted ("m.room.encrypted").
 */
@property (nonatomic, readonly) MXEventTypeString type;

/**
 The enum version of the 'type' property.
 */
@property (nonatomic, readonly) MXEventType eventType;

/**
 The event (decrypted, if necessary) content.
 The keys in this dictionary depend on the event type. 
 Check http://matrix.org/docs/spec/client_server/r0.2.0.html#room-events to get a list of content keys per
 event type.

 @discussion
 If the event is encrypted and the decryption failed (check 'decryptionError' property),
  'content' will remain encrypted.
 */
@property (nonatomic, readonly) NSDictionary<NSString *, id> *content;

/**
 The string event (possibly encrypted) type as provided by the homeserver.
 Unlike 'wireEventType', this field is always filled even for custom events.
 
 @discussion
 Do not access this property directly unless you absolutely have to. Prefer to use the
 'eventType' property that manages decryption.
 */
@property (nonatomic) MXEventTypeString wireType;

/**
 The enum version of the 'wireType' property.
 */
@property (nonatomic) MXEventType wireEventType;

/**
 The event (possibly encrypted) content.

 @discussion
 Do not access this property directly unless you absolutely have to. Prefer to use the
 'content' property that manages decryption.
 */
@property (nonatomic) NSDictionary<NSString *, id> *wireContent;

/**
 Optional. Contains the previous content for this event. If there is no previous content, this key will be missing.
 */
@property (nonatomic) NSDictionary<NSString *, id> *prevContent;

/**
 Contains the state key for this state event. If there is no state key for this state event, this will be an empty
 string. The presence of state_key makes this event a state event.
 */
@property (nonatomic) NSString *stateKey;

/**
 The timestamp in ms since Epoch generated by the origin homeserver when it receives the event
 from the client.
 */
@property (nonatomic) uint64_t originServerTs;

/**
 Information about this event which was not sent by the originating homeserver.
 HS sends this data under the 'unsigned' field but it is a reserved keyword. Hence, renaming.
 */
@property (nonatomic) MXEventUnsignedData *unsignedData;

/**
 The age of the event in milliseconds.
 As home servers clocks may be not synchronised, this relative value may be more accurate.
 It is computed by the user's home server each time it sends the event to a client.
 Then, the SDK updates it each time the property is read.
 */
@property (nonatomic) NSUInteger age;

/**
 The `age` value transcoded in a timestamp based on the device clock when the SDK received
 the event from the home server.
 Unlike `age`, this value is static.
 */
@property (nonatomic) uint64_t ageLocalTs;

/**
 In case of redaction event, this is the id of the event to redact.
 */
@property (nonatomic) NSString *redacts;

/**
 In case of redaction, redacted_because contains the event that caused it to be redacted,
 which may include a reason.
 */
@property (nonatomic) NSDictionary *redactedBecause;

/**
 In case of invite event, inviteRoomState contains a subset of the state of the room at the time of the invite.
 */
@property (nonatomic) NSArray<MXEvent *> *inviteRoomState;

/**
 If the event relates to another one, some data about the relation.
 */
@property (nonatomic) MXEventContentRelatesTo *relatesTo;

/**
 In case of sending failure (MXEventSentStateFailed), the error that occured.
 */
@property (nonatomic) NSError *sentError;

/**
 Indicates if the event hosts state data.
 */
- (BOOL)isState;

/**
 Indicates if the event is a local one.
 */
- (BOOL)isLocalEvent;

/**
 Indicates if the event has been redacted.
 */
- (BOOL)isRedactedEvent;

/**
 Return YES if the event is an emote event
 */
- (BOOL)isEmote;

/**
 Return YES when the event corresponds to a user profile change.
 */
- (BOOL)isUserProfileChange;

/**
 Return YES if the event contains a media: image, audio, video, file or sticker.
 */
- (BOOL)isMediaAttachment;

/**
 Return YES if the event is a replace event.
 */
- (BOOL)isEditEvent;

/**
 Return YES if the event is a reply event.
 */
- (BOOL)isReplyEvent;

/**
 Return YES if the event content has been edited.
 */
- (BOOL)contentHasBeenEdited;

/**
 Returns the event IDs for which a read receipt is defined in this event.
 
 This property is relevant only for events with 'kMXEventTypeStringReceipt' type.
 */
- (NSArray *)readReceiptEventIds;

/**
 Returns the fully-qualified IDs of the users who sent read receipts with this event.
 
 This property is relevant only for events with 'kMXEventTypeStringReceipt' type.
 */
- (NSArray *)readReceiptSenders;

/**
 Returns a pruned version of the event, which removes all keys we
 don't know about or think could potentially be dodgy.
 This is used when we "redact" an event. We want to remove all fields that the user has specified,
 but we do want to keep necessary information like type, state_key etc.
 */
- (MXEvent*)prune;

/**
 Returns an edited event from a replace event as it should come from the sync.

 @param event The replace event.
 @return Return edited event with replace event content.
 */
- (MXEvent*)editedEventFromReplacementEvent:(MXEvent*)event;

/**
 Returns the event with a new reference relation as it should come from the sync.

 @param event The reference event.
 @return Return an updated event with the new relation.
 */
- (MXEvent*)eventWithNewReferenceRelation:(MXEvent*)referenceEvent;

/**
 Comparator to use to order array of events by their originServerTs value.
 
 Arrays are then sorting so that the newest event will be positionned at index 0.
 
 @param otherEvent the MXEvent object to compare with self.
 @return a NSComparisonResult value: NSOrderedDescending if otherEvent is newer than self.
 */
- (NSComparisonResult)compareOriginServerTs:(MXEvent *)otherEvent;

/**
 Retrieve all the media URLs contained in the event.

 @return All available media URLs.
 */
- (NSArray<NSString*>*)getMediaURLs;

/**
 Indicate if event content could be scanned by `MXScanManager`.

 @return true if event content could be scanned by `MXScanManager`.
 */
- (BOOL)isContentScannable;

#pragma mark - Crypto

/**
 True if this event is encrypted.
 */
@property (nonatomic, readonly) BOOL isEncrypted;

/**
 Update the clear data on this event.

 This is used after decrypting an event; it should not be used by applications.
 It fires kMXEventDidDecryptNotification.

 @param decryptionResult the decryption result, including the plaintext and some key info.
 */
- (void)setClearData:(MXEventDecryptionResult *)decryptionResult;

/**
 For encrypted events, the plaintext payload for the event.
 This is a small MXEvent instance with typically value for `type` and 'content' fields.
 */
@property (nonatomic, readonly) MXEvent *clearEvent;

/**
 The curve25519 key for the device that we think sent this event.

 For an Olm-encrypted event, this is inferred directly from the DH
 exchange at the start of the session: the curve25519 key is involved in
 the DH exchange, so only a device which holds the private part of that
 key can establish such a session.

 For a megolm-encrypted event, it is inferred from the Olm message which
 established the megolm session
 */
@property (nonatomic, readonly) NSString *senderKey;

/**
 The additional keys the sender of this encrypted event claims to possess.
 Just a wrapper for `claimedEd25519Key` (q.v.)
 */
@property (nonatomic, readonly) NSDictionary *keysClaimed;

/**
 Get the ed25519 the sender of this event claims to own.

 For Olm messages, this claim is encoded directly in the plaintext of the
 event itself. For megolm messages, it is implied by the m.room_key event
 which established the megolm session.

 Until we download the device list of the sender, it's just a claim: the
 device list gives a proof that the owner of the curve25519 key used for
 this event (and returned by `senderKey`) also owns the ed25519 key by
 signing the public curve25519 key with the ed25519 key.

 In general, applications should not use this method directly, but should
 instead use [MXCrypto eventDeviceInfo:].
 */
@property (nonatomic, readonly) NSString *claimedEd25519Key;

/**
 Get the curve25519 keys of the devices which were involved in telling us
 about the claimedEd25519Key and sender curve25519 key.

 Normally this will be empty, but in the case of a forwarded megolm
 session, the sender keys are sent to us by another device (the forwarding
 device), which we need to trust to do this. In that case, the result will
 be a list consisting of one entry.

 If the device that sent us the key (A) got it from another device which
 it wasn't prepared to vouch for (B), the result will be [A, B]. And so on.

 @return base64-encoded curve25519 keys, from oldest to newest.
 */
@property (nonatomic, readonly) NSArray<NSString *> *forwardingCurve25519KeyChain;

/**
 If any, the error that occured during decryption.
 */
@property (nonatomic) NSError *decryptionError;

/**
 Get encrypted content files from encrypted event if present.
 
 @return Encrypted content files.
 */
- (NSArray<MXEncryptedContentFile*>*)getEncryptedContentFiles;

@end
