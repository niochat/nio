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

#import "OLMPkDecryption.h"

#include "olm/olm.h"
#include "olm/pk.h"
#include "OLMUtility.h"

@interface OLMPkDecryption ()
{
    OlmPkDecryption *session;
}
@end

@implementation OLMPkDecryption

- (void)dealloc {
    olm_clear_pk_decryption(session);
    free(session);
}

- (instancetype)init {
    self = [super init];
    if (self) {
        session = (OlmPkDecryption *)malloc(olm_pk_decryption_size());
        olm_pk_decryption(session);
    }
    return self;
}

- (NSString *)setPrivateKey:(NSData *)privateKey error:(NSError *__autoreleasing  _Nullable *)error {
    size_t publicKeyLength = olm_pk_key_length();
    NSMutableData *publicKeyData = [NSMutableData dataWithLength:publicKeyLength];
    if (!publicKeyData) {
        return nil;
    }

    size_t result = olm_pk_key_from_private(session,
                                            publicKeyData.mutableBytes, publicKeyLength,
                                            (void*)privateKey.bytes, privateKey.length);
    if (result == olm_error()) {
        const char *olm_error = olm_pk_decryption_last_error(session);
        NSLog(@"[OLMPkDecryption] setPrivateKey: olm_pk_key_from_private error: %s", olm_error);

        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        if (error && olm_error && errorString) {
            *error = [NSError errorWithDomain:OLMErrorDomain
                                         code:0
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: errorString,
                                                NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"olm_pk_key_from_private error: %@", errorString]
                                                }];
        }
        return nil;
    }

    NSString *publicKey = [[NSString alloc] initWithData:publicKeyData encoding:NSUTF8StringEncoding];
    return publicKey;
}

- (NSString *)generateKey:(NSError *__autoreleasing  _Nullable *)error {
    size_t randomLength = olm_pk_private_key_length();
    NSMutableData *random = [OLMUtility randomBytesOfLength:randomLength];
    if (!random) {
        return nil;
    }

    size_t publicKeyLength = olm_pk_key_length();
    NSMutableData *publicKeyData = [NSMutableData dataWithLength:publicKeyLength];
    if (!publicKeyData) {
        return nil;
    }

    size_t result = olm_pk_key_from_private(session,
                                            publicKeyData.mutableBytes, publicKeyData.length,
                                            random.mutableBytes, randomLength);
    [random resetBytesInRange:NSMakeRange(0, randomLength)];
    if (result == olm_error()) {
        const char *olm_error = olm_pk_decryption_last_error(session);
        NSLog(@"[OLMPkDecryption] generateKey: olm_pk_key_from_private error: %s", olm_error);

        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        if (error && olm_error && errorString) {
            *error = [NSError errorWithDomain:OLMErrorDomain
                                         code:0
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: errorString,
                                                NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"olm_pk_key_from_private error: %@", errorString]
                                                }];
        }
        return nil;
    }

    NSString *publicKey = [[NSString alloc] initWithData:publicKeyData encoding:NSUTF8StringEncoding];
    return publicKey;
}

- (NSData *)privateKey {
    size_t privateKeyLength = olm_pk_private_key_length();
    NSMutableData *privateKeyData = [NSMutableData dataWithLength:privateKeyLength];
    if (!privateKeyData) {
        return nil;
    }

    size_t result = olm_pk_get_private_key(session,
                                           privateKeyData.mutableBytes, privateKeyLength);
    if (result == olm_error()) {
        const char *olm_error = olm_pk_decryption_last_error(session);
        NSLog(@"[OLMPkDecryption] privateKey: olm_pk_get_private_key error: %s", olm_error);
        return nil;
    }

    NSData *privateKey = [privateKeyData copy];
    [privateKeyData resetBytesInRange:NSMakeRange(0, privateKeyData.length)];

    return privateKey;
}

- (NSString *)decryptMessage:(OLMPkMessage *)message error:(NSError *__autoreleasing  _Nullable *)error {
    NSData *messageData = [message.ciphertext dataUsingEncoding:NSUTF8StringEncoding];
    NSData *macData = [message.mac dataUsingEncoding:NSUTF8StringEncoding];
    NSData *ephemeralKeyData = [message.ephemeralKey dataUsingEncoding:NSUTF8StringEncoding];
    if (!messageData || !macData || !ephemeralKeyData) {
        return nil;
    }

    NSMutableData *mutMessage = messageData.mutableCopy;
    size_t maxPlaintextLength = olm_pk_max_plaintext_length(session, mutMessage.length);
    if (maxPlaintextLength == olm_error()) {
        const char *olm_error = olm_pk_decryption_last_error(session);

        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        NSLog(@"[OLMPkDecryption] decryptMessage: olm_pk_max_plaintext_length error: %@", errorString);

        if (error && olm_error && errorString) {
            *error = [NSError errorWithDomain:OLMErrorDomain
                                         code:0
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: errorString,
                                                NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"olm_pk_max_plaintext_length error: %@", errorString]
                                                }];
        }

        return nil;
    }

    mutMessage = messageData.mutableCopy;
    NSMutableData *plaintextData = [NSMutableData dataWithLength:maxPlaintextLength];
    size_t plaintextLength = olm_pk_decrypt(session,
                                            ephemeralKeyData.bytes, ephemeralKeyData.length,
                                            macData.bytes, macData.length,
                                            mutMessage.mutableBytes, mutMessage.length,
                                            plaintextData.mutableBytes, plaintextData.length);
    if (plaintextLength == olm_error()) {
        const char *olm_error = olm_pk_decryption_last_error(session);

        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        NSLog(@"[OLMPkDecryption] decryptMessage: olm_pk_decrypt error: %@", errorString);

        if (error && olm_error && errorString) {
            *error = [NSError errorWithDomain:OLMErrorDomain
                                         code:0
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: errorString,
                                                NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"olm_decrypt error: %@", errorString]
                                                }];
        }

        return nil;
    }

    plaintextData.length = plaintextLength;
    NSString *plaintext = [[NSString alloc] initWithData:plaintextData encoding:NSUTF8StringEncoding];
    [plaintextData resetBytesInRange:NSMakeRange(0, plaintextData.length)];
    return plaintext;
}

+ (NSUInteger)privateKeyLength {
    return olm_pk_private_key_length();
}

#pragma mark OLMSerializable

/** Initializes from encrypted serialized data. Will throw error if invalid key or invalid base64. */
- (instancetype) initWithSerializedData:(NSString *)serializedData key:(NSData *)key error:(NSError *__autoreleasing *)error {
    self = [self init];
    if (!self) {
        return nil;
    }

    NSParameterAssert(key.length > 0);
    NSParameterAssert(serializedData.length > 0);
    if (key.length == 0 || serializedData.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:OLMErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: @"Bad length."}];
        }
        return nil;
    }

    size_t ephemeralLength = olm_pk_key_length();
    NSMutableData *ephemeralBuffer = [NSMutableData dataWithLength:ephemeralLength];

    NSMutableData *pickle = [serializedData dataUsingEncoding:NSUTF8StringEncoding].mutableCopy;
    size_t result = olm_unpickle_pk_decryption(session,
                                               key.bytes, key.length,
                                               pickle.mutableBytes, pickle.length,
                                               ephemeralBuffer.mutableBytes, ephemeralLength);
    [pickle resetBytesInRange:NSMakeRange(0, pickle.length)];
    if (result == olm_error()) {
        const char *olm_error = olm_pk_decryption_last_error(session);
        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        if (error && errorString) {
            *error = [NSError errorWithDomain:OLMErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: errorString}];
        }
        return nil;
    }
    return self;
}

/** Serializes and encrypts object data, outputs base64 blob */
- (NSString*) serializeDataWithKey:(NSData*)key error:(NSError**)error {
    NSParameterAssert(key.length > 0);
    size_t length = olm_pickle_pk_decryption_length(session);
    NSMutableData *pickled = [NSMutableData dataWithLength:length];

    size_t result = olm_pickle_pk_decryption(session,
                                             key.bytes, key.length,
                                             pickled.mutableBytes, pickled.length);
    if (result == olm_error()) {
        const char *olm_error = olm_pk_decryption_last_error(session);
        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        if (error && errorString) {
            *error = [NSError errorWithDomain:OLMErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: errorString}];
        }
        return nil;
    }

    NSString *pickleString = [[NSString alloc] initWithData:pickled encoding:NSUTF8StringEncoding];
    [pickled resetBytesInRange:NSMakeRange(0, pickled.length)];

    return pickleString;
}

#pragma mark NSSecureCoding

+ (BOOL) supportsSecureCoding {
    return YES;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    NSString *version = [decoder decodeObjectOfClass:[NSString class] forKey:@"version"];

    NSError *error = nil;

    if ([version isEqualToString:@"1"]) {
        NSString *pickle = [decoder decodeObjectOfClass:[NSString class] forKey:@"pickle"];
        NSData *key = [decoder decodeObjectOfClass:[NSData class] forKey:@"key"];

        self = [self initWithSerializedData:pickle key:key error:&error];
    }

    NSParameterAssert(error == nil);
    NSParameterAssert(self != nil);
    if (!self) {
        return nil;
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    NSData *key = [OLMUtility randomBytesOfLength:32];
    NSError *error = nil;
    
    NSString *pickle = [self serializeDataWithKey:key error:&error];
    NSParameterAssert(pickle.length > 0 && error == nil);

    [encoder encodeObject:pickle forKey:@"pickle"];
    [encoder encodeObject:key forKey:@"key"];
    [encoder encodeObject:@"1" forKey:@"version"];
}

@end
