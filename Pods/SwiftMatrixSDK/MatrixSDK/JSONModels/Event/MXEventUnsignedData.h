/*
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

#import "MXJSONModel.h"

@class MXEvent, MXEventRelations;

NS_ASSUME_NONNULL_BEGIN

@interface MXEventUnsignedData : MXJSONModel

/**
 The age of the event in milliseconds.
 As homeservers clocks may be not synchronised, this relative value may be more accurate.
 It is computed by the user's home server each time it sends the event to a client.
 Then, the SDK updates it each time the property is read.
 */
@property (nonatomic, readonly) NSUInteger age;

/**
 The `age` value transcoded in a timestamp based on the device clock when the SDK received
 the event from the home server.
 Unlike `age`, this value is static.
 */
@property (nonatomic, readonly) uint64_t ageLocalTs;

/**
 The event id of the state event this event replaces.
 */
@property (nonatomic, readonly, nullable) NSString *replacesState;

/**
 The sender of the replaced state event.
 */
@property (nonatomic, readonly, nullable) NSString *prevSender;

/**
 The content of the replaced state event.
 */
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, id> *prevContent;

/**
 A reason for why the event was redacted.
 */
@property (nonatomic, readonly, nullable) NSDictionary *redactedBecause;

/**
 The client-supplied transaction ID, if the client being given the event is the same one which sent it.
 */
@property (nonatomic, readonly, nullable) NSString *transactionId;

/**
 A subset of the state of the room at the time of the invite, if membership is invite.

 Note that this state is informational, and SHOULD NOT be trusted; once the client has joined the room,
 it SHOULD fetch the live state from the server and discard the invite_room_state.
 Also, clients must not rely on any particular state being present here; they SHOULD behave properly
 (with possibly a degraded but not a broken experience) in the absence of any particular events here.
 If they are set on the room, at least the state for m.room.avatar, m.room.canonical_alias, m.room.join_rules,
 and m.room.name SHOULD be included.
 */
@property (nonatomic) NSArray<MXEvent *> *inviteRoomState;

/**
 Aggregated relations (reactions, edition, ...).
 */
@property (nonatomic, readonly, nullable) MXEventRelations *relations;

@end

NS_ASSUME_NONNULL_END
