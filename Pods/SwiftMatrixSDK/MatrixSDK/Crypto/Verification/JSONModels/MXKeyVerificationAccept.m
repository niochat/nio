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

#import "MXKeyVerificationAccept.h"

@implementation MXKeyVerificationAccept

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXKeyVerificationAccept *model = [[MXKeyVerificationAccept alloc] initWithJSONDictionary:JSONDictionary];
    if (model)
    {
        MXJSONModelSetString(model.keyAgreementProtocol, JSONDictionary[@"key_agreement_protocol"]);
        MXJSONModelSetString(model.hashAlgorithm, JSONDictionary[@"hash"]);
        MXJSONModelSetString(model.messageAuthenticationCode, JSONDictionary[@"message_authentication_code"]);
        MXJSONModelSetArray(model.shortAuthenticationString, JSONDictionary[@"short_authentication_string"]);
        MXJSONModelSetString(model.commitment, JSONDictionary[@"commitment"]);
    }

    return model;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = self.JSONDictionaryWithTransactionId;

    if (_keyAgreementProtocol)
    {
        JSONDictionary[@"key_agreement_protocol"] = _keyAgreementProtocol;
    }
    if (_hashAlgorithm)
    {
        JSONDictionary[@"hash"] = _hashAlgorithm;
    }
    if (_messageAuthenticationCode)
    {
        JSONDictionary[@"message_authentication_code"] = _messageAuthenticationCode;
    }
    if (_shortAuthenticationString)
    {
        JSONDictionary[@"short_authentication_string"] = _shortAuthenticationString;
    }
    if (_commitment)
    {
        JSONDictionary[@"commitment"] = _commitment;
    }

    return JSONDictionary;
}

- (BOOL)isValid
{
    BOOL isValid = YES;

    if (_keyAgreementProtocol.length == 0
        || _hashAlgorithm.length == 0
        || _messageAuthenticationCode.length == 0
        || _shortAuthenticationString.count == 0
        || _commitment.length == 0)
   {
        NSLog(@"[MXKeyVerification] Invalid MXKeyVerificationAccept: %@", self);
        isValid = NO;
    }

    return isValid;
}

@end
