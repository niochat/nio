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

NS_ASSUME_NONNULL_BEGIN

/**
 A transaction cancellation.
 */
@interface MXTransactionCancelCode : NSObject

/**
 The error code.
 */
@property (nonatomic, readonly) NSString *value;

/**
 A human readable reason.
 */
@property (nonatomic, readonly) NSString *humanReadable;

- (instancetype)initWithValue:(NSString*)value humanReadable:(NSString*)humanReadable;


#pragma mark - Predefined cancel codes

// The user cancelled the verification
+ (instancetype)user;

// The verification process timed out
+ (instancetype)timeout;

// The device does not know about that transaction
+ (instancetype)unknownTransaction;

// The device can’t agree on a key agreement, hash, MAC, or SAS method
+ (instancetype)unknownMethod;

// The hash commitment did not match
+ (instancetype)mismatchedCommitment;

// The SAS did not match
+ (instancetype)mismatchedSas;

// The device received an unexpected message
+ (instancetype)unexpectedMessage;

// An invalid message was received
+ (instancetype)invalidMessage;

// Keys did not match
+ (instancetype)mismatchedKeys;

// The user does not match
+ (instancetype)userMismatchError;

// The QR code is invalid
+ (instancetype)qrCodeInvalid;

@end

NS_ASSUME_NONNULL_END
