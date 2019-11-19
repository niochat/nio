/*
 Copyright 2016 OpenMarket Ltd

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

#import "MXJSONModel.h"

#import "MXUsersDevicesMap.h"

/**
 Key types.
 */
FOUNDATION_EXPORT NSString *const kMXKeyCurve25519Type;
FOUNDATION_EXPORT NSString *const kMXKeySignedCurve25519Type;
FOUNDATION_EXPORT NSString *const kMXKeyEd25519Type;

/**
 A `MXKey` instance stores a key data shared for Matrix cryptography.
 */
@interface MXKey : MXJSONModel

/**
 The type of the key.
 */
@property (nonatomic) NSString *type;

/**
 The id of the key.
 */
@property (nonatomic) NSString *keyId;

/**
 The key.
 */
@property (nonatomic) NSString *value;

/**
 The full identifier of the key.
 It is formatted as "<type>:<keyId>".
 */
@property (nonatomic) NSString *keyFullId;

/**
 Signatures by userId by deviceId (well, this is "<key_type:device_id>" which is almost the same).
 */
@property (nonatomic) MXUsersDevicesMap<NSString*> *signatures;

- (instancetype)initWithType:(NSString*)type keyId:(NSString*)keyId value:(NSString*)value;

/**
 Same as the parent [MXJSONModel JSONDictionary] but return only
 data that must be signed.
 */
@property (nonatomic, readonly) NSDictionary *signalableJSONDictionary;

@end
