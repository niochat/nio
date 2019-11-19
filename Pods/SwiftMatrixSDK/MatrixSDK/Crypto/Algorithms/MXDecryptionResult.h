/*
 Copyright 2016 OpenMarket Ltd

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

FOUNDATION_EXPORT NSString *const MXDecryptingErrorDomain;

typedef enum : NSUInteger
{
    MXDecryptingErrorEncryptionNotEnabledCode = 0,
    MXDecryptingErrorUnableToEncryptCode,
    MXDecryptingErrorUnableToDecryptCode,
    MXDecryptingErrorOlmCode,
    MXDecryptingErrorUnknownInboundSessionIdCode,
    MXDecryptingErrorInboundSessionMismatchRoomIdCode,
    MXDecryptingErrorMissingFieldsCode,
    MXDecryptingErrorMissingCiphertextCode,
    MXDecryptingErrorNotIncludedInRecipientsCode,
    MXDecryptingErrorBadRecipientCode,
    MXDecryptingErrorBadRecipientKeyCode,
    MXDecryptingErrorForwardedMessageCode,
    MXDecryptingErrorBadRoomCode,
    MXDecryptingErrorBadEncryptedMessageCode,
    MXDecryptingErrorDuplicateMessageIndexCode,
    MXDecryptingErrorMissingPropertyCode,
} MXDecryptingErrorCode;

FOUNDATION_EXPORT NSString* const MXDecryptingErrorEncryptionNotEnabledReason;
FOUNDATION_EXPORT NSString* const MXDecryptingErrorUnableToEncrypt;
FOUNDATION_EXPORT NSString* const MXDecryptingErrorUnableToEncryptReason;
FOUNDATION_EXPORT NSString* const MXDecryptingErrorUnableToDecrypt;
FOUNDATION_EXPORT NSString* const MXDecryptingErrorUnableToDecryptReason;
FOUNDATION_EXPORT NSString* const MXDecryptingErrorOlm;
FOUNDATION_EXPORT NSString* const MXDecryptingErrorOlmReason;
FOUNDATION_EXPORT NSString* const MXDecryptingErrorUnknownInboundSessionIdReason;
FOUNDATION_EXPORT NSString* const MXDecryptingErrorInboundSessionMismatchRoomIdReason;
FOUNDATION_EXPORT NSString* const MXDecryptingErrorMissingFieldsReason;
FOUNDATION_EXPORT NSString* const MXDecryptingErrorMissingCiphertextReason;
FOUNDATION_EXPORT NSString* const MXDecryptingErrorNotIncludedInRecipientsReason;
FOUNDATION_EXPORT NSString* const MXDecryptingErrorBadRecipientReason;
FOUNDATION_EXPORT NSString* const MXDecryptingErrorBadRecipientKeyReason;
FOUNDATION_EXPORT NSString* const MXDecryptingErrorForwardedMessageReason;
FOUNDATION_EXPORT NSString* const MXDecryptingErrorBadRoomReason;
FOUNDATION_EXPORT NSString* const MXDecryptingErrorBadEncryptedMessageReason;
FOUNDATION_EXPORT NSString* const MXDecryptingErrorDuplicateMessageIndexReason;
FOUNDATION_EXPORT NSString* const MXDecryptingErrorMissingPropertyReason;

/**
 Result of a decryption.
 */
@interface MXDecryptionResult : NSObject

/**
 The decrypted payload (with properties 'type', 'content')
 */
@property (nonatomic) NSDictionary *payload;

/**
 keys that the sender of the event claims ownership of:
 map from key type to base64-encoded key.
 */
@property (nonatomic) NSDictionary *keysClaimed;

/**
 The curve25519 key that the sender of the event is known to have ownership of.
 */
@property (nonatomic) NSString *senderKey;

/**
 Devices which forwarded this session to us (normally empty).
 */
@property NSArray<NSString *> *forwardingCurve25519KeyChain;

@end
