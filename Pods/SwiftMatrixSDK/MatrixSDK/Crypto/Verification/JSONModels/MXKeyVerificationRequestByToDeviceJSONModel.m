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

#import "MXKeyVerificationRequestByToDeviceJSONModel.h"

@implementation MXKeyVerificationRequestByToDeviceJSONModel

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXKeyVerificationRequestByToDeviceJSONModel *model = [MXKeyVerificationRequestByToDeviceJSONModel new];
    if (model)
    {
        MXJSONModelSetString(model.fromDevice, JSONDictionary[@"from_device"]);
        MXJSONModelSetString(model.transactionId, JSONDictionary[@"transaction_id"]);
        MXJSONModelSetArray(model.methods, JSONDictionary[@"methods"]);
        MXJSONModelSetUInt64(model.timestamp, JSONDictionary[@"timestamp"]);

    }
    
    // Sanitiy check
    if (!model.fromDevice.length)
    {
        model = nil;
    }
    
    return model;
}

- (NSDictionary *)JSONDictionary
{
    return @{
             @"from_device": _fromDevice,
             @"transaction_id": _transactionId,
             @"methods": _methods,
             @"timestamp": @(_timestamp),
             };
}

@end
