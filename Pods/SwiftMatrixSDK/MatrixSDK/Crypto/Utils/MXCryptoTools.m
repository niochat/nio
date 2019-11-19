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

#import "MXCryptoTools.h"

#import "NSObject+sortedKeys.h"

@implementation MXCryptoTools

+ (nullable NSString *)canonicalJSONStringForJSON:(NSDictionary *)JSONDictinary
{
    NSString *unescapedCanonicalJSON;

    NSData *canonicalJSONData = [NSJSONSerialization dataWithJSONObject:[JSONDictinary objectWithSortedKeys] options:0 error:nil];

    // NSJSONSerialization escapes the '/' character in base64 strings which is useless in our case
    // and does not match with other platforms.
    // Remove this escaping

    if (canonicalJSONData)
    {
        unescapedCanonicalJSON = [[NSString alloc] initWithData:canonicalJSONData encoding:NSUTF8StringEncoding];
        unescapedCanonicalJSON = [unescapedCanonicalJSON stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
    }

    return unescapedCanonicalJSON;
}

+ (nullable NSData *)canonicalJSONDataForJSON:(NSDictionary *)JSONDictinary
{
    return [[self canonicalJSONStringForJSON:JSONDictinary] dataUsingEncoding:NSUTF8StringEncoding];
}

@end
