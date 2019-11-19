/*
 Copyright 2016 Chris Ballinger
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

#import "OLMSession.h"
#import "OLMUtility.h"
#import "OLMAccount_Private.h"
#import "OLMSession_Private.h"
#include "olm/olm.h"

@implementation OLMSession

- (void) dealloc {
    olm_clear_session(_session);
    free(_session);
}

- (BOOL) initializeSessionMemory {
    size_t size = olm_session_size();
    _session = malloc(size);
    NSParameterAssert(_session != nil);
    if (!_session) {
        return NO;
    }
    _session = olm_session(_session);
    NSParameterAssert(_session != nil);
    if (!_session) {
        return NO;
    }
    return YES;
}

- (instancetype) init {
    self = [super init];
    if (!self) {
        return nil;
    }
    BOOL success = [self initializeSessionMemory];
    if (!success) {
        return nil;
    }
    return self;
}

- (instancetype) initWithAccount:(OLMAccount*)account {
    self = [self init];
    if (!self) {
        return nil;
    }
    NSParameterAssert(account != nil &&  account.account != NULL);
    if (account == nil || account.account == NULL) {
        return nil;
    }
    _account = account;
    return self;
}

- (instancetype) initOutboundSessionWithAccount:(OLMAccount*)account theirIdentityKey:(NSString*)theirIdentityKey theirOneTimeKey:(NSString*)theirOneTimeKey  error:(NSError**)error {
    self = [self initWithAccount:account];
    if (!self) {
        return nil;
    }
    NSMutableData *random = [OLMUtility randomBytesOfLength:olm_create_outbound_session_random_length(_session)];
    NSData *idKey = [theirIdentityKey dataUsingEncoding:NSUTF8StringEncoding];
    NSData *otKey = [theirOneTimeKey dataUsingEncoding:NSUTF8StringEncoding];
    size_t result = olm_create_outbound_session(_session, account.account, idKey.bytes, idKey.length, otKey.bytes, otKey.length, random.mutableBytes, random.length);
    [random resetBytesInRange:NSMakeRange(0, random.length)];
    if (result == olm_error()) {
        const char *olm_error = olm_session_last_error(_session);

        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        NSLog(@"olm_create_outbound_session error: %@", errorString);

        if (error && olm_error && errorString) {
            *error = [NSError errorWithDomain:OLMErrorDomain
                                         code:0
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: errorString,
                                                NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"olm_create_outbound_session error: %@", errorString]
                                                }];
        }

        return nil;
    }
    return self;
}

- (instancetype) initInboundSessionWithAccount:(OLMAccount*)account oneTimeKeyMessage:(NSString*)oneTimeKeyMessage error:(NSError**)error {
    self = [self initWithAccount:account];
    if (!self) {
        return nil;
    }
    NSMutableData *otk = [NSMutableData dataWithData:[oneTimeKeyMessage dataUsingEncoding:NSUTF8StringEncoding]];
    size_t result = olm_create_inbound_session(_session, account.account, otk.mutableBytes, oneTimeKeyMessage.length);
    if (result == olm_error()) {
        const char *olm_error = olm_session_last_error(_session);

        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        NSLog(@"olm_create_inbound_session error: %@", errorString);

        if (error && olm_error && errorString) {
            *error = [NSError errorWithDomain:OLMErrorDomain
                                         code:0
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: errorString,
                                                NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"olm_create_inbound_session error: %@", errorString]
                                                }];
        }

        return nil;
    }
    return self;
}

- (instancetype) initInboundSessionWithAccount:(OLMAccount*)account theirIdentityKey:(NSString*)theirIdentityKey oneTimeKeyMessage:(NSString*)oneTimeKeyMessage error:(NSError**)error {
    self = [self initWithAccount:account];
    if (!self) {
        return nil;
    }
    NSData *idKey = [theirIdentityKey dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *otk = [NSMutableData dataWithData:[oneTimeKeyMessage dataUsingEncoding:NSUTF8StringEncoding]];
    size_t result = olm_create_inbound_session_from(_session, account.account, idKey.bytes, idKey.length, otk.mutableBytes, otk.length);
    if (result == olm_error()) {
        const char *olm_error = olm_session_last_error(_session);

        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        NSLog(@"olm_create_inbound_session_from error: %@", errorString);

        if (error && olm_error && errorString) {
            *error = [NSError errorWithDomain:OLMErrorDomain
                                         code:0
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: errorString,
                                                NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"olm_create_inbound_session_from error: %@", errorString]
                                                }];
        }

        return nil;
    }
    return self;
}

- (NSString*) sessionIdentifier {
    size_t length = olm_session_id_length(_session);
    NSMutableData *idData = [NSMutableData dataWithLength:length];
    if (!idData) {
        return nil;
    }
    size_t result = olm_session_id(_session, idData.mutableBytes, idData.length);
    if (result == olm_error()) {
        const char *error = olm_session_last_error(_session);
        NSLog(@"olm_session_id error: %s", error);
        return nil;
    }
    NSString *idString = [[NSString alloc] initWithData:idData encoding:NSUTF8StringEncoding];
    return idString;
}

- (BOOL)matchesInboundSession:(NSString *)oneTimeKeyMessage {
    NSMutableData *otk = [NSMutableData dataWithData:[oneTimeKeyMessage dataUsingEncoding:NSUTF8StringEncoding]];

    size_t result = olm_matches_inbound_session(_session, otk.mutableBytes, otk.length);
    if (result == 1) {
        return YES;
    }
    else {
        if (result == olm_error()) {
            const char *error = olm_session_last_error(_session);
            NSLog(@"olm_matches_inbound_session error: %s", error);
        }
        return NO;
    }
}

- (BOOL)matchesInboundSessionFrom:(NSString *)theirIdentityKey oneTimeKeyMessage:(NSString *)oneTimeKeyMessage {
    NSData *idKey = [theirIdentityKey dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *otk = [NSMutableData dataWithData:[oneTimeKeyMessage dataUsingEncoding:NSUTF8StringEncoding]];

    size_t result = olm_matches_inbound_session_from(_session,
                                                     idKey.bytes, idKey.length,
                                                     otk.mutableBytes, otk.length);
    if (result == 1) {
        return YES;
    }
    else {
        if (result == olm_error()) {
            const char *error = olm_session_last_error(_session);
            NSLog(@"olm_matches_inbound_session error: %s", error);
        }
        return NO;
    }
}

- (OLMMessage*) encryptMessage:(NSString*)message error:(NSError**)error {
    size_t messageType = olm_encrypt_message_type(_session);
    size_t randomLength = olm_encrypt_random_length(_session);
    NSMutableData *random = [OLMUtility randomBytesOfLength:randomLength];
    NSData *plaintextData = [message dataUsingEncoding:NSUTF8StringEncoding];
    size_t ciphertextLength = olm_encrypt_message_length(_session, plaintextData.length);
    NSMutableData *ciphertext = [NSMutableData dataWithLength:ciphertextLength];
    if (!ciphertext) {
        return nil;
    }
    size_t result = olm_encrypt(_session, plaintextData.bytes, plaintextData.length, random.mutableBytes, random.length, ciphertext.mutableBytes, ciphertext.length);
    [random resetBytesInRange:NSMakeRange(0, random.length)];
    if (result == olm_error()) {
        const char *olm_error = olm_session_last_error(_session);

        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        NSLog(@"olm_encrypt error: %@", errorString);

        if (error && olm_error && errorString) {
            *error = [NSError errorWithDomain:OLMErrorDomain
                                         code:0
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: errorString,
                                                NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"olm_encrypt error: %@", errorString]
                                                }];
        }

        return nil;
    }
    NSString *ciphertextString = [[NSString alloc] initWithData:ciphertext encoding:NSUTF8StringEncoding];
    OLMMessage *encryptedMessage = [[OLMMessage alloc] initWithCiphertext:ciphertextString type:messageType];
    return encryptedMessage;
}

- (NSString*) decryptMessage:(OLMMessage*)message error:(NSError**)error {
    NSParameterAssert(message != nil);
    NSData *messageData = [message.ciphertext dataUsingEncoding:NSUTF8StringEncoding];
    if (!messageData) {
        return nil;
    }
    NSMutableData *mutMessage = messageData.mutableCopy;
    size_t maxPlaintextLength = olm_decrypt_max_plaintext_length(_session, message.type, mutMessage.mutableBytes, mutMessage.length);
    if (maxPlaintextLength == olm_error()) {
        const char *olm_error = olm_session_last_error(_session);

        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        NSLog(@"olm_decrypt_max_plaintext_length error: %@", errorString);

        if (error && olm_error && errorString) {
            *error = [NSError errorWithDomain:OLMErrorDomain
                                         code:0
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: errorString,
                                                NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"olm_decrypt_max_plaintext_length error: %@", errorString]
                                                }];
        }

        return nil;
    }
    // message buffer is destroyed by olm_decrypt_max_plaintext_length
    mutMessage = messageData.mutableCopy;
    NSMutableData *plaintextData = [NSMutableData dataWithLength:maxPlaintextLength];
    size_t plaintextLength = olm_decrypt(_session, message.type, mutMessage.mutableBytes, mutMessage.length, plaintextData.mutableBytes, plaintextData.length);
    if (plaintextLength == olm_error()) {
        const char *olm_error = olm_session_last_error(_session);

        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        NSLog(@"olm_decrypt error: %@", errorString);

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

#pragma mark OLMSerializable

/** Initializes from encrypted serialized data. Will throw error if invalid key or invalid base64. */
- (instancetype) initWithSerializedData:(NSString*)serializedData key:(NSData*)key error:(NSError**)error {
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
    size_t result = olm_unpickle_session(_session, key.bytes, key.length, pickle.mutableBytes, pickle.length);
    [pickle resetBytesInRange:NSMakeRange(0, pickle.length)];
    if (result == olm_error()) {
        const char *olm_error = olm_session_last_error(_session);
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
    size_t length = olm_pickle_session_length(_session);
    NSMutableData *pickled = [NSMutableData dataWithLength:length];
    size_t result = olm_pickle_session(_session, key.bytes, key.length, pickled.mutableBytes, pickled.length);
    if (result == olm_error()) {
        const char *olm_error = olm_session_last_error(_session);
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
