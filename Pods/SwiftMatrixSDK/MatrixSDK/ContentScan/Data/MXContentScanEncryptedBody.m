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

#import "MXContentScanEncryptedBody.h"
#import <OLMKit/OLMKit.h>

@implementation MXContentScanEncryptedBody

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXContentScanEncryptedBody *contentScanEncryptedBody = [[MXContentScanEncryptedBody alloc] init];
    if (contentScanEncryptedBody)
    {
        MXJSONModelSetString(contentScanEncryptedBody.ciphertext, JSONDictionary[@"ciphertext"]);
        MXJSONModelSetString(contentScanEncryptedBody.mac, JSONDictionary[@"mac"]);
        MXJSONModelSetString(contentScanEncryptedBody.ephemeral, JSONDictionary[@"ephemeral"]);
    }
    return contentScanEncryptedBody;
}

+ (id)modelFromOLMPkMessage:(OLMPkMessage *)OLMPkMessage
{
    MXContentScanEncryptedBody *contentScanEncryptedBody = [[MXContentScanEncryptedBody alloc] init];
    if (contentScanEncryptedBody)
    {
        contentScanEncryptedBody.ciphertext = OLMPkMessage.ciphertext;
        contentScanEncryptedBody.mac = OLMPkMessage.mac;
        contentScanEncryptedBody.ephemeral = OLMPkMessage.ephemeralKey;
    }
    return contentScanEncryptedBody;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];
    if (JSONDictionary)
    {
        JSONDictionary[@"ciphertext"] = _ciphertext;
        JSONDictionary[@"mac"] = _mac;
        JSONDictionary[@"ephemeral"] = _ephemeral;
    }
    
    return JSONDictionary;
}

@end
