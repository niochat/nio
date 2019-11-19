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

#import "OLMSAS.h"

#include "olm/olm.h"
#include "olm/sas.h"
#include "OLMUtility.h"

@interface OLMSAS () {
    void *olmSASbuffer;
    OlmSAS *olmSAS;
}
@end

@implementation OLMSAS

- (void)dealloc {
    olm_clear_sas(olmSAS);
    free(olmSASbuffer);
}

- (instancetype)init {
    self = [super init];
    if (self) {
        olmSASbuffer = malloc(olm_sas_size());
        olmSAS = olm_sas(olmSASbuffer);

        size_t randomLength = olm_create_sas_random_length(olmSAS);
        NSMutableData *random = [OLMUtility randomBytesOfLength:randomLength];
        if (!random) {
            return nil;
        }

        olm_create_sas(olmSAS, random.mutableBytes, randomLength);

        [random resetBytesInRange:NSMakeRange(0, randomLength)];
    }
    return self;
}

- (NSString * _Nullable)publicKey {
    size_t publicKeyLength = olm_sas_pubkey_length(olmSAS);
    NSMutableData *publicKeyData = [NSMutableData dataWithLength:publicKeyLength];
    if (!publicKeyData) {
        return nil;
    }

    size_t result = olm_sas_get_pubkey(olmSAS, publicKeyData.mutableBytes, publicKeyLength);
    if (result == olm_error()) {
        const char *olm_error = olm_sas_last_error(olmSAS);
        NSLog(@"[OLMSAS] publicKey: olm_sas_get_pubkey error: %s", olm_error);
        return nil;
    }

    NSString *publicKey = [[NSString alloc] initWithData:publicKeyData encoding:NSUTF8StringEncoding];
    return publicKey;
}

- (NSError * _Nullable)setTheirPublicKey:(NSString*)theirPublicKey {
    NSMutableData *theirPublicKeyData = [theirPublicKey dataUsingEncoding:NSUTF8StringEncoding].mutableCopy;

    size_t result = olm_sas_set_their_key(olmSAS, theirPublicKeyData.mutableBytes, theirPublicKeyData.length);
    if (result == olm_error()) {
        const char *olm_error = olm_sas_last_error(olmSAS);
        NSLog(@"[OLMSAS] setTheirPublicKey: olm_sas_set_their_key error: %s", olm_error);

        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        if (olm_error && errorString) {
            return [NSError errorWithDomain:OLMErrorDomain
                                       code:0
                                   userInfo:@{
                                              NSLocalizedDescriptionKey: errorString,
                                              NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"olm_sas_set_their_key error: %@", errorString]
                                              }];
        }
    }

    return nil;
}

- (NSData *)generateBytes:(NSString *)info length:(NSUInteger)length {
    NSData *infoData = [info dataUsingEncoding:NSUTF8StringEncoding];

    NSMutableData *bytes = [NSMutableData dataWithLength:length];
    if (!bytes) {
        return nil;
    }

    olm_sas_generate_bytes(olmSAS, infoData.bytes, infoData.length, bytes.mutableBytes, length);
    return bytes;
}

- (NSString *)calculateMac:(NSString *)input info:(NSString *)info error:(NSError *__autoreleasing  _Nullable *)error {
    NSMutableData *inputData = [input dataUsingEncoding:NSUTF8StringEncoding].mutableCopy;
    NSData *infoData = [info dataUsingEncoding:NSUTF8StringEncoding];

    size_t macLength = olm_sas_mac_length(olmSAS);
    NSMutableData *macData = [NSMutableData dataWithLength:macLength];
    if (!macData) {
        return nil;
    }

    size_t result = olm_sas_calculate_mac(olmSAS,
                                          inputData.mutableBytes, inputData.length,
                                          infoData.bytes, infoData.length,
                                          macData.mutableBytes, macLength);
    if (result == olm_error()) {
        const char *olm_error = olm_sas_last_error(olmSAS);
        NSLog(@"[OLMSAS] calculateMac: olm_sas_calculate_mac error: %s", olm_error);

        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        if (error && olm_error && errorString) {
            *error = [NSError errorWithDomain:OLMErrorDomain
                                         code:0
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: errorString,
                                                NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"olm_sas_calculate_mac error: %@", errorString]
                                                }];
        }
        return nil;
    }

    NSString *mac = [[NSString alloc] initWithData:macData encoding:NSUTF8StringEncoding];
    return mac;
}

- (NSString *)calculateMacLongKdf:(NSString *)input info:(NSString *)info error:(NSError *__autoreleasing  _Nullable *)error {
    NSMutableData *inputData = [input dataUsingEncoding:NSUTF8StringEncoding].mutableCopy;
    NSData *infoData = [info dataUsingEncoding:NSUTF8StringEncoding];

    size_t macLength = olm_sas_mac_length(olmSAS);
    NSMutableData *macData = [NSMutableData dataWithLength:macLength];
    if (!macData) {
        return nil;
    }

    size_t result = olm_sas_calculate_mac_long_kdf(olmSAS,
                                                   inputData.mutableBytes, inputData.length,
                                                   infoData.bytes, infoData.length,
                                                   macData.mutableBytes, macLength);
    if (result == olm_error()) {
        const char *olm_error = olm_sas_last_error(olmSAS);
        NSLog(@"[OLMSAS] calculateMacLongKdf: olm_sas_calculate_mac error: %s", olm_error);

        NSString *errorString = [NSString stringWithUTF8String:olm_error];
        if (error && olm_error && errorString) {
            *error = [NSError errorWithDomain:OLMErrorDomain
                                         code:0
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: errorString,
                                                NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"olm_sas_calculate_mac_long_kdf error: %@", errorString]
                                                }];
        }
        return nil;
    }

    NSString *mac = [[NSString alloc] initWithData:macData encoding:NSUTF8StringEncoding];
    return mac;
}

@end
