/*
 Copyright 2017 OpenMarket Ltd

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

/**
 Possible states for a room key request

 The state machine looks like:

     |
     V       (cancellation requested)
   UNSENT  -----------------------------+
     |                                  |
     | (send successful)                |
     V                                  |
    SENT                                |
     |--------------------------------  |  --------------+
     |                                  |                |
     |                                  | (cancellation requested with intent
     |                                  | to resend a new request)
     | (cancellation requested)         |                |
     V                                  |                V
 CANCELLATION_PENDING                   | CANCELLATION_PENDING_AND_WILL_RESEND
     |                                  |                |
     | (cancellation sent)              | (cancellation sent. Create new request
     |                                  |  in the UNSENT state)
     V                                  |                |
 (deleted)  <---------------------------+----------------+
 */
typedef enum : NSUInteger
{
    // request not yet sent
    MXRoomKeyRequestStateUnsent = 0,
    // request sent, awaiting reply
    MXRoomKeyRequestStateSent,
    // reply received, cancellation not yet sent
    MXRoomKeyRequestStateCancellationPending,
    // Cancellation not yet sent and will send a new request
    MXRoomKeyRequestStateCancellationPendingAndWillResend

} MXRoomKeyRequestState;


/**
 `MXOutgoingRoomKeyRequest` represents an outgoing room key request.
 */
@interface MXOutgoingRoomKeyRequest : NSObject

/**
 The requestId unique id for this request. Used for both
 an id within the request for later pairing with a cancellation, and for
 the transaction id when sending the to_device messages to our local
 server.
 */
@property (nonatomic) NSString *requestId;

/**
 The transaction id for the cancellation, if any.
 */
@property (nonatomic) NSString *cancellationTxnId;

/**
 The list of recipients for the request.
 Array of userId -> deviceId dictionary.
 */
@property (nonatomic) NSArray<NSDictionary<NSString*, NSString*>*> *recipients;

/**
 The parameters of a room key request. The details of the request may
 vary with the crypto algorithm, but the management and storage layers for
 outgoing requests expect it to have 'room_id' and 'session_id' properties
 */
@property (nonatomic) NSDictionary *requestBody;

// Shorcuts to requestBody data
@property (nonatomic, readonly) NSString *algorithm;
@property (nonatomic, readonly) NSString *roomId;
@property (nonatomic, readonly) NSString *sessionId;
@property (nonatomic, readonly) NSString *senderKey;

/**
 The current state of this request.
 */
@property (nonatomic) MXRoomKeyRequestState state;

@end
