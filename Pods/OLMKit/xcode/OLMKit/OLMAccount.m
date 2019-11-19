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

#import "OLMAccount.h"
#import "OLMAccount_Private.h"
#import "OLMSession.h"
#import "OLMSession_Private.h"
#import "OLMUtility.h"

@import Security;

@implementation OLMAccount

- (void) dealloc {
    olm_clear_account(_account);
    free(_account);
}

- (BOOL) initializeAccountMemory {
    size_t accountSize = olm_account_size();
    _account = malloc(accountSize);
    NSParameterAssert(_account != nil);
    if (!_account) {
        return NO;
    }
    _account = olm_account(_account);
    NSParameterAssert(_account != nil);
    if (!_account) {
        return NO;
    }
    return YES;
}

- (instancetype) init {
    self = [super init];
    if (!self) {
        return nil;
    }
    BOOL success = [self initializeAccountMemory];
    if (!success) {
        return nil;
    }
    return self;
}

- (instancetype) initNewAccount {
    self = [self init];
    if (!self) {
        return nil;
    }
    size_t randomLength = olm_create_account_random_length(_account);
    NSMutableData *random = [OLMUtility randomBytesOfLength:randomLength];
    size_t accountResult = olm_create_account(_account, random.mutableBytes, random.length);
    [random resetBytesInRange:NSMakeRange(0, random.length)];
    if (accountResult == olm_error()) {
        const char *error = olm_account_last_error(_account);
        NSLog(@"error creating account: %s", error);
        return nil;
    }
    return self;
}

- (NSUInteger) maxOneTimeKeys {
    return olm_account_max_number_of_one_time_keys(_account);
}


/** public identity keys */
- (NSDictionary*) identityKeys {
    size_t identityKeysLength = olm_account_identity_keys_length(_account);
    uint8_t *identityKeysBytes = malloc(identityKeysLength);
    if (!identityKeysBytes) {
        return nil;
    }
    size_t result = olm_account_identity_keys(_account, identityKeysBytes, identityKeysLength);
    if (result == olm_error()) {
        const char *error = olm_account_last_error(_account);
        NSLog(@"error getting id keys: %s", error);
        free(identityKeysBytes);
        return nil;
    }
    NSData *idKeyData = [NSData dataWithBytesNoCopy:identityKeysBytes length:identityKeysLength freeWhenDone:YES];
    NSError *error = nil;
    NSDictionary *keysDictionary = [NSJSONSerialization JSONObjectWithData:idKeyData options:0 error:&error];
    if (error) {
        NSLog(@"Could not decode JSON: %@", error.localizedDescription);
    }
    return keysDictionary;
}

- (NSString *)signMessage:(NSData *)messageData {
    size_t signatureLength = olm_account_signature_length(_account);
    uint8_t *signatureBytes = malloc(signatureLength);
    if (!signatureBytes) {
        return nil;
    }

    size_t result = olm_account_sign(_account, messageData.bytes, messageData.length, signatureBytes, signatureLength);
    if (result == olm_error()) {
        const char *error = olm_account_last_error(_account);
        NSLog(@"error signing message: %s", error);
        free(signatureBytes);
        return nil;
    }

    NSData *signatureData = [NSData dataWithBytesNoCopy:signatureBytes length:signatureLength freeWhenDone:YES];
    return [[NSString alloc] initWithData:signatureData encoding:NSUTF8StringEncoding];
}

- (NSDictionary*) oneTimeKeys {
    size_t otkLength = olm_account_one_time_keys_length(_account);
    uint8_t *otkBytes = malloc(otkLength);
    if (!otkBytes) {
        return nil;
    }
    size_t result = olm_account_one_time_keys(_account, otkBytes, otkLength);
    if (result == olm_error()) {
        const char *error = olm_account_last_error(_account);
        NSLog(@"error getting id keys: %s", error);
        free(otkBytes);
        return nil;
    }
    NSData *otk = [NSData dataWithBytesNoCopy:otkBytes length:otkLength freeWhenDone:YES];
    NSError *error = nil;
    NSDictionary *keysDictionary = [NSJSONSerialization JSONObjectWithData:otk options:0 error:&error];
    if (error) {
        NSLog(@"Could not decode JSON: %@", error.localizedDescription);
    }
    return keysDictionary;
}


- (void) generateOneTimeKeys:(NSUInteger)numberOfKeys {
    size_t randomLength = olm_account_generate_one_time_keys_random_length(_account, numberOfKeys);
    NSMutableData *random = [OLMUtility randomBytesOfLength:randomLength];
    size_t result = olm_account_generate_one_time_keys(_account, numberOfKeys, random.mutableBytes, random.length);
    [random resetBytesInRange:NSMakeRange(0, random.length)];
    if (result == olm_error()) {
        const char *error = olm_account_last_error(_account);
        NSLog(@"error generating keys: %s", error);
    }
}

- (BOOL) removeOneTimeKeysForSession:(OLMSession *)session {
    NSParameterAssert(session != nil);
    if (!session) {
        return NO;
    }
    size_t result = olm_remove_one_time_keys(self.account, session.session);
    if (result == olm_error()) {
        const char *error = olm_account_last_error(_account);
        NSLog(@"olm_remove_one_time_keys error: %s", error);
        return NO;
    }
    return YES;
}

- (void)markOneTimeKeysAsPublished
{
    olm_account_mark_keys_as_published(self.account);
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
    size_t result = olm_unpickle_account(_account, key.bytes, key.length, pickle.mutableBytes, pickle.length);
    [pickle resetBytesInRange:NSMakeRange(0, pickle.length)];
    if (result == olm_error()) {
        const char *olm_error = olm_account_last_error(_account);
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
    size_t length = olm_pickle_account_length(_account);
    NSMutableData *pickled = [NSMutableData dataWithLength:length];
    size_t result = olm_pickle_account(_account, key.bytes, key.length, pickled.mutableBytes, pickled.length);
    if (result == olm_error()) {
        const char *olm_error = olm_account_last_error(_account);
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
