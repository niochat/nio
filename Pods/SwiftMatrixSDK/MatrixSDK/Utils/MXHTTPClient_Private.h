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

#import "MXHTTPClient.h"

/**
 The `MXHTTPClient_Private` extension exposes internal operations like methods
 required for testing.

 Note: These methods are too intrusive. We should implement our own NSURLProtocol
 a la OHHTTPStubs and manage only a delay, not stub data.
 The issue is that AFNetworking does not use the shared NSURLSessionConfiguration so
 that [NSURLProtocol registerClass:] does not work which makes things longer to implement.

 FTR, OHHTTPStubs solves that by doing some swizzling (https://github.com/AliSoftware/OHHTTPStubs/blob/c7c96546db35d5bb15f027b42b9208e57f6c4289/OHHTTPStubs/Sources/NSURLSession/OHHTTPStubs%2BNSURLSessionConfiguration.m#L54).
 */
@interface MXHTTPClient ()

/**
 Set a delay in the reponse of requests containing `string` in their path.

 @param delayMs the delay in milliseconds. 0 to remove it.
 @param string a pattern in the request path.
 */
+ (void)setDelay:(NSUInteger)delayMs toRequestsContainingString:(NSString*)string;

/**
 Remove all created delays.
 */
+ (void)removeAllDelays;

@end
