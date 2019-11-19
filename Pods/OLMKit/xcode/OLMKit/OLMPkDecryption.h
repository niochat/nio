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

#import <Foundation/Foundation.h>

#import "OLMSerializable.h"
#import "OLMPkMessage.h"

NS_ASSUME_NONNULL_BEGIN

@interface OLMPkDecryption : NSObject <OLMSerializable, NSSecureCoding>

/**
 Initialise the key from the private part of a key as returned by `privateKey`.

 Note that the pubkey is a base64 encoded string, but the private key is
 an unencoded byte array.

 @param privateKey the private key part.
 @param error the error if any.
 @return the associated public key.
 */
- (NSString *)setPrivateKey:(NSData*)privateKey error:(NSError* _Nullable *)error;

/**
 Generate a new key to use for decrypting messages.

 @param error the error if any.
 @return the public part of the generated key.
 */
- (NSString *)generateKey:(NSError* _Nullable *)error;

/**
 Get the private key.

 @return the private key;
 */
- (NSData *)privateKey;

/**
 Decrypt a ciphertext.

 @param message the cipher message to decrypt.
 @param error the error if any.
 @return the decrypted message.
 */
- (NSString *)decryptMessage:(OLMPkMessage*)message error:(NSError* _Nullable *)error;

/**
 Private key length.

 @return the length in bytes.
 */
+ (NSUInteger)privateKeyLength;

@end

NS_ASSUME_NONNULL_END
