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

#import "MXCrossSigning_Private.h"

#import "MXCrypto_Private.h"
#import "MXDeviceInfo_Private.h"
#import "MXCrossSigningInfo_Private.h"
#import "MXKey.h"
#import "MXBase64Tools.h"


#pragma mark - Constants

NSString *const MXCrossSigningMyUserDidSignInOnNewDeviceNotification = @"MXCrossSigningMyUserDidSignInOnNewDeviceNotification";
NSString *const MXCrossSigningNotificationDeviceIdsKey = @"deviceIds";

NSString *const MXCrossSigningErrorDomain = @"org.matrix.sdk.crosssigning";


@interface MXCrossSigning ()

@end


@implementation MXCrossSigning

- (BOOL)canCrossSign
{
    return (_state >= MXCrossSigningStateCanCrossSign);
}

- (BOOL)canTrustCrossSigning
{
    return (_state >= MXCrossSigningStateTrustCrossSigning);
}

- (void)bootstrapWithPassword:(NSString*)password
                      success:(void (^)(void))success
                      failure:(void (^)(NSError *error))failure
{
    MXCredentials *myCreds = _crypto.mxSession.matrixRestClient.credentials;

    // Create keys
    NSDictionary<NSString*, NSData*> *privateKeys;
    MXCrossSigningInfo *keys = [self createKeys:&privateKeys];
    
    NSLog(@"[MXCrossSigning] Bootstrap on device %@. MSK: %@", myCreds.deviceId, keys.masterKeys.keys);

    // Delegate the storage of them
    [self storeCrossSigningKeys:privateKeys success:^{

        NSDictionary *signingKeys = @{
                                      @"master_key": keys.masterKeys.JSONDictionary,
                                      @"self_signing_key": keys.selfSignedKeys.JSONDictionary,
                                      @"user_signing_key": keys.userSignedKeys.JSONDictionary,
                                      };

        // Do the auth dance to upload them to the HS
        [self.crypto.matrixRestClient authSessionToUploadDeviceSigningKeys:^(MXAuthenticationSession *authSession) {

            NSDictionary *authParams = @{
                                         @"session": authSession.session,
                                         @"user": myCreds.userId,
                                         @"password": password,
                                         @"type": kMXLoginFlowTypePassword
                                         };

            [self.crypto.matrixRestClient uploadDeviceSigningKeys:signingKeys authParams:authParams success:^{

                // Store our user's keys
                [keys updateTrustLevel:[MXUserTrustLevel trustLevelWithCrossSigningVerified:YES locallyVerified:YES]];
                [self.crypto.store storeCrossSigningKeys:keys];
                
                // Cross-signing is bootstrapped
                // Refresh our state so that we can cross-sign
                [self refreshStateWithSuccess:^(BOOL stateUpdated) {
                    // Expose this device to other users as signed by me
                    // TODO: Check if it is the right way to do so
                    [self crossSignDeviceWithDeviceId:myCreds.deviceId success:^{
                        success();
                    } failure:failure];
                } failure:failure];

            } failure:failure];

        } failure:failure];
        
    } failure:^(NSError * _Nonnull error) {
        failure(error);
    }];
}


- (MXCrossSigningInfo *)createKeys:(NSDictionary<NSString *,NSData *> *__autoreleasing  _Nonnull *)outPrivateKeys
{
    NSString *myUserId = _crypto.mxSession.myUserId;
    NSString *myDeviceId = _crypto.mxSession.myDeviceId;

    MXCrossSigningInfo *crossSigningKeys = [[MXCrossSigningInfo alloc] initWithUserId:myUserId];

    NSMutableDictionary<NSString*, NSData*> *privateKeys = [NSMutableDictionary dictionary];

    // Master key
    NSData *masterKeyPrivate;
    OLMPkSigning *masterSigning;
    NSString *masterKeyPublic = [self makeSigningKey:&masterSigning privateKey:&masterKeyPrivate];

    if (masterKeyPublic)
    {
        NSString *type = MXCrossSigningKeyType.master;

        MXCrossSigningKey *masterKey = [[MXCrossSigningKey alloc] initWithUserId:myUserId usage:@[type] keys:masterKeyPublic];
        [crossSigningKeys addCrossSigningKey:masterKey type:type];
        privateKeys[type] = masterKeyPrivate;

        // Sign the MSK with device
        [masterKey addSignatureFromUserId:myUserId publicKey:myDeviceId signature:[_crypto.olmDevice signJSON:masterKey.signalableJSONDictionary]];
    }

    // self_signing key
    NSData *sskPrivate;
    NSString *sskPublic = [self makeSigningKey:nil privateKey:&sskPrivate];

    if (sskPublic)
    {
        NSString *type = MXCrossSigningKeyType.selfSigning;

        MXCrossSigningKey *ssk = [[MXCrossSigningKey alloc] initWithUserId:myUserId usage:@[type] keys:sskPublic];
        [_crossSigningTools pkSignKey:ssk withPkSigning:masterSigning userId:myUserId publicKey:masterKeyPublic];

        [crossSigningKeys addCrossSigningKey:ssk type:type];
        privateKeys[type] = sskPrivate;
    }

    // user_signing key
    NSData *uskPrivate;
    NSString *uskPublic = [self makeSigningKey:nil privateKey:&uskPrivate];

    if (uskPublic)
    {
        NSString *type = MXCrossSigningKeyType.userSigning;

        MXCrossSigningKey *usk = [[MXCrossSigningKey alloc] initWithUserId:myUserId usage:@[type] keys:uskPublic];
        [_crossSigningTools pkSignKey:usk withPkSigning:masterSigning userId:myUserId publicKey:masterKeyPublic];

        [crossSigningKeys addCrossSigningKey:usk type:type];
        privateKeys[type] = uskPrivate;
    }

    if (outPrivateKeys)
    {
        *outPrivateKeys = privateKeys;
    }

    return crossSigningKeys;
}

- (void)crossSignDeviceWithDeviceId:(NSString*)deviceId
                            success:(void (^)(void))success
                            failure:(void (^)(NSError *error))failure
{
    NSLog(@"[MXCrossSigning] crossSignDeviceWithDeviceId: %@", deviceId);
          
    NSString *myUserId = self.crypto.mxSession.myUserId;
    
    dispatch_async(self.crypto.cryptoQueue, ^{
        
        // Make sure we have latest data from the user
        [self.crypto.deviceList downloadKeys:@[myUserId] forceDownload:NO success:^(MXUsersDevicesMap<MXDeviceInfo *> *userDevices, NSDictionary<NSString *,MXCrossSigningInfo *> *crossSigningKeysMap) {
            
            MXDeviceInfo *device = [self.crypto.store deviceWithDeviceId:deviceId forUser:myUserId];
            
            // Sanity check
            if (!device)
            {
                NSLog(@"[MXCrossSigning] crossSignDeviceWithDeviceId: Unknown device %@", deviceId);
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSError *error = [NSError errorWithDomain:MXCrossSigningErrorDomain
                                                         code:MXCrossSigningUnknownDeviceIdErrorCode
                                                     userInfo:@{
                                                                NSLocalizedDescriptionKey: @"Unknown device",
                                                                }];
                    failure(error);
                });
                return;
            }
            
            [self signDevice:device success:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    success();
                });
            } failure:^(NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    failure(error);
                });
            }];
        } failure:^(NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(error);
            });
        }];
    });
}

- (void)signUserWithUserId:(NSString*)userId
                   success:(void (^)(void))success
                   failure:(void (^)(NSError *error))failure
{
    NSLog(@"[MXCrossSigning] signUserWithUserId: %@", userId);
    
    dispatch_async(self.crypto.cryptoQueue, ^{
        // Make sure we have latest data from the user
        [self.crypto.deviceList downloadKeys:@[userId] forceDownload:NO success:^(MXUsersDevicesMap<MXDeviceInfo *> *userDevices, NSDictionary<NSString *,MXCrossSigningInfo *> *crossSigningKeysMap) {
            
            MXCrossSigningInfo *otherUserKeys = [self.crypto.store crossSigningKeysForUser:userId];
            MXCrossSigningKey *otherUserMasterKeys = otherUserKeys.masterKeys;
            
            // Sanity check
            if (!otherUserMasterKeys)
            {
                NSLog(@"[MXCrossSigning] signUserWithUserId: User %@ unknown locally", userId);
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSError *error = [NSError errorWithDomain:MXCrossSigningErrorDomain
                                                         code:MXCrossSigningUnknownUserIdErrorCode
                                                     userInfo:@{
                                                                NSLocalizedDescriptionKey: @"Unknown user",
                                                                }];
                    failure(error);
                });
                return;
            }
            
            [self signKey:otherUserMasterKeys success:^{
                
                // Update other user's devices trust
                [self checkTrustLevelForDevicesOfUser:userId];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    success();
                });
            } failure:^(NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    failure(error);
                });
            }];
            
        } failure:^(NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(error);
            });
        }];
    });
}

- (void)requestPrivateKeysToDeviceIds:(nullable NSArray<NSString*>*)deviceIds
                              success:(void (^)(void))success
                onPrivateKeysReceived:(void (^)(void))onPrivateKeysReceived
                              failure:(void (^)(NSError *error))failure
{
    NSLog(@"[MXCrossSigning] requestPrivateKeysToDeviceIds: %@", deviceIds);
    
    // Make a secret share request for USK and SSK
    dispatch_group_t successGroup = dispatch_group_create();
    dispatch_group_t onPrivateKeysReceivedGroup = dispatch_group_create();
    
    __block NSString *uskRequestId, *sskRequestId;
    
    dispatch_group_enter(successGroup);
    dispatch_group_enter(onPrivateKeysReceivedGroup);
    [self.crypto.secretShareManager requestSecret:MXSecretId.crossSigningUserSigning toDeviceIds:deviceIds success:^(NSString * _Nonnull requestId) {
        uskRequestId = requestId;
        dispatch_group_leave(successGroup);
    } onSecretReceived:^(NSString * _Nonnull secret) {
        NSLog(@"[MXCrossSigning] requestPrivateKeysToDeviceIds: Got USK");        
        [self.crypto.store storeSecret:secret withSecretId:MXSecretId.crossSigningUserSigning];
        dispatch_group_leave(onPrivateKeysReceivedGroup);
    } failure:^(NSError * _Nonnull error) {
        // Cancel the other request
        [self.crypto.secretShareManager cancelRequestWithRequestId:sskRequestId success:^{} failure:^(NSError * _Nonnull error) {
        }];
        failure(error);
    }];
    
    dispatch_group_enter(successGroup);
    dispatch_group_enter(onPrivateKeysReceivedGroup);
    [self.crypto.secretShareManager requestSecret:MXSecretId.crossSigningSelfSigning toDeviceIds:deviceIds success:^(NSString * _Nonnull requestId) {
        sskRequestId = requestId;
        dispatch_group_leave(successGroup);
    } onSecretReceived:^(NSString * _Nonnull secret) {
        NSLog(@"[MXCrossSigning] requestPrivateKeysToDeviceIds: Got SSK");
        [self.crypto.store storeSecret:secret withSecretId:MXSecretId.crossSigningSelfSigning];
        dispatch_group_leave(onPrivateKeysReceivedGroup);
    } failure:^(NSError * _Nonnull error) {
        // Cancel the other request
        [self.crypto.secretShareManager cancelRequestWithRequestId:uskRequestId success:^{} failure:^(NSError * _Nonnull error) {
        }];
        failure(error);
    }];
    
    dispatch_group_notify(successGroup, dispatch_get_main_queue(), ^{
        NSLog(@"[MXCrossSigning] requestPrivateKeysToDeviceIds: request succeeded");
        success();
    });
    
    dispatch_group_notify(onPrivateKeysReceivedGroup, dispatch_get_main_queue(), ^{
        NSLog(@"[MXCrossSigning] requestPrivateKeysToDeviceIds: Got keys");
        [self refreshStateWithSuccess:^(BOOL stateUpdated) {
            onPrivateKeysReceived();
        } failure:^(NSError * _Nonnull error) {
            onPrivateKeysReceived();
        }];
    });
}


#pragma mark - SDK-Private methods -

- (instancetype)initWithCrypto:(MXCrypto *)crypto;
{
    self = [super init];
    if (self)
    {
        _state = MXCrossSigningStateNotBootstrapped;
        _crypto = crypto;
        _crossSigningTools = [MXCrossSigningTools new];
        
        NSString *myUserId = _crypto.mxSession.myUserId;
        _myUserCrossSigningKeys = [_crypto.store crossSigningKeysForUser:myUserId];
        
        [self computeState];
        [self registerUsersDevicesUpdateNotification];
     }
    return self;
}

- (void)refreshStateWithSuccess:(nullable void (^)(BOOL stateUpdated))success
                        failure:(nullable void (^)(NSError *error))failure
{
    MXCrossSigningState stateBefore = _state;
    BOOL canTrustCrossSigningBefore = self.canTrustCrossSigning;
    MXCrossSigningInfo *myUserCrossSigningKeysBefore = self.myUserCrossSigningKeys;
    
    NSString *myUserId = _crypto.mxSession.myUserId;
    _myUserCrossSigningKeys = [_crypto.store crossSigningKeysForUser:myUserId];
    
    NSLog(@"[MXCrossSigning] refreshState for device %@: Current state: %@", self.crypto.store.deviceId, @(self.state));

    // Refresh user's keys
    [self.crypto.deviceList downloadKeys:@[myUserId] forceDownload:YES success:^(MXUsersDevicesMap<MXDeviceInfo *> *usersDevicesInfoMap, NSDictionary<NSString *,MXCrossSigningInfo *> *crossSigningKeysMap) {
        
        BOOL sameCrossSigningKeys = [myUserCrossSigningKeysBefore hasSameKeysAsCrossSigningInfo:crossSigningKeysMap[myUserId]];
        self.myUserCrossSigningKeys = crossSigningKeysMap[myUserId];
        
        [self computeState];
        
        // If keys have changed, we need to recompute cross-signing trusts.
        // Compute cross-signing trusts also if we detect we can now.
        if (!sameCrossSigningKeys
            || (!canTrustCrossSigningBefore && self.canTrustCrossSigning))
        {
            [self resetTrust];
        }
        
        NSLog(@"[MXCrossSigning] refreshState for device %@: Updated state: %@", self.crypto.store.deviceId, @(self.state));
        
        if (success)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                success(self.state != stateBefore
                        || sameCrossSigningKeys);
            });
        }
    } failure:^(NSError *error) {
        NSLog(@"[MXCrossSigning] refreshStateWithSuccess: Failed to load my user's keys");
        if (failure)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(error);
            });
        }
    }];
}

- (BOOL)isUserWithCrossSigningKeysVerified:(MXCrossSigningInfo*)crossSigningKeys
{
    BOOL isUserVerified = NO;

    NSString *myUserId = _crypto.mxSession.myUserId;
    if ([myUserId isEqualToString:crossSigningKeys.userId])
    {
        // Can we trust the current cross-signing setup?
        return [self isSelfTrusted];
    }

    if (!self.myUserCrossSigningKeys.userSignedKeys)
    {
        // If there's no user signing key, they can't possibly be verified
        return NO;
    }

    NSError *error;
    isUserVerified = [self.crossSigningTools pkVerifyKey:crossSigningKeys.masterKeys
                                                                     userId:myUserId
                                                                  publicKey:self.myUserCrossSigningKeys.userSignedKeys.keys
                                                                      error:&error];
    if (error)
    {
        NSLog(@"[MXCrossSigning] computeUserTrustLevelForCrossSigningKeys failed. Error: %@", error);
    }

    return isUserVerified;
}

- (BOOL)isDeviceVerified:(MXDeviceInfo*)device
{
    BOOL isDeviceVerified = NO;

    MXCrossSigningInfo *userCrossSigning = [self.crypto.store crossSigningKeysForUser:device.userId];
    MXUserTrustLevel *userTrustLevel = [self.crypto trustLevelForUser:device.userId];

    MXCrossSigningKey *userSSK = userCrossSigning.selfSignedKeys;
    if (!userSSK)
    {
        // If the user has no self-signing key then we cannot make any
        // trust assertions about this device from cross-signing
        return NO;
    }

    // If we can verify the user's SSK from their master key...
    BOOL userSSKVerify = [self.crossSigningTools pkVerifyKey:userSSK
                                                      userId:userCrossSigning.userId
                                                   publicKey:userCrossSigning.masterKeys.keys
                                                       error:nil];

    // ...and this device's key from their SSK...
    BOOL deviceVerify = [self.crossSigningTools pkVerifyObject:device.JSONDictionary
                                                        userId:userCrossSigning.userId
                                                     publicKey:userSSK.keys
                                                         error:nil];

    // ...then we trust this device as much as far as we trust the user
    if (userSSKVerify && deviceVerify)
    {
        isDeviceVerified = userTrustLevel.isCrossSigningVerified;
    }

    return isDeviceVerified;
}

- (void)checkTrustLevelForDevicesOfUser:(NSString*)userId
{
    NSArray<MXDeviceInfo*> *devices = [self.crypto.store devicesForUser:userId].allValues;

    for (MXDeviceInfo *device in devices)
    {
        BOOL crossSigningVerified = [self isDeviceVerified:device];
        MXDeviceTrustLevel *trustLevel = [MXDeviceTrustLevel trustLevelWithLocalVerificationStatus:device.trustLevel.localVerificationStatus crossSigningVerified:crossSigningVerified];

        if ([device updateTrustLevel:trustLevel])
        {
            [self.crypto.store storeDeviceForUser:device.userId device:device];
        }
    }
}

- (void)requestPrivateKeys
{
    [self requestPrivateKeysToDeviceIds:nil success:^{
    } onPrivateKeysReceived:^{
    } failure:^(NSError * _Nonnull error) {
    }];
}


#pragma mark - Private methods -

- (void)computeState
{
    MXCrossSigningState state = MXCrossSigningStateNotBootstrapped;
    
    if (_myUserCrossSigningKeys)
    {
        state = MXCrossSigningStateCrossSigningExists;
        
        if ([self isSelfTrusted])
        {
            state = MXCrossSigningStateTrustCrossSigning;
            
            if (self.haveCrossSigningPrivateKeysInCryptoStore)
            {
                state = MXCrossSigningStateCanCrossSign;
            }
            
            // TODO: MXCrossSigningStateCanCrossSignAsynchronously
        }
    }
    
    _state = state;
    
    NSLog(@"[MXCrossSigning] myUserCrossSigningKeys: %@", _myUserCrossSigningKeys);
    NSLog(@"[MXCrossSigning] state: %@", @(_state));
}

// Recompute cross-signing trust on all users we know
- (void)resetTrust
{
    NSLog(@"[MXCrossSigning] resetTrust for device %@", self.crypto.mxSession.matrixRestClient.credentials.deviceId);
    
    for (MXCrossSigningInfo *crossSigningInfo in self.crypto.store.crossSigningKeys)
    {
        BOOL isCrossSigningVerified = [self isUserWithCrossSigningKeysVerified:crossSigningInfo];
        if (crossSigningInfo.trustLevel.isCrossSigningVerified != isCrossSigningVerified)
        {
            NSLog(@"[MXCrossSigning] resetTrust: Change trust for %@: %@ -> %@", crossSigningInfo.userId,
                  @(crossSigningInfo.trustLevel.isCrossSigningVerified),
                  @(isCrossSigningVerified));
            
            MXUserTrustLevel *newTrustLevel = [MXUserTrustLevel trustLevelWithCrossSigningVerified:isCrossSigningVerified locallyVerified:crossSigningInfo.trustLevel.isLocallyVerified];
            if ([crossSigningInfo updateTrustLevel:newTrustLevel])
            {
                [self.crypto.store storeCrossSigningKeys:crossSigningInfo];
            }
            
            // Update trust on associated devices
            [self checkTrustLevelForDevicesOfUser:crossSigningInfo.userId];
        }
    }
}

- (NSString *)makeSigningKey:(OLMPkSigning * _Nullable *)signing privateKey:(NSData* _Nullable *)privateKey
{
    OLMPkSigning *pkSigning = [[OLMPkSigning alloc] init];

    NSError *error;
    NSData *privKey = [OLMPkSigning generateSeed];
    NSString *pubKey = [pkSigning doInitWithSeed:privKey error:&error];
    if (error)
    {
        NSLog(@"[MXCrossSigning] makeSigningKey failed. Error: %@", error);
        return nil;
    }

    if (signing)
    {
        *signing = pkSigning;
    }
    if (privateKey)
    {
        *privateKey = privKey;
    }
    return pubKey;
}

/**
  Check that MSK is trusted by this device.
  Then, check that USK and SSK are trusted by the MSK.
 */
- (BOOL)isSelfTrusted
{
    // Is the master key trusted?
    BOOL isMasterKeyTrusted = NO;
    MXCrossSigningKey *myMasterKey = _myUserCrossSigningKeys.masterKeys;
    if (!myMasterKey)
    {
        // Cross-signing is not set up
        NSLog(@"[MXCrossSigning] isSelfTrusted: NO (No MSK)");
        return NO;
    }
    
    NSString *myUserId = _crypto.mxSession.myUserId;
    
    // Is the master key trusted?
    MXCrossSigningInfo *myCrossSigningInfo = [_crypto.store crossSigningKeysForUser:myUserId];
    if (myCrossSigningInfo && myCrossSigningInfo.trustLevel.isLocallyVerified)
    {
        isMasterKeyTrusted = YES;
    }
    else
    {
        // Is it signed by a locally trusted device?
        NSDictionary<NSString*, NSString*> *myUserSignatures = myMasterKey.signatures.map[myUserId];
        for (NSString *publicKeyId in myUserSignatures)
        {
            MXKey *key = [[MXKey alloc] initWithKeyFullId:publicKeyId value:myUserSignatures[publicKeyId]];
            if ([key.type isEqualToString:kMXKeyEd25519Type])
            {
                MXDeviceInfo *device = [self.crypto.store deviceWithDeviceId:key.keyId forUser:myUserId];
                if (device && device.trustLevel.isVerified)
                {
                    // Check signature validity
                    NSError *error;
                    isMasterKeyTrusted = [_crypto.olmDevice verifySignature:device.fingerprint JSON:myMasterKey.signalableJSONDictionary signature:key.value error:&error];
                    
                    if (isMasterKeyTrusted)
                    {
                        break;
                    }
                }
            }
        }
    }

    
    if (!isMasterKeyTrusted)
    {
        NSLog(@"[MXCrossSigning] isSelfTrusted: NO (MSK not trusted). MSK: %@", myMasterKey);
        NSLog(@"[MXCrossSigning] isSelfTrusted: My cross-signing info: %@", myCrossSigningInfo);
        NSLog(@"[MXCrossSigning] isSelfTrusted: My user devices: %@", [self.crypto.store devicesForUser:myUserId]);

        return NO;
    }
    
    // Is USK signed?
    MXCrossSigningKey *myUserKey = _myUserCrossSigningKeys.userSignedKeys;
    BOOL isUSKSignatureValid = [self checkSignatureOnKey:myUserKey byKey:myMasterKey userId:myUserId];
    if (!isUSKSignatureValid)
    {
        NSLog(@"[MXCrossSigning] isSelfTrusted: NO (Invalid MSK signature for USK). USK: %@", myUserKey);
        NSLog(@"[MXCrossSigning] isSelfTrusted: MSK: %@", myMasterKey);
        return NO;
    }
    
    // Is SSK signed?
    MXCrossSigningKey *mySelfKey = _myUserCrossSigningKeys.selfSignedKeys;
    BOOL isSSKSignatureValid = [self checkSignatureOnKey:mySelfKey byKey:myMasterKey userId:myUserId];
    if (!isSSKSignatureValid)
    {
        NSLog(@"[MXCrossSigning] isSelfTrusted: NO (Invalid MSK signature for SSK). SSK: %@", mySelfKey);
        NSLog(@"[MXCrossSigning] isSelfTrusted: MSK: %@", myMasterKey);
        return NO;
    }
    
    return YES;
}

- (BOOL)checkSignatureOnKey:(nullable MXCrossSigningKey*)key byKey:(MXCrossSigningKey*)signingKey userId:(NSString*)userId
{
    if (!key)
    {
        NSLog(@"[MXCrossSigning] checkSignatureOnKey: NO (No key)");
        return NO;
    }
    
    NSString *signingPublicKeyId = [NSString stringWithFormat:@"%@:%@", kMXKeyEd25519Type, signingKey.keys];
    NSString *signatureMadeBySigningKey = [key.signatures objectForDevice:signingPublicKeyId forUser:userId];
    if (!signatureMadeBySigningKey)
    {
        NSLog(@"[MXCrossSigning] checkSignatureOnKey: NO (Key not signed)");
        return NO;
    }
    
    NSError *error;
    BOOL isSignatureValid = [_crypto.olmDevice verifySignature:signingKey.keys JSON:key.signalableJSONDictionary signature:signatureMadeBySigningKey error:&error];
    if (!isSignatureValid)
    {
        NSLog(@"[MXCrossSigning] checkSignatureOnKey: NO (Invalid signature)");
        return NO;
    }
    
    return YES;
}

- (void)registerUsersDevicesUpdateNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(usersDevicesDidUpdate:) name:MXDeviceListDidUpdateUsersDevicesNotification object:self.crypto];
}

- (void)usersDevicesDidUpdate:(NSNotification*)notification
{
    // If we cannot cross-sign, we cannot self verify new devices of our user
    if (!self.canCrossSign)
    {
        return;
    }
    
    NSDictionary *userInfo = notification.userInfo;
    
    MXCredentials *myUser = _crypto.mxSession.matrixRestClient.credentials;
    
    NSArray<MXDeviceInfo*> *myUserDevices = userInfo[myUser.userId];
    
    if (myUserDevices)
    {
        NSMutableArray<NSString*> *newDeviceIds = [NSMutableArray new];
        
        for (MXDeviceInfo *deviceInfo in myUserDevices)
        {
            if (deviceInfo.trustLevel.localVerificationStatus == MXDeviceUnknown)
            {
                [newDeviceIds addObject:deviceInfo.deviceId];
            }
        }
        
        if (newDeviceIds.count)
        {
            NSDictionary *userInfo = @{ MXCrossSigningNotificationDeviceIdsKey: newDeviceIds };
            
            [[NSNotificationCenter defaultCenter] postNotificationName:MXCrossSigningMyUserDidSignInOnNewDeviceNotification object:self userInfo:userInfo];
        }
    }
}


#pragma mark - Signing

- (void)signDevice:(MXDeviceInfo*)device
           success:(void (^)(void))success
           failure:(void (^)(NSError *error))failure
{
    NSString *myUserId = _crypto.mxSession.myUserId;

    NSDictionary *object = @{
                             @"algorithms": device.algorithms,
                             @"keys": device.keys,
                             @"device_id": device.deviceId,
                             @"user_id": myUserId,
                             };

    // Sign the device
    [self signObject:object
         withKeyType:MXCrossSigningKeyType.selfSigning
             success:^(NSDictionary *signedObject)
     {
         // And upload the signature
         [self.crypto.mxSession.matrixRestClient uploadKeySignatures:@{
                                                                       myUserId: @{
                                                                               device.deviceId: signedObject
                                                                               }
                                                                       }
                                                             success:^
          {
              [self refreshStateWithSuccess:^(BOOL stateUpdated) {
                  success();
              } failure:failure];

          } failure:failure];

     } failure:failure];
}

- (void)signKey:(MXCrossSigningKey*)key
        success:(void (^)(void))success
        failure:(void (^)(NSError *error))failure
{
    // Sign the other user key
    [self signObject:key.signalableJSONDictionary
         withKeyType:MXCrossSigningKeyType.userSigning
             success:^(NSDictionary *signedObject)
     {
         // And upload the signature
         [self.crypto.mxSession.matrixRestClient uploadKeySignatures:@{
                                                                       key.userId: @{
                                                                               key.keys: signedObject
                                                                               }
                                                                       }
                                                             success:^
          {
              // Refresh data locally before returning
              // TODO: This network request is suboptimal. We could update data in the store directly
              [self.crypto.deviceList downloadKeys:@[key.userId] forceDownload:YES success:^(MXUsersDevicesMap<MXDeviceInfo *> *usersDevicesInfoMap, NSDictionary<NSString *,MXCrossSigningInfo *> *crossSigningKeysMap) {
                  success();
              } failure:failure];

          } failure:failure];
     }
             failure:failure];
}

- (void)signObject:(NSDictionary*)object withKeyType:(NSString*)keyType
           success:(void (^)(NSDictionary *signedObject))success
           failure:(void (^)(NSError *error))failure
{
    [self crossSigningKeyWithKeyType:keyType success:^(NSString *publicKey, OLMPkSigning *signing) {

        NSString *myUserId = self.crypto.mxSession.myUserId;

        NSError *error;
        NSDictionary *signedObject = [self.crossSigningTools pkSignObject:object withPkSigning:signing userId:myUserId publicKey:publicKey error:&error];
        if (!error)
        {
            success(signedObject);
        }
        else
        {
            failure(error);
        }
    } failure:failure];
}


#pragma mark - Private keys storage

- (BOOL)haveCrossSigningPrivateKeysInCryptoStore
{
    NSString *uskPrivateKeyBase64 = [self.crypto.store secretWithSecretId:MXSecretId.crossSigningUserSigning];
    NSString *sskPrivateKeyBase64 = [self.crypto.store secretWithSecretId:MXSecretId.crossSigningSelfSigning];
    if (uskPrivateKeyBase64 && sskPrivateKeyBase64)
    {
        // Check they are valid and they correspond to our current cross-signing keys
        if (_myUserCrossSigningKeys.userSignedKeys
            && _myUserCrossSigningKeys.selfSignedKeys)
        {
            OLMPkSigning *uskPkSigning = [self pkSigningFromBase64PrivateKey:uskPrivateKeyBase64
                                                       withExpectedPublicKey:_myUserCrossSigningKeys.userSignedKeys.keys];
            OLMPkSigning *sskPkSigning = [self pkSigningFromBase64PrivateKey:sskPrivateKeyBase64
                                                       withExpectedPublicKey:_myUserCrossSigningKeys.selfSignedKeys.keys];
            
            if (uskPkSigning && sskPkSigning)
            {
                return YES;
            }
        }
        
        // Else, delete them
        NSLog(@"[MXCrossSigning] haveCrossSigningPrivateKeysInCryptoStore: Delete local keys. They are obsolete");
        [self.crypto.store deleteSecretWithSecretId:MXSecretId.crossSigningUserSigning];
        [self.crypto.store deleteSecretWithSecretId:MXSecretId.crossSigningSelfSigning];
    }
    
    return NO;
}

- (void)crossSigningKeyWithKeyType:(NSString*)keyType
                           success:(void (^)(NSString *publicKey, OLMPkSigning *signing))success
                           failure:(void (^)(NSError *error))failure
{
    NSString *expectedPublicKey = _myUserCrossSigningKeys.keys[keyType].keys;
    if (!expectedPublicKey)
    {
        NSLog(@"[MXCrossSigning] getCrossSigningKeyWithKeyType: %@ failed. No such key present", keyType);
        failure(nil);
        return;
    }
    
    // Check local store
    NSString *secretId = [self secretIdFromKeyType:keyType];
    if (secretId)
    {
        NSString *privateKeyBase64 = [self.crypto.store secretWithSecretId:secretId];
        if (privateKeyBase64)
        {
            OLMPkSigning *pkSigning = [self pkSigningFromBase64PrivateKey:privateKeyBase64 withExpectedPublicKey:expectedPublicKey];
            if (!pkSigning)
            {
                NSLog(@"[MXCrossSigning] getCrossSigningKeyWithKeyType failed to get PK signing");
                failure(nil);
                return;
            }
            
            success(expectedPublicKey, pkSigning);
            return;
        }
    }
    
    NSLog(@"[MXCrossSigning] getCrossSigningKeyWithKeyType: %@ failed. No such key present", keyType);
    failure(nil);
}

- (void)storeCrossSigningKeys:(NSDictionary<NSString*, NSData*>*)privateKeys
                      success:(void (^)(void))success
                      failure:(void (^)(NSError *error))failure
{
    // Store MSK, USK & SSK keys to crypto store
    for (NSString *keyType in privateKeys)
    {
        NSString *secretId = [self secretIdFromKeyType:keyType];
        if (secretId)
        {
            NSString *secret = [MXBase64Tools unpaddedBase64FromData:privateKeys[keyType]];
            [self.crypto.store storeSecret:secret withSecretId:secretId];
        }
    }
    
    success();
}

// Convert a cross-signing key type to a SSSS secret id
- (nullable NSString*)secretIdFromKeyType:(NSString*)keyType
{
    NSString *secretId;
    if ([keyType isEqualToString:MXCrossSigningKeyType.master])
    {
        secretId = MXSecretId.crossSigningMaster;
    }
    else if ([keyType isEqualToString:MXCrossSigningKeyType.selfSigning])
    {
        secretId = MXSecretId.crossSigningSelfSigning;
    }
    else if ([keyType isEqualToString:MXCrossSigningKeyType.userSigning])
    {
        secretId = MXSecretId.crossSigningUserSigning;
    }
    
    return secretId;
}

- (nullable OLMPkSigning*)pkSigningFromBase64PrivateKey:(NSString*)base64PrivateKey withExpectedPublicKey:(NSString*)expectedPublicKey
{
    OLMPkSigning *pkSigning;
    
    NSData *privateKey = [MXBase64Tools dataFromUnpaddedBase64:base64PrivateKey];
    if (privateKey)
    {
        pkSigning = [self pkSigningFromPrivateKey:privateKey withExpectedPublicKey:expectedPublicKey];
    }
    
    return pkSigning;
}

- (nullable OLMPkSigning*)pkSigningFromPrivateKey:(NSData*)privateKey withExpectedPublicKey:(NSString*)expectedPublicKey
{
    NSError *error;
    OLMPkSigning *pkSigning = [[OLMPkSigning alloc] init];
    NSString *gotPublicKey = [pkSigning doInitWithSeed:privateKey error:&error];
    if (error)
    {
        NSLog(@"[MXCrossSigning] pkSigningFromPrivateKey failed to build PK signing. Error: %@", error);
        return nil;
    }
    
    if (![gotPublicKey isEqualToString:expectedPublicKey])
    {
        NSLog(@"[MXCrossSigning] pkSigningFromPrivateKey failed. Keys do not match: %@ vs %@", gotPublicKey, expectedPublicKey);
        return nil;
    }
    
    return pkSigning;
}

@end
