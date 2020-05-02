/*
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

#import "MXDeviceList.h"

#ifdef MX_CRYPTO

#import "MXCrypto_Private.h"

#import "MXDeviceListOperationsPool.h"
#import "MXTools.h"

@interface MXDeviceList ()
{
    __weak MXCrypto *crypto;

    // Users we are tracking device status for.
    // userId -> MXDeviceTrackingStatus*
    NSMutableDictionary<NSString*, NSNumber*> *deviceTrackingStatus;

    // The current request for each user.
    // userId -> MXDeviceListOperation
    NSMutableDictionary<NSString*, MXDeviceListOperation*> *keyDownloadsInProgressByUser;

    /**
     The pool which the http request is currenlty being processed.
     (nil if there is no current request).

     Note that currentPoolQuery.usersIds corresponds to the inProgressUsersWithNewDevices
     ivar we used before.
     */
    MXDeviceListOperationsPool *currentQueryPool;

    /**
     When currentPoolQuery is already being processed, all download
     requests go in this pool which will be launched once currentPoolQuery is
     complete.
     */
    MXDeviceListOperationsPool *nextQueryPool;
}
@end


@implementation MXDeviceList

- (id)initWithCrypto:(MXCrypto *)theCrypto
{
    self = [super init];
    if (self)
    {
        crypto = theCrypto;

        // Retrieve tracking status from the store
        deviceTrackingStatus = [NSMutableDictionary dictionaryWithDictionary:[crypto.store deviceTrackingStatus]];

        keyDownloadsInProgressByUser = [NSMutableDictionary dictionary];

        for (NSString *userId in deviceTrackingStatus.allKeys)
        {
            // if a download was in progress or failed when we got shut down, it isn't any more.
            MXDeviceTrackingStatus trackingStatus = MXDeviceTrackingStatusFromNSNumber(deviceTrackingStatus[userId]);
            if (trackingStatus == MXDeviceTrackingStatusDownloadInProgress
                || trackingStatus == MXDeviceTrackingStatusUnreachableServer)
            {
                deviceTrackingStatus[userId] = @(MXDeviceTrackingStatusPendingDownload);
            }
        }
    }
    return self;
}

- (void)close
{
    crypto = nil;
}

- (MXHTTPOperation*)downloadKeys:(NSArray<NSString*>*)userIds forceDownload:(BOOL)forceDownload
                         success:(void (^)(MXUsersDevicesMap<MXDeviceInfo*> *usersDevicesInfoMap,
                                           NSDictionary<NSString* /* userId*/, MXCrossSigningInfo*> *crossSigningKeysMap))success
                         failure:(void (^)(NSError *error))failure
{
    NSLog(@"[MXDeviceList] downloadKeys(forceDownload: %d) for %tu users", forceDownload, userIds.count);

    NSMutableArray *usersToDownload = [NSMutableArray array];
    BOOL doANewQuery = NO;

    for (NSString *userId in userIds)
    {
        if (![MXTools isMatrixUserIdentifier:userId])
        {
            NSLog(@"[MXDeviceList] downloadKeys: ERROR: Ignore malformed user id: %@", userId);
            continue;
        }

        MXDeviceTrackingStatus trackingStatus = MXDeviceTrackingStatusFromNSNumber(deviceTrackingStatus[userId]);

        if (trackingStatus == MXDeviceTrackingStatusDownloadInProgress)
        {
            // already a key download in progress/queued for this user; its results
            // will be good enough for us.
            [usersToDownload addObject:userId];
        }
        else if (forceDownload
                    || (trackingStatus != MXDeviceTrackingStatusUpToDate && trackingStatus != MXDeviceTrackingStatusUnreachableServer))
        {
            [usersToDownload addObject:userId];
            doANewQuery = YES;
        }
        else
        {
            NSLog(@"[MXDeviceList] downloadKeys: Skip user %@. trackingStatus: %@", userId, @(trackingStatus));
        }
    }

    __block MXDeviceListOperation *operation;

    if (usersToDownload.count)
    {
        NSLog(@"[MXDeviceList] downloadKeys for actually %tu users: %@", usersToDownload.count, usersToDownload);

        for (NSString *userId in usersToDownload)
        {
            deviceTrackingStatus[userId] = @(MXDeviceTrackingStatusDownloadInProgress);
        }

        // Persist the tracking status before launching download
        [self persistDeviceTrackingStatus];

        MXWeakify(self);
        operation = [[MXDeviceListOperation alloc] initWithUserIds:usersToDownload success:^(NSArray<NSString *> *succeededUserIds, NSArray<NSString *> *failedUserIds) {
            MXStrongifyAndReturnIfNil(self);

            NSLog(@"[MXDeviceList] downloadKeys (operation: %p) -> DONE", operation);

            for (NSString *userId in succeededUserIds)
            {
                // we may have queued up another download request for this user
                // since we started this request. If that happens, we should
                // ignore the completion of the first one.
                if (self->keyDownloadsInProgressByUser[userId] != operation)
                {
                    NSLog(@"[MXDeviceList] downloadKeys: Another update (operation: %p) in the queue for %@ - not marking up-to-date", self->keyDownloadsInProgressByUser[userId], userId);
                    continue;
                }
                [self->keyDownloadsInProgressByUser removeObjectForKey:userId];

                MXDeviceTrackingStatus trackingStatus = MXDeviceTrackingStatusFromNSNumber(self->deviceTrackingStatus[userId]);
                if (trackingStatus == MXDeviceTrackingStatusDownloadInProgress)
                {
                    // we didn't get any new invalidations since this download started:
                    // this user's device list is now up to date.
                    self->deviceTrackingStatus[userId] = @(MXDeviceTrackingStatusUpToDate);
                }
            }

            if (failedUserIds.count)
            {
                NSLog(@"[MXDeviceList] downloadKeys. Error updating device keys for users %@", failedUserIds);

                for (NSString *userId in failedUserIds)
                {
                    MXDeviceTrackingStatus trackingStatus = MXDeviceTrackingStatusFromNSNumber(self->deviceTrackingStatus[userId]);
                    if (trackingStatus == MXDeviceTrackingStatusDownloadInProgress)
                    {
                        self->deviceTrackingStatus[userId] = @(MXDeviceTrackingStatusUnreachableServer);
                    }
                }
            }

            [self persistDeviceTrackingStatus];

            if (success)
            {
                MXUsersDevicesMap<MXDeviceInfo *> *usersDevicesInfoMap = [self devicesForUsers:userIds];
                NSDictionary<NSString* , MXCrossSigningInfo*> *crossSigningKeysMap = [self crossSigningKeysForUsers:userIds];
                success(usersDevicesInfoMap, crossSigningKeysMap);
            }

        } failure:failure];

        for (NSString *userId in usersToDownload)
        {
            keyDownloadsInProgressByUser[userId] = operation;
        }
        
        if (currentQueryPool && doANewQuery == NO)
        {
            // Before reusing currentQueryPool, make sure it has all requested user ids
            BOOL containsAllUserIds = [currentQueryPool hasUsers:operation.userIds];
            if (containsAllUserIds == NO)
            {
                // It does not have all
                // Some user ids are in nextQueryPool
                doANewQuery = YES;
            }
        }

        if (doANewQuery || !currentQueryPool)
        {
            NSLog(@"[MXDeviceList] downloadKeys: waiting for next key query. Operation: %p", operation);

            [self startOrQueueDeviceQuery:operation];
        }
        else
        {
            NSLog(@"[MXDeviceList] downloadKeys: waiting for in-flight query to complete. Operation: %p", operation);
            [operation addToPool:currentQueryPool];
        }
    }
    else
    {
        NSLog(@"[MXDeviceList] downloadKeys: already have all necessary keys");
        if (success)
        {
            success([self devicesForUsers:userIds],
                    [self crossSigningKeysForUsers:userIds]);
        }
    }

    return operation;
}

- (NSArray<MXDeviceInfo *> *)storedDevicesForUser:(NSString *)userId
{
    return [crypto.store devicesForUser:userId].allValues;
}

- (MXDeviceInfo*)storedDevice:(NSString*)userId deviceId:(NSString*)deviceId
{
    return [crypto.store devicesForUser:userId][deviceId];
}

- (MXDeviceInfo *)deviceWithIdentityKey:(NSString *)senderKey andAlgorithm:(NSString *)algorithm
{
    if (![algorithm isEqualToString:kMXCryptoOlmAlgorithm]
        && ![algorithm isEqualToString:kMXCryptoMegolmAlgorithm])
    {
        // We only deal in olm keys
        return nil;
    }

    return [crypto.store deviceWithIdentityKey:senderKey];
}

- (void)startTrackingDeviceList:(NSString*)userId
{
    if (![MXTools isMatrixUserIdentifier:userId])
    {
        NSLog(@"[MXDeviceList] startTrackingDeviceList: ERROR: Ignore malformed user id: %@", userId);
        return;
    }

    MXDeviceTrackingStatus trackingStatus = MXDeviceTrackingStatusFromNSNumber(deviceTrackingStatus[userId]);

    if (!trackingStatus)
    {
        NSLog(@"[MXDeviceList] Now tracking device list for %@", userId);
        deviceTrackingStatus[userId] = @(MXDeviceTrackingStatusPendingDownload);
    }
    // we don't yet persist the tracking status, since there may be a lot
    // of calls; instead we wait for the forthcoming
    // refreshOutdatedDeviceLists.
}

- (void)stopTrackingDeviceList:(NSString *)userId
{
    MXDeviceTrackingStatus trackingStatus = MXDeviceTrackingStatusFromNSNumber(deviceTrackingStatus[userId]);

    if (trackingStatus)
    {
        NSLog(@"[MXDeviceList] No longer tracking device list for %@", userId);
        deviceTrackingStatus[userId] = @(MXDeviceTrackingStatusNotTracked);
    }
    // we don't yet persist the tracking status, since there may be a lot
    // of calls; instead we wait for the forthcoming
    // refreshOutdatedDeviceLists.
}

- (void)invalidateUserDeviceList:(NSString *)userId
{
    MXDeviceTrackingStatus trackingStatus = MXDeviceTrackingStatusFromNSNumber(deviceTrackingStatus[userId]);

    if (trackingStatus)
    {
        NSLog(@"[MXDeviceList] Marking device list outdated for %@", userId);
        deviceTrackingStatus[userId] = @(MXDeviceTrackingStatusPendingDownload);
    }
    // we don't yet persist the tracking status, since there may be a lot
    // of calls; instead we wait for the forthcoming
    // refreshOutdatedDeviceLists.
}

- (void)invalidateAllDeviceLists;
{
    for (NSString *userId in deviceTrackingStatus.allKeys)
    {
        [self invalidateUserDeviceList:userId];
    }
}

- (void)refreshOutdatedDeviceLists
{
    NSMutableArray *users = [NSMutableArray array];
    for (NSString *userId in deviceTrackingStatus)
    {
        MXDeviceTrackingStatus trackingStatus = MXDeviceTrackingStatusFromNSNumber(deviceTrackingStatus[userId]);
        if (trackingStatus == MXDeviceTrackingStatusPendingDownload)
            // || trackingStatus == MXDeviceTrackingStatusUnreachableServer)  // TODO: It would be nice to retry them sometimes.
                                                                              // At the moment, they are retried after app restart
        {
            [users addObject:userId];
        }
    }

    if (users.count)
    {
        [self downloadKeys:users forceDownload:NO success:^(MXUsersDevicesMap<MXDeviceInfo *> *usersDevicesInfoMap, NSDictionary<NSString *,MXCrossSigningInfo *> *crossSigningKeysMap) {
            NSLog(@"[MXDeviceList] refreshOutdatedDeviceLists (users: %tu): %@", usersDevicesInfoMap.userIds.count, usersDevicesInfoMap.userIds);
        } failure:^(NSError *error) {
            NSLog(@"[MXDeviceList] refreshOutdatedDeviceLists: ERROR updating device keys for users %@", users);
        }];
    }
}

- (void)persistDeviceTrackingStatus
{
    [crypto.store storeDeviceTrackingStatus:deviceTrackingStatus];
}

/**
 Get the stored device keys for a list of user ids.

 @param userIds the list of users to list keys for.
 @return users devices.
*/
- (MXUsersDevicesMap<MXDeviceInfo*> *)devicesForUsers:(NSArray<NSString*>*)userIds
{
    MXUsersDevicesMap<MXDeviceInfo*> *usersDevicesInfoMap = [[MXUsersDevicesMap alloc] init];

    for (NSString *userId in userIds)
    {
        // Retrive the data from the store
        NSDictionary<NSString*, MXDeviceInfo*> *devices = [crypto.store devicesForUser:userId];
        if (devices)
        {
            [usersDevicesInfoMap setObjects:devices forUser:userId];
        }
    }

    NSLog(@"[MXDeviceList] devicesForUsers: %@", usersDevicesInfoMap);

    return usersDevicesInfoMap;
}

/**
 Get the stored cross-signing keys for a list of user ids.

 @param userIds the list of users to list keys for.
 @return users cross-signing keys.
 */
- (NSDictionary<NSString* /* userId*/, MXCrossSigningInfo*> *)crossSigningKeysForUsers:(NSArray<NSString*>*)userIds
{
    NSMutableDictionary<NSString* , MXCrossSigningInfo*> *crossSigningKeysMap = [NSMutableDictionary dictionary];

    for (NSString *userId in userIds)
    {
        // Retrive the data from the store
        MXCrossSigningInfo *crossSigningKeys = [crypto.store crossSigningKeysForUser:userId];
        if (crossSigningKeys)
        {
            crossSigningKeysMap[userId] = crossSigningKeys;
        }
    }

    return crossSigningKeysMap;
}


- (void)startOrQueueDeviceQuery:(MXDeviceListOperation *)operation
{
    if (!currentQueryPool)
    {
        // No pool is currently being queried
        if (nextQueryPool)
        {
            // Launch the query for the existing next pool
            currentQueryPool = nextQueryPool;
            nextQueryPool = nil;
        }
        else
        {
            // Create a new pool to query right now
            currentQueryPool = [[MXDeviceListOperationsPool alloc] initWithCrypto:crypto];
        }

        [operation addToPool:currentQueryPool];
        [self startCurrentPoolQuery];
    }
    else
    {
        // Append the device list operation to the next pool
        if (!nextQueryPool)
        {
            nextQueryPool = [[MXDeviceListOperationsPool alloc] initWithCrypto:crypto];
        }
        [operation addToPool:nextQueryPool];
    }
}

- (void)startCurrentPoolQuery
{
    NSLog(@"[MXDeviceList] startCurrentPoolQuery(pool: %p) (users: %tu): %@", currentQueryPool, currentQueryPool.userIds.count, currentQueryPool.userIds);

    if (currentQueryPool.userIds)
    {
        NSString *token = _lastKnownSyncToken;

        // Add token
        MXWeakify(self);
        [currentQueryPool downloadKeys:token complete:^(NSDictionary<NSString *,NSDictionary *> *failedUserIds) {
            MXStrongifyAndReturnIfNil(self);

            NSLog(@"[MXDeviceList] startCurrentPoolQuery(pool: %p) -> DONE. failedUserIds (users: %tu): %@", self->currentQueryPool, failedUserIds.count, failedUserIds);

            if (token)
            {
                [self->crypto.store storeDeviceSyncToken:token];
            }

            self->currentQueryPool = nil;
            if (self->nextQueryPool)
            {
                self->currentQueryPool = self->nextQueryPool;
                self->nextQueryPool = nil;
                [self startCurrentPoolQuery];
            }
        }];
    }
}

@end

#endif
