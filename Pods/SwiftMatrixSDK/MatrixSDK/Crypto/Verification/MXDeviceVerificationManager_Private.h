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

#import "MXDeviceVerificationManager.h"

#import "MXDeviceVerificationTransaction_Private.h"

@class MXCrypto;

NS_ASSUME_NONNULL_BEGIN

/**
 The `MXKeyBackup_Private` extension exposes internal operations.
 */
@interface MXDeviceVerificationManager ()

/**
 The Matrix crypto.
 */
@property (nonatomic, readonly, weak) MXCrypto *crypto;

/**
 Constructor.

 @param mxSession the related 'MXSession'.
 */
- (instancetype)initWithCrypto:(MXCrypto *)crypto;


#pragma mark - Outgoing to_device events

/**
 Send a message to the other a peer in a device verification transaction.

 @param transaction the transation to talk trough.
 @param eventType the message type.
 @param content the message content.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)sendToOtherInTransaction:(MXDeviceVerificationTransaction*)transaction
                                   eventType:(NSString*)eventType
                                     content:(NSDictionary*)content
                                     success:(void (^)(void))success
                                     failure:(void (^)(NSError *error))failure;

/**
 Cancel a transaction. Send a cancellation event to the other peer.

 @param transaction the transaction to cancel.
 @param code the cancellation reason.
 */
- (void)cancelTransaction:(MXDeviceVerificationTransaction*)transaction code:(MXTransactionCancelCode*)code;

/**
 Remove a transaction from the queue.

 @param transactionId the transaction to remove.
 */
- (void)removeTransactionWithTransactionId:(NSString*)transactionId;

@end

NS_ASSUME_NONNULL_END
