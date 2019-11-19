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

@interface MXCryptoTools : NSObject

/**
 Get the canonical serialisation of a JSON dictionary.

 This ensures that a JSON has the same string representation cross platforms.

 @param JSONDictinary the JSON to convert.
 @return the canonical serialisation of the JSON.
 */
+ (nullable NSString*)canonicalJSONStringForJSON:(NSDictionary*)JSONDictinary;


/**
 Get the canonical serialisation of a JSON dictionary.

 @param JSONDictinary the JSON to convert.
 @return the canonical serialisation of the JSON in NSData format.
 */
+ (nullable NSData*)canonicalJSONDataForJSON:(NSDictionary*)JSONDictinary;

@end

NS_ASSUME_NONNULL_END
