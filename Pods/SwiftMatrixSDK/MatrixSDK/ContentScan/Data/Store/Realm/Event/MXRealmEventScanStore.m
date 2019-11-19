/*
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

#import "MXRealmEventScanStore.h"

#import <Realm/Realm.h>
#import "MXScanRealmProvider.h"
#import "MXRealmEventScan.h"
#import "MXEventScan.h"
#import "MXRealmEventScanMapper.h"
#import "MXRealmMediaScanStore.h"
#import "MXTools.h"

@interface MXRealmEventScanStore()

@property (nonatomic, strong) id<MXScanRealmProvider> realmProvider;
@property (nonatomic, strong) MXRealmEventScanMapper *realmEventScanMapper;
@property (nonatomic, strong) MXRealmMediaScanStore *realmMediaScanStore;

@property (nonatomic, strong, readonly) RLMRealm *realm;

@property (nonatomic, strong) RLMNotificationToken *eventScansNotificationToken;

@end

@implementation MXRealmEventScanStore

#pragma mark - Setup

- (nullable instancetype)initWithRealmProvider:(nonnull id<MXScanRealmProvider>)realmProvider
{
    self = [super init];
    if (self)
    {
        _realmProvider = realmProvider;
        _realmEventScanMapper = [MXRealmEventScanMapper new];
        _realmMediaScanStore = [[MXRealmMediaScanStore alloc] initWithRealmProvider:realmProvider];
    }
    return self;
}

#pragma mark - Properties overrides

- (RLMRealm*)realm
{
    return [self.realmProvider realm];
}

- (void)setDelegate:(id<MXEventScanStoreDelegate>)delegate
{
    _delegate = delegate;
    
    // Register to database changes only when setting a delegate
    if (delegate)
    {
        [self registerToEventScanChanges];
    }
    else
    {
        [self unregisterToEventScanChanges];
    }
}

#pragma mark - Public

- (nonnull MXEventScan *)createOrUpdateWithId:(nonnull NSString *)eventId andMediaURLs:(nonnull NSArray<NSString *> *)mediaURLs
{
    return [self createOrUpdateWithId:eventId initialAntivirusStatus:MXAntivirusScanStatusUnknown andMediaURLs:mediaURLs];
}

- (nonnull MXEventScan *)createOrUpdateWithId:(nonnull NSString *)eventId initialAntivirusStatus:(MXAntivirusScanStatus)initialAntivirusScanStatus andMediaURLs:(nonnull NSArray<NSString*>*)mediaURLs
{
    RLMRealm *realm = self.realm;
    
    __block MXRealmEventScan *realmEventScan;
    
    [realm transactionWithBlock:^{
        
        MXRealmEventScan *foundRealmEventScan = [self findRealmEventScanWithId:eventId inRealm:realm];
        
        NSArray<MXRealmMediaScan*> *realmMediaScans = [self.realmMediaScanStore findOrCreateRealmMediaScansWithURLs:mediaURLs initialAntivirusStatus:MXAntivirusScanStatusUnknown inRealm:realm useTransaction:NO];
        
        NSMutableDictionary *eventValues = [NSMutableDictionary new];
        
        eventValues[MXRealmEventScanAttributes.eventId] = eventId;
        eventValues[MXRealmEventScanRelationships.mediaScans] = realmMediaScans;

        // If event scan do not already exist take `initialAntivirusScanStatus` into account
        if (!foundRealmEventScan)
        {
            eventValues[MXRealmEventScanAttributes.antivirusScanStatusRawValue] = @(initialAntivirusScanStatus);
        }
        
        realmEventScan = [MXRealmEventScan createOrUpdateInRealm:realm withValue:eventValues];
    }];
    
    return [self.realmEventScanMapper eventScanFromRealmEventScan:realmEventScan];
}

- (nullable MXEventScan *)findWithId:(nonnull NSString *)eventId
{
    MXEventScan *eventScan;
    
    RLMRealm *realm = self.realm;
    MXRealmEventScan *realmEventScan = [self findRealmEventScanWithId:eventId inRealm:realm];
    
    if (realmEventScan)
    {
        eventScan = [self.realmEventScanMapper eventScanFromRealmEventScan:realmEventScan];
    }
    
    return eventScan;
}

- (BOOL)updateAntivirusScanStatus:(MXAntivirusScanStatus)antivirusScanStatus forId:(nonnull NSString *)eventId
{
    __block BOOL success = NO;
    
    RLMRealm *realm = self.realm;
    
    [realm transactionWithBlock:^{
        MXRealmEventScan *realmEventScan = [self findRealmEventScanWithId:eventId inRealm:realm];
        
        if (realmEventScan)
        {
            if (realmEventScan.antivirusScanStatus != antivirusScanStatus)
            {
                realmEventScan.antivirusScanStatusRawValue = antivirusScanStatus;
            }
            
            success = YES;
        }
    }];
    
    return success;
}


- (BOOL)updateAntivirusScanStatusFromMediaScansAntivirusScanStatusesAndAntivirusScanDate:(nonnull NSDate *)antivirusScanDate forId:(nonnull NSString *)eventId
{
    __block BOOL success = NO;
    
    RLMRealm *realm = self.realm;
    
    [realm transactionWithBlock:^{
        MXRealmEventScan *realmEventScan = [self findRealmEventScanWithId:eventId inRealm:realm];
        
        if (realmEventScan)
        {
            MXAntivirusScanStatus antivirusScanStatus = [self antivirusScanStatusFromRealmMediaScans:realmEventScan.mediaScans];
            
            if (realmEventScan.antivirusScanStatus != antivirusScanStatus)
            {
                realmEventScan.antivirusScanStatusRawValue = antivirusScanStatus;
            }
            
            realmEventScan.antivirusScanDate = antivirusScanDate;
            
            success = YES;
        }
    }];
    
    return success;
}

- (void)resetAllAntivirusScanStatusInProgressToUnknown
{
    RLMRealm *realm = self.realm;
    
    [realm transactionWithBlock:^{
        RLMResults *eventScansInProgress = [MXRealmEventScan objectsInRealm:realm where:@"%K = %d", MXRealmEventScanAttributes.antivirusScanStatusRawValue, MXAntivirusScanStatusInProgress];
        for (MXRealmEventScan *eventScan in eventScansInProgress)
        {
            eventScan.antivirusScanStatusRawValue = MXAntivirusScanStatusUnknown;
        }
    }];
}

- (void)deleteAll
{
    RLMRealm *realm = self.realm;
    
    __block NSArray *deletedEventScans;
    
    [realm transactionWithBlock:^{
        RLMResults *realmEventScansToDelete = [MXRealmEventScan objectsInRealm:realm withPredicate:nil];
        deletedEventScans = [self eventScansFromResults:realmEventScansToDelete];
        [realm deleteObjects:realmEventScansToDelete];
    }];
    
    [self warnDelegateOfChangeWithInsertions:@[] modifications:@[] deletions:deletedEventScans];
}

#pragma mark - Private

- (MXRealmEventScan*)findRealmEventScanWithId:(NSString*)eventId inRealm:(RLMRealm*)realm
{
    return [[MXRealmEventScan objectsInRealm:realm where:@"%K = %@", MXRealmEventScanAttributes.eventId, eventId] firstObject];
}

- (MXAntivirusScanStatus)antivirusScanStatusFromRealmMediaScans:(RLMArray<MXRealmMediaScan *><MXRealmMediaScan>*)realmMediaScans
{
    // If all medias are trusted the event is trusted
    MXAntivirusScanStatus eventAntivirusStatus = MXAntivirusScanStatusTrusted;
    
    for (MXRealmMediaScan *realmMediaScan in realmMediaScans)
    {
        MXAntivirusScanStatus mediaAntivirusStatus = realmMediaScan.antivirusScanStatus;
        
        // If one media is infected the event is considered infected
        if (mediaAntivirusStatus == MXAntivirusScanStatusInfected)
        {
            eventAntivirusStatus = MXAntivirusScanStatusInfected;
            break;
        }
        else
        {
            switch (mediaAntivirusStatus) {
                case MXAntivirusScanStatusInProgress:
                    // If one media is in progress the event is in progress
                    eventAntivirusStatus = MXAntivirusScanStatusInProgress;
                    break;
                case MXAntivirusScanStatusUnknown:
                    // If some media are trusted but other unknown the event is unknown
                    if (eventAntivirusStatus != MXAntivirusScanStatusInProgress)
                    {
                        eventAntivirusStatus = MXAntivirusScanStatusUnknown;
                    }
                    break;
                default:
                    break;
            }
        }
    }
    
    return eventAntivirusStatus;
}

- (void)registerToEventScanChanges
{
    if (self.eventScansNotificationToken)
    {
        return;
    }
    
    MXWeakify(self);
    
    self.eventScansNotificationToken = [[MXRealmEventScan objectsInRealm:self.realm withPredicate:nil] addNotificationBlock:^(RLMResults * _Nullable results, RLMCollectionChange * _Nullable change, NSError * _Nullable error) {
        
        MXStrongifyAndReturnIfNil(self);
        
        if (error)
        {
            NSLog(@"[MXRealmEventScanStore] Failed to open Realm on background worker: %@", error);
        }
        else if (change)
        {
            NSArray<MXEventScan*> *insertions = [self eventScansFromResults:results atIndexes:change.insertions];
            NSArray<MXEventScan*> *modifications = [self eventScansFromResults:results atIndexes:change.modifications];
            
            if (insertions.count || modifications.count)
            {
                [self warnDelegateOfChangeWithInsertions:insertions modifications:modifications deletions:@[]];
            }
        }
    }];
}

- (void)warnDelegateOfChangeWithInsertions:(nonnull NSArray<MXEventScan*>*)insertions modifications:(nonnull NSArray<MXEventScan*>*)modifications deletions:(nonnull NSArray<MXEventScan*>*)deletions
{
    [self.delegate eventScanStore:(MXEventScanStore*)self didObserveChangesWithInsertions:insertions modifications:modifications deletions:deletions];
}

- (void)unregisterToEventScanChanges
{
    self.eventScansNotificationToken = nil;
}

- (nonnull NSArray<MXEventScan*>*)eventScansFromResults:(nonnull RLMResults*)results atIndexes:(nonnull NSArray<NSNumber*>*)indexes
{
    NSMutableArray<MXEventScan*> *eventScans = [NSMutableArray new];
    
    for (NSNumber *index in indexes)
    {
        if (index.integerValue < results.count)
        {
            MXRealmEventScan *realmEventScan = [results objectAtIndex:index.integerValue];
            MXEventScan *eventScan = [self.realmEventScanMapper eventScanFromRealmEventScan:realmEventScan];
            [eventScans addObject:eventScan];
        }
    }
    
    return eventScans;
}

- (nonnull NSArray<MXEventScan*>*)eventScansFromResults:(nonnull RLMResults*)results
{
    NSMutableArray<MXEventScan*> *eventScans = [NSMutableArray new];
    
    for (MXRealmEventScan *realmEventScan in results)
    {
        MXEventScan *eventScan = [self.realmEventScanMapper eventScanFromRealmEventScan:realmEventScan];
        [eventScans addObject:eventScan];
    }
    
    return eventScans;
}

@end
