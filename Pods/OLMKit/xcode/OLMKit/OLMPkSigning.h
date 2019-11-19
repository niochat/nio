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

@interface OLMPkSigning : NSObject

/**
 Initialise the signing object with a public/private keypair from a seed.

 @param seed the seed.
 @param error the error if any.
 @return the public key
 */
- (NSString *)doInitWithSeed:(NSData*)seed error:(NSError* _Nullable *)error;

/**
 Sign a message.

 @param message the message to sign.
 @param error the error if any.
 @return the signature.
 */
- (NSString *)sign:(NSString*)message error:(NSError* _Nullable *)error;

/**
 Generate a seed.

 @return the generated seed.
 */
+ (NSData *)generateSeed;

@end

NS_ASSUME_NONNULL_END
