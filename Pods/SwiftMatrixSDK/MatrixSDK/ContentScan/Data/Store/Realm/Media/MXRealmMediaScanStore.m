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

#import "MXRealmMediaScanStore.h"

#import "MXMediaScan.h"
#import "MXRealmMediaScan.h"
#import "MXRealmHelper.h"
#import "MXTools.h"
#import "MXScanRealmProvider.h"
#import "MXRealmMediaScanMapper.h"

@interface MXRealmMediaScanStore()

@property (nonatomic, strong) id<MXScanRealmProvider> realmProvider;
@property (nonatomic, strong) MXRealmMediaScanMapper *realmMediaScanMapper;

@property (nonatomic, strong, readonly) RLMRealm *realm;

@property (nonatomic, strong) RLMNotificationToken *mediaScansNotificationToken;

@end

@implementation MXRealmMediaScanStore

#pragma mark - Setup

- (nullable instancetype)initWithRealmProvider:(nonnull id<MXScanRealmProvider>)realmProvider
{
    self = [super init];
    if (self)
    {
        _realmProvider = realmProvider;
        _realmMediaScanMapper = [MXRealmMediaScanMapper new];
    }
    return self;
}

#pragma mark - Properties overrides

- (void)setDelegate:(id<MXMediaScanStoreDelegate>)delegate
{
    _delegate = delegate;
    
    // Register to database changes only when setting a delegate
    if (delegate)
    {
        [self registerToMediaScanChanges];
    }
    else
    {
        [self unregisterToMediaScanChanges];
    }
}

- (RLMRealm*)realm
{
    return [self.realmProvider realm];
}

#pragma mark - Public

- (nonnull MXMediaScan*)findOrCreateWithURL:(nonnull NSString*)url
{
    RLMRealm *realm = self.realm;
    
    MXRealmMediaScan *realmMediaScan = [self findOrCreateRealmMediaScanWithURL:url inRealm:realm useTransaction:YES];
    
    return [self.realmMediaScanMapper mediaScanFromRealmMediaScan:realmMediaScan];
}

- (nonnull MXMediaScan*)findOrCreateWithURL:(nonnull NSString*)url initialAntivirusStatus:(MXAntivirusScanStatus)antivirusScanStatus
{
    RLMRealm *realm = self.realm;
    
    MXRealmMediaScan *realmMediaScan = [self findOrCreateRealmMediaScanWithURL:url initialAntivirusScanStatus:antivirusScanStatus inRealm:realm useTransaction:YES];
    
    return [self.realmMediaScanMapper mediaScanFromRealmMediaScan:realmMediaScan];
}

- (nullable MXMediaScan*)findWithURL:(nonnull NSString*)url
{
    MXMediaScan *mediaScan;
    
    RLMRealm *realm = self.realm;
    MXRealmMediaScan *realmMediaScan = [self findRealmMediaScanWithURL:url inRealm:realm];
    
    if (realmMediaScan)
    {
        mediaScan = [self.realmMediaScanMapper mediaScanFromRealmMediaScan:realmMediaScan];
    }
    
    return mediaScan;
}

- (BOOL)updateAntivirusScanStatus:(MXAntivirusScanStatus)antivirusScanStatus forURL:(nonnull NSString *)url
{
    return [self updateRealmMediaScanWithURL:url updateHandler:^(MXRealmMediaScan *realmMediaScan) {
        realmMediaScan.antivirusScanStatusRawValue = antivirusScanStatus;
    }];
}

- (BOOL)updateAntivirusScanStatus:(MXAntivirusScanStatus)antivirusScanStatus antivirusScanInfo:(NSString *)antivirusScanInfo antivirusScanDate:(nonnull NSDate *)antivirusScanDate forURL:(nonnull NSString *)url
{
    return [self updateRealmMediaScanWithURL:url updateHandler:^(MXRealmMediaScan *realmMediaScan) {
        realmMediaScan.antivirusScanStatusRawValue = antivirusScanStatus;
        realmMediaScan.antivirusScanInfo = antivirusScanInfo;
        realmMediaScan.antivirusScanDate = antivirusScanDate;
    }];
}

- (void)resetAllAntivirusScanStatusInProgressToUnknown
{
    RLMRealm *realm = self.realm;
    
    [realm transactionWithBlock:^{
        RLMResults *mediaScansInProgress = [MXRealmMediaScan objectsInRealm:realm where:@"%K = %d", MXRealmMediaScanAttributes.antivirusScanStatusRawValue, MXAntivirusScanStatusInProgress];
        for (MXRealmMediaScan *mediaScan in mediaScansInProgress)
        {
            mediaScan.antivirusScanStatusRawValue = MXAntivirusScanStatusUnknown;
        }
    }];
}

- (nonnull NSArray<MXRealmMediaScan*>*)findOrCreateRealmMediaScansWithURLs:(nonnull NSArray<NSString*>*)urls
                                                    initialAntivirusStatus:(MXAntivirusScanStatus)antivirusScanStatus
                                                                   inRealm:(nonnull RLMRealm*)realm
                                                            useTransaction:(BOOL)useTransaction;
{
    NSMutableArray<MXRealmMediaScan*> *realmMediaScans = [NSMutableArray new];
    
    for (NSString *url in urls)
    {
        MXRealmMediaScan *realmMediaScan = [self findOrCreateRealmMediaScanWithURL:url initialAntivirusScanStatus:antivirusScanStatus inRealm:realm useTransaction:useTransaction];
        [realmMediaScans addObject:realmMediaScan];
    }
    
    return realmMediaScans;
}

- (void)deleteAll
{
    RLMRealm *realm = self.realm;
    
    __block NSArray *deletedMediaScans;
    
    [realm transactionWithBlock:^{
        RLMResults *realmMediaScansToDelete = [MXRealmMediaScan objectsInRealm:realm withPredicate:nil];
        deletedMediaScans = [self mediaScansFromResults:realmMediaScansToDelete];
        [realm deleteObjects:realmMediaScansToDelete];
    }];
    
    [self warnDelegateOfChangeWithInsertions:@[] modifications:@[] deletions:deletedMediaScans];
}

#pragma mark - Private

- (nonnull MXRealmMediaScan*)findOrCreateRealmMediaScanWithURL:(nonnull NSString*)url inRealm:(nonnull RLMRealm*)realm useTransaction:(BOOL)useTransaction
{
    return [self findOrCreateRealmMediaScanWithURL:url initialAntivirusScanStatus:MXAntivirusScanStatusUnknown inRealm:realm useTransaction:useTransaction];
}

- (nonnull MXRealmMediaScan*)findOrCreateRealmMediaScanWithURL:(nonnull NSString*)url
                                    initialAntivirusScanStatus:(MXAntivirusScanStatus)initialAntivirusScanStatus
                                                       inRealm:(nonnull RLMRealm*)realm
                                                useTransaction:(BOOL)useTransaction
{
    __block MXRealmMediaScan *realmMediaScan;
    
    void (^realmOperations)(void) = ^{
        realmMediaScan = [self findRealmMediaScanWithURL:url inRealm:realm];
        
        if (!realmMediaScan)
        {
            realmMediaScan = [MXRealmMediaScan new];
            realmMediaScan.url = url;
            realmMediaScan.antivirusScanStatusRawValue = initialAntivirusScanStatus;
            
            [realm addOrUpdateObject:realmMediaScan];
        }
    };
    
    if (useTransaction)
    {
        [realm transactionWithBlock:^{
            realmOperations();
        }];
    }
    else
    {
        realmOperations();
    }
    
    return realmMediaScan;
}

- (nullable MXRealmMediaScan*)findRealmMediaScanWithURL:(NSString*)url inRealm:(nonnull RLMRealm*)realm
{
    return [[MXRealmMediaScan objectsInRealm:realm where:@"%K = %@", MXRealmMediaScanAttributes.url, url] firstObject];
}

- (BOOL)updateRealmMediaScanWithURL:(nonnull NSString*)url updateHandler:(void (^)(MXRealmMediaScan*))updateHandler
{
    __block BOOL updated = NO;
    
    RLMRealm *realm = self.realm;
    
    [realm transactionWithBlock:^{
        
        MXRealmMediaScan *realmMediaScan = [self findRealmMediaScanWithURL:url inRealm:realm];
        
        if (realmMediaScan)
        {
            updateHandler(realmMediaScan);
            updated = YES;
        }
    }];
    
    return updated;
}

- (void)warnDelegateOfChangeWithInsertions:(nonnull NSArray<MXMediaScan*>*)insertions modifications:(nonnull NSArray<MXMediaScan*>*)modifications deletions:(nonnull NSArray<MXMediaScan*>*)deletions
{
    [self.delegate mediaScanStore:(MXMediaScanStore*)self didObserveChangesWithInsertions:insertions modifications:modifications deletions:deletions];
}

- (void)registerToMediaScanChanges
{
    if (self.mediaScansNotificationToken)
    {
        return;
    }
    
    MXWeakify(self);
    
    self.mediaScansNotificationToken = [[MXRealmMediaScan objectsInRealm:self.realm withPredicate:nil] addNotificationBlock:^(RLMResults * _Nullable results, RLMCollectionChange * _Nullable change, NSError * _Nullable error) {
        
        MXStrongifyAndReturnIfNil(self);

        if (error)
        {
            NSLog(@"[MXRealmMediaScanStore] Failed to open Realm on background worker: %@", error);
        }
        else if (change)
        {            
            NSArray<MXMediaScan*> *insertions = [self mediaScansFromResults:results atIndexes:change.insertions];
            NSArray<MXMediaScan*> *modifications = [self mediaScansFromResults:results atIndexes:change.modifications];
            
            if (insertions.count || modifications.count)
            {
                [self warnDelegateOfChangeWithInsertions:insertions modifications:modifications deletions:@[]];
            }
        }
    }];
}

- (void)unregisterToMediaScanChanges
{
    self.mediaScansNotificationToken = nil;
}

- (nonnull NSArray<MXMediaScan*>*)mediaScansFromResults:(nonnull RLMResults*)results atIndexes:(nonnull NSArray<NSNumber*>*)indexes
{
    NSMutableArray<MXMediaScan*> *mediaScans = [NSMutableArray new];
    
    for (NSNumber *index in indexes)
    {
        if (index.integerValue < results.count)
        {
            MXRealmMediaScan *realmMediaScan = [results objectAtIndex:index.integerValue];
            MXMediaScan *mediaScan = [self.realmMediaScanMapper mediaScanFromRealmMediaScan:realmMediaScan];
            [mediaScans addObject:mediaScan];
        }
    }
    
    return mediaScans;
}

- (nonnull NSArray<MXMediaScan*>*)mediaScansFromResults:(nonnull RLMResults*)results
{
    NSMutableArray<MXMediaScan*> *mediaScans = [NSMutableArray new];
    
    for (MXRealmMediaScan *realmMediaScan in results)
    {
        MXMediaScan *mediaScan = [self.realmMediaScanMapper mediaScanFromRealmMediaScan:realmMediaScan];
        [mediaScans addObject:mediaScan];
    }
    
    return mediaScans;
}

@end
