/*
 Copyright 2016 OpenMarket Ltd
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

#import <Foundation/Foundation.h>

#import "MXSDKOptions.h"

#ifdef MX_CRYPTO

#import "MXCryptoStore.h"
#import "MXSession.h"
#import "MXRestClient.h"
#import "MXOlmDevice.h"
#import "MXDeviceList.h"
#import "MXCryptoAlgorithms.h"
#import "MXUsersDevicesMap.h"
#import "MXOlmSessionResult.h"
#import "MXKeyBackup_Private.h"

#import "MXCrypto.h"

/**
 The `MXCrypto_Private` extension exposes internal operations.
 
 These methods run on a dedicated thread and must be called with the corresponding care.
 */
@interface MXCrypto ()

/**
 The store for crypto data.
 */
@property (nonatomic, readonly) id<MXCryptoStore> store;

/**
  The libolm wrapper.
 */
@property (nonatomic, readonly) MXOlmDevice *olmDevice;

/**
 The Matrix session.
 */
@property (nonatomic, readonly) MXSession *mxSession;

/**
  The instance used to make requests to the homeserver.
 */
@property (nonatomic, readonly) MXRestClient *matrixRestClient;

/**
 Our device keys
 */
@property (nonatomic, readonly) MXDeviceInfo *myDevice;

/**
 The queue used for almost all crypto processing.
 */
@property (nonatomic, readonly) dispatch_queue_t cryptoQueue;

/**
 The list of devices.
 */
@property (nonatomic, readonly) MXDeviceList *deviceList;

/**
 Get the device which sent an event.

 @param event the event to be checked.
 @return device info.
 */
- (MXDeviceInfo*)eventSenderDeviceOfEvent:(MXEvent*)event;

/**
 Configure a room to use encryption.

 @param roomId the room id to enable encryption in.
 @param members a list of user ids.
 @param algorithm the encryption config for the room.
 @param inhibitDeviceQuery YES to suppress device list query for users in the room (for now)
 @return YES if the operation succeeds.
 */
- (BOOL)setEncryptionInRoom:(NSString*)roomId withMembers:(NSArray<NSString*>*)members algorithm:(NSString*)algorithm inhibitDeviceQuery:(BOOL)inhibitDeviceQuery;

/**
 Try to make sure we have established olm sessions for the given users.

 @param users a list of user ids.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance. May be nil if the data is already in the store.
 */
- (MXHTTPOperation*)ensureOlmSessionsForUsers:(NSArray*)users
                                      success:(void (^)(MXUsersDevicesMap<MXOlmSessionResult*> *results))success
                                      failure:(void (^)(NSError *error))failure;

/**
 Try to make sure we have established olm sessions for the given devices.

 @param devicesByUser a map from userid to list of devices.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (MXHTTPOperation*)ensureOlmSessionsForDevices:(NSDictionary<NSString* /* userId */, NSArray<MXDeviceInfo*>*>*)devicesByUser
                                          force:(BOOL)force
                                      success:(void (^)(MXUsersDevicesMap<MXOlmSessionResult*> *results))success
                                      failure:(void (^)(NSError *error))failure;

/**
 Encrypt an event payload for a list of devices.

 @param payloadFields fields to include in the encrypted payload.
 @param devices the list of the recipient devices.

 @return the content for an m.room.encrypted event.
 */
- (NSDictionary*)encryptMessage:(NSDictionary*)payloadFields forDevices:(NSArray<MXDeviceInfo*>*)devices;

/**
 Get a decryptor for a given room and algorithm.

 If we already have a decryptor for the given room and algorithm, return
 it. Otherwise try to instantiate it.

 @param roomId room id for decryptor. If undefined, a temporary decryptor is instantiated.
 @param algorithm the crypto algorithm.
 @return the decryptor.
 */
- (id<MXDecrypting>)getRoomDecryptor:(NSString*)roomId algorithm:(NSString*)algorithm;

/**
 Get the encryptor for a given room and algorithm.
 
 @param roomId room id for encryptor.
 @param algorithm the crypto algorithm.
 @return the decryptor.
 */
- (id<MXEncrypting>)getRoomEncryptor:(NSString*)roomId algorithm:(NSString*)algorithm;

/**
 Sign the given object with our ed25519 key.

 @param object the dictionary to sign.
 @return signatures.
 */
- (NSDictionary*)signObject:(NSDictionary*)object;


#pragma mark - import/export

/**
 Import a list of megolm session keys.

 @param sessionDatas megolm sessions.
 @param backUp YES to back up them to the homeserver.
 @param success A block object called when the operation succeeds.
                It provides the number of found keys and the number of successfully imported keys.
 @param failure A block object called when the operation fails.
 */
- (void)importMegolmSessionDatas:(NSArray<MXMegolmSessionData*>*)sessionDatas
                          backUp:(BOOL)backUp
                         success:(void (^)(NSUInteger total, NSUInteger imported))success
                         failure:(void (^)(NSError *error))failure;


#pragma mark - Key sharing

/**
 Send a request for some room keys, if we have not already done so.

 @param requestBody the requestBody.
 @param recipients a {Array<{userId: string, deviceId: string}>}.
 */
- (void)requestRoomKey:(NSDictionary*)requestBody recipients:(NSArray<NSDictionary<NSString*, NSString*>*>*)recipients;

/**
 Cancel any earlier room key request.

 @param requestBody parameters to match for cancellation
 */
- (void)cancelRoomKeyRequest:(NSDictionary*)requestBody;

// Create a message to forward a megolm session
- (NSDictionary*)buildMegolmKeyForwardingMessage:(NSString*)roomId senderKey:(NSString*)senderKey sessionId:(NSString*)sessionId chainIndex:(NSNumber*)chainIndex;

@end

#endif
