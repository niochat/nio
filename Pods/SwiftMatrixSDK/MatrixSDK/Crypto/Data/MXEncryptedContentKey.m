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

#import "MXEncryptedContentKey.h"

@implementation MXEncryptedContentKey

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXEncryptedContentKey *encryptedContentKey = [[MXEncryptedContentKey alloc] init];
    if (encryptedContentKey)
    {
        MXJSONModelSetString(encryptedContentKey.alg, JSONDictionary[@"alg"]);
        MXJSONModelSetBoolean(encryptedContentKey.ext, JSONDictionary[@"ext"]);
        MXJSONModelSetString(encryptedContentKey.k, JSONDictionary[@"k"]);
        MXJSONModelSetArray(encryptedContentKey.keyOps, JSONDictionary[@"key_ops"]);
        MXJSONModelSetString(encryptedContentKey.kty, JSONDictionary[@"kty"]);
    }
    return encryptedContentKey;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];
    if (JSONDictionary)
    {
        JSONDictionary[@"alg"] = _alg;
        JSONDictionary[@"ext"] = @(_ext);
        JSONDictionary[@"k"] = _k;
        JSONDictionary[@"key_ops"] = _keyOps;
        JSONDictionary[@"kty"] = _kty;
    }
    
    return JSONDictionary;
}

@end
