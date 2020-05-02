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

#import "MXTransactionCancelCode.h"

@implementation MXTransactionCancelCode

- (instancetype)initWithValue:(NSString*)value humanReadable:(NSString*)humanReadable
{
    self = [self init];
    if (self)
    {
        _value = value;
        _humanReadable = humanReadable;
    }
    return self;
}


#pragma mark - Predefined cancel codes

+ (instancetype)user
{
    return [[MXTransactionCancelCode alloc] initWithValue:@"m.user" humanReadable:@"The user cancelled the verification"];
}

+ (instancetype)timeout
{
    return [[MXTransactionCancelCode alloc] initWithValue:@"m.timeout" humanReadable:@"The verification process timed out"];
}

+ (instancetype)unknownTransaction
{
    return [[MXTransactionCancelCode alloc] initWithValue:@"m.unknown_transaction" humanReadable:@"The device does not know about that transaction"];
}

+ (instancetype)unknownMethod
{
    return [[MXTransactionCancelCode alloc] initWithValue:@"m.unknown_method" humanReadable:@"The device can’t agree on a key agreement, hash, MAC, or SAS method"];
}

+ (instancetype)mismatchedCommitment
{
    return [[MXTransactionCancelCode alloc] initWithValue:@"m.mismatched_commitment" humanReadable:@"The hash commitment did not match"];
}

+ (instancetype)mismatchedSas
{
    return [[MXTransactionCancelCode alloc] initWithValue:@"m.mismatched_sas" humanReadable:@"The SAS did not match"];
}

+ (instancetype)unexpectedMessage
{
    return [[MXTransactionCancelCode alloc] initWithValue:@"m.unexpected_message" humanReadable:@"The device received an unexpected message"];
}

+ (instancetype)invalidMessage
{
    return [[MXTransactionCancelCode alloc] initWithValue:@"m.invalid_message" humanReadable:@"An invalid message was received"];
}

+ (instancetype)mismatchedKeys
{
    return [[MXTransactionCancelCode alloc] initWithValue:@"m.key_mismatch" humanReadable:@"Key mismatch"];
}

+ (instancetype)userMismatchError
{
    return [[MXTransactionCancelCode alloc] initWithValue:@"m.user_error" humanReadable:@"User mismatch"];
}

+ (instancetype)qrCodeInvalid
{
    return [[MXTransactionCancelCode alloc] initWithValue:@"m.qr_code.invalid" humanReadable:@"Invalid QR code"];
}

@end
