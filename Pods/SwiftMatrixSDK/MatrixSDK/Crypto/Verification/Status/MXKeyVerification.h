/*
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

#import "MXKeyVerificationRequest.h"
#import "MXKeyVerificationTransaction.h"


NS_ASSUME_NONNULL_BEGIN

/**
 Overall verification state.
 */
typedef NS_ENUM(NSInteger, MXKeyVerificationState)
{
    // First request states
    MXKeyVerificationStateRequestPending = 0,
    MXKeyVerificationStateRequestExpired,
    MXKeyVerificationStateRequestReady,
    MXKeyVerificationStateRequestCancelled,
    MXKeyVerificationStateRequestCancelledByMe,
    // Once the request has been accepted, we have transaction states
    MXKeyVerificationStateTransactionStarted,
    MXKeyVerificationStateTransactionCancelled,
    MXKeyVerificationStateTransactionCancelledByMe,
    MXKeyVerificationStateTransactionFailed,

    MXKeyVerificationStateVerified
};

/**
 Represents the status of a key verification.

 A key verification has 2 life cycles:
 - one for the request
 - one for the transactions
 */
@interface MXKeyVerification : NSObject

@property (nonatomic) MXKeyVerificationState state;

// Those values may be not provided if there are not in progress
@property (nonatomic, nullable) MXKeyVerificationRequest *request;
@property (nonatomic, nullable) MXKeyVerificationTransaction *transaction;

@property (nonatomic, readonly) BOOL isRequestAccepted;

@end

NS_ASSUME_NONNULL_END
