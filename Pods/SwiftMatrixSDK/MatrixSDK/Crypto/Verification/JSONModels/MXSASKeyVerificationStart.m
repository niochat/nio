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

#import "MXSASKeyVerificationStart.h"

#import "MXSASTransaction.h"

@implementation MXSASKeyVerificationStart

- (instancetype)initWithJSONDictionary:(NSDictionary *)JSONDictionary
{
    self = [super initWithJSONDictionary:JSONDictionary];
    if (self)
    {
        MXJSONModelSetArray(_keyAgreementProtocols, JSONDictionary[@"key_agreement_protocols"]);
        MXJSONModelSetArray(_hashAlgorithms, JSONDictionary[@"hashes"]);
        MXJSONModelSetArray(_messageAuthenticationCodes, JSONDictionary[@"message_authentication_codes"]);
        MXJSONModelSetArray(_shortAuthenticationString, JSONDictionary[@"short_authentication_string"]);
    }
    
    // Sanitiy check
    if (!self.isValid)
    {
        return nil;
    }
    
    return self;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [[super JSONDictionary] mutableCopy];
    
    [JSONDictionary addEntriesFromDictionary:@{
                                               @"key_agreement_protocols": _keyAgreementProtocols,
                                               @"hashes": _hashAlgorithms,
                                               @"message_authentication_codes": _messageAuthenticationCodes,
                                               @"short_authentication_string": _shortAuthenticationString,
                                               }];
    
    [JSONDictionary addEntriesFromDictionary:self.JSONDictionaryWithTransactionId];
    
    return JSONDictionary;
}

- (BOOL)isValid
{
    BOOL isValid = YES;
    
    if (self.fromDevice.length == 0
        || self.method.length == 0
        || _keyAgreementProtocols.count == 0
        || _hashAlgorithms.count == 0
        || [_hashAlgorithms containsObject:@"sha256"] == NO
        || _messageAuthenticationCodes.count == 0
        || ([_messageAuthenticationCodes containsObject:MXKeyVerificationSASMacSha256] == NO
            && [_messageAuthenticationCodes containsObject:MXKeyVerificationSASMacSha256LongKdf] == NO)    // Accept old MAC format
        || _shortAuthenticationString.count == 0
        || [_shortAuthenticationString containsObject:MXKeyVerificationSASModeDecimal] == NO)
    {
        NSLog(@"[MXKeyVerification] Invalid MXSASKeyVerificationStart: %@", self);
        isValid = NO;
    }
    
    return isValid;
}

@end
