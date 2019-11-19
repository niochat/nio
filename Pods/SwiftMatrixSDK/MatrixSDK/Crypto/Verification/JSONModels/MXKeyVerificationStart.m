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

#import "MXKeyVerificationStart.h"

#import "MXSASTransaction.h"

@implementation MXKeyVerificationStart

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXKeyVerificationStart *model = [MXKeyVerificationStart new];
    if (model)
    {
        MXJSONModelSetString(model.method, JSONDictionary[@"method"]);
        MXJSONModelSetString(model.fromDevice, JSONDictionary[@"from_device"]);
        MXJSONModelSetString(model.transactionId, JSONDictionary[@"transaction_id"]);
        MXJSONModelSetArray(model.keyAgreementProtocols, JSONDictionary[@"key_agreement_protocols"]);
        MXJSONModelSetArray(model.hashAlgorithms, JSONDictionary[@"hashes"]);
        MXJSONModelSetArray(model.messageAuthenticationCodes, JSONDictionary[@"message_authentication_codes"]);
        MXJSONModelSetArray(model.shortAuthenticationString, JSONDictionary[@"short_authentication_string"]);
    }

    // Sanitiy check
    if (!model.transactionId.length || !model.fromDevice.length)
    {
        model = nil;
    }

    return model;
}

- (NSDictionary *)JSONDictionary
{
    return @{
             @"method": _method,
             @"from_device": _fromDevice,
             @"transaction_id": _transactionId,
             @"key_agreement_protocols": _keyAgreementProtocols,
             @"hashes": _hashAlgorithms,
             @"message_authentication_codes": _messageAuthenticationCodes,
             @"short_authentication_string": _shortAuthenticationString,
             };
}

- (BOOL)isValid
{
    BOOL isValid = YES;

    if (_method.length == 0
        || _keyAgreementProtocols.count == 0
        || _hashAlgorithms.count == 0
        || [_hashAlgorithms containsObject:@"sha256"] == NO
        || _messageAuthenticationCodes.count == 0
        || ([_messageAuthenticationCodes containsObject:MXKeyVerificationSASMacSha256] == NO
            && [_messageAuthenticationCodes containsObject:MXKeyVerificationSASMacSha256LongKdf] == NO)    // Accept old MAC format
        || _shortAuthenticationString.count == 0
        || [_shortAuthenticationString containsObject:MXKeyVerificationSASModeDecimal] == NO)
    {
        NSLog(@"[MXKeyVerification] Invalid MXKeyVerificationStart: %@", self);
        isValid = NO;
    }

    return isValid;
}

@end
