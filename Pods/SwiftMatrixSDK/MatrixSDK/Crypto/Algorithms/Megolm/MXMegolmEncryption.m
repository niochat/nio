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

#import "MXSDKOptions.h"

#ifdef MX_CRYPTO

#import "MXMegolmEncryption.h"

#import "MXCryptoAlgorithms.h"
#import "MXCrypto_Private.h"
#import "MXQueuedEncryption.h"
#import "MXTools.h"

@interface MXOutboundSessionInfo : NSObject
{
    // When the session was created
    NSDate  *creationTime;
}

- (instancetype)initWithSessionID:(NSString*)sessionId;

/**
 Check if it's time to rotate the session.

 @param rotationPeriodMsgs the max number of encryptions before rotating.
 @param rotationPeriodMs the max duration of an encryption session before rotating.
 @return YES if rotation is needed.
 */
- (BOOL)needsRotation:(NSUInteger)rotationPeriodMsgs rotationPeriodMs:(NSUInteger)rotationPeriodMs;

/**
 Determine if this session has been shared with devices which it shouldn't
 have been.

 @param devicesInRoom userId -> {deviceId -> object} devices we should shared the session with.
 @return YES if we have shared the session with devices which aren't in devicesInRoom.
 */
- (BOOL)sharedWithTooManyDevices:(MXUsersDevicesMap<MXDeviceInfo *> *)devicesInRoom;

// The id of the session
@property (nonatomic, readonly) NSString *sessionId;

// Number of times this session has been used
@property (nonatomic) NSUInteger useCount;

// If a share operation is in progress, the corresping http request
@property (nonatomic) MXHTTPOperation* shareOperation;

// Devices with which we have shared the session key
// userId -> {deviceId -> msgindex}
@property (nonatomic) MXUsersDevicesMap<NSNumber*> *sharedWithDevices;

@end


@interface MXMegolmEncryption ()
{
    MXCrypto *crypto;

    // The id of the room we will be sending to.
    NSString *roomId;

    NSString *deviceId;

    // OutboundSessionInfo. Null if we haven't yet started setting one up. Note
    // that even if this is non-null, it may not be ready for use (in which
    // case outboundSession.shareOperation will be non-nill.)
    MXOutboundSessionInfo *outboundSession;
    
    // Map of outbound sessions by sessions ID. Used if we need a particular
    // session.
    NSMutableDictionary<NSString*, MXOutboundSessionInfo*> *outboundSessions;

    NSMutableArray<MXQueuedEncryption*> *pendingEncryptions;

    // Session rotation periods
    NSUInteger sessionRotationPeriodMsgs;
    NSUInteger sessionRotationPeriodMs;
}

@end


@implementation MXMegolmEncryption

+ (void)load
{
    // Register this class as the encryptor for olm
    [[MXCryptoAlgorithms sharedAlgorithms] registerEncryptorClass:MXMegolmEncryption.class forAlgorithm:kMXCryptoMegolmAlgorithm];
}


#pragma mark - MXEncrypting
- (instancetype)initWithCrypto:(MXCrypto *)theCrypto andRoom:(NSString *)theRoomId
{
    self = [super init];
    if (self)
    {
        crypto = theCrypto;
        roomId = theRoomId;
        deviceId = crypto.store.deviceId;

        outboundSessions = [NSMutableDictionary dictionary];
        pendingEncryptions = [NSMutableArray array];

        // Default rotation periods
        // TODO: Make it configurable via parameters
        sessionRotationPeriodMsgs = 100;
        sessionRotationPeriodMs = 7 * 24 * 3600 * 1000;
    }
    return self;
}

- (MXHTTPOperation*)encryptEventContent:(NSDictionary*)eventContent eventType:(MXEventTypeString)eventType
                               forUsers:(NSArray<NSString*>*)users
                                success:(void (^)(NSDictionary *encryptedContent))success
                                failure:(void (^)(NSError *error))failure
{
    // Queue the encryption request
    // It will be processed when everything is set up
    MXQueuedEncryption *queuedEncryption = [[MXQueuedEncryption alloc] init];
    queuedEncryption.eventContent = eventContent;
    queuedEncryption.eventType = eventType;
    queuedEncryption.success = success;
    queuedEncryption.failure = failure;
    [pendingEncryptions addObject:queuedEncryption];

    return [self ensureSessionForUsers:users success:^(NSObject *sessionInfo) {

        MXOutboundSessionInfo *session = (MXOutboundSessionInfo*)sessionInfo;
        [self processPendingEncryptionsInSession:session withError:nil];

    } failure:^(NSError *error) {
        [self processPendingEncryptionsInSession:nil withError:error];
    }];
}

- (MXHTTPOperation*)ensureSessionForUsers:(NSArray<NSString*>*)users
                                  success:(void (^)(NSObject *sessionInfo))success
                                  failure:(void (^)(NSError *error))failure
{
    NSDate *startDate = [NSDate date];

    MXHTTPOperation *operation;
    operation = [self getDevicesInRoom:users success:^(MXUsersDevicesMap<MXDeviceInfo *> *devicesInRoom) {

        MXHTTPOperation *operation2 = [self ensureOutboundSession:devicesInRoom success:^(MXOutboundSessionInfo *session) {

            NSLog(@"[MXMegolmEncryption] ensureSessionForUsers took %.0fms", [[NSDate date] timeIntervalSinceDate:startDate] * 1000);

            if (success)
            {
                success(session);
            }

        } failure:failure];
        
        [operation mutateTo:operation2];

    } failure:failure];

    return operation;
}


#pragma mark - Private methods

/*
 Get the list of devices which can encrypt data to.

 @param users the users whose devices must be checked.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
*/
- (MXHTTPOperation *)getDevicesInRoom:(NSArray<NSString*>*)users
                              success:(void (^)(MXUsersDevicesMap<MXDeviceInfo *> *devicesInRoom))success
                              failure:(void (^)(NSError *))failure
{
    // We are happy to use a cached version here: we assume that if we already
    // have a list of the user's devices, then we already share an e2e room
    // with them, which means that they will have announced any new devices via
    // an m.new_device.
    MXWeakify(self);
    return [crypto.deviceList downloadKeys:users forceDownload:NO success:^(MXUsersDevicesMap<MXDeviceInfo *> *devices, NSDictionary<NSString *,MXCrossSigningInfo *> *crossSigningKeysMap) {
        MXStrongifyAndReturnIfNil(self);

        BOOL encryptToVerifiedDevicesOnly = self->crypto.globalBlacklistUnverifiedDevices
        || [self->crypto isBlacklistUnverifiedDevicesInRoom:self->roomId];

        MXUsersDevicesMap<MXDeviceInfo*> *devicesInRoom = [[MXUsersDevicesMap alloc] init];
        MXUsersDevicesMap<MXDeviceInfo*> *unknownDevices = [[MXUsersDevicesMap alloc] init];

        for (NSString *userId in devices.userIds)
        {
            for (NSString *deviceID in [devices deviceIdsForUser:userId])
            {
                MXDeviceInfo *deviceInfo = [devices objectForDevice:deviceID forUser:userId];

                if (!deviceInfo.trustLevel.isVerified
                    && self->crypto.warnOnUnknowDevices && deviceInfo.trustLevel.localVerificationStatus == MXDeviceUnknown)
                {
                    // The device is not yet known by the user
                    [unknownDevices setObject:deviceInfo forUser:userId andDevice:deviceID];
                    continue;
                }

                if (deviceInfo.trustLevel.localVerificationStatus == MXDeviceBlocked
                    || (!deviceInfo.trustLevel.isVerified && encryptToVerifiedDevicesOnly))
                {
                    // Remove any blocked devices
                    NSLog(@"[MXMegolmEncryption] getDevicesInRoom: blocked device: %@", deviceInfo);
                    continue;
                }

                if ([deviceInfo.identityKey isEqualToString:self->crypto.olmDevice.deviceCurve25519Key])
                {
                    // Don't bother sending to ourself
                    continue;
                }

                [devicesInRoom setObject:deviceInfo forUser:userId andDevice:deviceID];
            }
        }

        // Check if any of these devices are not yet known to the user.
        // if so, warn the user so they can verify or ignore.
        if (!unknownDevices.count)
        {
            success(devicesInRoom);
        }
        else
        {
            NSError *error = [NSError errorWithDomain:MXEncryptingErrorDomain
                                                 code:MXEncryptingErrorUnknownDeviceCode
                                             userInfo:@{
                                                        NSLocalizedDescriptionKey: MXEncryptingErrorUnknownDeviceReason,
                                                        @"MXEncryptingErrorUnknownDeviceDevicesKey": unknownDevices
                                                        }];
            
            failure(error);
        }

    } failure: failure];

}

/**
 Ensure that we have an outbound session ready for the devices in the room.

 @param devicesInRoom the devices in the room.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (MXHTTPOperation *)ensureOutboundSession:(MXUsersDevicesMap<MXDeviceInfo *> *)devicesInRoom
                                   success:(void (^)(MXOutboundSessionInfo *session))success
                                   failure:(void (^)(NSError *))failure
{
    MXOutboundSessionInfo *session = outboundSession;

    // Need to make a brand new session?
    if (session && [session needsRotation:sessionRotationPeriodMsgs rotationPeriodMs:sessionRotationPeriodMs])
    {
        session = nil;
    }

    // Determine if we have shared with anyone we shouldn't have
    if (session && [session sharedWithTooManyDevices:devicesInRoom])
    {
        session = nil;
    }

    if (!session)
    {
        outboundSession = session = [self prepareNewSession];
        outboundSessions[outboundSession.sessionId] = outboundSession;
    }

    if (session.shareOperation)
    {
        // Prep already in progress
        return session.shareOperation;
    }

    // No share in progress: Share the current setup

    NSMutableDictionary<NSString* /* userId */, NSMutableArray<MXDeviceInfo*>*> *shareMap = [NSMutableDictionary dictionary];

    for (NSString *userId in devicesInRoom.userIds)
    {
        for (NSString *deviceID in [devicesInRoom deviceIdsForUser:userId])
        {
            MXDeviceInfo *deviceInfo = [devicesInRoom objectForDevice:deviceID forUser:userId];

            if (![session.sharedWithDevices objectForDevice:deviceID forUser:userId])
            {
                if (!shareMap[userId])
                {
                    shareMap[userId] = [NSMutableArray array];
                }
                [shareMap[userId] addObject:deviceInfo];
            }
        }
    }

    session.shareOperation = [self shareKey:session withDevices:shareMap success:^{

        session.shareOperation = nil;
        success(session);

    } failure:^(NSError *error) {

        session.shareOperation = nil;
        failure(error);
    }];

    return session.shareOperation;
}

- (MXOutboundSessionInfo*)prepareNewSession
{
    NSString *sessionId = [crypto.olmDevice createOutboundGroupSession];

    [crypto.olmDevice addInboundGroupSession:sessionId
                                  sessionKey:[crypto.olmDevice sessionKeyForOutboundGroupSession:sessionId]
                                      roomId:roomId
                                   senderKey:crypto.olmDevice.deviceCurve25519Key
                forwardingCurve25519KeyChain:@[]
                                 keysClaimed:@{
                                               @"ed25519": crypto.olmDevice.deviceEd25519Key
                                               }
                                exportFormat:NO
     ];

    [crypto.backup maybeSendKeyBackup];

    return [[MXOutboundSessionInfo alloc] initWithSessionID:sessionId];
}

- (MXHTTPOperation*)shareKey:(MXOutboundSessionInfo*)session
                 withDevices:(NSDictionary<NSString* /* userId */, NSArray<MXDeviceInfo*>*>*)devicesByUser
                        success:(void (^)(void))success
                        failure:(void (^)(NSError *))failure

{
    NSString *sessionKey = [crypto.olmDevice sessionKeyForOutboundGroupSession:session.sessionId];
    NSUInteger chainIndex = [crypto.olmDevice messageIndexForOutboundGroupSession:session.sessionId];

    NSDictionary *payload = @{
                              @"type": kMXEventTypeStringRoomKey,
                              @"content": @{
                                      @"algorithm": kMXCryptoMegolmAlgorithm,
                                      @"room_id": roomId,
                                      @"session_id": session.sessionId,
                                      @"session_key": sessionKey,
                                      @"chain_index": @(chainIndex)
                                      }
                              };

    NSLog(@"[MXMegolmEncryption] shareKey: with %tu users: %@", devicesByUser.count, devicesByUser);

    MXHTTPOperation *operation;
    MXWeakify(self);
    operation = [crypto ensureOlmSessionsForDevices:devicesByUser force:NO success:^(MXUsersDevicesMap<MXOlmSessionResult *> *results) {
        MXStrongifyAndReturnIfNil(self);

        NSLog(@"[MXMegolmEncryption] shareKey: ensureOlmSessionsForDevices result (users: %tu - devices: %tu): %@", results.map.count,  results.count, results);

        MXUsersDevicesMap<NSDictionary*> *contentMap = [[MXUsersDevicesMap alloc] init];
        BOOL haveTargets = NO;

        for (NSString *userId in devicesByUser.allKeys)
        {
            NSArray<MXDeviceInfo*> *devicesToShareWith = devicesByUser[userId];

            for (MXDeviceInfo *deviceInfo in devicesToShareWith)
            {
                NSString *deviceID = deviceInfo.deviceId;

                MXOlmSessionResult *sessionResult = [results objectForDevice:deviceID forUser:userId];
                if (!sessionResult.sessionId)
                {
                    // no session with this device, probably because there
                    // were no one-time keys.
                    //
                    // we could send them a to_device message anyway, as a
                    // signal that they have missed out on the key sharing
                    // message because of the lack of keys, but there's not
                    // much point in that really; it will mostly serve to clog
                    // up to_device inboxes.
                    //
                    // ensureOlmSessionsForUsers has already done the logging,
                    // so just skip it.
                    continue;
                }

                NSLog(@"[MXMegolmEncryption] shareKey: Sharing keys with device %@:%@", userId, deviceID);

                MXDeviceInfo *deviceInfo = sessionResult.device;

                [contentMap setObject:[self->crypto encryptMessage:payload forDevices:@[deviceInfo]]
                              forUser:userId andDevice:deviceID];

                haveTargets = YES;
            }
        }

        if (haveTargets)
        {
            //NSLog(@"[MXMegolmEncryption] shareKey. Actually share with %tu users and %tu devices: %@", contentMap.userIds.count, contentMap.count, contentMap);
            NSLog(@"[MXMegolmEncryption] shareKey: Actually share with %tu users and %tu devices", contentMap.userIds.count, contentMap.count);

            MXHTTPOperation *operation2 = [self->crypto.matrixRestClient sendToDevice:kMXEventTypeStringRoomEncrypted contentMap:contentMap txnId:nil success:^{

                NSLog(@"[MXMegolmEncryption] shareKey: request succeeded");

                // Add the devices we have shared with to session.sharedWithDevices.
                //
                // we deliberately iterate over devicesByUser (ie, the devices we
                // attempted to share with) rather than the contentMap (those we did
                // share with), because we don't want to try to claim a one-time-key
                // for dead devices on every message.
                for (NSString *userId in devicesByUser)
                {
                    NSArray *devicesToShareWith = devicesByUser[userId];
                    for (MXDeviceInfo *deviceInfo in devicesToShareWith)
                    {
                        [session.sharedWithDevices setObject:@(chainIndex) forUser:userId andDevice:deviceInfo.deviceId];
                    }
                }

                success();

            } failure:failure];
            [operation mutateTo:operation2];
        }
        else
        {
            success();
        }

    } failure:^(NSError *error) {

        NSLog(@"[MXMegolmEncryption] shareKey: request failed. Error: %@", error);
        if (failure)
        {
            failure(error);
        }
    }];

    return operation;
}

- (MXHTTPOperation*)reshareKey:(NSString*)sessionId
                      withUser:(NSString*)userId
                     andDevice:(NSString*)deviceId
                     senderKey:(NSString*)senderKey
                       success:(void (^)(void))success
                       failure:(void (^)(NSError *error))failure
{
    NSLog(@"[MXMegolmEncryption] reshareKey: %@ to %@:%@", sessionId, userId, deviceId);
    
    MXDeviceInfo *deviceInfo = [crypto.store deviceWithDeviceId:deviceId forUser:userId];
    if (!deviceInfo)
    {
        NSLog(@"[MXMegolmEncryption] reshareKey: ERROR: Unknown device");
        failure(nil);
        return nil;
    }
    
    // Get the chain index of the key we previously sent this device
    MXOutboundSessionInfo *obSessionInfo = outboundSessions[sessionId];
    NSNumber *chainIndex = [obSessionInfo.sharedWithDevices objectForDevice:deviceId forUser:userId];
    if (!chainIndex)
    {
        NSLog(@"[MXMegolmEncryption] reshareKey: ERROR: Never share megolm with this device");
        failure(nil);
        return nil;
    }

    MXHTTPOperation *operation;
    MXWeakify(self);
    operation = [crypto ensureOlmSessionsForDevices:@{
                                                      userId: @[deviceInfo]
                                                      }
                                              force:NO
                                            success:^(MXUsersDevicesMap<MXOlmSessionResult *> *results)
                 {
                     MXStrongifyAndReturnIfNil(self);
                     
                     MXOlmSessionResult *olmSessionResult = [results objectForDevice:deviceId forUser:userId];
                     if (!olmSessionResult.sessionId)
                     {
                         // no session with this device, probably because there
                         // were no one-time keys.
                         //
                         // ensureOlmSessionsForUsers has already done the logging,
                         // so just skip it.
                         if (success)
                         {
                             success();
                         }
                         return;
                     }
                     
                     MXDeviceInfo *deviceInfo = olmSessionResult.device;
                     
                     NSLog(@"[MXMegolmEncryption] reshareKey: sharing keys for session %@|%@:%@ with device %@:%@", senderKey, sessionId, chainIndex, userId, deviceId);
                     
                     NSDictionary *payload = [self->crypto buildMegolmKeyForwardingMessage:self->roomId senderKey:senderKey sessionId:sessionId chainIndex:chainIndex];
                    
                     
                     MXUsersDevicesMap<NSDictionary*> *contentMap = [[MXUsersDevicesMap alloc] init];
                     [contentMap setObject:[self->crypto encryptMessage:payload forDevices:@[deviceInfo]]
                                   forUser:userId andDevice:deviceId];
                     
                     MXHTTPOperation *operation2 = [self->crypto.matrixRestClient sendToDevice:kMXEventTypeStringRoomEncrypted contentMap:contentMap txnId:nil success:success failure:failure];
                     [operation mutateTo:operation2];
                     
                 } failure:failure];
    
    return operation;
}

- (void)processPendingEncryptionsInSession:(MXOutboundSessionInfo*)session withError:(NSError*)error
{
    if (session)
    {
        // Everything is in place, encrypt all pending events
        for (MXQueuedEncryption *queuedEncryption in pendingEncryptions)
        {
            NSDictionary *payloadJson = @{
                                          @"room_id": roomId,
                                          @"type": queuedEncryption.eventType,
                                          @"content": queuedEncryption.eventContent
                                          };

            NSData *payloadData = [NSJSONSerialization  dataWithJSONObject:payloadJson options:0 error:nil];
            NSString *payloadString = [[NSString alloc] initWithData:payloadData encoding:NSUTF8StringEncoding];

            NSString *ciphertext = [crypto.olmDevice encryptGroupMessage:session.sessionId payloadString:payloadString];

            queuedEncryption.success(@{
                      @"algorithm": kMXCryptoMegolmAlgorithm,
                      @"sender_key": crypto.olmDevice.deviceCurve25519Key,
                      @"ciphertext": ciphertext,
                      @"session_id": session.sessionId,

                      // Include our device ID so that recipients can send us a
                      // m.new_device message if they don't have our session key.
                      @"device_id": deviceId
                      });

            session.useCount++;
        }
    }
    else
    {
        for (MXQueuedEncryption *queuedEncryption in pendingEncryptions)
        {
            queuedEncryption.failure(error);
        }
    }

    [pendingEncryptions removeAllObjects];
}

@end


#pragma mark - MXOutboundSessionInfo

@implementation MXOutboundSessionInfo

- (instancetype)initWithSessionID:(NSString *)sessionId
{
    self = [super init];
    if (self)
    {
        _sessionId = sessionId;
        _sharedWithDevices = [[MXUsersDevicesMap alloc] init];
        creationTime = [NSDate date];
    }
    return self;
}

- (BOOL)needsRotation:(NSUInteger)rotationPeriodMsgs rotationPeriodMs:(NSUInteger)rotationPeriodMs
{
    BOOL needsRotation = NO;
    NSUInteger sessionLifetime = [[NSDate date] timeIntervalSinceDate:creationTime] * 1000;

    if (_useCount >= rotationPeriodMsgs || sessionLifetime >= rotationPeriodMs)
    {
        NSLog(@"[MXMegolmEncryption] Rotating megolm session after %tu messages, %tu ms", _useCount, sessionLifetime);
        needsRotation = YES;
    }

    return needsRotation;
}

- (BOOL)sharedWithTooManyDevices:(MXUsersDevicesMap<MXDeviceInfo *> *)devicesInRoom
{
    for (NSString *userId in _sharedWithDevices.userIds)
    {
        if (![devicesInRoom deviceIdsForUser:userId])
        {
            NSLog(@"[MXMegolmEncryption] Starting new session because we shared with %@",  userId);
            return YES;
        }

        for (NSString *deviceId in [_sharedWithDevices deviceIdsForUser:userId])
        {
            if (! [devicesInRoom objectForDevice:deviceId forUser:userId])
            {
                NSLog(@"[MXMegolmEncryption] Starting new session because we shared with %@:%@", userId, deviceId);
                return YES;
            }
        }
    }

    return NO;
}

@end

#endif
