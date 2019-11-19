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

#import "OLMInboundGroupSession.h"

#import "OLMUtility.h"
#include "olm/olm.h"

@interface OLMInboundGroupSession ()
{
    OlmInboundGroupSession *session;
}
@end


@implementation OLMInboundGroupSession

- (void)dealloc {
    olm_clear_inbound_group_session(session);
    free(session);
}

- (instancetype)init {
    self = [super init];
    if (self)
    {
        session = malloc(olm_inbound_group_session_size());
        if (session) {
            session = olm_inbound_group_session(session);
        }

        if (!session) {
            return nil;
        }
    }
    return self;
}

- (instancetype)initInboundGroupSessionWithSessionKey:(NSString *)sessionKey error:(NSError**)error {
    self = [self init];
    if (self) {
        NSData *sessionKeyData = [sessionKey dataUsingEncoding:NSUTF8StringEncoding];
        size_t result = olm_init_inbound_group_session(session, sessionKeyData.bytes, sessionKeyData.length);
        if (result == olm_error())   {
            const char *olm_error = olm_inbound_group_session_last_error(session);

            NSString *errorString = [NSString stringWithUTF8String:olm_error];
            NSLog(@"olm_init_inbound_group_session error: %@", errorString);

            if (error && olm_error && errorString) {
                *error = [NSError errorWithDomain:OLMErrorDomain
                                             code:0
                                         userInfo:@{
                                                    NSLocalizedDescriptionKey: errorString,
                                                    NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"olm_init_inbound_group_session error: %@", errorString]
                                                    }];
            }

            return nil;
        }
    }
    return self;
}

- (instancetype)initInboundGroupSessionWithImportedSession:(NSString *)sessionKey error:(NSError *__autoreleasing *)error
{
    self = [self init];
    if (self) {
        NSData *sessionKeyData = [sessionKey dataUsingEncoding:NSUTF8StringEncoding];
        size_t result = olm_import_inbound_group_session(session, sessionKeyData.bytes, sessionKeyData.length);
        if (result == olm_error())   {
            const char *olm_error = olm_inbound_group_session_last_error(session);

            NSString *errorString = [NSString stringWithUTF8String:olm_error];
            NSLog(@"olm_import_inbound_group_session error: %@", errorString);

            if (error && olm_error && errorString) {
                *error = [NSError errorWithDomain:OLMErrorDomain
                                             code:0
                                         userInfo:@{
                                                    NSLocalizedDescriptionKey: errorString,
                                                    NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"olm_import_inbound_group_session error: %@", errorString]
                                                    }];
            }

            return nil;
        }
    }
    return self;
}

- (NSString *)sessionIdentifier {
    size_t length = olm_inbound_group_session_id_length(session);
    NSMutableData *idData = [NSMutableData dataWithLength:length];
    if (!idData) {
        return nil;
    }
    size_t result = olm_inbound_group_session_id(session, idData.mutableBytes, idData.length);
    if (result == olm_error()) {
        const char *error = olm_inbound_group_session_last_error(session);
        NSLog(@"olm_inbound_group_session_id error: %s", error);
        return nil;
    }
    NSString *idString = [[NSString alloc] initWithData:idData encoding:NSUTF8StringEncoding];
    return idString;
}

- (NSString *)decryptMessage:(NSString *)message messageIndex:(NSUInteger*)messageIndex error:(NSError**)error
{
    NSParameterAssert(message != nil);
    NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
    if (!messageData) {
        return nil;
    }
    NSMutableData *mutMessage = messageData.mutableCopy;
    size_t maxPlaintextLength = olm_group_decrypt_max_plaintext_length(session, mutMessage.mutableBytes, mutMessage.length);
    if (maxPlaintextLength == olm_error()) {
        const char *olm_error = olm_inbound_group_session_last_error(session);

        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        NSLog(@"olm_group_decrypt_max_plaintext_length error: %@", errorString);

        if (error && olm_error && errorString) {
            *error = [NSError errorWithDomain:OLMErrorDomain
                                         code:0
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: errorString,
                                                NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"olm_group_decrypt_max_plaintext_length error: %@", errorString]
                                                }];
        }
        
        return nil;
    }
    // message buffer is destroyed by olm_group_decrypt_max_plaintext_length
    mutMessage = messageData.mutableCopy;
    NSMutableData *plaintextData = [NSMutableData dataWithLength:maxPlaintextLength];

    uint32_t message_index;
    size_t plaintextLength = olm_group_decrypt(session, mutMessage.mutableBytes, mutMessage.length, plaintextData.mutableBytes, plaintextData.length, &message_index);
    if (plaintextLength == olm_error()) {
        const char *olm_error = olm_inbound_group_session_last_error(session);

        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        NSLog(@"olm_group_decrypt error: %@", errorString);

        if (error && olm_error && errorString) {
            *error = [NSError errorWithDomain:OLMErrorDomain
                                         code:0
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: errorString,
                                                NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"olm_group_decrypt error: %@", errorString]
                                                }];
        }

        return nil;
    }
    plaintextData.length = plaintextLength;
    NSString *plaintext = [[NSString alloc] initWithData:plaintextData encoding:NSUTF8StringEncoding];
    [plaintextData resetBytesInRange:NSMakeRange(0, plaintextData.length)];

    if (messageIndex)
    {
        *messageIndex = message_index;
    }

    return plaintext;
}

- (NSUInteger)firstKnownIndex
{
    return olm_inbound_group_session_first_known_index(session);
}

- (BOOL)isVerified
{
    return (0 != olm_inbound_group_session_is_verified(session));
}

- (NSString*)exportSessionAtMessageIndex:(NSUInteger)messageIndex error:(NSError**)error;
{
    size_t length = olm_export_inbound_group_session_length(session);
    NSMutableData *key = [NSMutableData dataWithLength:length];
    size_t result = olm_export_inbound_group_session(session, key.mutableBytes, key.length, (uint32_t)messageIndex);
    if (result == olm_error()) {
        const char *olm_error = olm_inbound_group_session_last_error(session);
        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        if (error && errorString) {
            *error = [NSError errorWithDomain:OLMErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: errorString}];
        }
        return nil;
    }
    NSString *keyString = [[NSString alloc] initWithData:key encoding:NSUTF8StringEncoding];
    [key resetBytesInRange:NSMakeRange(0, key.length)];
    return keyString;
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
    size_t result = olm_unpickle_inbound_group_session(session, key.bytes, key.length, pickle.mutableBytes, pickle.length);
    [pickle resetBytesInRange:NSMakeRange(0, pickle.length)];
    if (result == olm_error()) {
        const char *olm_error = olm_inbound_group_session_last_error(session);
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
    size_t length = olm_pickle_inbound_group_session_length(session);
    NSMutableData *pickled = [NSMutableData dataWithLength:length];
    size_t result = olm_pickle_inbound_group_session(session, key.bytes, key.length, pickled.mutableBytes, pickled.length);
    if (result == olm_error()) {
        const char *olm_error = olm_inbound_group_session_last_error(session);
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
