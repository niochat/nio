/*
 Copyright 2020 The Matrix.org Foundation C.I.C
 
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

@interface MXBase64Tools : NSObject

#pragma mark - Padding

+ (NSString *)base64ToUnpaddedBase64:(NSString *)base64;

+ (NSString *)padBase64:(NSString *)unpadded;

#pragma mark - URL

+ (NSString *)base64UrlToBase64:(NSString *)base64Url;

+ (NSString *)base64ToBase64Url:(NSString *)base64;

#pragma mark - Data

+ (NSData *)dataFromUnpaddedBase64:(NSString *)unpaddedBase64;

+ (NSString *)base64FromData:(NSData *)data;

+ (NSString *)unpaddedBase64FromData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
