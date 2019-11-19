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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Utility to compute a backup private key from a password and vice-versa.
 */
@interface MXKeyBackupPassword : NSObject

/**
 Compute a private key from a password.

 @param password the password to use.
 @param salt the salt used to generate the private key.
 @param iterations number of key derivations done on the generated private key.
 @param error the output error.
 @return a private key.
 */
+ (nullable NSData *)generatePrivateKeyWithPassword:(NSString*)password salt:(NSString * _Nullable *_Nonnull)salt iterations:(NSUInteger*)iterations error:(NSError * _Nullable *)error;

/**
 Retrieve a private key from {password, salt, iterations}

 @param password the password used to generated the private key.
 @param salt the salt.
 @param iterations number of key derivations
 @param error the output error
 @return a private key.
 */
+ (nullable NSData *)retrievePrivateKeyWithPassword:(NSString*)password salt:(NSString*)salt iterations:(NSUInteger)iterations error:(NSError * _Nullable *)error;

@end

NS_ASSUME_NONNULL_END
