/*
 Copyright 2016 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
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

#import "MXCrypto.h"

#import "MXCrypto_Private.h"

#import "MXSession.h"
#import "MXTools.h"

#import "MXOlmDevice.h"
#import "MXUsersDevicesMap.h"
#import "MXDeviceInfo.h"
#import "MXKey.h"

#import "MXRealmCryptoStore.h"

#import "MXMegolmSessionData.h"
#import "MXMegolmExportEncryption.h"

#import "MXOutgoingRoomKeyRequestManager.h"
#import "MXIncomingRoomKeyRequestManager.h"

#import "MXDeviceVerificationManager_Private.h"

/**
 The store to use for crypto.
 */
#define MXCryptoStoreClass MXRealmCryptoStore

NSString *const kMXCryptoRoomKeyRequestNotification = @"kMXCryptoRoomKeyRequestNotification";
NSString *const kMXCryptoRoomKeyRequestNotificationRequestKey = @"kMXCryptoRoomKeyRequestNotificationRequestKey";
NSString *const kMXCryptoRoomKeyRequestCancellationNotification = @"kMXCryptoRoomKeyRequestCancellationNotification";
NSString *const kMXCryptoRoomKeyRequestCancellationNotificationRequestKey = @"kMXCryptoRoomKeyRequestCancellationNotificationRequestKey";

#ifdef MX_CRYPTO

// Frequency with which to check & upload one-time keys
NSTimeInterval kMXCryptoUploadOneTimeKeysPeriod = 60.0; // one minute

@interface MXCrypto ()
{
    // MXEncrypting instance for each room.
    NSMutableDictionary<NSString*, id<MXEncrypting>> *roomEncryptors;

    // A map from algorithm to MXDecrypting instance, for each room
    NSMutableDictionary<NSString* /* roomId */,
        NSMutableDictionary<NSString* /* algorithm */, id<MXDecrypting>>*> *roomDecryptors;

    // Listener on memberships changes
    id roomMembershipEventsListener;

    // For dev
    // @TODO: could be removed
    NSDictionary *lastPublishedOneTimeKeys;

    // The one-time keys count sent by /sync
    // -1 means the information was not sent by the server
    NSUInteger oneTimeKeyCount;

    // Last time we check available one-time keys on the homeserver
    NSDate *lastOneTimeKeyCheck;

    // The current one-time key operation, if any
    MXHTTPOperation *uploadOneTimeKeysOperation;

    // The operation used for crypto starting requests
    MXHTTPOperation *startOperation;

    // The manager for sending room key requests
    MXOutgoingRoomKeyRequestManager *outgoingRoomKeyRequestManager;

    // The manager for incoming room key requests
    MXIncomingRoomKeyRequestManager *incomingRoomKeyRequestManager;
}
@end

#endif


@implementation MXCrypto

+ (MXCrypto *)createCryptoWithMatrixSession:(MXSession *)mxSession
{
    __block MXCrypto *crypto;

#ifdef MX_CRYPTO

    dispatch_queue_t cryptoQueue = [MXCrypto dispatchQueueForUser:mxSession.matrixRestClient.credentials.userId];
    dispatch_sync(cryptoQueue, ^{

        MXCryptoStoreClass *cryptoStore = [MXCryptoStoreClass createStoreWithCredentials:mxSession.matrixRestClient.credentials];
        crypto = [[MXCrypto alloc] initWithMatrixSession:mxSession cryptoQueue:cryptoQueue andStore:cryptoStore];

    });
#endif

    return crypto;
}

+ (void)checkCryptoWithMatrixSession:(MXSession *)mxSession complete:(void (^)(MXCrypto *))complete
{
#ifdef MX_CRYPTO

    NSLog(@"[MXCrypto] checkCryptoWithMatrixSession for %@", mxSession.matrixRestClient.credentials.userId);

    dispatch_queue_t cryptoQueue = [MXCrypto dispatchQueueForUser:mxSession.matrixRestClient.credentials.userId];
    dispatch_async(cryptoQueue, ^{

        if ([MXCryptoStoreClass hasDataForCredentials:mxSession.matrixRestClient.credentials])
        {
            NSLog(@"[MXCrypto] checkCryptoWithMatrixSession: Crypto store exists");

            // If it already exists, open and init crypto
            MXCryptoStoreClass *cryptoStore = [[MXCryptoStoreClass alloc] initWithCredentials:mxSession.matrixRestClient.credentials];

            [cryptoStore open:^{

                NSLog(@"[MXCrypto] checkCryptoWithMatrixSession: Crypto store opened");

                MXCrypto *crypto = [[MXCrypto alloc] initWithMatrixSession:mxSession cryptoQueue:cryptoQueue andStore:cryptoStore];

                dispatch_async(dispatch_get_main_queue(), ^{
                    complete(crypto);
                });

            } failure:^(NSError *error) {

                NSLog(@"[MXCrypto] checkCryptoWithMatrixSession: Crypto store failed to open. Error: %@", error);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    complete(nil);
                });
            }];
        }
        else if ([MXSDKOptions sharedInstance].enableCryptoWhenStartingMXSession
                 // Without the device id provided by the hs, the crypto does not work
                 && mxSession.matrixRestClient.credentials.deviceId)
        {
            NSLog(@"[MXCrypto] checkCryptoWithMatrixSession: Need to create the store");

            // Create it
            MXCryptoStoreClass *cryptoStore = [MXCryptoStoreClass createStoreWithCredentials:mxSession.matrixRestClient.credentials];
            MXCrypto *crypto = [[MXCrypto alloc] initWithMatrixSession:mxSession cryptoQueue:cryptoQueue andStore:cryptoStore];

            dispatch_async(dispatch_get_main_queue(), ^{
                complete(crypto);
            });
        }
        else
        {
            // Else do not enable crypto
            dispatch_async(dispatch_get_main_queue(), ^{
                complete(nil);
            });
        }

    });

#else
    complete(nil);
#endif
}

- (void)deleteStore:(void (^)(void))onComplete;
{
#ifdef MX_CRYPTO
    MXWeakify(self);
    dispatch_async(_cryptoQueue, ^{
        MXStrongifyAndReturnIfNil(self);

        [MXCryptoStoreClass deleteStoreWithCredentials:self.mxSession.matrixRestClient.credentials];

        if (onComplete)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                onComplete();
            });
        }
    });
#endif
}

- (void)start:(void (^)(void))success
      failure:(void (^)(NSError *error))failure
{

#ifdef MX_CRYPTO
    NSLog(@"[MXCrypto] start");

    // The session must be initialised enough before starting this module
    if (!_mxSession.myUser.userId)
    {
        NSLog(@"[MXCrypto] start. ERROR: mxSession.myUser.userId cannot be nil");
        failure(nil);
        return;
    }

    // Start uploading user device keys
    MXWeakify(self);
    startOperation = [self uploadDeviceKeys:^(MXKeysUploadResponse *keysUploadResponse) {
        MXStrongifyAndReturnIfNil(self);

        if (!self->startOperation)
        {
            return;
        }

        // Upload our one-time keys
        // TODO: matrix-js-sdk does not do it anymore and waits for the completion
        // of /sync (see comments of the other usage of maybeUploadOneTimeKeys in
        // this file)
        // On iOS, for test purpose, we still need to know when the OTKs are sent
        // so that we can start sending message to a device.
        // Keep maybeUploadOneTimeKeys for the moment.
        MXWeakify(self);
        [self maybeUploadOneTimeKeys:^{
            MXStrongifyAndReturnIfNil(self);

            NSLog(@"[MXCrypto] start ###########################################################");
            NSLog(@"[MXCrypto] uploadDeviceKeys done for %@: ", self.mxSession.myUser.userId);

            NSLog(@"[MXCrypto]    - device id  : %@", self.store.deviceId);
            NSLog(@"[MXCrypto]    - ed25519    : %@", self.olmDevice.deviceEd25519Key);
            NSLog(@"[MXCrypto]    - curve25519 : %@", self.olmDevice.deviceCurve25519Key);
            //NSLog(@"   - oneTimeKeys: %@", lastPublishedOneTimeKeys);
            NSLog(@"[MXCrypto] ");
            NSLog(@"[MXCrypto] Store: %@", self.store);
            NSLog(@"[MXCrypto] ");

            [self->outgoingRoomKeyRequestManager start];

            [self->_backup checkAndStartKeyBackup];

            dispatch_async(dispatch_get_main_queue(), ^{
                self->startOperation = nil;
                success();
            });


        } failure:^(NSError *error) {
            MXStrongifyAndReturnIfNil(self);

            NSLog(@"[MXCrypto] start. Error in maybeUploadOneTimeKeys: %@", error);
            dispatch_async(dispatch_get_main_queue(), ^{
                self->startOperation = nil;
                failure(error);
            });
        }];

    } failure:^(NSError *error) {
        MXStrongifyAndReturnIfNil(self);

        NSLog(@"[MXCrypto] start. Error in uploadDeviceKeys: %@", error);
        dispatch_async(dispatch_get_main_queue(), ^{
            self->startOperation = nil;
            failure(error);
        });
    }];

#endif
}

- (void)close:(BOOL)deleteStore
{
#ifdef MX_CRYPTO

    NSLog(@"[MXCrypto] close. store: %@", _store);

    [_mxSession removeListener:roomMembershipEventsListener];

    [startOperation cancel];
    startOperation = nil;

    MXWeakify(self);
    dispatch_sync(_cryptoQueue, ^{
        MXStrongifyAndReturnIfNil(self);

        // Cancel pending one-time keys upload
        [self->uploadOneTimeKeysOperation cancel];
        self->uploadOneTimeKeysOperation = nil;

        [self->outgoingRoomKeyRequestManager close];
        self->outgoingRoomKeyRequestManager = nil;

        if (deleteStore)
        {
            [MXCryptoStoreClass deleteStoreWithCredentials:self.mxSession.matrixRestClient.credentials];
        }

        self->_olmDevice = nil;
        self->_cryptoQueue = nil;
        self->_store = nil;

        [self.deviceList close];
        self->_deviceList = nil;

        [self->roomEncryptors removeAllObjects];
        self->roomEncryptors = nil;

        [self->roomDecryptors removeAllObjects];
        self->roomDecryptors = nil;

        self->_myDevice = nil;

        NSLog(@"[MXCrypto] close: done");
    });

#endif
}

- (MXHTTPOperation *)encryptEventContent:(NSDictionary *)eventContent withType:(MXEventTypeString)eventType inRoom:(MXRoom *)room
                                 success:(void (^)(NSDictionary *, NSString *))success
                                 failure:(void (^)(NSError *))failure
{
#ifdef MX_CRYPTO

    NSLog(@"[MXCrypto] encryptEventContent");

    NSDate *startDate = [NSDate date];

    // Create an empty operation that will be mutated later
    MXHTTPOperation *operation = [[MXHTTPOperation alloc] init];

    // Pick the list of recipients based on the membership list.

    // TODO: there is a race condition here! What if a new user turns up
    // just as you are sending a secret message?

    MXWeakify(self);
    [room state:^(MXRoomState *roomState) {
        MXStrongifyAndReturnIfNil(self);

        MXWeakify(self);
        [room members:^(MXRoomMembers *roomMembers) {
            MXStrongifyAndReturnIfNil(self);

            NSMutableArray *userIds = [NSMutableArray array];
            NSArray<MXRoomMember *> *encryptionTargetMembers = [roomMembers encryptionTargetMembers:roomState.historyVisibility];
            for (MXRoomMember *roomMember in encryptionTargetMembers)
            {
                [userIds addObject:roomMember.userId];
            }

            MXWeakify(self);
            dispatch_async(self.cryptoQueue, ^{
                MXStrongifyAndReturnIfNil(self);

                NSString *algorithm;
                id<MXEncrypting> alg = self->roomEncryptors[room.roomId];

                NSLog(@"[MXCrypto] encryptEventContent: with %@", roomState.encryptionAlgorithm);

                if (!alg)
                {
                    // If the crypto has been enabled after the initialSync (the global one or the one for this room),
                    // the algorithm has not been initialised yet. So, do it now from room state information
                    algorithm = roomState.encryptionAlgorithm;
                    if (algorithm)
                    {
                        [self setEncryptionInRoom:room.roomId withMembers:userIds algorithm:algorithm inhibitDeviceQuery:NO];
                        alg = self->roomEncryptors[room.roomId];
                    }
                }
                else
                {
                    // For log purpose
                    algorithm = NSStringFromClass(alg.class);
                }

                // Sanity check (we don't expect an encrypted content here).
                if (alg && [eventType isEqualToString:kMXEventTypeStringRoomEncrypted] == NO)
                {
#ifdef DEBUG
                    NSLog(@"[MXCrypto] encryptEventContent: content: %@", eventContent);
#endif

                    MXHTTPOperation *operation2 = [alg encryptEventContent:eventContent eventType:eventType forUsers:userIds success:^(NSDictionary *encryptedContent) {

                        NSLog(@"[MXCrypto] encryptEventContent: Success in %.0fms using sessionId: %@",
                              [[NSDate date] timeIntervalSinceDate:startDate] * 1000,
                              encryptedContent[@"session_id"]);

                        dispatch_async(dispatch_get_main_queue(), ^{
                            success(encryptedContent, kMXEventTypeStringRoomEncrypted);
                        });

                    } failure:^(NSError *error) {
                        NSLog(@"[MXCrypto] encryptEventContent: Error: %@", error);

                        dispatch_async(dispatch_get_main_queue(), ^{
                            failure(error);
                        });
                    }];

                    // Mutate the HTTP operation if an HTTP is required for the encryption
                    [operation mutateTo:operation2];
                }
                else
                {
                    NSLog(@"[MXCrypto] encryptEventContent: Invalid algorithm");

                    NSError *error = [NSError errorWithDomain:MXDecryptingErrorDomain
                                                         code:MXDecryptingErrorUnableToEncryptCode
                                                     userInfo:@{
                                                                NSLocalizedDescriptionKey: MXDecryptingErrorUnableToEncrypt,
                                                                NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:MXDecryptingErrorUnableToEncryptReason, algorithm]
                                                                }];

                    dispatch_async(dispatch_get_main_queue(), ^{
                        failure(error);
                    });
                }
            });

        } failure:failure];
    }];

    return operation;

#else
    return nil;
#endif
}

- (MXEventDecryptionResult *)decryptEvent:(MXEvent *)event inTimeline:(NSString*)timeline error:(NSError* __autoreleasing * )error
{
#ifdef MX_CRYPTO

    __block MXEventDecryptionResult *result;

    // TODO: dispatch_async (https://github.com/matrix-org/matrix-ios-sdk/issues/205)
    // At the moment, we lock the main thread while decrypting events.
    // Fortunately, decrypting is far quicker that encrypting.
    dispatch_sync(_decryptionQueue, ^{

        if (!event.content.count)
        {
            NSLog(@"[MXCrypto] decryptEvent: No content to decrypt in event %@ (isRedacted: %@). Event: %@", event.eventId, @(event.isRedactedEvent), event.JSONDictionary);
            result = [[MXEventDecryptionResult alloc] init];
            result.clearEvent = event.content;
            return;
        }

        id<MXDecrypting> alg = [self getRoomDecryptor:event.roomId algorithm:event.content[@"algorithm"]];
        if (!alg)
        {
            NSLog(@"[MXCrypto] decryptEvent: Unable to decrypt %@ with algorithm %@. Event: %@", event.eventId, event.content[@"algorithm"], event.JSONDictionary);

            if (error)
            {
                *error = [NSError errorWithDomain:MXDecryptingErrorDomain
                                             code:MXDecryptingErrorUnableToDecryptCode
                                         userInfo:@{
                                                    NSLocalizedDescriptionKey: MXDecryptingErrorUnableToDecrypt,
                                                    NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:MXDecryptingErrorUnableToDecryptReason, event, event.content[@"algorithm"]]
                                                    }];
            }
        }
        else
        {
            result = [alg decryptEvent:event inTimeline:timeline error:error];
            if (error && *error)
            {
                NSLog(@"[MXCrypto] decryptEvent: Error for %@: %@\nEvent: %@", event.eventId, *error, event.JSONDictionary);
            }
        }
    });

    return result;

#else
    return nil;
#endif
}

- (MXHTTPOperation*)ensureEncryptionInRoom:(NSString*)roomId
                                   success:(void (^)(void))success
                                   failure:(void (^)(NSError *error))failure
{
    // Create an empty operation that will be mutated later
    MXHTTPOperation *operation = [[MXHTTPOperation alloc] init];

#ifdef MX_CRYPTO
    MXRoom *room = [_mxSession roomWithRoomId:roomId];
    if (room.summary.isEncrypted)
    {
        MXWeakify(self);
        [room state:^(MXRoomState *roomState) {
            MXStrongifyAndReturnIfNil(self);

            MXWeakify(self);
            [room members:^(MXRoomMembers *roomMembers) {
                MXStrongifyAndReturnIfNil(self);

                // Get user ids in this room
                NSMutableArray *userIds = [NSMutableArray array];
                NSArray<MXRoomMember *> *encryptionTargetMembers = [roomMembers encryptionTargetMembers:roomState.historyVisibility];
                for (MXRoomMember *member in encryptionTargetMembers)
                {
                    [userIds addObject:member.userId];
                }

                MXWeakify(self);
                dispatch_async(self.cryptoQueue, ^{
                    MXStrongifyAndReturnIfNil(self);

                    NSString *algorithm;
                    id<MXEncrypting> alg = self->roomEncryptors[room.roomId];

                    if (!alg)
                    {
                        // The algorithm has not been initialised yet. So, do it now from room state information
                        algorithm = roomState.encryptionAlgorithm;
                        if (algorithm)
                        {
                            [self setEncryptionInRoom:room.roomId withMembers:userIds algorithm:algorithm inhibitDeviceQuery:NO];
                            alg = self->roomEncryptors[room.roomId];
                        }
                    }

                    if (alg)
                    {
                        // Check we have everything to encrypt events
                        MXHTTPOperation *operation2 = [alg ensureSessionForUsers:userIds success:^(NSObject *sessionInfo) {

                            if (success)
                            {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    success();
                                });
                            }

                        } failure:^(NSError *error) {
                            if (failure)
                            {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    failure(error);
                                });
                            }
                        }];
                        
                        [operation mutateTo:operation2];
                    }
                    else if (failure)
                    {
                        NSError *error = [NSError errorWithDomain:MXDecryptingErrorDomain
                                                             code:MXDecryptingErrorUnableToEncryptCode
                                                         userInfo:@{
                                                                    NSLocalizedDescriptionKey: MXDecryptingErrorUnableToEncrypt,
                                                                    NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:MXDecryptingErrorUnableToEncryptReason, algorithm]
                                                                    }];

                        dispatch_async(dispatch_get_main_queue(), ^{
                            failure(error);
                        });
                    }
                });


            } failure:failure];
        }];
    }
    else
#endif
    {
        if (success)
        {
            success();
        }
    }

    return operation;
}

- (void)handleDeviceListsChanges:(MXDeviceListResponse*)deviceLists
{
#ifdef MX_CRYPTO

    if (deviceLists.changed.count == 0 && deviceLists.left.count == 0)
    {
        // Don't go further if there is nothing to process
        return;
    }

    NSLog(@"[MXCrypto] handleDeviceListsChanges (changes: %@, left: %@):\nchanges: %@\nleft: %@", @(deviceLists.changed.count), @(deviceLists.left.count),
          deviceLists.changed, deviceLists.left);

    MXWeakify(self);
    dispatch_async(_cryptoQueue, ^{
        MXStrongifyAndReturnIfNil(self);

        // Flag users to refresh
        for (NSString *userId in deviceLists.changed)
        {
            [self.deviceList invalidateUserDeviceList:userId];
        }

        for (NSString *userId in deviceLists.left)
        {
            [self.deviceList stopTrackingDeviceList:userId];
        }

        // don't flush the outdated device list yet - we do it once we finish
        // processing the sync.
    });

#endif
}

- (void)handleDeviceOneTimeKeysCount:(NSDictionary<NSString *, NSNumber*>*)deviceOneTimeKeysCount
{
#ifdef MX_CRYPTO

    if (deviceOneTimeKeysCount.count == 0)
    {
        // Don't go further if there is nothing to process
        return;
    }

    NSLog(@"[MXCrypto] handleDeviceOneTimeKeysCount: %@ keys on the homeserver", deviceOneTimeKeysCount[@"signed_curve25519"]);

    MXWeakify(self);
    dispatch_async(_cryptoQueue, ^{
        MXStrongifyAndReturnIfNil(self);

        NSNumber *currentCount;
        MXJSONModelSetNumber(currentCount, deviceOneTimeKeysCount[@"signed_curve25519"]);

        if (currentCount)
        {
            self->oneTimeKeyCount = [currentCount unsignedIntegerValue];
        }
    });

#endif
}

- (void)onSyncCompleted:(NSString *)oldSyncToken nextSyncToken:(NSString *)nextSyncToken catchingUp:(BOOL)catchingUp
{
#ifdef MX_CRYPTO

    MXWeakify(self);
    dispatch_async(_cryptoQueue, ^{
        MXStrongifyAndReturnIfNil(self);

        if (!oldSyncToken)
        {
            NSLog(@"[MXCrypto] onSyncCompleted: Completed initial sync");

            // If we have a deviceSyncToken, we can tell the deviceList to
            // invalidate devices which have changed since then.
            NSString *oldDeviceSyncToken = self.store.deviceSyncToken;
            if (oldDeviceSyncToken)
            {
                NSLog(@"[MXCrypto] onSyncCompleted: invalidating device list from deviceSyncToken: %@", oldDeviceSyncToken);

                [self invalidateDeviceListsSince:oldDeviceSyncToken to:nextSyncToken success:^() {

                    self.deviceList.lastKnownSyncToken = nextSyncToken;
                    [self.deviceList refreshOutdatedDeviceLists];

                } failure:^(NSError *error) {

                    // If that failed, we fall back to invalidating everyone.
                    NSLog(@"[MXCrypto] onSyncCompleted: Error fetching changed device list. Error: %@", error);
                    [self.deviceList invalidateAllDeviceLists];
                }];
            }
            else
            {
                // Otherwise, we have to invalidate all devices for all users we
                // are tracking.
                NSLog(@"[MXCrypto] onSyncCompleted: Completed first initialsync; invalidating all device list caches");
                [self.deviceList invalidateAllDeviceLists];
            }
        }

        // we can now store our sync token so that we can get an update on
        // restart rather than having to invalidate everyone.
        //
        // (we don't really need to do this on every sync - we could just
        // do it periodically)
        [self.store storeDeviceSyncToken:nextSyncToken];

        // catch up on any new devices we got told about during the sync.
        self.deviceList.lastKnownSyncToken = nextSyncToken;
        [self.deviceList refreshOutdatedDeviceLists];

        // We don't start uploading one-time keys until we've caught up with
        // to-device messages, to help us avoid throwing away one-time-keys that we
        // are about to receive messages for
        // (https://github.com/vector-im/riot-web/issues/2782).
        if (!catchingUp)
        {
            [self maybeUploadOneTimeKeys:nil failure:nil];
            [self->incomingRoomKeyRequestManager processReceivedRoomKeyRequests];
        }
    });

#endif
}

- (MXDeviceInfo *)eventDeviceInfo:(MXEvent *)event
{
    __block MXDeviceInfo *device;

#ifdef MX_CRYPTO

    if (event.isEncrypted)
    {
        // Use decryptionQueue because this is a simple read in the db
        // AND we do it synchronously
        // @TODO: dispatch_async
        MXWeakify(self);
        dispatch_sync(_decryptionQueue, ^{
            MXStrongifyAndReturnIfNil(self);

            NSString *algorithm = event.wireContent[@"algorithm"];
            device = [self.deviceList deviceWithIdentityKey:event.senderKey andAlgorithm:algorithm];

        });
    }

#endif

    return device;
}

- (void)setDeviceVerification:(MXDeviceVerification)verificationStatus forDevice:(NSString*)deviceId ofUser:(NSString*)userId
                      success:(void (^)(void))success
                      failure:(void (^)(NSError *error))failure
{
#ifdef MX_CRYPTO
    
    // Note: failure is not currently used but it would make sense the day device
    // verification will be sync'ed with the hs.
    MXWeakify(self);
    dispatch_async(_cryptoQueue, ^{
        MXStrongifyAndReturnIfNil(self);

        MXDeviceInfo *device = [self.store deviceWithDeviceId:deviceId forUser:userId];

        // Sanity check
        if (!device)
        {
            NSLog(@"[MXCrypto] setDeviceVerificationForDevice: Unknown device %@:%@", userId, deviceId);

            if (success)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    success();
                });
            }
            return;
        }

        if (device.verified != verificationStatus)
        {
            device.verified = verificationStatus;
            [self.store storeDeviceForUser:userId device:device];

            if ([userId isEqualToString:self.mxSession.myUser.userId])
            {
                // If one of the user's own devices is being marked as verified / unverified,
                // check the key backup status, since whether or not we use this depends on
                // whether it has a signature from a verified device
                [self.backup checkAndStartKeyBackup];
            }
        }

        if (success)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                success();
            });
        }
    });
#else
    if (success)
    {
        success();
    }
#endif
}

- (void)setDevicesKnown:(MXUsersDevicesMap<MXDeviceInfo *> *)devices complete:(void (^)(void))complete
{
#ifdef MX_CRYPTO
    MXWeakify(self);
    dispatch_async(_cryptoQueue, ^{
        MXStrongifyAndReturnIfNil(self);

        for (NSString *userId in devices.userIds)
        {
            for (NSString *deviceID in [devices deviceIdsForUser:userId])
            {
                MXDeviceInfo *device = [devices objectForDevice:deviceID forUser:userId];

                if (device.verified == MXDeviceUnknown)
                {
                    device.verified = MXDeviceUnverified;
                    [self.store storeDeviceForUser:device.userId device:device];
                }
            }
        }

        if (complete)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                complete();
            });
        }
    });
#else
    if (complete)
    {
        complete();
    }
#endif
}

- (MXHTTPOperation*)downloadKeys:(NSArray<NSString*>*)userIds
                   forceDownload:(BOOL)forceDownload
                         success:(void (^)(MXUsersDevicesMap<MXDeviceInfo*> *usersDevicesInfoMap))success
                         failure:(void (^)(NSError *error))failure
{
#ifdef MX_CRYPTO

    // Create an empty operation that will be mutated later
    MXHTTPOperation *operation = [[MXHTTPOperation alloc] init];

    dispatch_async(_cryptoQueue, ^{

        MXHTTPOperation *operation2 = [self.deviceList downloadKeys:userIds forceDownload:forceDownload success:^(MXUsersDevicesMap<MXDeviceInfo *> *usersDevicesInfoMap) {
            if (success)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    success(usersDevicesInfoMap);
                });
            }
        } failure:^(NSError *error) {
            if (failure)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    failure(error);
                });
            }
        }];
        
        [operation mutateTo:operation2];
    });

    return operation;
#else
    if (success)
    {
        success(nil);
    }
    return nil;
#endif
}

- (void)resetReplayAttackCheckInTimeline:(NSString*)timeline
{
#ifdef MX_CRYPTO
    MXWeakify(self);
    dispatch_async(_decryptionQueue, ^{
        MXStrongifyAndReturnIfNil(self);
        [self.olmDevice resetReplayAttackCheckInTimeline:timeline];
    });
#endif
}

- (void)resetDeviceKeys
{
#ifdef MX_CRYPTO
    MXWeakify(self);
    dispatch_sync(_decryptionQueue, ^{
        MXStrongifyAndReturnIfNil(self);

        // Reset tracking status
        [self.store storeDeviceTrackingStatus:nil];

        // Reset the sync token
        // [self handleDeviceListsChanges] will download all keys at the coming initial /sync
        [self.store storeDeviceSyncToken:nil];
    });
#endif
}

- (NSString *)deviceCurve25519Key
{
#ifdef MX_CRYPTO
    return _olmDevice.deviceCurve25519Key;
#else
    return nil;
#endif
}

- (NSString *)deviceEd25519Key
{
#ifdef MX_CRYPTO
    return _olmDevice.deviceEd25519Key;
#else
    return nil;
#endif
}

- (NSString *)olmVersion
{
#ifdef MX_CRYPTO
    return _olmDevice.olmVersion;
#else
    return nil;
#endif
}


#pragma mark - import/export

- (void)exportRoomKeys:(void (^)(NSArray<NSDictionary *> *))success failure:(void (^)(NSError *))failure
{
#ifdef MX_CRYPTO
    MXWeakify(self);
    dispatch_async(_decryptionQueue, ^{
        MXStrongifyAndReturnIfNil(self);

        NSDate *startDate = [NSDate date];

        NSMutableArray *keys = [NSMutableArray array];

        for (MXOlmInboundGroupSession *session in [self.store inboundGroupSessions])
        {
            MXMegolmSessionData *sessionData = [session exportSessionData];
            if (sessionData)
            {
                [keys addObject:sessionData.JSONDictionary];
            }
        }

        NSLog(@"[MXCrypto] exportRoomKeys: Exported %tu keys in %.0fms", keys.count, [[NSDate date] timeIntervalSinceDate:startDate] * 1000);

        dispatch_async(dispatch_get_main_queue(), ^{

            if (success)
            {
                success(keys);
            }

        });

    });
#endif
}

- (void)exportRoomKeysWithPassword:(NSString *)password success:(void (^)(NSData *))success failure:(void (^)(NSError *))failure
{
#ifdef MX_CRYPTO
    MXWeakify(self);
    dispatch_async(_decryptionQueue, ^{
        MXStrongifyAndReturnIfNil(self);

        NSData *keyFile;
        NSError *error;

        NSDate *startDate = [NSDate date];

        // Export the keys
        NSMutableArray *keys = [NSMutableArray array];
        for (MXOlmInboundGroupSession *session in [self.store inboundGroupSessions])
        {
            MXMegolmSessionData *sessionData = [session exportSessionData];
            if (sessionData)
            {
                [keys addObject:sessionData.JSONDictionary];
            }
        }

        NSLog(@"[MXCrypto] exportRoomKeysWithPassword: Exportion of %tu keys took %.0fms", keys.count, [[NSDate date] timeIntervalSinceDate:startDate] * 1000);

        // Convert them to JSON
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:keys
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:&error];
        if (jsonData)
        {
            // Encrypt them
            keyFile = [MXMegolmExportEncryption encryptMegolmKeyFile:jsonData withPassword:password kdfRounds:0 error:&error];
        }

        NSLog(@"[MXCrypto] exportRoomKeysWithPassword: Exported and encrypted %tu keys in %.0fms", keys.count, [[NSDate date] timeIntervalSinceDate:startDate] * 1000);

        dispatch_async(dispatch_get_main_queue(), ^{

            if (keyFile)
            {
                if (success)
                {
                    success(keyFile);
                }
            }
            else
            {
                NSLog(@"[MXCrypto] exportRoomKeysWithPassword: Error: %@", error);
                if (failure)
                {
                    failure(error);
                }
            }
        });
    });
#endif
}

- (void)importRoomKeys:(NSArray<NSDictionary *> *)keys success:(void (^)(NSUInteger total, NSUInteger imported))success failure:(void (^)(NSError *))failure
{
#ifdef MX_CRYPTO
    dispatch_async(_decryptionQueue, ^{

        NSLog(@"[MXCrypto] importRoomKeys:");

        // Convert JSON to MXMegolmSessionData
        NSArray<MXMegolmSessionData *> *sessionDatas = [MXMegolmSessionData modelsFromJSON:keys];

        [self importMegolmSessionDatas:sessionDatas backUp:YES success:success failure:failure];
    });
#endif
}

- (void)importMegolmSessionDatas:(NSArray<MXMegolmSessionData*>*)sessionDatas backUp:(BOOL)backUp success:(void (^)(NSUInteger total, NSUInteger imported))success failure:(void (^)(NSError *error))failure
{
#ifdef MX_CRYPTO
    MXWeakify(self);
    dispatch_async(_decryptionQueue, ^{
        MXStrongifyAndReturnIfNil(self);

        NSLog(@"[MXCrypto] importMegolmSessionDatas: backUp: %@", @(backUp));

        NSDate *startDate = [NSDate date];

        // Import keys
        NSArray<MXOlmInboundGroupSession *>* sessions = [self.olmDevice importInboundGroupSessions:sessionDatas];

        NSLog(@"[MXCrypto] importMegolmSessionDatas: Imported %@ keys in store", @(sessions.count));

        // Do not back up the key if it comes from a backup recovery
        if (backUp)
        {
            [self.backup maybeSendKeyBackup];
        }
        else
        {
            [self.store markBackupDoneForInboundGroupSessions:sessions];
        }

        // Notify there are new keys
        NSLog(@"[MXCrypto] importMegolmSessionDatas: Notifying about new keys...");
        for (MXOlmInboundGroupSession *session in sessions)
        {
            id<MXDecrypting> alg = [self getRoomDecryptor:session.roomId algorithm:kMXCryptoMegolmAlgorithm];
            [alg didImportRoomKey:session];
        }

        NSUInteger imported = sessions.count;
        NSUInteger totalKeyCount = sessionDatas.count;

        NSLog(@"[MXCrypto] importMegolmSessionDatas: Complete. Imported %tu keys from %tu provided keys in %.0fms", imported, totalKeyCount, [[NSDate date] timeIntervalSinceDate:startDate] * 1000);

        dispatch_async(dispatch_get_main_queue(), ^{

            if (success)
            {
                success(totalKeyCount, imported);
            }
        });
    });
#endif
}

- (void)importRoomKeys:(NSData *)keyFile withPassword:(NSString *)password success:(void (^)(NSUInteger total, NSUInteger imported))success failure:(void (^)(NSError *))failure
{
#ifdef MX_CRYPTO
    dispatch_async(_decryptionQueue, ^{

        NSLog(@"[MXCrypto] importRoomKeys:withPassord:");

        NSError *error;
        NSDate *startDate = [NSDate date];

        NSData *jsonData = [MXMegolmExportEncryption decryptMegolmKeyFile:keyFile withPassword:password error:&error];
        if(jsonData)
        {
            NSArray *keys = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
            if (keys)
            {
                [self importRoomKeys:keys success:^(NSUInteger total, NSUInteger imported) {

                    NSLog(@"[MXCrypto] importRoomKeys:withPassord: Imported %tu keys from %tu provided keys in %.0fms", imported, total, [[NSDate date] timeIntervalSinceDate:startDate] * 1000);

                    if (success)
                    {
                        success(total, imported);
                    }

                } failure:failure];
                return;
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{

            NSLog(@"[MXCrypto] importRoomKeys:withPassord: Error: %@", error);

            if (failure)
            {
                failure(error);
            }
        });
    });
#endif
}

#pragma mark - Key sharing

- (void)pendingKeyRequests:(void (^)(MXUsersDevicesMap<NSArray<MXIncomingRoomKeyRequest *> *> *pendingKeyRequests))onComplete
{
    NSParameterAssert(onComplete);

#ifdef MX_CRYPTO
    MXWeakify(self);
    dispatch_async(_decryptionQueue, ^{
        MXStrongifyAndReturnIfNil(self);

        MXUsersDevicesMap<NSArray<MXIncomingRoomKeyRequest *> *> *pendingKeyRequests = self->incomingRoomKeyRequestManager.pendingKeyRequests;

        dispatch_async(dispatch_get_main_queue(), ^{
            onComplete(pendingKeyRequests);
        });
    });
#endif
}

- (void)acceptKeyRequest:(MXIncomingRoomKeyRequest *)keyRequest
                 success:(void (^)(void))success
                 failure:(void (^)(NSError *error))failure
{
#ifdef MX_CRYPTO
    dispatch_async(_decryptionQueue, ^{

        NSLog(@"[MXCrypto] acceptKeyRequest: %@", keyRequest);
        [self acceptKeyRequestFromCryptoThread:keyRequest success:success failure:failure];
    });
#endif
}

- (void)acceptAllPendingKeyRequestsFromUser:(NSString *)userId andDevice:(NSString *)deviceId onComplete:(void (^)(void))onComplete
{
#ifdef MX_CRYPTO
    MXWeakify(self);
    dispatch_async(_decryptionQueue, ^{
        MXStrongifyAndReturnIfNil(self);

        NSArray<MXIncomingRoomKeyRequest *> *requests = [self->incomingRoomKeyRequestManager.pendingKeyRequests objectForDevice:deviceId forUser:userId];

        NSLog(@"[MXCrypto] acceptAllPendingKeyRequestsFromUser from %@:%@. %@ pending requests", userId, deviceId, @(requests.count));

        for (MXIncomingRoomKeyRequest *request in requests)
        {
            // TODO: Add success and failure blocks to acceptAllPendingKeyRequestsFromUser
            [self acceptKeyRequestFromCryptoThread:request success:nil failure:nil];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (onComplete)
            {
                onComplete();
            }
        });
    });
#endif
}

#ifdef MX_CRYPTO
- (void)acceptKeyRequestFromCryptoThread:(MXIncomingRoomKeyRequest *)keyRequest
                                 success:(void (^)(void))success
                                 failure:(void (^)(NSError *error))failure
{
    NSString *userId = keyRequest.userId;
    NSString *deviceId = keyRequest.deviceId;
    NSString *requestId = keyRequest.requestId;

    NSDictionary *body = keyRequest.requestBody;
    NSString *roomId, *alg;

    MXJSONModelSetString(roomId, body[@"room_id"]);
    MXJSONModelSetString(alg, body[@"algorithm"]);

    // The request is no more pending
    [incomingRoomKeyRequestManager removePendingKeyRequest:requestId fromUser:userId andDevice:deviceId];

    id<MXDecrypting> decryptor = [self getRoomDecryptor:roomId algorithm:alg];
    if (decryptor)
    {
        [decryptor shareKeysWithDevice:keyRequest success:success failure:failure];
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{

            NSLog(@"[MXCrypto] acceptPendingKeyRequests: ERROR: unknown alg %@ in room %@", alg, roomId);
            if (failure)
            {
                failure(nil);
            }
        });
    }
}
#endif

- (void)ignoreKeyRequest:(MXIncomingRoomKeyRequest *)keyRequest onComplete:(void (^)(void))onComplete
{
#ifdef MX_CRYPTO
    dispatch_async(_decryptionQueue, ^{

        NSLog(@"[MXCrypto] ignoreKeyRequest: %@", keyRequest);
        [self ignoreKeyRequestFromCryptoThread:keyRequest];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (onComplete)
            {
                onComplete();
            }
        });
    });
#endif
}

- (void)ignoreAllPendingKeyRequestsFromUser:(NSString *)userId andDevice:(NSString *)deviceId onComplete:(void (^)(void))onComplete
{
#ifdef MX_CRYPTO
    MXWeakify(self);
    dispatch_async(_decryptionQueue, ^{
        MXStrongifyAndReturnIfNil(self);

        NSArray<MXIncomingRoomKeyRequest *> *requests = [self->incomingRoomKeyRequestManager.pendingKeyRequests objectForDevice:deviceId forUser:userId];

        NSLog(@"[MXCrypto] ignoreAllPendingKeyRequestsFromUser from %@:%@. %@ pending requests", userId, deviceId, @(requests.count));

        for (MXIncomingRoomKeyRequest *request in requests)
        {
            [self ignoreKeyRequestFromCryptoThread:request];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (onComplete)
            {
                onComplete();
            }
        });
    });
#endif
}

#ifdef MX_CRYPTO
- (void)ignoreKeyRequestFromCryptoThread:(MXIncomingRoomKeyRequest *)keyRequest
{
    NSString *userId = keyRequest.userId;
    NSString *deviceId = keyRequest.deviceId;
    NSString *requestId = keyRequest.requestId;

    // Make request no more pending
    [incomingRoomKeyRequestManager removePendingKeyRequest:requestId fromUser:userId andDevice:deviceId];
}
#endif

- (void)reRequestRoomKeyForEvent:(MXEvent *)event
{
#ifdef MX_CRYPTO
    MXWeakify(self);
    dispatch_async(_decryptionQueue, ^{
        MXStrongifyAndReturnIfNil(self);

        NSLog(@"[MXCrypto] reRequestRoomKeyForEvent: %@", event.eventId);

        NSDictionary *wireContent = event.wireContent;
        NSString *algorithm, *senderKey, *sessionId;
        MXJSONModelSetString(algorithm, wireContent[@"algorithm"]);
        MXJSONModelSetString(senderKey, wireContent[@"sender_key"]);
        MXJSONModelSetString(sessionId, wireContent[@"session_id"]);

        if (algorithm && senderKey && sessionId)
        {
            [self->outgoingRoomKeyRequestManager resendRoomKeyRequest:@{
                                                                        @"room_id": event.roomId,
                                                                        @"algorithm": algorithm,
                                                                        @"sender_key": senderKey,
                                                                        @"session_id": sessionId
                                                                        }];
        }
    });
#endif
}


#pragma mark - Crypto settings
- (BOOL)globalBlacklistUnverifiedDevices
{
#ifdef MX_CRYPTO
    return _store.globalBlacklistUnverifiedDevices;
#else
    return NO;
#endif
}

- (void)setGlobalBlacklistUnverifiedDevices:(BOOL)globalBlacklistUnverifiedDevices
{
#ifdef MX_CRYPTO
    _store.globalBlacklistUnverifiedDevices = globalBlacklistUnverifiedDevices;
#endif
}

- (BOOL)isBlacklistUnverifiedDevicesInRoom:(NSString *)roomId
{
#ifdef MX_CRYPTO
    return [_store blacklistUnverifiedDevicesInRoom:roomId];
#else
    return NO;
#endif
}

- (void)setBlacklistUnverifiedDevicesInRoom:(NSString *)roomId blacklist:(BOOL)blacklist
{
#ifdef MX_CRYPTO
    [_store storeBlacklistUnverifiedDevicesInRoom:roomId blacklist:blacklist];
#endif
}


#pragma mark - Private API

#ifdef MX_CRYPTO

- (instancetype)initWithMatrixSession:(MXSession*)matrixSession cryptoQueue:(dispatch_queue_t)theCryptoQueue andStore:(id<MXCryptoStore>)store
{
    // This method must be called on the crypto thread
    self = [super init];
    if (self)
    {
        _mxSession = matrixSession;
        _cryptoQueue = theCryptoQueue;
        _store = store;

        // Default configuration
        _warnOnUnknowDevices = YES;

        _decryptionQueue = [MXCrypto dispatchQueueForUser:_mxSession.matrixRestClient.credentials.userId];

        _olmDevice = [[MXOlmDevice alloc] initWithStore:_store];

        _deviceList = [[MXDeviceList alloc] initWithCrypto:self];

        // Use our own REST client that answers on the crypto thread
        _matrixRestClient = [[MXRestClient alloc] initWithCredentials:_mxSession.matrixRestClient.credentials andOnUnrecognizedCertificateBlock:nil];
        _matrixRestClient.completionQueue = _cryptoQueue;

        roomEncryptors = [NSMutableDictionary dictionary];
        roomDecryptors = [NSMutableDictionary dictionary];

        // Build our device keys: they will later be uploaded
        NSString *deviceId = _store.deviceId;
        if (!deviceId)
        {
            // Generate a device id if the homeserver did not provide it or it was lost
            deviceId = [self generateDeviceId];

            NSLog(@"[MXCrypto] Warning: No device id in MXCredentials. The id %@ was created", deviceId);

            [_store storeDeviceId:deviceId];
        }

        NSString *userId = _matrixRestClient.credentials.userId;

        _myDevice = [[MXDeviceInfo alloc] initWithDeviceId:deviceId];
        _myDevice.userId = userId;
        _myDevice.keys = @{
                          [NSString stringWithFormat:@"ed25519:%@", deviceId]: _olmDevice.deviceEd25519Key,
                          [NSString stringWithFormat:@"curve25519:%@", deviceId]: _olmDevice.deviceCurve25519Key,
                          };
        _myDevice.algorithms = [[MXCryptoAlgorithms sharedAlgorithms] supportedAlgorithms];
        _myDevice.verified = MXDeviceVerified;

        // Add our own deviceinfo to the store
        NSMutableDictionary *myDevices = [NSMutableDictionary dictionaryWithDictionary:[_store devicesForUser:userId]];
        myDevices[_myDevice.deviceId] = _myDevice;
        [_store storeDevicesForUser:userId devices:myDevices];

        oneTimeKeyCount = -1;

        _backup = [[MXKeyBackup alloc] initWithCrypto:self];

        outgoingRoomKeyRequestManager = [[MXOutgoingRoomKeyRequestManager alloc]
                                         initWithMatrixRestClient:_matrixRestClient
                                         deviceId:_myDevice.deviceId
                                         cryptoQueue:[MXCrypto dispatchQueueForUser:_myDevice.userId]
                                         cryptoStore:_store];

        incomingRoomKeyRequestManager = [[MXIncomingRoomKeyRequestManager alloc] initWithCrypto:self];

        _deviceVerificationManager = [[MXDeviceVerificationManager alloc] initWithCrypto:self];
        
        [self registerEventHandlers];
        
    }
    return self;
}

- (MXDeviceInfo *)eventSenderDeviceOfEvent:(MXEvent *)event
{
    NSString *senderKey = event.senderKey;
    NSString *algorithm = event.wireContent[@"algorithm"];

    if (!senderKey || !algorithm)
    {
        return nil;
    }

    NSArray *forwardingChain = event.forwardingCurve25519KeyChain;
    if (forwardingChain.count > 0)
    {
        // we got this event from somewhere else
        // TODO: check if we can trust the forwarders.
        return nil;
    }

    // senderKey is the Curve25519 identity key of the device which the event
    // was sent from. In the case of Megolm, it's actually the Curve25519
    // identity key of the device which set up the Megolm session.
    MXDeviceInfo *device = [_deviceList deviceWithIdentityKey:senderKey andAlgorithm:algorithm];
    if (!device)
    {
        // we haven't downloaded the details of this device yet.
        return nil;
    }

    // So far so good, but now we need to check that the sender of this event
    // hadn't advertised someone else's Curve25519 key as their own. We do that
    // by checking the Ed25519 claimed by the event (or, in the case of megolm,
    // the event which set up the megolm session), to check that it matches the
    // fingerprint of the purported sending device.
    //
    // (see https://github.com/vector-im/vector-web/issues/2215)
    NSString *claimedKey = event.keysClaimed[@"ed25519"];
    if (!claimedKey)
    {
        NSLog(@"[MXCrypto] eventSenderDeviceOfEvent: Event %@ claims no ed25519 key. Cannot verify sending device", event.eventId);
        return nil;
    }

    if (![claimedKey isEqualToString:device.fingerprint])
    {
        NSLog(@"[MXCrypto] eventSenderDeviceOfEvent: Event %@ claims ed25519 key %@. Cannot verify sending device but sender device has key %@", event.eventId, claimedKey, device.fingerprint);
        return nil;
    }
    
    return device;
}

- (BOOL)setEncryptionInRoom:(NSString*)roomId withMembers:(NSArray<NSString*>*)members algorithm:(NSString*)algorithm inhibitDeviceQuery:(BOOL)inhibitDeviceQuery
{
    // If we already have encryption in this room, we should ignore this event
    // (for now at least. Maybe we should alert the user somehow?)
    NSString *existingAlgorithm = [_store algorithmForRoom:roomId];
    if (existingAlgorithm && ![existingAlgorithm isEqualToString:algorithm])
    {
        NSLog(@"[MXCrypto] setEncryptionInRoom: Ignoring m.room.encryption event which requests a change of config in %@", roomId);
        return NO;
    }

    Class encryptionClass = [[MXCryptoAlgorithms sharedAlgorithms] encryptorClassForAlgorithm:algorithm];
    if (!encryptionClass)
    {
        NSLog(@"[MXCrypto] setEncryptionInRoom: Unable to encrypt with %@", algorithm);
        return NO;
    }

    if (!existingAlgorithm)
    {
        [_store storeAlgorithmForRoom:roomId algorithm:algorithm];
    }

    id<MXEncrypting> alg = [[encryptionClass alloc] initWithCrypto:self andRoom:roomId];

    roomEncryptors[roomId] = alg;

    // make sure we are tracking the device lists for all users in this room.
    NSLog(@"[MXCrypto] setEncryptionInRoom: Enabling encryption in %@; starting to track device lists for all users therein", roomId);

    for (NSString *userId in members)
    {
        [_deviceList startTrackingDeviceList:userId];
    }

    if (!inhibitDeviceQuery)
    {
        [_deviceList refreshOutdatedDeviceLists];
    }

    return YES;
}

- (MXHTTPOperation*)ensureOlmSessionsForUsers:(NSArray*)users
                                      success:(void (^)(MXUsersDevicesMap<MXOlmSessionResult*> *results))success
                                      failure:(void (^)(NSError *error))failure
{
    NSLog(@"[MXCrypto] ensureOlmSessionsForUsers: %@", users);

    NSMutableDictionary<NSString* /* userId */, NSMutableArray<MXDeviceInfo*>*> *devicesByUser = [NSMutableDictionary dictionary];

    for (NSString *userId in users)
    {
        devicesByUser[userId] = [NSMutableArray array];

        NSArray<MXDeviceInfo *> *devices = [self.deviceList storedDevicesForUser:userId];
        for (MXDeviceInfo *device in devices)
        {
            NSString *key = device.identityKey;

            if ([key isEqualToString:_olmDevice.deviceCurve25519Key])
            {
                // Don't bother setting up session to ourself
                continue;
            }

            if (device.verified == MXDeviceBlocked) {
                // Don't bother setting up sessions with blocked users
                continue;
            }

            [devicesByUser[userId] addObject:device];
        }
    }

    return [self ensureOlmSessionsForDevices:devicesByUser success:success failure:failure];
}

- (MXHTTPOperation*)ensureOlmSessionsForDevices:(NSDictionary<NSString* /* userId */, NSArray<MXDeviceInfo*>*>*)devicesByUser
                                        success:(void (^)(MXUsersDevicesMap<MXOlmSessionResult*> *results))success
                                        failure:(void (^)(NSError *error))failure

{
    NSMutableArray<MXDeviceInfo*> *devicesWithoutSession = [NSMutableArray array];

    MXUsersDevicesMap<MXOlmSessionResult*> *results = [[MXUsersDevicesMap alloc] init];

    NSUInteger count = 0;
    for (NSString *userId in devicesByUser)
    {
        count += devicesByUser[userId].count;

        for (MXDeviceInfo *deviceInfo in devicesByUser[userId])
        {
            NSString *deviceId = deviceInfo.deviceId;
            NSString *key = deviceInfo.identityKey;

            NSString *sessionId = [_olmDevice sessionIdForDevice:key];
            if (!sessionId)
            {
                [devicesWithoutSession addObject:deviceInfo];
            }

            MXOlmSessionResult *olmSessionResult = [[MXOlmSessionResult alloc] initWithDevice:deviceInfo andOlmSession:sessionId];
            [results setObject:olmSessionResult forUser:userId andDevice:deviceId];
        }
    }

    NSLog(@"[MXCrypto] ensureOlmSessionsForDevices (users: %tu - devices: %tu): %@", devicesByUser.count, count, devicesByUser);

    if (devicesWithoutSession.count == 0)
    {
        if (success)
        {
            success(results);
        }
        return nil;
    }

    NSString *oneTimeKeyAlgorithm = kMXKeySignedCurve25519Type;

    // Prepare the request for claiming one-time keys
    MXUsersDevicesMap<NSString*> *usersDevicesToClaim = [[MXUsersDevicesMap<NSString*> alloc] init];
    for (MXDeviceInfo *device in devicesWithoutSession)
    {
        [usersDevicesToClaim setObject:oneTimeKeyAlgorithm forUser:device.userId andDevice:device.deviceId];
    }

    // TODO: this has a race condition - if we try to send another message
    // while we are claiming a key, we will end up claiming two and setting up
    // two sessions.
    //
    // That should eventually resolve itself, but it's poor form.

    NSLog(@"[MXCrypto] ensureOlmSessionsForDevices: claimOneTimeKeysForUsersDevices (users: %tu - devices: %tu)",
          usersDevicesToClaim.map.count, usersDevicesToClaim.count);

    return [_matrixRestClient claimOneTimeKeysForUsersDevices:usersDevicesToClaim success:^(MXKeysClaimResponse *keysClaimResponse) {

        NSLog(@"[MXCrypto] ensureOlmSessionsForDevices: claimOneTimeKeysForUsersDevices response (users: %tu - devices: %tu): %@",
              keysClaimResponse.oneTimeKeys.map.count, keysClaimResponse.oneTimeKeys.count, keysClaimResponse.oneTimeKeys);

        for (NSString *userId in devicesByUser)
        {
            for (MXDeviceInfo *deviceInfo in devicesByUser[userId])
            {
                MXKey *oneTimeKey;
                for (NSString *deviceId in [keysClaimResponse.oneTimeKeys deviceIdsForUser:userId])
                {
                    MXOlmSessionResult *olmSessionResult = [results objectForDevice:deviceId forUser:userId];
                    if (olmSessionResult.sessionId)
                    {
                        // We already have a result for this device
                        continue;
                    }

                    MXKey *key = [keysClaimResponse.oneTimeKeys objectForDevice:deviceId forUser:userId];
                    if ([key.type isEqualToString:oneTimeKeyAlgorithm])
                    {
                        oneTimeKey = key;
                    }

                    if (!oneTimeKey)
                    {
                        NSLog(@"[MXCrypto] ensureOlmSessionsForDevices: No one-time keys (alg=%@) for device %@:%@", oneTimeKeyAlgorithm, userId, deviceId);
                        continue;
                    }

                    NSString *sid = [self verifyKeyAndStartSession:oneTimeKey userId:userId deviceInfo:deviceInfo];

                    // Update the result for this device in results
                    olmSessionResult.sessionId = sid;
                }
            }
        }

        if (success)
        {
            success(results);
        }

    } failure:^(NSError *error) {

        NSLog(@"[MXCrypto] ensureOlmSessionsForDevices: claimOneTimeKeysForUsersDevices request failed.");

        if (failure)
        {
            failure(error);
        }
    }];
}

- (NSString*)verifyKeyAndStartSession:(MXKey*)oneTimeKey userId:(NSString*)userId deviceInfo:(MXDeviceInfo*)deviceInfo
{
    NSString *sessionId;

    NSString *deviceId = deviceInfo.deviceId;
    NSString *signKeyId = [NSString stringWithFormat:@"ed25519:%@", deviceId];
    NSString *signature = [oneTimeKey.signatures objectForDevice:signKeyId forUser:userId];

    // Check one-time key signature
    NSError *error;
    if ([_olmDevice verifySignature:deviceInfo.fingerprint JSON:oneTimeKey.signalableJSONDictionary signature:signature error:&error])
    {
        // Update the result for this device in results
        sessionId = [_olmDevice createOutboundSession:deviceInfo.identityKey theirOneTimeKey:oneTimeKey.value];

        if (sessionId)
        {
            NSLog(@"[MXCrypto] Started new sessionid %@ for device %@ (theirOneTimeKey: %@)", sessionId, deviceInfo, oneTimeKey.value);
        }
        else
        {
            // Possibly a bad key
            NSLog(@"[MXCrypto] Error starting session with device %@:%@", userId, deviceId);
        }
    }
    else
    {
        NSLog(@"[MXCrypto] Unable to verify signature on one-time key for device %@:%@. Error: %@", userId, deviceId, error.localizedFailureReason);
    }

    return sessionId;
}

- (NSDictionary*)encryptMessage:(NSDictionary*)payloadFields forDevices:(NSArray<MXDeviceInfo*>*)devices
{
    NSMutableDictionary *ciphertext = [NSMutableDictionary dictionary];
    for (MXDeviceInfo *recipientDevice in devices)
    {
        NSString *sessionId = [_olmDevice sessionIdForDevice:recipientDevice.identityKey];
        if (sessionId)
        {
            NSMutableDictionary *payloadJson = [NSMutableDictionary dictionaryWithDictionary:payloadFields];
            payloadJson[@"sender"] = _matrixRestClient.credentials.userId;
            payloadJson[@"sender_device"] = _store.deviceId;

            // Include the Ed25519 key so that the recipient knows what
            // device this message came from.
            // We don't need to include the curve25519 key since the
            // recipient will already know this from the olm headers.
            // When combined with the device keys retrieved from the
            // homeserver signed by the ed25519 key this proves that
            // the curve25519 key and the ed25519 key are owned by
            // the same device.
            payloadJson[@"keys"] = @{
                                     @"ed25519": _olmDevice.deviceEd25519Key
                                     };

            // Include the recipient device details in the payload,
            // to avoid unknown key attacks, per
            // https://github.com/vector-im/vector-web/issues/2483
            payloadJson[@"recipient"] = recipientDevice.userId;
            payloadJson[@"recipient_keys"] = @{
                                               @"ed25519": recipientDevice.fingerprint
                                               };

            NSData *payloadData = [NSJSONSerialization  dataWithJSONObject:payloadJson options:0 error:nil];
            NSString *payloadString = [[NSString alloc] initWithData:payloadData encoding:NSUTF8StringEncoding];

            //NSLog(@"[MXCrypto] encryptMessage: %@\nUsing sessionid %@ for device %@", payloadJson, sessionId, recipientDevice.identityKey);
            ciphertext[recipientDevice.identityKey] = [_olmDevice encryptMessage:recipientDevice.identityKey sessionId:sessionId payloadString:payloadString];
        }
    }

    return @{
             @"algorithm": kMXCryptoOlmAlgorithm,
             @"sender_key": _olmDevice.deviceCurve25519Key,
             @"ciphertext": ciphertext
             };
}

- (id<MXDecrypting>)getRoomDecryptor:(NSString*)roomId algorithm:(NSString*)algorithm
{
    id<MXDecrypting> alg;

    if (roomId)
    {
        if (!roomDecryptors[roomId])
        {
            roomDecryptors[roomId] = [NSMutableDictionary dictionary];
        }

        alg = roomDecryptors[roomId][algorithm];
        if (alg)
        {
            return alg;
        }
    }

    Class algClass = [[MXCryptoAlgorithms sharedAlgorithms] decryptorClassForAlgorithm:algorithm];
    if (algClass)
    {
        alg = [[algClass alloc] initWithCrypto:self];

        if (roomId)
        {
            roomDecryptors[roomId][algorithm] = alg;
        }
    }

    return alg;
}

- (NSDictionary*)signObject:(NSDictionary*)object
{
    return @{
             _myDevice.userId: @{
                     [NSString stringWithFormat:@"ed25519:%@", _myDevice.deviceId]: [_olmDevice signJSON:object]
                     }
             };
}


#pragma mark - Key sharing
- (void)requestRoomKey:(NSDictionary*)requestBody recipients:(NSArray<NSDictionary<NSString*, NSString*>*>*)recipients
{
    [outgoingRoomKeyRequestManager sendRoomKeyRequest:requestBody recipients:recipients];
}

- (void)cancelRoomKeyRequest:(NSDictionary*)requestBody
{
    [outgoingRoomKeyRequestManager cancelRoomKeyRequest:requestBody];
}


#pragma mark - Private methods
/**
 Get or create the GCD queue for a given user.

 @param userId the user id.
 @return the dispatch queue to use to handle the crypto for this user.
 */
+ (dispatch_queue_t)dispatchQueueForUser:(NSString*)userId
{
    static NSMutableDictionary <NSString*, dispatch_queue_t> *dispatchQueues;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatchQueues = [NSMutableDictionary dictionary];
    });

    dispatch_queue_t queue = dispatchQueues[userId];
    if (!queue)
    {
        @synchronized (dispatchQueues)
        {
            NSLog(@"[MXCrypto] Create dispatch queue for %@'s crypto", userId);
            queue = dispatch_queue_create([NSString stringWithFormat:@"MXCrypto-%@", userId].UTF8String, DISPATCH_QUEUE_SERIAL);
            dispatchQueues[userId] = queue;
        }
    }

    return queue;
}

- (NSString*)generateDeviceId
{
    return [[[MXTools generateSecret] stringByReplacingOccurrencesOfString:@"-" withString:@""] substringToIndex:10];
}

/**
 Ask the server which users have new devices since a given token,
 and invalidate them.

 @param oldSyncToken the old token.
 @param lastKnownSyncToken the new token.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (void)invalidateDeviceListsSince:(NSString*)oldSyncToken to:(NSString*)lastKnownSyncToken
                           success:(void (^)(void))success
                           failure:(void (^)(NSError *error))failure
{
    [_matrixRestClient keyChangesFrom:oldSyncToken to:lastKnownSyncToken success:^(MXDeviceListResponse *deviceLists) {

        NSLog(@"[MXCrypto] invalidateDeviceListsSince: got key changes since %@: changed: %@\nleft: %@", oldSyncToken, deviceLists.changed, deviceLists.left);

        [self handleDeviceListsChanges:deviceLists];

        success();

    } failure:failure];
}

/**
 Listen to events that change the signatures chain.
 */
- (void)registerEventHandlers
{
    dispatch_async(dispatch_get_main_queue(), ^{

        // Observe incoming to-device events
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onToDeviceEvent:) name:kMXSessionOnToDeviceEventNotification object:self.mxSession];

        // Observe membership changes
        self->roomMembershipEventsListener = [self.mxSession listenToEventsOfTypes:@[kMXEventTypeStringRoomEncryption, kMXEventTypeStringRoomMember] onEvent:^(MXEvent *event, MXTimelineDirection direction, id customObject) {

            if (direction == MXTimelineDirectionForwards)
            {
                if (event.eventType == MXEventTypeRoomEncryption)
                {
                    [self onCryptoEvent:event];
                }
                else if (event.eventType == MXEventTypeRoomMember)
                {
                    [self onRoomMembership:event roomState:customObject];
                }
            }
        }];

    });
}

/**
 Handle a to-device event.

 @param notification the notification containing the to-device event.
 */
- (void)onToDeviceEvent:(NSNotification *)notification
{
    MXEvent *event = notification.userInfo[kMXSessionNotificationEventKey];

    NSLog(@"[MXCrypto] onToDeviceEvent: event.type: %@", event.type);

    if (_cryptoQueue)
    {
        MXWeakify(self);
        switch (event.eventType)
        {
            case MXEventTypeRoomKey:
            case MXEventTypeRoomForwardedKey:
            {
                // Room key is used for decryption. Switch to the associated queue
                dispatch_async(_decryptionQueue, ^{
                    MXStrongifyAndReturnIfNil(self);

                    [self onRoomKeyEvent:event];
                });
                break;
            }

            case MXEventTypeRoomKeyRequest:
            {
                dispatch_async(_cryptoQueue, ^{
                    MXStrongifyAndReturnIfNil(self);

                    [self->incomingRoomKeyRequestManager onRoomKeyRequestEvent:event];
                });
                break;
            }

            default:
                break;
        }
    }
}

/**
 Handle a key event.

 @param event the key event.
 */
- (void)onRoomKeyEvent:(MXEvent*)event
{
    if (!event.content[@"room_id"] || !event.content[@"algorithm"])
    {
        NSLog(@"[MXCrypto] onRoomKeyEvent: ERROR: Key event is missing fields");
        return;
    }

    id<MXDecrypting> alg = [self getRoomDecryptor:event.content[@"room_id"] algorithm:event.content[@"algorithm"]];
    if (!alg)
    {
        NSLog(@"[MXCrypto] onRoomKeyEvent: ERROR: Unable to handle keys for %@", event.content[@"algorithm"]);
        return;
    }

    [alg onRoomKeyEvent:event];
}

/**
 Handle an m.room.encryption event.

 @param event the encryption event.
 */
- (void)onCryptoEvent:(MXEvent*)event
{
    MXRoom *room = [_mxSession roomWithRoomId:event.roomId];

    MXWeakify(self);
    void (^success)(MXRoomMembers *roomMembers, MXRoomState *roomState) = ^void(MXRoomMembers *roomMembers, MXRoomState *roomState)
    {
        MXStrongifyAndReturnIfNil(self);

        NSMutableArray *members = [NSMutableArray array];
        NSArray<MXRoomMember *> *encryptionTargetMembers = [roomMembers encryptionTargetMembers:roomState.historyVisibility];
        for (MXRoomMember *roomMember in encryptionTargetMembers)
        {
            [members addObject:roomMember.userId];
        }

        if (self.cryptoQueue)
        {
            dispatch_async(self.cryptoQueue, ^{
                [self setEncryptionInRoom:event.roomId withMembers:members algorithm:event.content[@"algorithm"] inhibitDeviceQuery:YES];
            });
        }
    };
    
    [room state:^(MXRoomState *roomState) {
        [room members:^(MXRoomMembers *roomMembers) {
            success(roomMembers, roomState);
        } failure:^(NSError *error) {
            NSLog(@"[MXCrypto] onCryptoEvent: Warning: Unable to get all members from the HS. Fallback by using lazy-loaded members");
            success(roomState.members, roomState);
        }];
    }];
}

/**
 Handle a change in the membership state of a member of a room.

 @param event the membership event causing the change.
 @param roomState the know state of the room when the event occurs.
 */
- (void)onRoomMembership:(MXEvent*)event roomState:(MXRoomState*)roomState
{
    id<MXEncrypting> alg = roomEncryptors[event.roomId];
    if (!alg)
    {
        // No encrypting in this room
        return;
    }

    // Check whether we have to track the devices for this user.
    BOOL shouldTrack = NO;
    NSString *userId = event.stateKey;
    MXRoomMember *member = [roomState.members memberWithUserId:userId];
    if (member)
    {
        if (member.membership == MXMembershipJoin)
        {
            NSLog(@"[MXCrypto] onRoomMembership: Join event for %@ in %@", member.userId, event.roomId);
            shouldTrack = YES;
        }
        // Check whether we should encrypt for the invited members too
        else if (member.membership == MXMembershipInvite && ![roomState.historyVisibility isEqualToString:kMXRoomHistoryVisibilityJoined])
        {
            // track the deviceList for this invited user.
            // Caution: there's a big edge case here in that federated servers do not
            // know what other servers are in the room at the time they've been invited.
            // They therefore will not send device updates if a user logs in whilst
            // their state is invite.
            NSLog(@"[MXCrypto] onRoomMembership: Invite event for %@ in %@", member.userId, event.roomId);
            shouldTrack = YES;
        }
    }
    
    if (shouldTrack && self.cryptoQueue)
    {
        MXWeakify(self);
        dispatch_async(self.cryptoQueue, ^{
            MXStrongifyAndReturnIfNil(self);
            
            // make sure we are tracking the deviceList for this user
            [self.deviceList startTrackingDeviceList:member.userId];
        });
    }
}

/**
 Upload my user's device keys.
 */
- (MXHTTPOperation *)uploadDeviceKeys:(void (^)(MXKeysUploadResponse *keysUploadResponse))success failure:(void (^)(NSError *))failure
{
    // Sanity check
    if (!_matrixRestClient.credentials.userId)
    {
        NSLog(@"[MXCrypto] uploadDeviceKeys. ERROR: _matrixRestClient.credentials.userId cannot be nil");
        failure(nil);
        return nil;
    }

    // Prepare the device keys data to send
    // Sign it
    NSString *signature = [_olmDevice signJSON:_myDevice.signalableJSONDictionary];
    _myDevice.signatures = @{
                            _matrixRestClient.credentials.userId: @{
                                    [NSString stringWithFormat:@"ed25519:%@", _myDevice.deviceId]: signature
                                    }
                            };

    // For now, we set the device id explicitly, as we may not be using the
    // same one as used in login.
    return [_matrixRestClient uploadKeys:_myDevice.JSONDictionary oneTimeKeys:nil forDevice:_myDevice.deviceId success:success failure:failure];
}

/**
 Check if it's time to upload one-time keys, and do so if so.
 */
- (void)maybeUploadOneTimeKeys:(void (^)(void))success failure:(void (^)(NSError *))failure
{
    if (uploadOneTimeKeysOperation)
    {
        NSLog(@"[MXCrypto] maybeUploadOneTimeKeys: already in progress");
        if (success)
        {
            success();
        }
        return;
    }

    NSDate *now = [NSDate date];
    if (lastOneTimeKeyCheck && [now timeIntervalSinceDate:lastOneTimeKeyCheck] < kMXCryptoUploadOneTimeKeysPeriod)
    {
        // We've done a key upload recently.
        if (success)
        {
            success();
        }
        return;
    }

    lastOneTimeKeyCheck = now;

    if (oneTimeKeyCount != -1)
    {
        // We already have the current one_time_key count from a /sync response.
        // Use this value instead of asking the server for the current key count.
        NSLog(@"[MXCrypto] maybeUploadOneTimeKeys: there are %tu one-time keys on the homeserver", oneTimeKeyCount);

        if ([self generateOneTimeKeys:oneTimeKeyCount])
        {
            MXWeakify(self);
            uploadOneTimeKeysOperation = [self uploadOneTimeKeys:^(MXKeysUploadResponse *keysUploadResponse) {
                MXStrongifyAndReturnIfNil(self);

                self->uploadOneTimeKeysOperation = nil;
                if (success)
                {
                    success();
                }

            } failure:^(NSError *error) {
                MXStrongifyAndReturnIfNil(self);

                NSLog(@"[MXCrypto] maybeUploadOneTimeKeys: Failed to publish one-time keys. Error: %@", error);
                self->uploadOneTimeKeysOperation = nil;

                if (failure)
                {
                    failure(error);
                }
            }];
        }
        else if (success)
        {
            success();
        }

        // Reset oneTimeKeyCount to prevent start uploading based on old data.
        // It will be set again on the next /sync-response
        oneTimeKeyCount = -1;
    }
    else
    {
        // Ask the server how many keys we have
        NSLog(@"[MXCrypto] maybeUploadOneTimeKeys: Make a request to get available one-time keys on the homeserver");

        MXWeakify(self);
        uploadOneTimeKeysOperation = [_matrixRestClient uploadKeys:_myDevice.JSONDictionary oneTimeKeys:nil forDevice:_myDevice.deviceId success:^(MXKeysUploadResponse *keysUploadResponse) {
            MXStrongifyAndReturnIfNil(self);

            if (!self->uploadOneTimeKeysOperation)
            {
                if (success)
                {
                    success();
                }
                return;
            }

            // We first find how many keys the server has for us.
            NSUInteger keyCount = [keysUploadResponse oneTimeKeyCountsForAlgorithm:@"signed_curve25519"];

            NSLog(@"[MXCrypto] maybeUploadOneTimeKeys: %tu one-time keys on the homeserver", self->oneTimeKeyCount);

            if ([self generateOneTimeKeys:keyCount])
            {
                MXWeakify(self);
                MXHTTPOperation *operation2 = [self uploadOneTimeKeys:^(MXKeysUploadResponse *keysUploadResponse) {
                    MXStrongifyAndReturnIfNil(self);

                    self->uploadOneTimeKeysOperation = nil;
                    if (success)
                    {
                        success();
                    }

                } failure:^(NSError *error) {
                    MXStrongifyAndReturnIfNil(self);

                    NSLog(@"[MXCrypto] maybeUploadOneTimeKeys: Failed to publish one-time keys. Error: %@", error);
                    self->uploadOneTimeKeysOperation = nil;

                    if (failure)
                    {
                        failure(error);
                    }
                }];

                // Mutate MXHTTPOperation so that the user can cancel this new operation
                [self->uploadOneTimeKeysOperation mutateTo:operation2];                
            }
            else
            {
                self->uploadOneTimeKeysOperation = nil;
                if (success)
                {
                    success();
                }
            }

        } failure:^(NSError *error) {
            MXStrongifyAndReturnIfNil(self);

            NSLog(@"[MXCrypto] maybeUploadOneTimeKeys: Get published one-time keys count failed. Error: %@", error);
            self->uploadOneTimeKeysOperation = nil;

            if (failure)
            {
                failure(error);
            }
        }];
    }
}

/**
 Generate required one-time keys.

 @param keyCount the number of key currently available on the homeserver.
 @return NO if no keys need to be generated.
 */
- (BOOL)generateOneTimeKeys:(NSUInteger)keyCount
{
    // We need to keep a pool of one time public keys on the server so that
    // other devices can start conversations with us. But we can only store
    // a finite number of private keys in the olm Account object.
    // To complicate things further then can be a delay between a device
    // claiming a public one time key from the server and it sending us a
    // message. We need to keep the corresponding private key locally until
    // we receive the message.
    // But that message might never arrive leaving us stuck with duff
    // private keys clogging up our local storage.
    // So we need some kind of enginering compromise to balance all of
    // these factors.

    NSLog(@"[MXCrypto] generateOneTimeKeys: %tu one-time keys on the homeserver", keyCount);

    // First check how many keys we can store in the Account object.
    NSUInteger maxOneTimeKeys = _olmDevice.maxNumberOfOneTimeKeys;

    // Try to keep at most half that number on the server. This leaves the
    // rest of the slots free to hold keys that have been claimed from the
    // server but we haven't recevied a message for.
    // If we run out of slots when generating new keys then olm will
    // discard the oldest private keys first. This will eventually clean
    // out stale private keys that won't receive a message.
    NSUInteger keyLimit = maxOneTimeKeys / 2;

    // We work out how many new keys we need to create to top up the server
    // If there are too many keys on the server then we don't need to
    // create any more keys.
    NSUInteger numberToGenerate = 0;
    if (keyLimit > keyCount)
    {
        numberToGenerate = keyLimit - keyCount;
    }


    NSLog(@"[MXCrypto] generateOneTimeKeys: Generate %tu keys", numberToGenerate);

    if (numberToGenerate)
    {
        // Ask olm to generate new one time keys, then upload them to synapse.
        NSDate *startDate = [NSDate date];
        [_olmDevice generateOneTimeKeys:numberToGenerate];
        NSLog(@"[MXCrypto] generateOneTimeKeys: Keys generated in %.0fms", [[NSDate date] timeIntervalSinceDate:startDate] * 1000);
    }

    return (numberToGenerate > 0);
}

/**
 Upload my user's one time keys.
 */
- (MXHTTPOperation *)uploadOneTimeKeys:(void (^)(MXKeysUploadResponse *keysUploadResponse))success failure:(void (^)(NSError *))failure
{
    NSDictionary *oneTimeKeys = _olmDevice.oneTimeKeys;
    NSMutableDictionary *oneTimeJson = [NSMutableDictionary dictionary];

    for (NSString *keyId in oneTimeKeys[@"curve25519"])
    {
        // Sign each one-time key
        NSMutableDictionary *k = [NSMutableDictionary dictionary];
        k[@"key"] = oneTimeKeys[@"curve25519"][keyId];
        k[@"signatures"] = [self signObject:k];

        oneTimeJson[[NSString stringWithFormat:@"signed_curve25519:%@", keyId]] = k;
    }

    NSLog(@"[MXCrypto] uploadOneTimeKeys: Upload %tu keys", ((NSDictionary*)oneTimeKeys[@"curve25519"]).count);

    // For now, we set the device id explicitly, as we may not be using the
    // same one as used in login.
    MXWeakify(self);
    return [_matrixRestClient uploadKeys:nil oneTimeKeys:oneTimeJson forDevice:_myDevice.deviceId success:^(MXKeysUploadResponse *keysUploadResponse) {
        MXStrongifyAndReturnIfNil(self);

        self->lastPublishedOneTimeKeys = oneTimeKeys;
        [self.olmDevice markOneTimeKeysAsPublished];
        success(keysUploadResponse);

    } failure:^(NSError *error) {
        NSLog(@"[MXCrypto] uploadOneTimeKeys fails.");
        failure(error);
    }];
}

#endif

@end
