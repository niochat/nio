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

#import "OLMPkSigning.h"

#include "olm/olm.h"
#include "olm/pk.h"
#include "OLMUtility.h"

@interface OLMPkSigning ()
{
    OlmPkSigning *sign;
}
@end

@implementation OLMPkSigning

- (void)dealloc {
    olm_clear_pk_signing(sign);
    free(sign);
}


- (instancetype)init {
    self = [super init];
    if (self) {
        sign = (OlmPkSigning *)malloc(olm_pk_signing_size());
        olm_pk_signing(sign);
    }
    return self;
}

- (NSString *)doInitWithSeed:(NSData *)seed error:(NSError *__autoreleasing  _Nullable *)error {
    size_t publicKeyLength = olm_pk_signing_public_key_length();
    NSMutableData *publicKeyData = [NSMutableData dataWithLength:publicKeyLength];
    if (!publicKeyData) {
        return nil;
    }

    NSMutableData *mutableSeed = [NSMutableData dataWithData:seed];

    size_t result = olm_pk_signing_key_from_seed(sign,
                                                 publicKeyData.mutableBytes, publicKeyLength,
                                                 mutableSeed.mutableBytes, mutableSeed.length);
    if (result == olm_error()) {
        const char *olm_error = olm_pk_signing_last_error(sign);

        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        NSLog(@"[OLMPkSigning] doInitWithSeed: olm_pk_signing_key_from_seed error: %@", errorString);

        if (error && olm_error && errorString) {
            *error = [NSError errorWithDomain:OLMErrorDomain
                                         code:0
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: errorString,
                                                NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"olm_pk_signing_key_from_seed error: %@", errorString]
                                                }];
        }

        return nil;
    }

    [mutableSeed resetBytesInRange:NSMakeRange(0, mutableSeed.length)];

    NSString *publicKey = [[NSString alloc] initWithData:publicKeyData encoding:NSUTF8StringEncoding];
    return publicKey;
}

- (NSString *)sign:(NSString *)message error:(NSError *__autoreleasing  _Nullable *)error {
    NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];

    size_t signatureLength = olm_pk_signature_length();
    NSMutableData *signatureData = [NSMutableData dataWithLength:signatureLength];
    if (!signatureData) {
        return nil;
    }

    size_t result = olm_pk_sign(sign,
                                messageData.bytes, messageData.length,
                                signatureData.mutableBytes, signatureLength);
    if (result == olm_error()) {
        const char *olm_error = olm_pk_signing_last_error(sign);

        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        NSLog(@"[OLMPkSigning] sign: olm_pk_sign error: %@", errorString);

        if (error && olm_error && errorString) {
            *error = [NSError errorWithDomain:OLMErrorDomain
                                         code:0
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: errorString,
                                                NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"olm_pk_sign error: %@", errorString]
                                                }];
        }

        return nil;
    }

    NSString *signature = [[NSString alloc] initWithData:signatureData encoding:NSUTF8StringEncoding];
    return signature;
}

+ (NSData *)generateSeed {
    size_t seedLength = olm_pk_signing_seed_length();
    NSMutableData *seed = [OLMUtility randomBytesOfLength:seedLength];
    if (!seed) {
        return nil;
    }

    return seed;
}

@end
