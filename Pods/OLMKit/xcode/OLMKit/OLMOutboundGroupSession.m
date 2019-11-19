/*
 Copyright 2016 OpenMarket Ltd
 Copyright 2016 Vector Creations Ltd

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

#import "OLMOutboundGroupSession.h"

#import "OLMUtility.h"
#include "olm/olm.h"

@interface OLMOutboundGroupSession ()
{
    OlmOutboundGroupSession *session;
}
@end

@implementation OLMOutboundGroupSession

- (void)dealloc {
    olm_clear_outbound_group_session(session);
    free(session);
}

- (instancetype)init {
    self = [super init];
    if (self)
    {
        session = malloc(olm_outbound_group_session_size());
        if (session) {
            session = olm_outbound_group_session(session);
        }

        if (!session) {
            return nil;
        }
    }
    return self;
}

- (instancetype)initOutboundGroupSession {
    self = [self init];
    if (self) {
        NSMutableData *random = [OLMUtility randomBytesOfLength:olm_init_outbound_group_session_random_length(session)];

        size_t result = olm_init_outbound_group_session(session, random.mutableBytes, random.length);
        [random resetBytesInRange:NSMakeRange(0, random.length)];
        if (result == olm_error())   {
            const char *error = olm_outbound_group_session_last_error(session);
            NSLog(@"olm_init_outbound_group_session error: %s", error);
            return nil;
        }
    }
    return self;
}

- (NSString *)sessionIdentifier {
    size_t length = olm_outbound_group_session_id_length(session);
    NSMutableData *idData = [NSMutableData dataWithLength:length];
    if (!idData) {
        return nil;
    }
    size_t result = olm_outbound_group_session_id(session, idData.mutableBytes, idData.length);
    if (result == olm_error()) {
        const char *error = olm_outbound_group_session_last_error(session);
        NSLog(@"olm_outbound_group_session_id error: %s", error);
        return nil;
    }
    NSString *idString = [[NSString alloc] initWithData:idData encoding:NSUTF8StringEncoding];
    return idString;
}

- (NSUInteger)messageIndex {
    return olm_outbound_group_session_message_index(session);
}

- (NSString *)sessionKey {
    size_t length = olm_outbound_group_session_key_length(session);
    NSMutableData *sessionKeyData = [NSMutableData dataWithLength:length];
    if (!sessionKeyData) {
        return nil;
    }
    size_t result = olm_outbound_group_session_key(session, sessionKeyData.mutableBytes, sessionKeyData.length);
    if (result == olm_error()) {
        const char *error = olm_outbound_group_session_last_error(session);
        NSLog(@"olm_outbound_group_session_key error: %s", error);
        return nil;
    }
    NSString *sessionKey = [[NSString alloc] initWithData:sessionKeyData encoding:NSUTF8StringEncoding];
    [sessionKeyData resetBytesInRange:NSMakeRange(0, sessionKeyData.length)];
    return sessionKey;
}

- (NSString *)encryptMessage:(NSString *)message error:(NSError**)error {
    NSData *plaintextData = [message dataUsingEncoding:NSUTF8StringEncoding];
    size_t ciphertextLength = olm_group_encrypt_message_length(session, plaintextData.length);
    NSMutableData *ciphertext = [NSMutableData dataWithLength:ciphertextLength];
    if (!ciphertext) {
        return nil;
    }
    size_t result = olm_group_encrypt(session, plaintextData.bytes, plaintextData.length, ciphertext.mutableBytes, ciphertext.length);
    if (result == olm_error()) {
        const char *olm_error = olm_outbound_group_session_last_error(session);

        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        NSLog(@"olm_group_encrypt error: %@", errorString);

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
    return [[NSString alloc] initWithData:ciphertext encoding:NSUTF8StringEncoding];
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
    NSMutableData *pickle = [serializedData dataUsingEncoding:NSUTF8StringEncoding].mutableCopy;
    size_t result = olm_unpickle_outbound_group_session(session, key.bytes, key.length, pickle.mutableBytes, pickle.length);
    [pickle resetBytesInRange:NSMakeRange(0, pickle.length)];
    if (result == olm_error()) {
        const char *olm_error = olm_outbound_group_session_last_error(session);
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
    size_t length = olm_pickle_outbound_group_session_length(session);
    NSMutableData *pickled = [NSMutableData dataWithLength:length];
    size_t result = olm_pickle_outbound_group_session(session, key.bytes, key.length, pickled.mutableBytes, pickled.length);
    if (result == olm_error()) {
        const char *olm_error = olm_outbound_group_session_last_error(session);
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
