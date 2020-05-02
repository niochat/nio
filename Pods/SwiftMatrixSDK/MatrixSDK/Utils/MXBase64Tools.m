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

#import "MXBase64Tools.h"

@implementation MXBase64Tools

#pragma mark - Padding

+ (NSString *)base64ToUnpaddedBase64:(NSString *)base64
{
    return [base64 stringByReplacingOccurrencesOfString:@"=" withString:@""];
}

+ (NSString *)padBase64:(NSString *)unpadded
{
    NSString *ret = unpadded;
    
    while (ret.length % 4) {
        ret = [ret stringByAppendingString:@"="];
    }
    return ret;
}

#pragma mark - URL

+ (NSString *)base64UrlToBase64:(NSString *)base64Url
{
    NSString *ret = base64Url;
    ret = [ret stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
    ret = [ret stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    
    // iOS needs the padding to decode base64
    return [[self class] padBase64:ret];
}

+ (NSString *)base64ToBase64Url:(NSString *)base64
{
    NSString *ret = base64;
    ret = [ret stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    ret = [ret stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    // base64url has no padding
    return [ret stringByReplacingOccurrencesOfString:@"=" withString:@""];
}

#pragma mark - Data

+ (NSData *)dataFromUnpaddedBase64:(NSString *)unpaddedBase64
{
    NSString *base64String = [[self class] padBase64:unpaddedBase64];
    return [[NSData alloc] initWithBase64EncodedString:base64String options:NSDataBase64DecodingIgnoreUnknownCharacters];
}

+ (NSString *)base64FromData:(NSData *)data
{
    return [data base64EncodedStringWithOptions:0];
}

+ (NSString *)unpaddedBase64FromData:(NSData *)data
{
    NSString *base64 = [[self class] base64FromData:data];
    return [[self class] base64ToUnpaddedBase64:base64];
}

@end
