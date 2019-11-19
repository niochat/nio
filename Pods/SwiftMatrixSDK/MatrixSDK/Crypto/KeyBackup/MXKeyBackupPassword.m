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

#import "MXKeyBackupPassword.h"

#import "MXTools.h"
#import "MXCryptoConstants.h"

#import <OLMKit/OLMKit.h>

#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonKeyDerivation.h>

#pragma mark - Constants

static NSUInteger const kSaltLength = 32;
static NSUInteger const kDefaultIterations = 500000;


@implementation MXKeyBackupPassword

+ (NSData *)generatePrivateKeyWithPassword:(NSString *)password salt:(NSString *__autoreleasing *)salt iterations:(NSUInteger *)iterations error:(NSError *__autoreleasing  _Nullable *)error
{
    *salt = [[MXTools generateSecret] substringWithRange:NSMakeRange(0, kSaltLength)];
    *iterations = kDefaultIterations;

    NSData *privateKey = [self deriveKey:password salt:*salt iterations:kDefaultIterations error:error];

    return privateKey;
}

+ (NSData *)retrievePrivateKeyWithPassword:(NSString *)password salt:(NSString *)salt iterations:(NSUInteger)iterations error:(NSError *__autoreleasing  _Nullable *)error
{
    return [self deriveKey:password salt:salt iterations:iterations error:error];
}


#pragma mark - Private methods

/**
 Compute a private key by deriving a password and a salt strings.

 @param password the password.
 @param salt the salt.
 @param iterations number of derivations.
 @param error the output error.
 @return a private key.
 */
+ (nullable NSData *)deriveKey:(NSString*)password salt:(NSString*)salt iterations:(NSUInteger)iterations error:(NSError *__autoreleasing  _Nullable *)error
{
    NSDate *startDate = [NSDate date];

    NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    NSData *saltData = [salt dataUsingEncoding:NSUTF8StringEncoding];

    NSMutableData *derivedKey = [NSMutableData dataWithLength:[OLMPkDecryption privateKeyLength]];

    int result =  CCKeyDerivationPBKDF(kCCPBKDF2,
                                   passwordData.bytes,
                                   passwordData.length,
                                   saltData.bytes,
                                   saltData.length,
                                   kCCPRFHmacAlgSHA512,
                                   (uint)iterations,
                                   derivedKey.mutableBytes,
                                   derivedKey.length);

    NSLog(@"[MXKeyBackupPassword] deriveKey: %tu iterations took %.0fms", iterations, [[NSDate date] timeIntervalSinceDate:startDate] * 1000);

    if (result != kCCSuccess)
    {
        derivedKey = nil;

        if (*error)
        {
            *error = [NSError errorWithDomain:MXKeyBackupErrorDomain
                                                 code:MXKeyBackupErrorCannotDeriveKeyCode
                                             userInfo:@{
                                                        NSLocalizedDescriptionKey: [NSString stringWithFormat:@"CCKeyDerivationPBKDF fails: %@", @(result)]
                                                        }];
        }
    }

    return derivedKey;
}

@end
