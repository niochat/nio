/*
 Copyright 2016 OpenMarket Ltd
 
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

/**
 Define a `NSData` category at MatrixSDK level.
 */
@interface NSData (MatrixSDK)

/**
 Return a MD5 hash code from NSData content.
 
 @return a hex string without space.
 */
- (NSString*)mx_MD5;

/**
 Return a SHA256 hash code from NSData content.
 
 @return a hex string without space.
 */
- (NSString*)mx_SHA256;

/**
 Return a readable SHA256 hash code from NSData content.
 
 @return a hex string with a white space between each value.
 */
- (NSString*)mx_SHA256AsHexString;

@end
