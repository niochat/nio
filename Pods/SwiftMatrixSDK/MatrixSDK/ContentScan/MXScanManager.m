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

#import "MXScanManager.h"
#import <OLMKit/OLMKit.h>

#import "MXMediaScanStore.h"
#import "MXRealmMediaScanStore.h"
#import "MXMediaScan.h"

#import "MXEventScanStore.h"
#import "MXRealmEventScanStore.h"
#import "MXEventScan.h"

#import "MXRestClient.h"
#import "MXTools.h"
#import "MXScanRealmFileProvider.h"

#pragma mark - Defines & Constants

NSString *const MXScanManagerEventScanDidChangeNotification = @"MXScanManagerEventScanDidChangeNotification";

NSString *const MXScanManagerMediaScanDidChangeNotification = @"MXScanManagerMediaScanDidChangeNotification";

NSString *const MXScanManagerScanDidChangeNotificationInsertionsUserInfoKey = @"insertions";
NSString *const MXScanManagerScanDidChangeNotificationModificationsUserInfoKey = @"modifications";
NSString *const MXScanManagerScanDidChangeNotificationDeletionsUserInfoKey = @"deletions";

NSString *const MXErrorContentScannerReasonKey                  = @"reason";
NSString *const MXErrorContentScannerReasonValueBadDecryption   = @"MCS_BAD_DECRYPTION";

static NSTimeInterval const kDefaultScanUpdateInterval = 120;
static const char * const kProcessingQueueName = "org.MatrixSDK.MXScanManager";

#pragma mark - Private Interface

@interface MXScanManager () <MXMediaScanStoreDelegate, MXEventScanStoreDelegate>

@property (nonatomic, strong) id<MXScanRealmProvider> realmProvider;
@property (nonatomic, strong) id<MXMediaScanStore> mediaScanStore;
@property (nonatomic, strong) id<MXEventScanStore> eventScanStore;

@property (nonatomic, strong) MXRestClient *restClient;
@property (nonatomic) NSTimeInterval scanInterval;
@property (nonatomic) NSString *serverPublicKey;

@property (nonatomic, strong) dispatch_queue_t processingQueue;

@end

#pragma mark - Implementation

@implementation MXScanManager

#pragma mark - Setup

- (instancetype)initWithRestClient:(MXRestClient*)restClient
{
    self = [super init];
    if (self)
    {
        NSString *antivirusServerDomain;
        NSURLComponents *antivirusURLComponents = [[NSURLComponents alloc] initWithString:restClient.antivirusServer];
        antivirusServerDomain = antivirusURLComponents.host;
        
        if (antivirusServerDomain)
        {
            _restClient = restClient;
            _antivirusServerURL = restClient.antivirusServer;
            _antivirusServerPathPrefix = restClient.antivirusServerPathPrefix;
            _enableEncryptedBoby = YES;
            id<MXScanRealmProvider> scanRealmProvider = [[MXScanRealmFileProvider alloc] initWithAntivirusServerDomain:antivirusServerDomain];
            _mediaScanStore = [[MXRealmMediaScanStore alloc] initWithRealmProvider:scanRealmProvider];
            _eventScanStore = [[MXRealmEventScanStore alloc] initWithRealmProvider:scanRealmProvider];
            _realmProvider = scanRealmProvider;
            _scanInterval = kDefaultScanUpdateInterval;
            _processingQueue = dispatch_queue_create(kProcessingQueueName, DISPATCH_QUEUE_CONCURRENT);
            _completionQueue = dispatch_get_main_queue();
            _mediaScanStore.delegate = self;
            _eventScanStore.delegate = self;
        }
        else
        {
            return nil;
        }
    }
    return self;
}

#pragma mark - Public

- (void)resetAllAntivirusScanStatusInProgressToUnknown
{    
    [self.mediaScanStore resetAllAntivirusScanStatusInProgressToUnknown];
    [self.eventScanStore resetAllAntivirusScanStatusInProgressToUnknown];
}

- (void)deleteAllAntivirusScans
{
    [self.eventScanStore deleteAll];
    [self.mediaScanStore deleteAll];
}

#pragma mark Media

- (nullable MXMediaScan*)mediaScanWithURL:(nonnull NSString*)mediaURL
{
    return [self.mediaScanStore findOrCreateWithURL:mediaURL];
}

- (void)scanUnencryptedMediaWithURL:(nonnull NSString*)mediaURL completion:(void (^ _Nullable)(MXMediaScan* _Nullable mediaScan, BOOL mediaScanDidSucceed))completion
{
    [self scanUnencryptedMediaWithURL:mediaURL orEncryptedFile:nil completion:completion];
}

- (void)scanUnencryptedMediaIfNeededWithURL:(nonnull NSString*)mediaURL
{
    [self scanUnencryptedMediaWithURL:mediaURL completion:nil];
}

- (void)scanEncryptedMediaWithEncryptedFile:(nonnull MXEncryptedContentFile*)encryptedContentFile completion:(void (^ _Nullable)(MXMediaScan* _Nullable mediaScan, BOOL mediaScanDidSucceed))completion
{
    [self scanUnencryptedMediaWithURL:nil orEncryptedFile:encryptedContentFile completion:completion];
}

- (void)scanEncryptedMediaIfNeededWithEncryptedFile:(nonnull MXEncryptedContentFile*)encryptedContentFile
{
    [self scanEncryptedMediaWithEncryptedFile:encryptedContentFile completion:nil];
}

#pragma mark Event

- (nullable MXEventScan*)eventScanWithId:(nonnull NSString*)eventId
{
    return [self.eventScanStore findWithId:eventId];
}

- (void)scanEvent:(nonnull MXEvent*)event completion:(void (^ _Nullable)(MXEventScan* _Nullable eventScan, BOOL eventScanDidSucceed))completion
{
    MXEvent *eventCopy = [event copy];
    NSString *eventId = eventCopy.eventId;
    
    // Sanity check, the event id should not be nil
    if (!eventId)
    {
        if (completion)
        {
            [self dispatchCompletion:^{
                completion(nil, NO);
            }];
        }
        return;
    }
    
    [self dispatchProcessing:^{
        
        MXEventScan *eventScan = [self.eventScanStore findWithId:eventId];

        if (eventScan && eventScan.antivirusScanStatus == MXAntivirusScanStatusInProgress)
        {
            // If a scan is already in progress for the given event, wait for an update of the associated MXEventScan, only if a completion block exist
            if (completion)
            {
                __weak NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
                
                __block id eventScanToken = [notificationCenter addObserverForName:MXScanManagerEventScanDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
                    
                    NSDictionary *userInfo = note.userInfo;
                    
                    if (userInfo)
                    {
                        NSDictionary<NSString*, NSArray<MXEventScan*>*> *mediaScanChanges = userInfo;
                        
                        NSArray<MXEventScan*> *insertions = mediaScanChanges[MXScanManagerScanDidChangeNotificationInsertionsUserInfoKey];
                        NSArray<MXEventScan*> *modifications = mediaScanChanges[MXScanManagerScanDidChangeNotificationModificationsUserInfoKey];
                        NSArray<MXEventScan*> *deletions = mediaScanChanges[MXScanManagerScanDidChangeNotificationDeletionsUserInfoKey];
                        
                        NSString *eventId = eventScan.eventId;
                        
                        MXEventScan *insertedEventScan = [self eventScanForEventId:eventId inEventScans:insertions];
                        MXEventScan *modifiedEventScan = [self eventScanForEventId:eventId inEventScans:modifications];
                        MXEventScan *deletedEventScan = [self eventScanForEventId:eventId inEventScans:deletions];
                        
                        if (insertedEventScan || modifiedEventScan)
                        {
                            MXEventScan *finalEventScan = insertedEventScan ?: modifiedEventScan;
                            
                            if (finalEventScan.antivirusScanStatus != MXAntivirusScanStatusInProgress)
                            {
                                [notificationCenter removeObserver:eventScanToken];

                                [self dispatchCompletion:^{
                                    completion(finalEventScan, YES);
                                }];
                            }
                        }
                        else if (deletedEventScan)
                        {
                            [notificationCenter removeObserver:eventScanToken];
                            
                            [self dispatchCompletion:^{
                                completion(nil, NO);
                            }];
                        }
                    }
                    else
                    {
                        [notificationCenter removeObserver:eventScanToken];
                    }
                }];
            }
        }
        else if (!eventScan || [self isUpdateNeededForEventScan:eventScan])
        {
            NSArray<NSString*> *mediaURLs = [eventCopy getMediaURLs];
            
            MXAntivirusScanStatus antivirusScanStatus;
            
            if (mediaURLs.count == 0)
            {
                antivirusScanStatus = MXAntivirusScanStatusTrusted;
            }
            else
            {
                antivirusScanStatus = MXAntivirusScanStatusInProgress;
            }
            
            if (!eventScan)
            {
                [self.eventScanStore createOrUpdateWithId:eventId initialAntivirusStatus:antivirusScanStatus andMediaURLs:mediaURLs];
            }
            else
            {
                [self.eventScanStore updateAntivirusScanStatus:antivirusScanStatus forId:eventId];
            }
            
            if (antivirusScanStatus == MXAntivirusScanStatusTrusted)
            {
                MXEventScan *updatedEventScan = [self.eventScanStore findWithId:eventId];
                
                if (completion)
                {
                    [self dispatchCompletion:^{
                        completion(updatedEventScan, YES);
                    }];
                }
            }
            else
            {
                __block BOOL success = YES;
                
                dispatch_group_t mediaScansGroup = dispatch_group_create();
                
                if (event.isEncrypted)
                {
                    NSArray<MXEncryptedContentFile*> *encryptedContentFiles = [event getEncryptedContentFiles];
                    
                    for (MXEncryptedContentFile *encryptedContentFile in encryptedContentFiles)
                    {
                        dispatch_group_enter(mediaScansGroup);
                        
                        [self scanEncryptedMediaWithEncryptedFile:encryptedContentFile completion:^(MXMediaScan * _Nullable mediaScan, BOOL mediaScanDidSucceed) {
                            success = success && mediaScanDidSucceed;
                            
                            dispatch_group_leave(mediaScansGroup);
                        }];
                    }
                }
                else
                {
                    for (NSString *mediaURL in mediaURLs)
                    {
                        dispatch_group_enter(mediaScansGroup);
                        
                        [self scanUnencryptedMediaWithURL:mediaURL completion:^(MXMediaScan * _Nullable mediaScan, BOOL mediaScanDidSucceed) {
                            success = success && mediaScanDidSucceed;
                            
                            dispatch_group_leave(mediaScansGroup);
                        }];
                    }
                }
                
                dispatch_group_notify(mediaScansGroup, self.processingQueue, ^{
                    [self.eventScanStore updateAntivirusScanStatusFromMediaScansAntivirusScanStatusesAndAntivirusScanDate:[NSDate date] forId:eventId];
                    
                    MXEventScan *updatedEventScan = [self.eventScanStore findWithId:eventId];
                    
                    if (completion)
                    {
                        [self dispatchCompletion:^{
                            completion(updatedEventScan, YES);
                        }];
                    }
                });
            }
        }
        else
        {
            if (completion)
            {
                [self dispatchCompletion:^{
                    completion(eventScan, YES);
                }];
            }
        }
    }];
}

- (void)scanEventIfNeeded:(nonnull MXEvent*)event
{
    [self scanEvent:event completion:nil];
}

#pragma mark Encrypted body

- (void)encryptRequestBody:(nonnull NSDictionary *)requestBody completion:(void (^ _Nonnull)(MXContentScanEncryptedBody* _Nullable encryptedBody))completion
{
    [self getAntivirusServerPublicKey:^(NSString * _Nullable publicKey) {
        if (publicKey.length)
        {
            OLMPkEncryption *olmPkEncryption = [OLMPkEncryption new];
            [olmPkEncryption setRecipientKey:publicKey];
            NSString *message = [MXTools serialiseJSONObject:requestBody];
            OLMPkMessage *olmPkMessage = [olmPkEncryption encryptMessage:message error:nil];
            completion([MXContentScanEncryptedBody modelFromOLMPkMessage:olmPkMessage]);
        }
        else
        {
            NSLog(@"[MXScanManager] encrypt body failed, a server public key is required");
            completion(nil);
        }
    }];
}

#pragma mark Server key

- (void)getAntivirusServerPublicKey:(void (^ _Nonnull)(NSString* _Nullable publicKey))completion
{
    // Check whether the key has been already retrieved.
    if (_serverPublicKey)
    {
        completion(_serverPublicKey);
    }
    else
    {
        MXWeakify(self);
        [self.restClient getAntivirusServerPublicKey:^(NSString *publicKey) {
            
            MXStrongifyAndReturnIfNil(self);
            self.serverPublicKey = publicKey;
            completion(publicKey);
            
        } failure:^(NSError *error) {
            
            NSLog(@"[MXScanManager] get server key failed");
            completion(nil);
            
        }];
    }
}

- (void)checkAntivirusServerPublicKeyOnError:(nullable NSError *)error
{
    if ([error.userInfo[MXHTTPClientErrorResponseDataKey] isKindOfClass:NSDictionary.class])
    {
        NSDictionary *response = error.userInfo[MXHTTPClientErrorResponseDataKey];
        if ([response[MXErrorContentScannerReasonKey] isEqualToString:MXErrorContentScannerReasonValueBadDecryption])
        {
            [self resetAntivirusServerPublicKey];
        }
    }
}

- (void)resetAntivirusServerPublicKey
{
    NSLog(@"[MXScanManager] reset server public key");
    _serverPublicKey = nil;
}

#pragma mark - Private

#pragma mark Media

- (void)scanUnencryptedMediaWithURL:(nullable NSString*)unencryptedMediaURL
                    orEncryptedFile:(nullable MXEncryptedContentFile*)encryptedContentFile
                         completion:(void (^ _Nullable)(MXMediaScan* _Nullable mediaScan, BOOL mediaScanDidSucceed))completion
{
    [self dispatchProcessing:^{
        
        NSString *mediaURL;
        
        if (encryptedContentFile)
        {
            mediaURL = encryptedContentFile.url;
        }
        else
        {
            mediaURL = unencryptedMediaURL;
        }
        
        MXMediaScan *mediaScan = [self.mediaScanStore findWithURL:mediaURL];
        
        if (mediaScan.antivirusScanStatus == MXAntivirusScanStatusInProgress)
        {
            if (completion)
            {
                __weak NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
                
                __block id mediaScanToken = [notificationCenter addObserverForName:MXScanManagerMediaScanDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
                    
                    NSDictionary *userInfo = note.userInfo;
                    
                    if (userInfo)
                    {
                        NSDictionary<NSString*, NSArray<MXMediaScan*>*> *mediaScanChanges = userInfo;
                        
                        NSArray<MXMediaScan*> *insertions = mediaScanChanges[MXScanManagerScanDidChangeNotificationInsertionsUserInfoKey];
                        NSArray<MXMediaScan*> *modifications = mediaScanChanges[MXScanManagerScanDidChangeNotificationModificationsUserInfoKey];
                        NSArray<MXMediaScan*> *deletions = mediaScanChanges[MXScanManagerScanDidChangeNotificationDeletionsUserInfoKey];
                        
                        MXMediaScan *insertedMediaScan = [self mediaScanForMediaURL:mediaURL inMediaScans:insertions];
                        MXMediaScan *modifiedMediaScan = [self mediaScanForMediaURL:mediaURL inMediaScans:modifications];
                        MXMediaScan *deletedMediaScan = [self mediaScanForMediaURL:mediaURL inMediaScans:deletions];
                        
                        if (insertedMediaScan || modifiedMediaScan)
                        {
                            MXMediaScan *finalMediaScan = insertedMediaScan ?: modifiedMediaScan;
                            
                            if (finalMediaScan.antivirusScanStatus != MXAntivirusScanStatusInProgress)
                            {
                                [notificationCenter removeObserver:mediaScanToken];
                                
                                if (completion)
                                {
                                    [self dispatchCompletion:^{
                                        completion(finalMediaScan, YES);
                                    }];
                                }
                            }
                        }
                        else if (deletedMediaScan)
                        {
                            [notificationCenter removeObserver:mediaScanToken];
                            
                            if (completion)
                            {
                                [self dispatchCompletion:^{
                                    completion(nil, NO);
                                }];
                            }
                        }
                    }
                    else
                    {
                        [notificationCenter removeObserver:mediaScanToken];
                    }
                }];
            }
        }
        else if (!mediaScan || [self isUpdateNeededForMediaScan:mediaScan])
        {
            if (!mediaScan)
            {
                mediaScan = [self.mediaScanStore findOrCreateWithURL:mediaURL initialAntivirusStatus:MXAntivirusScanStatusInProgress];
            }
            else
            {
                [self.mediaScanStore updateAntivirusScanStatus:MXAntivirusScanStatusInProgress forURL:mediaURL];
            }
            
            MXWeakify(self);
            
            void (^mediaScanSuccess)(MXContentScanResult *scanResult) = ^void(MXContentScanResult *scanResult) {
                MXStrongifyAndReturnIfNil(self);
                
                MXAntivirusScanStatus scanStatus = scanResult.clean ? MXAntivirusScanStatusTrusted : MXAntivirusScanStatusInfected;
                
                [self.mediaScanStore updateAntivirusScanStatus:scanStatus antivirusScanInfo:scanResult.info antivirusScanDate:[NSDate date] forURL:mediaURL];
                
                if (completion)
                {
                    MXMediaScan *finalMediaScan = [self.mediaScanStore findWithURL:mediaURL];
                    
                    [self dispatchCompletion:^{
                        completion(finalMediaScan, YES);
                    }];
                }
            };
            
            void (^mediaScanFailure)(NSError *error) = ^void(NSError *error) {
                MXStrongifyAndReturnIfNil(self);
                
                // Check whether the public key must be updated
                [self checkAntivirusServerPublicKeyOnError:error];
                
                [self.mediaScanStore updateAntivirusScanStatus:MXAntivirusScanStatusUnknown antivirusScanInfo:nil antivirusScanDate:[NSDate date] forURL:mediaURL];
                
                if (completion)
                {
                    MXMediaScan *finalMediaScan = [self.mediaScanStore findWithURL:mediaURL];
                    [self dispatchCompletion:^{
                        completion(finalMediaScan, NO);
                    }];
                }
            };
            
            if (encryptedContentFile)
            {
                if (self.isEncryptedBobyEnabled)
                {
                    [self encryptRequestBody:@{@"file": encryptedContentFile.JSONDictionary} completion:^(MXContentScanEncryptedBody * _Nullable encryptedBody) {
                        if (encryptedBody)
                        {
                            [self.restClient scanEncryptedContentWithSecureExchange:encryptedBody success:mediaScanSuccess failure:mediaScanFailure];
                        }
                        else
                        {
                            NSLog(@"[MXScanManager] scan encrypted content failed, body encryption failed");
                            mediaScanFailure(nil);
                        }
                    }];
                }
                else
                {
                    [self.restClient scanEncryptedContent:encryptedContentFile success:mediaScanSuccess failure:mediaScanFailure];
                }
            }
            else
            {
                [self.restClient scanUnencryptedContent:mediaURL success:mediaScanSuccess failure:mediaScanFailure];
            }
        }
        else
        {
            if (completion)
            {
                [self dispatchCompletion:^{
                    completion(mediaScan, YES);
                }];
            }
        }
    }];
}

- (BOOL)isUpdateNeededForMediaScan:(MXMediaScan*)mediaScan
{
    BOOL isScanRequired = NO;
    
    if (mediaScan.antivirusScanStatus == MXAntivirusScanStatusUnknown)
    {
        if (mediaScan.antivirusScanDate)
        {
            NSTimeInterval antivirusScanIntervalSinceNow = -mediaScan.antivirusScanDate.timeIntervalSinceNow;
            isScanRequired = antivirusScanIntervalSinceNow < 0 || antivirusScanIntervalSinceNow > self.scanInterval;
        }
        else
        {
            isScanRequired = YES;
        }
    }
    
    return isScanRequired;
}

- (nullable MXMediaScan*)mediaScanForMediaURL:(nonnull NSString*)mediaURL inMediaScans:(nonnull NSArray<MXMediaScan*>*)mediaScans
{
    MXMediaScan *mediaScan;
    
    NSUInteger mediaScanIndex = [mediaScans indexOfObjectPassingTest:^BOOL(MXMediaScan * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.url isEqualToString:mediaURL])
        {
            *stop = YES;
            return YES;
        }
        return NO;
    }];
    
    if (mediaScanIndex != NSNotFound)
    {
        mediaScan = mediaScans[mediaScanIndex];
    }
    
    return mediaScan;
}

#pragma mark Event

- (BOOL)isUpdateNeededForEventScan:(MXEventScan*)eventScan
{
    BOOL isScanRequired = NO;
    
    if (eventScan.antivirusScanStatus == MXAntivirusScanStatusUnknown)
    {
        if (eventScan.antivirusScanDate)
        {
            NSTimeInterval antivirusScanIntervalSinceNow = -eventScan.antivirusScanDate.timeIntervalSinceNow;
            isScanRequired = antivirusScanIntervalSinceNow < 0 || antivirusScanIntervalSinceNow > self.scanInterval;
        }
        else
        {
            isScanRequired = YES;
        }
    }
    
    return isScanRequired;
}

- (nullable MXEventScan*)eventScanForEventId:(nonnull NSString*)eventId inEventScans:(nonnull NSArray<MXEventScan*>*)eventScans
{
    MXEventScan *eventScan;
    
    NSUInteger eventScanIndex = [eventScans indexOfObjectPassingTest:^BOOL(MXEventScan * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.eventId isEqualToString:eventId])
        {
            *stop = YES;
            return YES;
        }
        return NO;
    }];
    
    if (eventScanIndex != NSNotFound)
    {
        eventScan = eventScans[eventScanIndex];
    }
    
    return eventScan;
}

#pragma mark Queue management

- (void)dispatchProcessing:(dispatch_block_t)processingBlock
{
    dispatch_async(self.processingQueue, ^{
        
        if (processingBlock)
        {
            processingBlock();
        }
    });
}

- (void)dispatchCompletion:(dispatch_block_t)completionBlock
{
    dispatch_async(self.completionQueue, ^{
        
        if (completionBlock)
        {
            completionBlock();
        }
    });
}

#pragma mark - MXMediaScanStoreDelegate

- (void)mediaScanStore:(nonnull MXMediaScanStore *)mediaScanStore didObserveChangesWithInsertions:(nonnull NSArray<MXMediaScan *> *)insertions modifications:(nonnull NSArray<MXMediaScan *> *)modifications deletions:(nonnull NSArray<MXMediaScan *> *)deletions
{
    NSMutableDictionary<NSString*, NSArray<MXMediaScan*>*> *mediaScanChanges = [NSMutableDictionary new];
    
    mediaScanChanges[MXScanManagerScanDidChangeNotificationInsertionsUserInfoKey] = insertions;
    mediaScanChanges[MXScanManagerScanDidChangeNotificationModificationsUserInfoKey] = modifications;
    mediaScanChanges[MXScanManagerScanDidChangeNotificationDeletionsUserInfoKey] = deletions;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MXScanManagerMediaScanDidChangeNotification object:self userInfo:mediaScanChanges];
}

#pragma mark - MXEventScanStoreDelegate

- (void)eventScanStore:(nonnull MXEventScanStore *)eventScanStore didObserveChangesWithInsertions:(nonnull NSArray<MXEventScan *> *)insertions modifications:(nonnull NSArray<MXEventScan *> *)modifications deletions:(nonnull NSArray<MXEventScan *> *)deletions
{
    NSMutableDictionary<NSString*, NSArray<MXEventScan*>*> *eventScanChanges = [NSMutableDictionary new];
    
    eventScanChanges[MXScanManagerScanDidChangeNotificationInsertionsUserInfoKey] = insertions;
    eventScanChanges[MXScanManagerScanDidChangeNotificationModificationsUserInfoKey] = modifications;
    eventScanChanges[MXScanManagerScanDidChangeNotificationDeletionsUserInfoKey] = deletions;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MXScanManagerEventScanDidChangeNotification object:self userInfo:eventScanChanges];
}

@end
