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

#import "MXDecryptionResult.h"

NSString *const MXDecryptingErrorDomain = @"org.matrix.sdk.decryption";

NSString* const MXDecryptingErrorEncryptionNotEnabledReason         = @"Encryption not enabled";
NSString* const MXDecryptingErrorUnableToEncrypt                    = @"Unable to encrypt";
NSString* const MXDecryptingErrorUnableToEncryptReason              = @"Unable to encrypt %@";
NSString* const MXDecryptingErrorUnableToDecrypt                    = @"Unable to decrypt";
NSString* const MXDecryptingErrorUnableToDecryptReason              = @"Unable to decrypt %@. Algorithm: %@";
NSString* const MXDecryptingErrorOlm                                = @"Error: OLM.%@";
NSString* const MXDecryptingErrorOlmReason                          = @"Unable to decrypt %@. OLM error: %@";
NSString* const MXDecryptingErrorUnknownInboundSessionIdReason      = @"Unknown inbound session id";
NSString* const MXDecryptingErrorInboundSessionMismatchRoomIdReason = @"Mismatched room_id for inbound group session (expected %@, was %@)";
NSString* const MXDecryptingErrorMissingFieldsReason                = @"Missing fields in input";
NSString* const MXDecryptingErrorMissingCiphertextReason            = @"Missing ciphertext";
NSString* const MXDecryptingErrorNotIncludedInRecipientsReason      = @"Not included in recipients";
NSString* const MXDecryptingErrorBadRecipientReason                 = @"Message was intented for %@";
NSString* const MXDecryptingErrorBadRecipientKeyReason              = @"Message not intended for this device";
NSString* const MXDecryptingErrorForwardedMessageReason             = @"Message forwarded from %@";
NSString* const MXDecryptingErrorBadRoomReason                      = @"Message intended for room %@";
NSString* const MXDecryptingErrorBadEncryptedMessageReason          = @"Bad Encrypted Message";
NSString* const MXDecryptingErrorDuplicateMessageIndexReason        = @"Duplicate message index, possible replay attack %@";
NSString* const MXDecryptingErrorMissingPropertyReason              = @"No '%@' property. Cannot prevent unknown-key attack";

@implementation MXDecryptionResult

@end

