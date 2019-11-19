/*
 Copyright 2016 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd

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

#import <Foundation/Foundation.h>

#import "MXJSONModel.h"

/**
 The device verification state.
 */
typedef enum : NSUInteger
{
    /**
     The user has not yet verified this device.
     */
    MXDeviceUnverified,

    /**
     The user has verified this device.
     */
    MXDeviceVerified,

    /**
     The user has blocked the device.
     */
    MXDeviceBlocked,

    /**
     This is the first time the user sees the device.
 
     Note: The position of this value in the enum does not reflect the life cycle of the verification
     state. It is at the end because it was added afterwards and we need to stay compatible
     with what was stored in the crypto store.
     */
    MXDeviceUnknown

} MXDeviceVerification;


/**
 Information about a user's device.
 */
@interface MXDeviceInfo : MXJSONModel

- (instancetype)initWithDeviceId:(NSString*)deviceId;

/**
 The id of this device.
 */
@property (nonatomic, readonly) NSString *deviceId;

/**
 The id of the user of this device.
 */
@property (nonatomic) NSString *userId;

/**
 The list of algorithms supported by this device.
 */
@property (nonatomic) NSArray<NSString*> *algorithms;

/**
 A map from <key type>:<id> -> <base64-encoded key>.
 */
@property (nonatomic) NSDictionary *keys;

/**
 The signature of this MXDeviceInfo.
 A map from <key type>:<device_id> -> <base64-encoded key>>.
 */
@property (nonatomic) NSDictionary *signatures;

/**
 Additional data from the homeserver.
 HS sends this data under the 'unsigned' field but it is a reserved keyword. Hence, renaming.
 */
@property (nonatomic) NSDictionary *unsignedData;


#pragma mark - Shortcuts to access data

/**
 * The base64-encoded fingerprint for this device (ie, the Ed25519 key).
 */
@property (nonatomic, readonly) NSString *fingerprint;

/**
 * The base64-encoded identity key for this device (ie, the Curve25519 key).
 */
@property (nonatomic, readonly) NSString *identityKey;

/**
 * The configured display name for this device, if any.
 */
@property (nonatomic, readonly) NSString *displayName;


#pragma mark - Additional information

/**
 Verification state of this device.
 */
@property (nonatomic) MXDeviceVerification verified;


#pragma mark - Instance methods
/**
 Same as the parent [MXJSONModel JSONDictionary] but return only
 data that must be signed.
 */
@property (nonatomic, readonly) NSDictionary *signalableJSONDictionary;

@end
