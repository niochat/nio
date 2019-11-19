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

NS_ASSUME_NONNULL_BEGIN

@interface OLMPkMessage : NSObject

@property (nonatomic, copy, readonly) NSString *ciphertext;
@property (nonatomic, copy, readonly,) NSString *mac;
@property (nonatomic, copy, readonly) NSString *ephemeralKey;

- (instancetype) initWithCiphertext:(NSString*)ciphertext mac:(NSString*)mac ephemeralKey:(NSString*)ephemeralKey;

@end

NS_ASSUME_NONNULL_END
