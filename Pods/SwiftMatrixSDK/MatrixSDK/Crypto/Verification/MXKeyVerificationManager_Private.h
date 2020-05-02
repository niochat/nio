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

#import "MXKeyVerificationManager.h"

#import "MXKeyVerificationTransaction_Private.h"

@class MXCrypto;
@class MXQRCodeData;

NS_ASSUME_NONNULL_BEGIN

/**
 The `MXKeyBackup_Private` extension exposes internal operations.
 */
@interface MXKeyVerificationManager ()

/**
 The Matrix crypto.
 */
@property (nonatomic, readonly, weak) MXCrypto *crypto;

/**
 Constructor.

 @param crypto the related 'MXCrypto'.
 */
- (instancetype)initWithCrypto:(MXCrypto *)crypto;


#pragma mark - Requests

/**
 Send a message to the other peer in a device verification request.
 
 @param request the request to talk trough.
 @param eventType the message type.
 @param content the message content.
 
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)sendToOtherInRequest:(MXKeyVerificationRequest*)request
                               eventType:(NSString*)eventType
                                 content:(NSDictionary*)content
                                 success:(dispatch_block_t)success
                                 failure:(void (^)(NSError *error))failure;

/**
 Cancel a key verification request or reject an incoming key verification request.

 @param request the request.
 @param success a block called when the operation succeeds.
 @param failure a block called when the operation fails.
 */
- (void)cancelVerificationRequest:(MXKeyVerificationRequest*)request
                          success:(void(^)(void))success
                          failure:(void(^)(NSError *error))failure;

- (BOOL)isRequestStillValid:(MXKeyVerificationRequest*)request;

- (void)removePendingRequestWithRequestId:(NSString*)requestId;

- (void)computeReadyMethodsFromVerificationRequestWithId:(NSString*)transactionId
                                     andSupportedMethods:(NSArray<NSString*>*)supportedMethods
                                              completion:(void (^)(NSArray<NSString*>* readyMethods, MXQRCodeData * _Nullable qrCodeData))completion;

- (MXQRCodeData*)createQRCodeDataWithTransactionId:(NSString*)transactionId otherUserId:(NSString*)otherUserId otherDeviceId:(NSString*)otherDeviceId;

- (void)createQRCodeTransactionWithQRCodeData:(nullable MXQRCodeData*)qrCodeData
                                       userId:(NSString*)userId
                                     deviceId:(NSString*)deviceId
                                transactionId:(nullable NSString*)transactionId
                                     dmRoomId:(nullable NSString*)dmRoomId
                                    dmEventId:(nullable NSString*)dmEventId
                                      success:(void(^)(MXQRCodeTransaction *transaction))success
                                      failure:(void(^)(NSError *error))failure;

- (void)createQRCodeTransactionFromRequest:(MXKeyVerificationRequest*)request
                                qrCodeData:(nullable MXQRCodeData*)qrCodeData
                                   success:(void(^)(MXQRCodeTransaction *transaction))success
                                   failure:(void(^)(NSError *error))failure;

- (BOOL)isOtherQRCodeDataKeysValid:(MXQRCodeData*)otherQRCodeData otherUserId:(NSString*)otherUserId otherDevice:(MXDeviceInfo*)otherDevice;

#pragma mark - Transactions

/**
 Send a message to the other peer in a device verification transaction.

 @param transaction the transation to talk trough.
 @param eventType the message type.
 @param content the message content.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)sendToOtherInTransaction:(MXKeyVerificationTransaction*)transaction
                                   eventType:(NSString*)eventType
                                     content:(NSDictionary*)content
                                     success:(void (^)(void))success
                                     failure:(void (^)(NSError *error))failure;

/**
 Cancel a transaction. Send a cancellation event to the other peer.

 @param transaction the transaction to cancel.
 @param code the cancellation reason.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (void)cancelTransaction:(MXKeyVerificationTransaction*)transaction
                     code:(MXTransactionCancelCode*)code
                  success:(void (^)(void))success
                  failure:(void (^)(NSError *error))failure;

/**
 Remove a transaction from the queue.

 @param transactionId the transaction to remove.
 */
- (void)removeTransactionWithTransactionId:(NSString*)transactionId;

@end

NS_ASSUME_NONNULL_END
