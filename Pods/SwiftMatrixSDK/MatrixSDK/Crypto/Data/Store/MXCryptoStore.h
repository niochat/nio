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

#import "MXSDKOptions.h"

#ifdef MX_CRYPTO

#import "MXJSONModels.h"
#import "MXCredentials.h"

#import <OLMKit/OLMKit.h>
#import "MXOlmSession.h"
#import "MXOlmInboundGroupSession.h"
#import "MXDeviceInfo.h"
#import "MXCrossSigningInfo.h"
#import "MXOutgoingRoomKeyRequest.h"
#import "MXIncomingRoomKeyRequest.h"

/**
 The `MXCryptoStore` protocol defines an interface that must be implemented in order to store
 crypto data for a matrix account.
 */
@protocol MXCryptoStore <NSObject>

/**
 Indicate if the store contains data for the passed account.
 YES means that the user enabled the crypto in a previous sesison.
 */
+ (BOOL)hasDataForCredentials:(MXCredentials*)credentials;

/**
 Create a crypto store for the passed credentials.
 
 @param credentials the credentials of the account.
 @return the ready to use store.
 */
+ (instancetype)createStoreWithCredentials:(MXCredentials*)credentials;

/**
 Delete the crypto store for the passed credentials.

 @param credentials the credentials of the account.
 */
+ (void)deleteStoreWithCredentials:(MXCredentials*)credentials;

/**
 Create a crypto store for the passed credentials.

 @param credentials the credentials of the account.
 @return the store. Call the open method before using it.
 */
- (instancetype)initWithCredentials:(MXCredentials *)credentials;

/**
 Open the store corresponding to the passed account.

 The implementation can use a separated thread for loading data but the callback blocks
 must be called from the main thread.

 @param onComplete the callback called once the data has been loaded.
 @param failure the callback called in case of error.
 */
- (void)open:(void (^)(void))onComplete failure:(void (^)(NSError *error))failure;

/**
 Store the device id.
 */
- (void)storeDeviceId:(NSString*)deviceId;

/**
 The device id.
 */
- (NSString*)deviceId;

/**
 Store the end to end account for the logged-in user.
 */
- (void)storeAccount:(OLMAccount*)account;

/**
 * Load the end to end account for the logged-in user.
 */
- (OLMAccount*)account;

/**
 Store the sync token corresponding to the device list.

 This is used when starting the client, to get a list of the users who
 have changed their device list since the list time we were running.

 @param deviceSyncToken the token.
 */
- (void)storeDeviceSyncToken:(NSString*)deviceSyncToken;

/**
 Get the sync token corresponding to the device list.
 
 @return the token.
 */
- (NSString*)deviceSyncToken;

/**
 Store a device for a user.

 @param userId the user's id.
 @param device the device to store.
 */
- (void)storeDeviceForUser:(NSString*)userId device:(MXDeviceInfo*)device;

/**
 Retrieve a device for a user.

 @param deviceId the device id.
 @param userId the user's id.
 @return The device.
 */
- (MXDeviceInfo*)deviceWithDeviceId:(NSString*)deviceId forUser:(NSString*)userId;

/**
 Retrieve a device by its identity key.

 @param identityKey the device identity key (`MXDeviceInfo.identityKey`)/
 @return The device.
 */
- (MXDeviceInfo*)deviceWithIdentityKey:(NSString*)identityKey;

/**
 Store the known devices for a user.

 @param userId The user's id.
 @param devices A map from device id to 'MXDevice' object for the device.
 */
- (void)storeDevicesForUser:(NSString*)userId devices:(NSDictionary<NSString*, MXDeviceInfo*>*)devices;

/**
 Retrieve the known devices for a user.

 @param userId The user's id.
 @return A map from device id to 'MXDevice' object for the device or nil if we haven't
         managed to get a list of devices for this user yet.
 */
- (NSDictionary<NSString*, MXDeviceInfo*>*)devicesForUser:(NSString*)userId;

/**
 The device tracking status.

 @return A map from user id to MXDeviceTrackingStatus.
 */
- (NSDictionary<NSString*, NSNumber*>*)deviceTrackingStatus;

/**
 Store the device tracking status.

 @param statusMap A map from user id to MXDeviceTrackingStatus.
 */
- (void)storeDeviceTrackingStatus:(NSDictionary<NSString*, NSNumber*>*)statusMap;


#pragma mark - Cross-signing keys

/**
 Store cross signing keys for a user.

 @param crossSigningInfo The user's cross signing keys.
 */
- (void)storeCrossSigningKeys:(MXCrossSigningInfo*)crossSigningInfo;

/**
 Retrieve the cross signing keys for a user.

 @param userId The user's id.
 @return the cross signing keys.
 */
- (MXCrossSigningInfo*)crossSigningKeysForUser:(NSString*)userId;

/**
 Return all cross-signing keys we know about.
 
 @return all cross signing keys.
 */
- (NSArray<MXCrossSigningInfo*> *)crossSigningKeys;


#pragma mark - Message keys

/**
 Store the crypto algorithm for a room.

 @param roomId the id of the room.
 @algorithm the algorithm.
 */
- (void)storeAlgorithmForRoom:(NSString*)roomId algorithm:(NSString*)algorithm;

/**
 The crypto algorithm used in a room.
 nil if the room is not encrypted.
 */
- (NSString*)algorithmForRoom:(NSString*)roomId;

/**
 Store a session between the logged-in user and another device.

 @param deviceKey the public key of the other device.
 @param session the end-to-end session.
 */
- (void)storeSession:(MXOlmSession*)session forDevice:(NSString*)deviceKey;

/**
 Retrieve an end-to-end session between the logged-in user and another
 device.

 @param deviceKey the public key of the other device.
 @return a array of end-to-end sessions sorted by the last updated first.
 */
- (MXOlmSession*)sessionWithDevice:(NSString*)deviceKey andSessionId:(NSString*)sessionId;

/**
 Retrieve all end-to-end sessions between the logged-in user and another
 device sorted by `lastReceivedMessageTs`, the most recent(higest value) first.

 @param deviceKey the public key of the other device.
 @return a array of end-to-end sessions.
 */
- (NSArray<MXOlmSession*>*)sessionsWithDevice:(NSString*)deviceKey;


/**
 Store inbound group sessions.

 @param sessions inbound group sessions.
 */
- (void)storeInboundGroupSessions:(NSArray<MXOlmInboundGroupSession *>*)sessions;

/**
 Retrieve an inbound group session.

 @param sessionId the session identifier.
 @param senderKey the base64-encoded curve25519 key of the sender.
 @return an inbound group session.
 */
- (MXOlmInboundGroupSession*)inboundGroupSessionWithId:(NSString*)sessionId andSenderKey:(NSString*)senderKey;

/**
 Retrieve all inbound group sessions.
 
 @return the list of all inbound group sessions.
 */
- (NSArray<MXOlmInboundGroupSession*> *)inboundGroupSessions;


#pragma mark - Key backup

/**
 The backup version currently used.
 Nil means no backup.
 */
@property (nonatomic) NSString *backupVersion;

/**
 Mark all inbound group sessions as not backed up.
 */
- (void)resetBackupMarkers;

/**
 Mark inbound group sessions as backed up on the user homeserver.

 @param sessions inbound group sessions.
 */
- (void)markBackupDoneForInboundGroupSessions:(NSArray<MXOlmInboundGroupSession *>*)sessions;

/**
 Retrieve inbound group sessions that are not yet backed up.

 @param limit the maximum number of sessions to return.
 @return an array of non backed up inbound group sessions.
 */
- (NSArray<MXOlmInboundGroupSession*>*)inboundGroupSessionsToBackup:(NSUInteger)limit;

/**
 Number of stored inbound group sessions.

 @param onlyBackedUp if YES, count only session marked as backed up.
 @return a count.
 */
- (NSUInteger)inboundGroupSessionsCount:(BOOL)onlyBackedUp;


#pragma mark - Key sharing - Outgoing key requests

/**
 Look for existing outgoing room key request, and returns the result synchronously.

 @param requestBody the existing request to look for.
 @return a MXOutgoingRoomKeyRequest matching the request, or nil if not found.
 */
- (MXOutgoingRoomKeyRequest*)outgoingRoomKeyRequestWithRequestBody:(NSDictionary *)requestBody;

/**
 Look for the first outgoing key request that matches the state.

 @param state to look for.
 @return a MXOutgoingRoomKeyRequest matching the request, or nil if not found.
 */
- (MXOutgoingRoomKeyRequest*)outgoingRoomKeyRequestWithState:(MXRoomKeyRequestState)state;

/**
 Get all outgoing key requests that match the state.
 
 @param state to look for.
 @return a MXOutgoingRoomKeyRequest matching the request, or nil if not found.
 */
- (NSArray<MXOutgoingRoomKeyRequest*> *)allOutgoingRoomKeyRequestsWithState:(MXRoomKeyRequestState)state;

/**
 Store an outgoing room key request.

 @param request the room key request to store.
 */
- (void)storeOutgoingRoomKeyRequest:(MXOutgoingRoomKeyRequest*)request;

/**
 Update an outgoing room key request.

 @request the room key request to update in the store.
 */
- (void)updateOutgoingRoomKeyRequest:(MXOutgoingRoomKeyRequest*)request;

/**
 Delete an outgoing room key request.

 @param requestId the id of the request to delete.
 */
- (void)deleteOutgoingRoomKeyRequestWithRequestId:(NSString*)requestId;


#pragma mark - Key sharing - Incoming key requests

/**
 Store an incoming room key request.

 @param request the room key request to store.
 */
- (void)storeIncomingRoomKeyRequest:(MXIncomingRoomKeyRequest*)request;

/**
 Delete an incoming room key request.

 @param requestId the id of the request to delete.
 @param userId the user id.
 @param deviceId the user's device id.
 */
- (void)deleteIncomingRoomKeyRequest:(NSString*)requestId fromUser:(NSString*)userId andDevice:(NSString*)deviceId;

/**
 Get an incoming room key request.

 @param requestId the id of the request to retrieve.
 @param userId the user id.
 @param deviceId the user's device id.
 @return a MXIncomingRoomKeyRequest matching the request, or nil if not found.
 */
- (MXIncomingRoomKeyRequest*)incomingRoomKeyRequestWithRequestId:(NSString*)requestId fromUser:(NSString*)userId andDevice:(NSString*)deviceId;

/**
 Get all incoming room key requests.

 @return a map userId -> deviceId -> [MXIncomingRoomKeyRequest*].
 */
- (MXUsersDevicesMap<NSArray<MXIncomingRoomKeyRequest *> *> *)incomingRoomKeyRequests;


#pragma mark - Secret storage

/**
 Store a secret.
 
 @param secret the secret.
 @param secretId the id of the secret.
 */
- (void)storeSecret:(NSString*)secret withSecretId:(NSString*)secretId;

/**
 Retrieve a secret.
 
 @param secretId the id of the secret.
 @return the secret. Nil if the secret does not exist.
 */
- (NSString*)secretWithSecretId:(NSString*)secretId;


/**
 Delete a secret.
 
 @param secretId the id of the secret.
 */
- (void)deleteSecretWithSecretId:(NSString*)secretId;


#pragma mark - Crypto settings

/**
 The global override for whether the client should ever send encrypted
 messages to unverified devices.

 This settings is stored in the crypto store.

 If NO, it can still be overridden per-room.
 If YES, it overrides the per-room settings.

 Default is NO.
 */
@property (nonatomic) BOOL globalBlacklistUnverifiedDevices;

/**
 Tells whether the client should encrypt messages only for the verified devices
 in this room.

 Will be ignored if globalBlacklistUnverifiedDevices is YES.
 This settings is stored in the crypto store.

 The default value is NO.

 @param roomId the room id.
 @return YES if the client should encrypt messages only for the verified devices.
 */
- (BOOL)blacklistUnverifiedDevicesInRoom:(NSString *)roomId;

/**
 Set the blacklist of unverified devices in a room.

 @param roomId the room id.
 @param blacklist YES to encrypt messsages for only verified devices.
 */
- (void)storeBlacklistUnverifiedDevicesInRoom:(NSString *)roomId blacklist:(BOOL)blacklist;


#pragma mark - Methods for unitary tests purpose
/**
 Remove an inbound group session.

 @param sessionId the session identifier.
 @param senderKey the base64-encoded curve25519 key of the sender.
 */
- (void)removeInboundGroupSessionWithId:(NSString*)sessionId andSenderKey:(NSString*)senderKey;

@end

#endif
