/*
 Copyright 2018 New Vector Ltd

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

#import "OLMPkEncryption.h"

#include "olm/olm.h"
#include "olm/pk.h"
#include "OLMUtility.h"

@interface OLMPkEncryption ()
{
    OlmPkEncryption *session;
}
@end

@implementation OLMPkEncryption

- (void)dealloc {
    olm_clear_pk_encryption(session);
    free(session);
}


- (instancetype)init {
    self = [super init];
    if (self) {
        session = (OlmPkEncryption *)malloc(olm_pk_encryption_size());
        olm_pk_encryption(session);
    }
    return self;
}

- (void)setRecipientKey:(NSString*)recipientKey {
    NSData *recipientKeyData = [recipientKey dataUsingEncoding:NSUTF8StringEncoding];
    olm_pk_encryption_set_recipient_key(session, recipientKeyData.bytes, recipientKeyData.length);
}

- (OLMPkMessage *)encryptMessage:(NSString *)message error:(NSError *__autoreleasing  _Nullable *)error {
    NSData *plaintextData = [message dataUsingEncoding:NSUTF8StringEncoding];

    size_t randomLength = olm_pk_encrypt_random_length(session);
    NSMutableData *random = [OLMUtility randomBytesOfLength:randomLength];
    if (!random) {
        return nil;
    }

    size_t ciphertextLength = olm_pk_ciphertext_length(session, plaintextData.length);
    NSMutableData *ciphertext = [NSMutableData dataWithLength:ciphertextLength];
    if (!ciphertext) {
        return nil;
    }

    size_t macLength = olm_pk_mac_length(session);
    NSMutableData *macData = [NSMutableData dataWithLength:macLength];
    if (!macData) {
        return nil;
    }

    size_t ephemeralKeyLength = olm_pk_key_length();
    NSMutableData *ephemeralKeyData = [NSMutableData dataWithLength:ephemeralKeyLength];
    if (!ephemeralKeyData) {
        return nil;
    }

    size_t result = olm_pk_encrypt(session,
                                   plaintextData.bytes, plaintextData.length,
                                   ciphertext.mutableBytes, ciphertext.length,
                                   macData.mutableBytes, macLength,
                                   ephemeralKeyData.mutableBytes, ephemeralKeyLength,
                                   random.mutableBytes, randomLength);
    if (result == olm_error()) {
        const char *olm_error = olm_pk_encryption_last_error(session);

        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        NSLog(@"[OLMPkEncryption] encryptMessage: olm_group_encrypt error: %@", errorString);

        if (error && olm_error && errorString) {
            *error = [NSError errorWithDomain:OLMErrorDomain
                                         code:0
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: errorString,
                                                NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"olm_group_encrypt error: %@", errorString]
                                                }];
        }

        return nil;
    }

    OLMPkMessage *encryptedMessage = [[OLMPkMessage alloc]
                                      initWithCiphertext:[[NSString alloc] initWithData:ciphertext encoding:NSUTF8StringEncoding]
                                      mac:[[NSString alloc] initWithData:macData encoding:NSUTF8StringEncoding]
                                      ephemeralKey:[[NSString alloc] initWithData:ephemeralKeyData encoding:NSUTF8StringEncoding]];


    return encryptedMessage;
}

@end
