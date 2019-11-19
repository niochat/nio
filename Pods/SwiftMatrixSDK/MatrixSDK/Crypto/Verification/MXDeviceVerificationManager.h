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

#import "MXDeviceVerificationTransaction.h"

#import "MXSASTransaction.h"
#import "MXIncomingSASTransaction.h"
#import "MXOutgoingSASTransaction.h"

NS_ASSUME_NONNULL_BEGIN


#pragma mark - Constants

FOUNDATION_EXPORT NSString *const MXDeviceVerificationErrorDomain;

typedef enum : NSUInteger
{
    MXDeviceVerificationUnknownDeviceCode,
    MXDeviceVerificationUnsupportedMethodCode
} MXDeviceVerificationErrorCode;


/**
 Posted on new device verification transaction.
 */
FOUNDATION_EXPORT NSString *const MXDeviceVerificationManagerNewTransactionNotification;

/**
 The key in the notification userInfo dictionary containing the `MXDeviceVerificationTransaction` instance.
 */
FOUNDATION_EXPORT NSString *const MXDeviceVerificationManagerNotificationTransactionKey;


/**
 The `MXDeviceVerificationManager` class instance manages interactive device
 verifications according to MSC1267 (Interactive key verification):
 https://github.com/matrix-org/matrix-doc/issues/1267.
 */
@interface MXDeviceVerificationManager : NSObject

/**
 Begin a device verification.

 @param userId the other user id.
 @param deviceId the other user device id.
 @param method the verification method (ex: MXKeyVerificationMethodSAS).
 @param success a block called when the operation succeeds.
 @param failure a block called when the operation fails.
 */
- (void)beginKeyVerificationWithUserId:(NSString*)userId
                           andDeviceId:(NSString*)deviceId
                                method:(NSString*)method
                               success:(void(^)(MXDeviceVerificationTransaction *transaction))success
                               failure:(void(^)(NSError *error))failure;

/**
 All transactions in progress.

 @param complete a block called with all transactions.
 */
- (void)transactions:(void(^)(NSArray<MXDeviceVerificationTransaction*> *transactions))complete;

@end

NS_ASSUME_NONNULL_END
