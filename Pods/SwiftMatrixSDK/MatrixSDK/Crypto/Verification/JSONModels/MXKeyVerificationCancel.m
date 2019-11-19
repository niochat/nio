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

#import "MXKeyVerificationCancel.h"

@implementation MXKeyVerificationCancel

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXKeyVerificationCancel *model = [MXKeyVerificationCancel new];
    if (model)
    {
        MXJSONModelSetString(model.transactionId, JSONDictionary[@"transaction_id"]);
        MXJSONModelSetString(model.code, JSONDictionary[@"code"]);
        MXJSONModelSetString(model.reason, JSONDictionary[@"reason"]);
    }

    // Sanitiy check
    if (!model.transactionId.length)
    {
        model = nil;
    }

    return model;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionaryWithDictionary:
                                           @{
                                             @"transaction_id": _transactionId,
                                             @"code": _code
                                             }];
    if (_reason)
    {
        JSONDictionary[@"reason"] = _reason;
    }

    return JSONDictionary;
}

@end
