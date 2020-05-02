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

#import "MXTransactionCancelCode.h"
#import "MXDeviceInfo.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Constants

/**
 Notification sent when the transaction has been updated.
 */
FOUNDATION_EXPORT NSString * _Nonnull const MXKeyVerificationTransactionDidChangeNotification;

typedef NS_ENUM(NSInteger, MXKeyVerificationTransport) {
    MXKeyVerificationTransportToDevice = 0,
    MXKeyVerificationTransportDirectMessage,
};


/**
 An handler on an interactive device verification.
 */
@interface MXKeyVerificationTransaction: NSObject

/**
 The transaction id.
 */
@property (nonatomic, readonly) NSString *transactionId;

/**
 Transport layer.
 Default is by to_device events.
 */
@property (nonatomic, readonly) MXKeyVerificationTransport transport;

/**
 YES for an incoming verification request.
 */
@property (nonatomic) BOOL isIncoming;

/**
 The creation date.
 */
@property (nonatomic, strong) NSDate *creationDate;

/**
 The other user device.
 */
@property (nonatomic, readonly) MXDeviceInfo *otherDevice;

/**
 The other user id.
 */
@property (nonatomic, readonly) NSString *otherUserId;

/**
 The other user device id.
 */
@property (nonatomic, readonly) NSString *otherDeviceId;

/**
 The cancellation reason, if any.
 */
@property (nonatomic, nullable) MXTransactionCancelCode *reasonCancelCode;

/**
 The occured error (like network error), if any.
 */
@property (nonatomic, nullable) NSError *error;

/**
 Cancel this transaction.

 @param code the cancellation reason
 */
- (void)cancelWithCancelCode:(MXTransactionCancelCode*)code;

/**
 Cancel this transaction.
 
 @param code the cancellation reason
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (void)cancelWithCancelCode:(MXTransactionCancelCode *)code
                     success:(void (^)(void))success
                     failure:(void (^)(NSError *error))failure;


#pragma mark - Transport layer
#pragma mark Direct message

@property (nonatomic, nullable, readonly) NSString *dmRoomId;
@property (nonatomic, nullable, readonly) NSString *dmEventId;

@end

NS_ASSUME_NONNULL_END
