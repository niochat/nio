/*
 Copyright 2019 The Matrix.org Foundation C.I.C

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

#import "MXCrossSigningInfo.h"
#import "MXCrossSigningKey.h"

@class MXCrypto;


NS_ASSUME_NONNULL_BEGIN


#pragma mark - Constants

/**
 Notification name sent when current user sign in on new devices. Provides new device ids.
 It is sent only if our session can cross-sign the new devices.
 Give an associated userInfo dictionary of type NSDictionary<NSString*, NSArray<NSString*>*> with following key: "deviceIds". Use constants below for convenience.
 */
extern NSString *const MXCrossSigningMyUserDidSignInOnNewDeviceNotification;

/**
 userInfo dictionary keys used by `MXCrossSigningDidDetectNewSignInNotification`.
 */
extern NSString *const MXCrossSigningNotificationDeviceIdsKey;

/**
 Cross-signing state of the current acount.
 */
typedef NS_ENUM(NSInteger, MXCrossSigningState)
{
    /**
     Cross-signing is not enabled for this account.
     No cross-signing keys have been published on the server.
     */
    MXCrossSigningStateNotBootstrapped = 0,
    
    /**
     Cross-signing has been enabled for this account.
     Cross-signing public keys have been published on the server but they are not trusted by this device.
     */
    MXCrossSigningStateCrossSigningExists,
    
    /**
     MXCrossSigningStateCrossSigningExists and it is trusted by this device.
     Based on cross-signing:
         - this device can trust other users and their cross-signed devices
         - this device can trust other cross-signed devices of this account
     */
    MXCrossSigningStateTrustCrossSigning,
    
    /**
     MXCrossSigningStateTrustCrossSigning and we can cross-sign.
     This device has cross-signing private keys.
     It can cross-sign other users or other devices of this account.
     */
    MXCrossSigningStateCanCrossSign,
    
    /**
     Same as MXCrossSigningStateCanCrossSign but private keys can only be used asynchronously.
     Access to these keys may require UI interaction with the user like passphrase, Face ID, etc.
     */
    // TODO: This is unused for the moment but it will come back with the full implemenation of SSSS.
    // All related code has been removed to remove noise. Check the code in this commit.
    MXCrossSigningStateCanCrossSignAsynchronously,
};


FOUNDATION_EXPORT NSString *const MXCrossSigningErrorDomain;
typedef NS_ENUM(NSInteger, MXCrossSigningErrorCode)
{
    MXCrossSigningUnknownUserIdErrorCode,
    MXCrossSigningUnknownDeviceIdErrorCode,
};


@interface MXCrossSigning : NSObject

/**
 The Matrix crypto.
 */
@property (nonatomic, readonly, weak) MXCrypto *crypto;

/**
 Cross-signing state for this account and this device.
 */
@property (nonatomic, readonly) MXCrossSigningState state;
@property (nonatomic, readonly) BOOL canTrustCrossSigning;
@property (nonatomic, readonly) BOOL canCrossSign;

/**
 Check update for this device cross-signing state (self.state).
 
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (void)refreshStateWithSuccess:(nullable void (^)(BOOL stateUpdated))success
                        failure:(nullable void (^)(NSError *error))failure;

/**
 Bootstrap cross-signing on this device.

 This creates cross-signing keys. It will use keysStorageDelegate to store
 private parts.

 TODO: Support other authentication flows than password.
 TODO: This method will probably change or disappear. It is here mostly for development
 while SSSS is not available.

 @param password the account password to upload keys to the HS.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (void)bootstrapWithPassword:(NSString*)password
                      success:(void (^)(void))success
                      failure:(void (^)(NSError *error))failure;

/**
 Cross-sign another device of our user.

 This method will use keysStorageDelegate get the private part of the Self Signing
 Key (MXCrossSigningKeyType.selfSigning).

 @param deviceId the id of the device to cross-sign.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (void)crossSignDeviceWithDeviceId:(NSString*)deviceId
                            success:(void (^)(void))success
                            failure:(void (^)(NSError *error))failure;

/**
 Trust a user from one of their devices.

 This method will use keysStorageDelegate get the private part of the User Signing
 Key (MXCrossSigningKeyType.userSigning).

 @param userId the id of ther user.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (void)signUserWithUserId:(NSString*)userId
                   success:(void (^)(void))success
                   failure:(void (^)(NSError *error))failure;


/**
 Request private keys for cross-signing from other devices.
 
 @param deviceIds ids of device to make requests to. Nil to request all.
 
 @param success A block object called when the operation succeeds.
 @param onPrivateKeysReceived A block called when the secret has been received from another device.
 @param failure A block object called when the operation fails.
 */
- (void)requestPrivateKeysToDeviceIds:(nullable NSArray<NSString*>*)deviceIds
                              success:(void (^)(void))success
                onPrivateKeysReceived:(void (^)(void))onPrivateKeysReceived
                              failure:(void (^)(NSError *error))failure;

@end

NS_ASSUME_NONNULL_END
