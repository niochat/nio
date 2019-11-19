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

#import "MXEncryptedContentFile.h"
#import "MXEncryptedContentKey.h"

@implementation MXEncryptedContentFile

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXEncryptedContentFile *encryptedContentFile = [[MXEncryptedContentFile alloc] init];
    if (encryptedContentFile)
    {
        MXJSONModelSetString(encryptedContentFile.v, JSONDictionary[@"v"]);
        MXJSONModelSetString(encryptedContentFile.url, JSONDictionary[@"url"]);
        MXJSONModelSetString(encryptedContentFile.mimetype, JSONDictionary[@"mimetype"]);
        MXJSONModelSetMXJSONModel(encryptedContentFile.key, MXEncryptedContentKey, JSONDictionary[@"key"]);
        MXJSONModelSetString(encryptedContentFile.iv, JSONDictionary[@"iv"]);
        MXJSONModelSetDictionary(encryptedContentFile.hashes, JSONDictionary[@"hashes"]);
    }
    return encryptedContentFile;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];
    if (JSONDictionary)
    {
        JSONDictionary[@"v"] = _v;
        JSONDictionary[@"url"] = _url;
        JSONDictionary[@"mimetype"] = _mimetype;
        JSONDictionary[@"key"] = _key.JSONDictionary;
        JSONDictionary[@"iv"] = _iv;
        JSONDictionary[@"hashes"] = _hashes;
    }
    
    return JSONDictionary;
}

@end
