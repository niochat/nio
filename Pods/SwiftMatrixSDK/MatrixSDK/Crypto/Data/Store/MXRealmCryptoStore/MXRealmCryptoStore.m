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

#import "MXRealmCryptoStore.h"

#ifdef MX_CRYPTO

#import <Realm/Realm.h>
#import "MXSession.h"
#import "MXTools.h"
#import "MXCryptoTools.h"

NSUInteger const kMXRealmCryptoStoreVersion = 12;

static NSString *const kMXRealmCryptoStoreFolder = @"MXRealmCryptoStore";


#pragma mark - Realm objects that encapsulate existing ones

@interface MXRealmDeviceInfo : RLMObject
@property NSData *deviceInfoData;
@property (nonatomic) NSString *deviceId;
@property (nonatomic) NSString *identityKey;
@end

@implementation MXRealmDeviceInfo
@end
RLM_ARRAY_TYPE(MXRealmDeviceInfo)

@interface MXRealmCrossSigningInfo : RLMObject
@property NSData *data;
@end

@implementation MXRealmCrossSigningInfo
@end
RLM_ARRAY_TYPE(MXRealmCrossSigningInfo)


@interface MXRealmUser : RLMObject
@property (nonatomic) NSString *userId;
@property RLMArray<MXRealmDeviceInfo *><MXRealmDeviceInfo> *devices;
@property MXRealmCrossSigningInfo *crossSigningKeys;
@end

@implementation MXRealmUser
+ (NSString *)primaryKey
{
    return @"userId";
}
@end
RLM_ARRAY_TYPE(MXRealmUser)


@interface MXRealmRoomAlgorithm : RLMObject
@property NSString *roomId;
@property NSString *algorithm;
@property BOOL blacklistUnverifiedDevices;
@end

@implementation MXRealmRoomAlgorithm

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _blacklistUnverifiedDevices = NO;
    }
    return self;
}

+ (NSString *)primaryKey
{
    return @"roomId";
}
@end
RLM_ARRAY_TYPE(MXRealmRoomAlgorithm)


@interface MXRealmOlmSession : RLMObject
@property NSString *sessionId;
@property NSString *deviceKey;
@property NSTimeInterval lastReceivedMessageTs;
@property NSData *olmSessionData;
@end

@implementation MXRealmOlmSession
@end
RLM_ARRAY_TYPE(MXRealmOlmSession)


@interface MXRealmOlmInboundGroupSession : RLMObject
@property NSString *sessionId;
@property NSString *senderKey;
@property NSData *olmInboundGroupSessionData;

// A primary key is required to update `backedUp`.
// Do our combined primary key ourselves as it is not supported by Realm.
@property NSString *sessionIdSenderKey;

// Indicate if the key has been backed up to the homeserver
@property BOOL backedUp;
@end

@implementation MXRealmOlmInboundGroupSession
+ (NSString *)primaryKey
{
    return @"sessionIdSenderKey";
}

+ (NSString *)primaryKeyWithSessionId:(NSString*)sessionId senderKey:(NSString*)senderKey
{
    return [NSString stringWithFormat:@"%@|%@", sessionId, senderKey];
}
@end
RLM_ARRAY_TYPE(MXRealmOlmInboundGroupSession)


@interface MXRealmOlmAccount : RLMObject

/**
 The user id.
 */
@property (nonatomic) NSString *userId;

/**
 The device id.
 */
@property (nonatomic) NSString *deviceId;

/**
 The pickled OLMAccount object.
 */
@property NSData *olmAccountData;

/**
 The sync token corresponding to the device list.
 */
@property (nonatomic) NSString *deviceSyncToken;

/**
 NSData serialisation of users we are tracking device status for.
 userId -> MXDeviceTrackingStatus*
 */
@property (nonatomic)  NSData *deviceTrackingStatusData;

/**
 Settings for blacklisting unverified devices.
 */
@property (nonatomic) BOOL globalBlacklistUnverifiedDevices;

/**
 The backup version currently used.
 */
@property (nonatomic) NSString *backupVersion;

@end

@implementation MXRealmOlmAccount

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _globalBlacklistUnverifiedDevices = NO;
    }
    return self;
}

+ (NSString *)primaryKey
{
    return @"userId";
}
@end

@interface MXRealmOutgoingRoomKeyRequest : RLMObject
@property (nonatomic) NSString *requestId;
@property (nonatomic) NSString *cancellationTxnId;
@property (nonatomic) NSData *recipientsData;
@property (nonatomic) NSString *requestBodyString;
@property (nonatomic) NSString *requestBodyHash;
@property (nonatomic) NSNumber<RLMInt> *state;

- (MXOutgoingRoomKeyRequest *)outgoingRoomKeyRequest;

@end

@implementation MXRealmOutgoingRoomKeyRequest
+ (NSString *)primaryKey
{
    return @"requestId";
}

- (MXOutgoingRoomKeyRequest *)outgoingRoomKeyRequest
{
    MXOutgoingRoomKeyRequest *outgoingRoomKeyRequest = [[MXOutgoingRoomKeyRequest alloc] init];

    outgoingRoomKeyRequest.requestId = self.requestId;
    outgoingRoomKeyRequest.cancellationTxnId = self.cancellationTxnId;
    outgoingRoomKeyRequest.state = (MXRoomKeyRequestState)[self.state unsignedIntegerValue];
    outgoingRoomKeyRequest.recipients = [NSKeyedUnarchiver unarchiveObjectWithData:self.recipientsData];
    outgoingRoomKeyRequest.requestBody = [MXTools deserialiseJSONString:self.requestBodyString];

    return outgoingRoomKeyRequest;
}

@end

@interface MXRealmIncomingRoomKeyRequest : RLMObject
@property (nonatomic) NSString *requestId;
@property (nonatomic) NSString *userId;
@property (nonatomic) NSString *deviceId;
@property (nonatomic) NSData *requestBodyData;

- (MXIncomingRoomKeyRequest *)incomingRoomKeyRequest;

@end

@implementation MXRealmIncomingRoomKeyRequest

- (MXIncomingRoomKeyRequest *)incomingRoomKeyRequest
{
    MXIncomingRoomKeyRequest *incomingRoomKeyRequest = [[MXIncomingRoomKeyRequest alloc] init];

    incomingRoomKeyRequest.requestId = self.requestId;
    incomingRoomKeyRequest.userId = self.userId;
    incomingRoomKeyRequest.deviceId = self.deviceId;
    incomingRoomKeyRequest.requestBody = [NSKeyedUnarchiver unarchiveObjectWithData:self.requestBodyData];

    return incomingRoomKeyRequest;
}

@end


@interface MXRealmSecret : RLMObject
@property NSString *secretId;
@property NSString *secret;
@end

@implementation MXRealmSecret

+ (NSString *)primaryKey
{
    return @"secretId";
}
@end
RLM_ARRAY_TYPE(MXRealmSecret)


#pragma mark - MXRealmCryptoStore

@interface MXRealmCryptoStore ()
{
    NSString *userId;
    NSString *deviceId;
}

/**
 The realm on the current thread.

 As MXCryptoStore methods can be called from different threads, we need to load realm objects
 from the root. This is how Realm works in multi-threading environment.
 */
@property (readonly) RLMRealm *realm;

/**
 The MXRealmOlmAccount on the current thread.
 */
@property (readonly) MXRealmOlmAccount *accountInCurrentThread;

@end

@implementation MXRealmCryptoStore

+ (BOOL)hasDataForCredentials:(MXCredentials*)credentials
{
    RLMRealm *realm = [MXRealmCryptoStore realmForUser:credentials.userId andDevice:credentials.deviceId];
    return (nil != [MXRealmOlmAccount objectsInRealm:realm where:@"userId = %@", credentials.userId].firstObject);
}

+ (instancetype)createStoreWithCredentials:(MXCredentials*)credentials
{
    NSLog(@"[MXRealmCryptoStore] createStore for %@:%@", credentials.userId, credentials.deviceId);

    RLMRealm *realm = [MXRealmCryptoStore realmForUser:credentials.userId andDevice:credentials.deviceId];

    MXRealmOlmAccount *account = [[MXRealmOlmAccount alloc] initWithValue:@{
                                                                          @"userId" : credentials.userId,
                                                                          }];
    account.deviceId = credentials.deviceId;

    [realm beginWriteTransaction];
    [realm addObject:account];
    [realm commitWriteTransaction];

    return [[MXRealmCryptoStore alloc] initWithCredentials:credentials];
}

+ (void)deleteStoreWithCredentials:(MXCredentials*)credentials
{
    NSLog(@"[MXRealmCryptoStore] deleteStore for %@:%@", credentials.userId, credentials.deviceId);

    RLMRealm *realm = [MXRealmCryptoStore realmForUser:credentials.userId andDevice:credentials.deviceId];

    [realm transactionWithBlock:^{
        [realm deleteAllObjects];
    }];
}

- (instancetype)initWithCredentials:(MXCredentials *)credentials
{
    NSLog(@"[MXRealmCryptoStore] initWithCredentials for %@:%@", credentials.userId, credentials.deviceId);

    self = [super init];
    if (self)
    {
        userId = credentials.userId;
        deviceId = credentials.deviceId;

        MXRealmOlmAccount *account = self.accountInCurrentThread;
        if (!account)
        {
            return nil;
        }
        else
        {
            // Make sure the device id corresponds
            if (account.deviceId && ![account.deviceId isEqualToString:credentials.deviceId])
            {
                NSLog(@"[MXRealmCryptoStore] Credentials do not match");
                [MXRealmCryptoStore deleteStoreWithCredentials:credentials];
                return [MXRealmCryptoStore createStoreWithCredentials:credentials];
            }
        }

        NSLog(@"[MXRealmCryptoStore] Schema version: %llu", account.realm.configuration.schemaVersion);
    }
    return self;
}

- (RLMRealm *)realm
{
    return [MXRealmCryptoStore realmForUser:userId andDevice:deviceId];
}

- (MXRealmOlmAccount*)accountInCurrentThread
{
    return [MXRealmOlmAccount objectsInRealm:self.realm where:@"userId = %@", userId].firstObject;
}

- (void)open:(void (^)(void))onComplete failure:(void (^)(NSError *error))failure
{
    onComplete();
}

- (void)storeDeviceId:(NSString*)deviceId
{
    MXRealmOlmAccount *account = self.accountInCurrentThread;

    [account.realm transactionWithBlock:^{
        account.deviceId = deviceId;
    }];
}

- (NSString*)deviceId
{
    MXRealmOlmAccount *account = self.accountInCurrentThread;

    return account.deviceId;
}

- (void)storeAccount:(OLMAccount*)olmAccount
{
    NSDate *startDate = [NSDate date];

    MXRealmOlmAccount *account = self.accountInCurrentThread;

    [account.realm transactionWithBlock:^{
        account.olmAccountData = [NSKeyedArchiver archivedDataWithRootObject:olmAccount];
    }];

    NSLog(@"[MXRealmCryptoStore] storeAccount in %.0fms", [[NSDate date] timeIntervalSinceDate:startDate] * 1000);
}

- (OLMAccount*)account
{
    MXRealmOlmAccount *account = self.accountInCurrentThread;
    if (account.olmAccountData)
    {
        return [NSKeyedUnarchiver unarchiveObjectWithData:account.olmAccountData];
    }
    return nil;
}

- (void)storeDeviceSyncToken:(NSString*)deviceSyncToken
{
    MXRealmOlmAccount *account = self.accountInCurrentThread;
    [account.realm transactionWithBlock:^{
        account.deviceSyncToken = deviceSyncToken;
    }];
}

- (NSString*)deviceSyncToken
{
    MXRealmOlmAccount *account = self.accountInCurrentThread;
    return account.deviceSyncToken;
}

- (void)storeDeviceForUser:(NSString*)userID device:(MXDeviceInfo*)device
{
    NSDate *startDate = [NSDate date];

    RLMRealm *realm = self.realm;

    [realm transactionWithBlock:^{

        MXRealmUser *realmUser = [MXRealmUser objectsInRealm:realm where:@"userId = %@", userID].firstObject;
        if (!realmUser)
        {
            realmUser = [[MXRealmUser alloc] initWithValue:@{
                                                            @"userId": userID,
                                                            }];

            [realm addObject:realmUser];
        }

        MXRealmDeviceInfo *realmDevice = [[realmUser.devices objectsWhere:@"deviceId = %@", device.deviceId] firstObject];
        if (!realmDevice)
        {
            realmDevice = [[MXRealmDeviceInfo alloc] initWithValue:@{
                                                                    @"deviceId": device.deviceId,
                                                                    @"deviceInfoData": [NSKeyedArchiver archivedDataWithRootObject:device]
                                                                    }];
            realmDevice.identityKey = device.identityKey;
            [realmUser.devices addObject:realmDevice];
        }
        else
        {
            realmDevice.deviceInfoData = [NSKeyedArchiver archivedDataWithRootObject:device];
        }

    }];

    NSLog(@"[MXRealmCryptoStore] storeDeviceForUser in %.0fms", [[NSDate date] timeIntervalSinceDate:startDate] * 1000);
}

- (MXDeviceInfo*)deviceWithDeviceId:(NSString*)deviceId forUser:(NSString*)userID
{
    MXRealmUser *realmUser = [MXRealmUser objectsInRealm:self.realm where:@"userId = %@", userID].firstObject;

    MXRealmDeviceInfo *realmDevice = [[realmUser.devices objectsWhere:@"deviceId = %@", deviceId] firstObject];
    if (realmDevice)
    {
        return [NSKeyedUnarchiver unarchiveObjectWithData:realmDevice.deviceInfoData];
    }

    return nil;
}

- (MXDeviceInfo*)deviceWithIdentityKey:(NSString*)identityKey
{
    MXRealmDeviceInfo *realmDevice = [MXRealmDeviceInfo objectsInRealm:self.realm where:@"identityKey = %@", identityKey].firstObject;
    if (realmDevice)
    {
        return [NSKeyedUnarchiver unarchiveObjectWithData:realmDevice.deviceInfoData];
    }

    return nil;
}

- (void)storeDevicesForUser:(NSString*)userID devices:(NSDictionary<NSString*, MXDeviceInfo*>*)devices
{
    NSDate *startDate = [NSDate date];

    RLMRealm *realm = self.realm;

    [realm transactionWithBlock:^{

        MXRealmUser *realmUser = [MXRealmUser objectsInRealm:realm where:@"userId = %@", userID].firstObject;
        if (!realmUser)
        {
            realmUser = [[MXRealmUser alloc] initWithValue:@{
                                                             @"userId": userID,
                                                             }];
            [realm addObject:realmUser];
        }
        else
        {
            // Reset all previously stored devices for this user
            [realm deleteObjects:realmUser.devices];
        }

        for (NSString *deviceId in devices)
        {
            MXDeviceInfo *device = devices[deviceId];
            MXRealmDeviceInfo *realmDevice = [[MXRealmDeviceInfo alloc] initWithValue:@{
                                                                                        @"deviceId": device.deviceId,
                                                                                        @"deviceInfoData": [NSKeyedArchiver archivedDataWithRootObject:device]
                                                                                        }];
            realmDevice.identityKey = device.identityKey;
            [realmUser.devices addObject:realmDevice];
        }
    }];

    NSLog(@"[MXRealmCryptoStore] storeDevicesForUser (count: %tu) in %.0fms", devices.count, [[NSDate date] timeIntervalSinceDate:startDate] * 1000);
}

- (NSDictionary<NSString*, MXDeviceInfo*>*)devicesForUser:(NSString*)userID
{
    NSMutableDictionary *devicesForUser;

    MXRealmUser *realmUser = [MXRealmUser objectsInRealm:self.realm where:@"userId = %@", userID].firstObject;
    if (realmUser)
    {
        devicesForUser = [NSMutableDictionary dictionary];

        for (MXRealmDeviceInfo *realmDevice in realmUser.devices)
        {
            devicesForUser[realmDevice.deviceId] = [NSKeyedUnarchiver unarchiveObjectWithData:realmDevice.deviceInfoData];
        }
    }

    return devicesForUser;
}

- (NSDictionary<NSString*, NSNumber*>*)deviceTrackingStatus
{
    MXRealmOlmAccount *account = self.accountInCurrentThread;
    return [NSKeyedUnarchiver unarchiveObjectWithData:account.deviceTrackingStatusData];
}

- (void)storeDeviceTrackingStatus:(NSDictionary<NSString*, NSNumber*>*)statusMap
{
    MXRealmOlmAccount *account = self.accountInCurrentThread;
    [account.realm transactionWithBlock:^{

        account.deviceTrackingStatusData = [NSKeyedArchiver archivedDataWithRootObject:statusMap];
    }];
}


#pragma mark - Cross-signing keys

- (void)storeCrossSigningKeys:(MXCrossSigningInfo*)crossSigningInfo
{
    RLMRealm *realm = self.realm;

    [realm transactionWithBlock:^{

        MXRealmUser *realmUser = [MXRealmUser objectsInRealm:realm where:@"userId = %@", crossSigningInfo.userId].firstObject;
        if (!realmUser)
        {
            realmUser = [[MXRealmUser alloc] initWithValue:@{
                                                             @"userId": crossSigningInfo.userId,
                                                             }];

            [realm addObject:realmUser];
        }

        MXRealmCrossSigningInfo *realmCrossSigningKeys = [[MXRealmCrossSigningInfo alloc] initWithValue:@{
                                                                                                    @"data": [NSKeyedArchiver archivedDataWithRootObject:crossSigningInfo]
                                                                                                   }];
        if (realmUser.crossSigningKeys)
        {
            // Remove orphan MXRealmCrossSigningInfo objects from the DB
            [realm deleteObject:realmUser.crossSigningKeys];
        }
        
        realmUser.crossSigningKeys = realmCrossSigningKeys;
    }];
}

- (MXCrossSigningInfo*)crossSigningKeysForUser:(NSString*)userId
{
    MXCrossSigningInfo *crossSigningKeys;

    MXRealmUser *realmUser = [MXRealmUser objectsInRealm:self.realm where:@"userId = %@", userId].firstObject;
    if (realmUser)
    {
        crossSigningKeys = [NSKeyedUnarchiver unarchiveObjectWithData:realmUser.crossSigningKeys.data];
    }

    return crossSigningKeys;
}

- (NSArray<MXCrossSigningInfo *> *)crossSigningKeys
{
    NSMutableArray<MXCrossSigningInfo*> *crossSigningKeys = [NSMutableArray array];
    
    for (MXRealmCrossSigningInfo *realmCrossSigningKey in [MXRealmCrossSigningInfo allObjectsInRealm:self.realm])
    {
        [crossSigningKeys addObject:[NSKeyedUnarchiver unarchiveObjectWithData:realmCrossSigningKey.data]];
    }
    
    return crossSigningKeys;
}


#pragma mark - Message keys

- (void)storeAlgorithmForRoom:(NSString*)roomId algorithm:(NSString*)algorithm
{
    __block BOOL isNew = NO;
    NSDate *startDate = [NSDate date];

    RLMRealm *realm = self.realm;
    [realm transactionWithBlock:^{

        MXRealmRoomAlgorithm *roomAlgorithm = [self realmRoomAlgorithmForRoom:roomId inRealm:realm];
        if (roomAlgorithm)
        {
            // Update the existing one
            roomAlgorithm.algorithm = algorithm;
        }
        else
        {
            // Create it
            roomAlgorithm = [[MXRealmRoomAlgorithm alloc] initWithValue:@{
                                                                          @"roomId": roomId,
                                                                          @"algorithm": algorithm
                                                                          }];
            [realm addObject:roomAlgorithm];
        }
    }];

    NSLog(@"[MXRealmCryptoStore] storeAlgorithmForRoom (%@) in %.0fms", (isNew?@"NEW":@"UPDATE"), [[NSDate date] timeIntervalSinceDate:startDate] * 1000);
}

- (NSString*)algorithmForRoom:(NSString*)roomId
{
    return [self realmRoomAlgorithmForRoom:roomId inRealm:self.realm].algorithm;
}

- (void)storeBlacklistUnverifiedDevicesInRoom:(NSString *)roomId blacklist:(BOOL)blacklist
{
    BOOL isNew = NO;
    NSDate *startDate = [NSDate date];

    RLMRealm *realm = self.realm;
    [realm transactionWithBlock:^{

        MXRealmRoomAlgorithm *roomAlgorithm = [self realmRoomAlgorithmForRoom:roomId inRealm:realm];
        if (roomAlgorithm)
        {
            // Update the existing one
            roomAlgorithm.blacklistUnverifiedDevices = blacklist;
        }
        else
        {
            // Create it
            roomAlgorithm = [[MXRealmRoomAlgorithm alloc] initWithValue:@{
                                                                          @"roomId": roomId,
                                                                          @"blacklist": @(blacklist)
                                                                          }];
            [realm addObject:roomAlgorithm];
        }
    }];

    NSLog(@"[MXRealmCryptoStore] storeBlacklistUnverifiedDevicesInRoom (%@) in %.0fms", (isNew?@"NEW":@"UPDATE"), [[NSDate date] timeIntervalSinceDate:startDate] * 1000);
}

- (BOOL)blacklistUnverifiedDevicesInRoom:(NSString *)roomId
{
    return [self realmRoomAlgorithmForRoom:roomId inRealm:self.realm].blacklistUnverifiedDevices;
}

- (MXRealmRoomAlgorithm *)realmRoomAlgorithmForRoom:(NSString*)roomId inRealm:(RLMRealm*)realm
{
    return [MXRealmRoomAlgorithm objectsInRealm:realm where:@"roomId = %@", roomId].firstObject;
}


- (void)storeSession:(MXOlmSession*)session forDevice:(NSString*)deviceKey
{
    __block BOOL isNew = NO;
    NSDate *startDate = [NSDate date];

    RLMRealm *realm = self.realm;
    [realm transactionWithBlock:^{

        MXRealmOlmSession *realmOlmSession = [MXRealmOlmSession objectsInRealm:realm where:@"sessionId = %@ AND deviceKey = %@", session.session.sessionIdentifier, deviceKey].firstObject;
        if (realmOlmSession)
        {
            // Update the existing one
            realmOlmSession.olmSessionData = [NSKeyedArchiver archivedDataWithRootObject:session.session];
        }
        else
        {
            // Create it
            isNew = YES;
            realmOlmSession = [[MXRealmOlmSession alloc] initWithValue:@{
                                                                         @"sessionId": session.session.sessionIdentifier,
                                                                         @"deviceKey": deviceKey,
                                                                         @"olmSessionData": [NSKeyedArchiver archivedDataWithRootObject:session.session]
                                                                         }];
            realmOlmSession.lastReceivedMessageTs = session.lastReceivedMessageTs;

            [realm addObject:realmOlmSession];
        }
    }];

    NSLog(@"[MXRealmCryptoStore] storeSession (%@) in %.0fms", (isNew?@"NEW":@"UPDATE"), [[NSDate date] timeIntervalSinceDate:startDate] * 1000);
}

- (MXOlmSession*)sessionWithDevice:(NSString*)deviceKey andSessionId:(NSString*)sessionId
{
    MXRealmOlmSession *realmOlmSession = [MXRealmOlmSession objectsInRealm:self.realm
                                                                      where:@"sessionId = %@ AND deviceKey = %@", sessionId, deviceKey].firstObject;

    MXOlmSession *mxOlmSession;
    if (realmOlmSession.olmSessionData)
    {
        OLMSession *olmSession = [NSKeyedUnarchiver unarchiveObjectWithData:realmOlmSession.olmSessionData];

        mxOlmSession = [[MXOlmSession alloc] initWithOlmSession:olmSession];
        mxOlmSession.lastReceivedMessageTs = realmOlmSession.lastReceivedMessageTs;
    }

    return mxOlmSession;
}

- (NSArray<MXOlmSession*>*)sessionsWithDevice:(NSString*)deviceKey;
{
    NSMutableArray<MXOlmSession*> *sessionsWithDevice;

    RLMResults<MXRealmOlmSession *> *realmOlmSessions = [[MXRealmOlmSession objectsInRealm:self.realm
                                                                                     where:@"deviceKey = %@", deviceKey]
                                                         sortedResultsUsingKeyPath:@"lastReceivedMessageTs" ascending:NO];
    for (MXRealmOlmSession *realmOlmSession in realmOlmSessions)
    {
        if (!sessionsWithDevice)
        {
            sessionsWithDevice = [NSMutableArray array];
        }

        if (realmOlmSession.olmSessionData)
        {
            OLMSession *olmSession = [NSKeyedUnarchiver unarchiveObjectWithData:realmOlmSession.olmSessionData];

            MXOlmSession *mxOlmSession = [[MXOlmSession alloc] initWithOlmSession:olmSession];
            mxOlmSession.lastReceivedMessageTs = realmOlmSession.lastReceivedMessageTs;

            [sessionsWithDevice addObject:mxOlmSession];
        }
    }

    return sessionsWithDevice;
}

- (void)storeInboundGroupSessions:(NSArray<MXOlmInboundGroupSession *>*)sessions
{
    __block NSUInteger newCount = 0;
    NSDate *startDate = [NSDate date];

    RLMRealm *realm = self.realm;
    [realm transactionWithBlock:^{

        for (MXOlmInboundGroupSession *session in sessions)
        {
            NSString *sessionIdSenderKey = [MXRealmOlmInboundGroupSession primaryKeyWithSessionId:session.session.sessionIdentifier
                                                                                        senderKey:session.senderKey];
            MXRealmOlmInboundGroupSession *realmSession = [MXRealmOlmInboundGroupSession objectsInRealm:realm where:@"sessionIdSenderKey = %@", sessionIdSenderKey].firstObject;
            if (realmSession)
            {
                // Update the existing one
                realmSession.olmInboundGroupSessionData = [NSKeyedArchiver archivedDataWithRootObject:session];
            }
            else
            {
                // Create it
                newCount++;
                NSString *sessionIdSenderKey = [MXRealmOlmInboundGroupSession primaryKeyWithSessionId:session.session.sessionIdentifier
                                                                                            senderKey:session.senderKey];
                realmSession = [[MXRealmOlmInboundGroupSession alloc] initWithValue:@{
                                                                                      @"sessionId": session.session.sessionIdentifier,
                                                                                      @"senderKey": session.senderKey,
                                                                                      @"sessionIdSenderKey": sessionIdSenderKey,
                                                                                      @"olmInboundGroupSessionData": [NSKeyedArchiver archivedDataWithRootObject:session]
                                                                                      }];

                [realm addObject:realmSession];
            }
        }
    }];


    NSLog(@"[MXRealmCryptoStore] storeInboundGroupSessions: store %@ keys (%@ new) in %.0fms", @(sessions.count), @(newCount), [[NSDate date] timeIntervalSinceDate:startDate] * 1000);
}

- (MXOlmInboundGroupSession*)inboundGroupSessionWithId:(NSString*)sessionId andSenderKey:(NSString*)senderKey
{
    MXOlmInboundGroupSession *session;
    NSString *sessionIdSenderKey = [MXRealmOlmInboundGroupSession primaryKeyWithSessionId:sessionId
                                                                                senderKey:senderKey];
    MXRealmOlmInboundGroupSession *realmSession = [MXRealmOlmInboundGroupSession objectsInRealm:self.realm where:@"sessionIdSenderKey = %@", sessionIdSenderKey].firstObject;

    NSLog(@"[MXRealmCryptoStore] inboundGroupSessionWithId: %@ -> %@", sessionId, realmSession ? @"found" : @"not found");

    if (realmSession)
    {
        session = [NSKeyedUnarchiver unarchiveObjectWithData:realmSession.olmInboundGroupSessionData];

        if (!session)
        {
            NSLog(@"[MXRealmCryptoStore] inboundGroupSessionWithId: ERROR: Failed to create MXOlmInboundGroupSession object");
        }
    }

    return session;
}

- (NSArray<MXOlmInboundGroupSession *> *)inboundGroupSessions
{
    NSMutableArray *sessions = [NSMutableArray array];

    for (MXRealmOlmInboundGroupSession *realmSession in [MXRealmOlmInboundGroupSession allObjectsInRealm:self.realm])
    {
        [sessions addObject:[NSKeyedUnarchiver unarchiveObjectWithData:realmSession.olmInboundGroupSessionData]];
    }

    return sessions;
}

- (void)removeInboundGroupSessionWithId:(NSString*)sessionId andSenderKey:(NSString*)senderKey
{
    RLMRealm *realm = self.realm;
    [realm transactionWithBlock:^{

        RLMResults<MXRealmOlmInboundGroupSession *> *realmSessions = [MXRealmOlmInboundGroupSession objectsInRealm:realm where:@"sessionId = %@ AND senderKey = %@", sessionId, senderKey];

        [realm deleteObjects:realmSessions];
    }];
}


#pragma mark - Key backup

- (void)setBackupVersion:(NSString *)backupVersion
{
    MXRealmOlmAccount *account = self.accountInCurrentThread;
    [account.realm transactionWithBlock:^{
        account.backupVersion = backupVersion;
    }];
}

- (NSString *)backupVersion
{
    MXRealmOlmAccount *account = self.accountInCurrentThread;
    return account.backupVersion;
}

- (void)resetBackupMarkers
{
    RLMRealm *realm = self.realm;
    [realm transactionWithBlock:^{

        RLMResults<MXRealmOlmInboundGroupSession *> *realmSessions = [MXRealmOlmInboundGroupSession allObjectsInRealm:realm];

        for (MXRealmOlmInboundGroupSession *realmSession in realmSessions)
        {
            realmSession.backedUp = NO;
        }

        [realm addOrUpdateObjects:realmSessions];
    }];
}

- (void)markBackupDoneForInboundGroupSessions:(NSArray<MXOlmInboundGroupSession *>*)sessions
{
    RLMRealm *realm = self.realm;
    [realm transactionWithBlock:^{

        for (MXOlmInboundGroupSession *session in sessions)
        {
            NSString *sessionIdSenderKey = [MXRealmOlmInboundGroupSession primaryKeyWithSessionId:session.session.sessionIdentifier
                                                                                        senderKey:session.senderKey];
            MXRealmOlmInboundGroupSession *realmSession = [MXRealmOlmInboundGroupSession objectsInRealm:realm where:@"sessionIdSenderKey = %@", sessionIdSenderKey].firstObject;

            if (realmSession)
            {
                realmSession.backedUp = YES;

                [realm addOrUpdateObject:realmSession];
            }
        }
    }];
}

- (NSArray<MXOlmInboundGroupSession*>*)inboundGroupSessionsToBackup:(NSUInteger)limit
{
    NSMutableArray *sessions = [NSMutableArray new];

    RLMRealm *realm = self.realm;

    RLMResults<MXRealmOlmInboundGroupSession *> *realmSessions = [MXRealmOlmInboundGroupSession objectsInRealm:realm where:@"backedUp = NO"];

    for (MXRealmOlmInboundGroupSession *realmSession in realmSessions)
    {
        MXOlmInboundGroupSession *session = [NSKeyedUnarchiver unarchiveObjectWithData:realmSession.olmInboundGroupSessionData];
        [sessions addObject:session];

        if (sessions.count >= limit)
        {
            break;
        }
    }

    return sessions;
}

- (NSUInteger)inboundGroupSessionsCount:(BOOL)onlyBackedUp
{
    RLMRealm *realm = self.realm;
    RLMResults<MXRealmOlmInboundGroupSession *> *realmSessions;

    if (onlyBackedUp)
    {
        realmSessions = [MXRealmOlmInboundGroupSession objectsInRealm:realm where:@"backedUp = YES"];
    }
    else
    {
        realmSessions = [MXRealmOlmInboundGroupSession allObjectsInRealm:realm];
    }

    return realmSessions.count;
}

#pragma mark - Key sharing - Outgoing key requests

- (MXOutgoingRoomKeyRequest*)outgoingRoomKeyRequestWithRequestBody:(NSDictionary *)requestBody
{
    MXOutgoingRoomKeyRequest *request;

    NSString *requestBodyHash = [MXCryptoTools canonicalJSONStringForJSON:requestBody];

    RLMResults<MXRealmOutgoingRoomKeyRequest *> *realmOutgoingRoomKeyRequests =  [MXRealmOutgoingRoomKeyRequest objectsInRealm:self.realm where:@"requestBodyHash = %@", requestBodyHash];
    if (realmOutgoingRoomKeyRequests.count)
    {
        request = realmOutgoingRoomKeyRequests[0].outgoingRoomKeyRequest;
    }

    return request;
}

- (MXOutgoingRoomKeyRequest*)outgoingRoomKeyRequestWithState:(MXRoomKeyRequestState)state
{
    MXOutgoingRoomKeyRequest *request;

    RLMResults<MXRealmOutgoingRoomKeyRequest *> *realmOutgoingRoomKeyRequests = [MXRealmOutgoingRoomKeyRequest objectsInRealm:self.realm where:@"state = %@", @(state)];
    if (realmOutgoingRoomKeyRequests.count)
    {
        request = realmOutgoingRoomKeyRequests[0].outgoingRoomKeyRequest;
    }

    return request;
}

- (NSArray<MXOutgoingRoomKeyRequest*> *)allOutgoingRoomKeyRequestsWithState:(MXRoomKeyRequestState)state
{
    NSMutableArray<MXOutgoingRoomKeyRequest*> *allOutgoingRoomKeyRequests = [NSMutableArray array];
    
    for (MXRealmOutgoingRoomKeyRequest *realmOutgoingRoomKeyRequest in [MXRealmOutgoingRoomKeyRequest allObjectsInRealm:self.realm])
    {
        [allOutgoingRoomKeyRequests addObject:realmOutgoingRoomKeyRequest.outgoingRoomKeyRequest];
    }
    
    return allOutgoingRoomKeyRequests;
}

- (void)storeOutgoingRoomKeyRequest:(MXOutgoingRoomKeyRequest*)request
{
    RLMRealm *realm = self.realm;
    [realm transactionWithBlock:^{

        NSString *requestBodyString = [MXTools serialiseJSONObject:request.requestBody];
        NSString *requestBodyHash = [MXCryptoTools canonicalJSONStringForJSON:request.requestBody];

        MXRealmOutgoingRoomKeyRequest *realmOutgoingRoomKeyRequest =
        [[MXRealmOutgoingRoomKeyRequest alloc] initWithValue:@{
                                                               @"requestId": request.requestId,
                                                               @"recipientsData": [NSKeyedArchiver archivedDataWithRootObject:request.recipients],
                                                               @"requestBodyString": requestBodyString,
                                                               @"requestBodyHash": requestBodyHash,
                                                               @"state": @(request.state)
                                                               }];

        realmOutgoingRoomKeyRequest.cancellationTxnId = request.cancellationTxnId;

        [realm addObject:realmOutgoingRoomKeyRequest];
    }];
}

- (void)updateOutgoingRoomKeyRequest:(MXOutgoingRoomKeyRequest*)request
{
    RLMRealm *realm = self.realm;
    [realm transactionWithBlock:^{

        MXRealmOutgoingRoomKeyRequest *realmOutgoingRoomKeyRequest = [MXRealmOutgoingRoomKeyRequest objectsInRealm:realm where:@"requestId = %@", request.requestId].firstObject;

        if (realmOutgoingRoomKeyRequest)
        {
            // Well, only the state changes
            realmOutgoingRoomKeyRequest.state = @(request.state);

            [realm addOrUpdateObject:realmOutgoingRoomKeyRequest];
        }
    }];
}

- (void)deleteOutgoingRoomKeyRequestWithRequestId:(NSString*)requestId
{
    RLMRealm *realm = self.realm;
    [realm transactionWithBlock:^{

        RLMResults<MXRealmOutgoingRoomKeyRequest *> *realmOutgoingRoomKeyRequests = [MXRealmOutgoingRoomKeyRequest objectsInRealm:realm where:@"requestId = %@", requestId];

        [realm deleteObjects:realmOutgoingRoomKeyRequests];
    }];
}


#pragma mark - Key sharing - Incoming key requests

- (void)storeIncomingRoomKeyRequest:(MXIncomingRoomKeyRequest*)request
{
    RLMRealm *realm = self.realm;
    [realm transactionWithBlock:^{

        MXRealmIncomingRoomKeyRequest *realmIncomingRoomKeyRequest =
        [[MXRealmIncomingRoomKeyRequest alloc] initWithValue:@{
                                                               @"requestId": request.requestId,
                                                               @"userId": request.userId,
                                                               @"deviceId": request.deviceId,
                                                               @"requestBodyData": [NSKeyedArchiver archivedDataWithRootObject:request.requestBody]
                                                               }];
        [realm addObject:realmIncomingRoomKeyRequest];
    }];
}

- (void)deleteIncomingRoomKeyRequest:(NSString*)requestId fromUser:(NSString*)userId andDevice:(NSString*)deviceId
{
    RLMRealm *realm = self.realm;
    [realm transactionWithBlock:^{

        RLMResults<MXRealmIncomingRoomKeyRequest *> *realmIncomingRoomKeyRequests = [MXRealmIncomingRoomKeyRequest objectsInRealm:realm where:@"requestId = %@ AND userId = %@ AND deviceId = %@", requestId, userId, deviceId];
        
        [realm deleteObjects:realmIncomingRoomKeyRequests];
    }];
}

- (MXIncomingRoomKeyRequest*)incomingRoomKeyRequestWithRequestId:(NSString*)requestId fromUser:(NSString*)userId andDevice:(NSString*)deviceId
{
    RLMRealm *realm = self.realm;

    RLMResults<MXRealmIncomingRoomKeyRequest *> *realmIncomingRoomKeyRequests = [MXRealmIncomingRoomKeyRequest objectsInRealm:realm where:@"requestId = %@ AND userId = %@ AND deviceId = %@", requestId, userId, deviceId];

    return realmIncomingRoomKeyRequests.firstObject.incomingRoomKeyRequest;
}

- (MXUsersDevicesMap<NSArray<MXIncomingRoomKeyRequest *> *> *)incomingRoomKeyRequests
{
    MXUsersDevicesMap<NSMutableArray<MXIncomingRoomKeyRequest *> *> *incomingRoomKeyRequests = [[MXUsersDevicesMap alloc] init];

    RLMRealm *realm = self.realm;

    RLMResults<MXRealmIncomingRoomKeyRequest *> *realmIncomingRoomKeyRequests = [MXRealmIncomingRoomKeyRequest allObjectsInRealm:realm];
    for (MXRealmIncomingRoomKeyRequest *realmRequest in realmIncomingRoomKeyRequests)
    {
        MXIncomingRoomKeyRequest *request = realmRequest.incomingRoomKeyRequest;

        NSMutableArray<MXIncomingRoomKeyRequest *> *requests = [incomingRoomKeyRequests objectForDevice:request.deviceId forUser:request.userId];
        if (!requests)
        {
            requests = [[NSMutableArray alloc] init];
            [incomingRoomKeyRequests setObject:requests forUser:request.userId andDevice:request.deviceId];
        }

        [requests addObject:request];
    }

    return incomingRoomKeyRequests;
}


#pragma mark - Secret storage

- (void)storeSecret:(NSString*)secret withSecretId:(NSString*)secretId
{
    RLMRealm *realm = self.realm;
    [realm transactionWithBlock:^{
        
        MXRealmSecret *realmSecret =
        [[MXRealmSecret alloc] initWithValue:@{
                                               @"secretId": secretId,
                                               @"secret": secret,
                                               }];
        [realm addOrUpdateObject:realmSecret];
    }];
}

- (NSString*)secretWithSecretId:(NSString*)secretId
{
    RLMResults<MXRealmSecret *> *realmSecrets = [MXRealmSecret objectsInRealm:self.realm where:@"secretId = %@", secretId];
    return realmSecrets.firstObject.secret;
}

- (void)deleteSecretWithSecretId:(NSString*)secretId
{
    RLMRealm *realm = self.realm;
    [realm transactionWithBlock:^{
        [realm deleteObjects:[MXRealmSecret objectsInRealm:self.realm where:@"secretId = %@", secretId]];
    }];
}


#pragma mark - Crypto settings

- (BOOL)globalBlacklistUnverifiedDevices
{
    MXRealmOlmAccount *account = self.accountInCurrentThread;
    return account.globalBlacklistUnverifiedDevices;
}

- (void)setGlobalBlacklistUnverifiedDevices:(BOOL)globalBlacklistUnverifiedDevices
{
    MXRealmOlmAccount *account = self.accountInCurrentThread;
    [account.realm transactionWithBlock:^{
        account.globalBlacklistUnverifiedDevices = globalBlacklistUnverifiedDevices;
    }];
}

#pragma mark - Private methods
+ (RLMRealm*)realmForUser:(NSString*)userId andDevice:(NSString*)deviceId
{
    // Each user has its own db file.
    // Else, it can lead to issue with primary keys.
    // Ex: if 2 users are is the same encrypted room, [self storeAlgorithmForRoom]
    // will be called twice for the same room id which breaks the uniqueness of the
    // primary key (roomId) for this table.
    RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];

    NSURL *defaultRealmPathURL = config.fileURL.URLByDeletingLastPathComponent;

#if TARGET_OS_SIMULATOR
    // On simulator from iOS 11, the Documents folder used by Realm by default
    // can be missing. Create it if required
    // https://stackoverflow.com/a/50817364
    if (![NSFileManager.defaultManager fileExistsAtPath:defaultRealmPathURL.path])
    {
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:defaultRealmPathURL.path
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
        NSLog(@"[MXRealmCryptoStore] On simulator, create the file tree used by Realm. Error: %@", error);
    }
#endif
    
    // Default db file URL: use the default directory, but replace the filename with the userId.
    NSString *realmFile = userId;
    if (MXTools.isRunningUnitTests)
    {
        // Append the device id for unit tests so that we can run e2e tests 
        // with users with several devices
        realmFile = [NSString stringWithFormat:@"%@-%@", userId, deviceId];
    }

    NSURL *defaultRealmFileURL = [[defaultRealmPathURL URLByAppendingPathComponent:realmFile]
                              URLByAppendingPathExtension:@"realm"];
    
    // Check for a potential application group id.
    NSString *applicationGroupIdentifier = [MXSDKOptions sharedInstance].applicationGroupIdentifier;
    if (applicationGroupIdentifier)
    {
        // Use the shared db file URL.
        NSURL *sharedContainerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:applicationGroupIdentifier];
        NSURL *realmFileFolderURL = [sharedContainerURL URLByAppendingPathComponent:kMXRealmCryptoStoreFolder];
        NSURL *realmFileURL = [[realmFileFolderURL URLByAppendingPathComponent:userId] URLByAppendingPathExtension:@"realm"];
        
        config.fileURL = realmFileURL;
        
        // Check whether an existing db file has to be be moved from the default folder to the shared container.
        if ([NSFileManager.defaultManager fileExistsAtPath:[defaultRealmFileURL path]])
        {
            if (![NSFileManager.defaultManager fileExistsAtPath:[realmFileURL path]])
            {
                // Move this db file in the container directory associated with the application group identifier.
                NSLog(@"[MXRealmCryptoStore] Move the db file to the application group container");
                
                if (![NSFileManager.defaultManager fileExistsAtPath:realmFileFolderURL.path])
                {
                    [[NSFileManager defaultManager] createDirectoryAtPath:realmFileFolderURL.path withIntermediateDirectories:YES attributes:nil error:nil];
                }
                
                NSError *fileManagerError = nil;
                
                [NSFileManager.defaultManager moveItemAtURL:defaultRealmFileURL toURL:realmFileURL error:&fileManagerError];
                
                if (fileManagerError)
                {
                    NSLog(@"[MXRealmCryptoStore] Move db file failed (%@)", fileManagerError);
                    // Keep using the old file
                    config.fileURL = defaultRealmFileURL;
                }
            }
            else
            {
                // Remove the residual db file.
                [NSFileManager.defaultManager removeItemAtURL:defaultRealmFileURL error:nil];
            }
        }
        else
        {
            // Make sure the full exists before giving it to Realm 
            if (![NSFileManager.defaultManager fileExistsAtPath:realmFileFolderURL.path])
            {
                [[NSFileManager defaultManager] createDirectoryAtPath:realmFileFolderURL.path withIntermediateDirectories:YES attributes:nil error:nil];
            }
        }
    }
    else
    {
        // Use the default URL
        config.fileURL = defaultRealmFileURL;
    }

    // Manage only our objects in this realm 
    config.objectClasses = @[
                             MXRealmDeviceInfo.class,
                             MXRealmCrossSigningInfo.class,
                             MXRealmUser.class,
                             MXRealmRoomAlgorithm.class,
                             MXRealmOlmSession.class,
                             MXRealmOlmInboundGroupSession.class,   
                             MXRealmOlmAccount.class,
                             MXRealmOutgoingRoomKeyRequest.class,
                             MXRealmIncomingRoomKeyRequest.class,
                             MXRealmSecret.class,
                             ];

    config.schemaVersion = kMXRealmCryptoStoreVersion;

    __block BOOL cleanDuplicatedDevices = NO;

    // Set the block which will be called automatically when opening a Realm with a
    // schema version lower than the one set above
    config.migrationBlock = ^(RLMMigration *migration, uint64_t oldSchemaVersion) {

        // Note: There is nothing to do most of the time
        // Realm will automatically detect new properties and removed properties
        // And will update the schema on disk automatically

        if (oldSchemaVersion < kMXRealmCryptoStoreVersion)
        {
            NSLog(@"[MXRealmCryptoStore] Required migration detected. oldSchemaVersion: %llu - current: %tu", oldSchemaVersion, kMXRealmCryptoStoreVersion);

            switch (oldSchemaVersion)
            {
                case 1:
                {
                    // There was a bug in schema version #1 where inbound group sessions
                    // and olm sessions were duplicated:
                    // https://github.com/matrix-org/matrix-ios-sdk/issues/227

                    NSLog(@"[MXRealmCryptoStore] Migration from schema #1 -> #2");

                    // We need to update the db because a sessionId property has been added MXRealmOlmSession
                    // to ensure uniqueness
                    NSLog(@"[MXRealmCryptoStore]    Add sessionId field to all MXRealmOlmSession objects");
                    [migration enumerateObjects:MXRealmOlmSession.className block:^(RLMObject *oldObject, RLMObject *newObject) {

                        OLMSession *olmSession =  [NSKeyedUnarchiver unarchiveObjectWithData:oldObject[@"olmSessionData"]];

                        newObject[@"sessionId"] = olmSession.sessionIdentifier;
                    }];

                    // We need to clean the db from duplicated MXRealmOlmSessions
                    NSLog(@"[MXRealmCryptoStore]    Make MXRealmOlmSession objects unique for the (sessionId, deviceKey) pair");
                    __block NSUInteger deleteCount = 0;
                    NSMutableArray<NSString*> *olmSessionUniquePairs = [NSMutableArray array];
                    [migration enumerateObjects:MXRealmOlmSession.className block:^(RLMObject *oldObject, RLMObject *newObject) {

                        NSString *olmSessionUniquePair = [NSString stringWithFormat:@"%@ - %@", newObject[@"sessionId"], newObject[@"deviceKey"]];

                        if (NSNotFound == [olmSessionUniquePairs indexOfObject:olmSessionUniquePair])
                        {
                            [olmSessionUniquePairs addObject:olmSessionUniquePair];
                        }
                        else
                        {
                            NSLog(@"[MXRealmCryptoStore]        - delete MXRealmOlmSession: %@", olmSessionUniquePair);
                            [migration deleteObject:newObject];
                            deleteCount++;
                        }
                    }];

                    NSLog(@"[MXRealmCryptoStore]    -> deleted %tu duplicated MXRealmOlmSession objects", deleteCount);

                    // And from duplicated MXRealmOlmInboundGroupSessions
                    NSLog(@"[MXRealmCryptoStore]    Make MXRealmOlmInboundGroupSession objects unique for the (sessionId, senderKey) pair");
                    deleteCount = 0;
                    NSMutableArray<NSString*> *olmInboundGroupSessionUniquePairs = [NSMutableArray array];
                    [migration enumerateObjects:MXRealmOlmInboundGroupSession.className block:^(RLMObject *oldObject, RLMObject *newObject) {

                        NSString *olmInboundGroupSessionUniquePair = [NSString stringWithFormat:@"%@ - %@", newObject[@"sessionId"], newObject[@"senderKey"]];

                        if (NSNotFound == [olmInboundGroupSessionUniquePairs indexOfObject:olmInboundGroupSessionUniquePair])
                        {
                            [olmInboundGroupSessionUniquePairs addObject:olmInboundGroupSessionUniquePair];
                        }
                        else
                        {
                            NSLog(@"[MXRealmCryptoStore]        - delete MXRealmOlmInboundGroupSession: %@", olmInboundGroupSessionUniquePair);
                            [migration deleteObject:newObject];
                            deleteCount++;
                        }
                    }];

                    NSLog(@"[MXRealmCryptoStore]    -> deleted %tu duplicated MXRealmOlmInboundGroupSession objects", deleteCount);

                    NSLog(@"[MXRealmCryptoStore] Migration from schema #1 -> #2 completed");
                }

                case 2:
                    NSLog(@"[MXRealmCryptoStore] Migration from schema #2 -> #3: Nothing to do (add MXRealmOlmAccount.deviceSyncToken)");

                case 3:
                    NSLog(@"[MXRealmCryptoStore] Migration from schema #3 -> #4: Nothing to do (add MXRealmOlmAccount.globalBlacklistUnverifiedDevices & MXRealmRoomAlgortithm.blacklistUnverifiedDevices)");

                case 4:
                    NSLog(@"[MXRealmCryptoStore] Migration from schema #4 -> #5: Nothing to do (add deviceTrackingStatusData)");

                case 5:
                    NSLog(@"[MXRealmCryptoStore] Migration from schema #5 -> #6: Nothing to do (remove MXRealmOlmAccount.deviceAnnounced)");

                case 6:
                {
                    NSLog(@"[MXRealmCryptoStore] Migration from schema #6 -> #7");

                    // We need to update the db because a sessionId property has been added to MXRealmOlmInboundGroupSession
                    // to ensure uniqueness
                    NSLog(@"[MXRealmCryptoStore]    Add sessionIdSenderKey, a combined primary key, to all MXRealmOlmInboundGroupSession objects");
                    [migration enumerateObjects:MXRealmOlmInboundGroupSession.className block:^(RLMObject *oldObject, RLMObject *newObject) {

                        newObject[@"sessionIdSenderKey"] = [MXRealmOlmInboundGroupSession primaryKeyWithSessionId:oldObject[@"sessionId"]
                                                                                                        senderKey:oldObject[@"senderKey"]];
                    }];

                    // We need to update the db because a identityKey property has been added to MXRealmDeviceInfo
                    NSLog(@"[MXRealmCryptoStore]    Add identityKey to all MXRealmDeviceInfo objects");
                    [migration enumerateObjects:MXRealmDeviceInfo.className block:^(RLMObject *oldObject, RLMObject *newObject) {

                        MXDeviceInfo *device = [NSKeyedUnarchiver unarchiveObjectWithData:oldObject[@"deviceInfoData"]];
                        NSString *identityKey = device.identityKey;
                        if (identityKey)
                        {
                            newObject[@"identityKey"] = identityKey;
                        }
                    }];

                    NSLog(@"[MXRealmCryptoStore] Migration from schema #6 -> #7 completed");
                }

                case 7:
                {
                    NSLog(@"[MXRealmCryptoStore] Migration from schema #7 -> #8");

                    // This schema update is only for cleaning duplicated devices.
                    // With the Realm Obj-C SDK, the realm instance is not public. We cannot
                    // make queries. So, the cleaning will be done afterwards.
                    cleanDuplicatedDevices = YES;
                }

                case 8:
                {
                    // MXRealmOlmSession.lastReceivedMessageTs has been added to implement:
                    // Use the last olm session that got a message
                    // https://github.com/vector-im/riot-ios/issues/2128

                    NSLog(@"[MXRealmCryptoStore] Migration from schema #8 -> #9");

                    NSLog(@"[MXRealmCryptoStore]    Add lastReceivedMessageTs = 0 to all MXRealmOlmSession objects");
                    [migration enumerateObjects:MXRealmOlmSession.className block:^(RLMObject *oldObject, RLMObject *newObject) {

                        newObject[@"lastReceivedMessageTs"] = @(0);
                    }];

                    NSLog(@"[MXRealmCryptoStore] Migration from schema #8 -> #9 completed");
                }

                case 9:
                {
                    NSLog(@"[MXRealmCryptoStore] Migration from schema #9 -> #10");

                    NSLog(@"[MXRealmCryptoStore]    Add requestBodyHash to all MXRealmOutgoingRoomKeyRequest objects");
                    [migration enumerateObjects:MXRealmOutgoingRoomKeyRequest.className block:^(RLMObject *oldObject, RLMObject *newObject) {

                        NSDictionary *requestBody = [MXTools deserialiseJSONString:oldObject[@"requestBodyString"]];
                        if (requestBody)
                        {
                            newObject[@"requestBodyHash"] = [MXCryptoTools canonicalJSONStringForJSON:requestBody];
                        }
                    }];

                    // This schema update needs a fix of cleanDuplicatedDevicesInRealm introduced in schema #8.
                    cleanDuplicatedDevices = YES;
                }

                case 10:
                    NSLog(@"[MXRealmCryptoStore] Migration from schema #10 -> #11: Nothing to do (added optional MXRealmUser.crossSigningKeys)");

                case 11:
                {
                    NSLog(@"[MXRealmCryptoStore] Migration from schema #10 -> #11");

                    // Because of https://github.com/vector-im/riot-ios/issues/2896, algorithms were not stored
                    // Fix it by defaulting to usual values
                    NSLog(@"[MXRealmCryptoStore]    Fix missing algorithms to all MXRealmDeviceInfo objects");

                    [migration enumerateObjects:MXRealmDeviceInfo.className block:^(RLMObject *oldObject, RLMObject *newObject) {

                        MXDeviceInfo *device = [NSKeyedUnarchiver unarchiveObjectWithData:oldObject[@"deviceInfoData"]];
                        if (!device.algorithms)
                        {
                            device.algorithms = @[
                                                  kMXCryptoOlmAlgorithm,
                                                  kMXCryptoMegolmAlgorithm
                                                  ];
                        }
                        newObject[@"deviceInfoData"] = [NSKeyedArchiver archivedDataWithRootObject:device];
                    }];
                }
            }
        }
    };

    NSError *error;
    RLMRealm *realm = [RLMRealm realmWithConfiguration:config error:&error];
    if (error)
    {
        NSLog(@"[MXRealmCryptoStore] realmForUser gets error: %@", error);

        // Remove the db file
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:config.fileURL.path error:&error];
        NSLog(@"[MXRealmCryptoStore] removeItemAtPath error result: %@", error);

        // And try again
        realm = [RLMRealm realmWithConfiguration:config error:&error];
        if (!realm)
        {
            NSLog(@"[MXRealmCryptoStore] realmForUser still gets after reset. Error: %@", error);
        }

        // Report this db reset to higher modules
        // A user logout and in is anyway required to make crypto work reliably again
        dispatch_async(dispatch_get_main_queue(),^{
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXSessionCryptoDidCorruptDataNotification
                                                                object:userId
                                                              userInfo:nil];
        });
    }

    if (cleanDuplicatedDevices)
    {
        NSLog(@"[MXRealmCryptoStore] Do cleaning for duplicating devices");

        NSUInteger before = [MXRealmDeviceInfo allObjectsInRealm:realm].count;
        [self cleanDuplicatedDevicesInRealm:realm];
        NSUInteger after = [MXRealmDeviceInfo allObjectsInRealm:realm].count;

        NSLog(@"[MXRealmCryptoStore] Cleaning for duplicating devices completed. There are now %@ devices. There were %@ before. %@ devices have been removed.", @(after), @(before), @(before - after));
    }

    // Wait for completion of other operations on this realm launched from other threads
    [realm refresh];

    return realm;
}

/**
 Clean duplicated & orphan devices.

 @param realm the DB instance to clean.
 */
+ (void)cleanDuplicatedDevicesInRealm:(RLMRealm*)realm
{
    [realm transactionWithBlock:^{

        // Due to a bug (https://github.com/vector-im/riot-ios/issues/2132), there were
        // duplicated devices living in the database without no more relationship with
        // their user.
        // Keep only devices with a relationship with a user and delete all others.
        for (MXRealmUser *realmUser in [MXRealmUser allObjectsInRealm:realm])
        {
            for (MXRealmDeviceInfo *device in realmUser.devices)
            {
                if (!device.isInvalidated)
                {
                    // The related device needs to be cloned in order to add it afterwards
                    MXRealmDeviceInfo *deviceCopy = [[MXRealmDeviceInfo alloc] initWithValue:device];

                    [realm deleteObjects:[MXRealmDeviceInfo objectsInRealm:realm where:@"identityKey = %@", device.identityKey]];

                    [realmUser.devices addObject:deviceCopy];
                }
            }
        }
    }];
}

@end

#endif
