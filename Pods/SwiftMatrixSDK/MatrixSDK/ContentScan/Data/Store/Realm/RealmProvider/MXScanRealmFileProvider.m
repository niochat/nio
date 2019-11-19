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

#import "MXScanRealmFileProvider.h"

#import "MXRealmHelper.h"

#import "MXRealmEventScan.h"
#import "MXRealmMediaScan.h"

@interface MXScanRealmFileProvider()

@property (nonatomic, strong) RLMRealmConfiguration *realmConfiguration;
@property (nonatomic, strong) NSString *antivirusServerDomain;

@end

@implementation MXScanRealmFileProvider

#pragma mark - Setup

- (nullable instancetype)initWithAntivirusServerDomain:(nonnull NSString*)antivirusServerDomain
{
    self = [super init];
    if (self)
    {
        _realmConfiguration = [self realmConfigurationForAntivirusServerDomain:antivirusServerDomain];
        _antivirusServerDomain = antivirusServerDomain;
    }
    return self;
}

#pragma mark - Public

- (nullable RLMRealm*)realm
{
    NSError *error;
    RLMRealm *realm = [RLMRealm realmWithConfiguration:self.realmConfiguration error:&error];
    
    if (error)
    {
        NSLog(@"[MXRealmFileProvider] realmForUser gets error: %@", error);
    }
    
    return realm;
}

- (void)deleteAllObjects
{
    RLMRealm *realm = [self realm];
    
    [realm transactionWithBlock:^{
        [realm deleteAllObjects];
    }];
}

#pragma mark - Private

- (nonnull RLMRealmConfiguration*)realmConfigurationForAntivirusServerDomain:(nonnull NSString*)antivirusServerDomain
{
    RLMRealmConfiguration *realmConfiguration = [RLMRealmConfiguration defaultConfiguration];
    
    NSString *fileName = antivirusServerDomain;
    // TODO: Use an MXFileManager to handle directory move from app container to shared container
    NSURL *mediasScanRootDirectoryURL = [[[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil] URLByAppendingPathComponent:@"Antivirus"];
    NSString *realmFileExtension = [MXRealmHelper realmFileExtension];
    
    NSURL *realmFileFolderURL = [mediasScanRootDirectoryURL URLByAppendingPathComponent:antivirusServerDomain isDirectory:YES];
    NSURL *realmFileURL = [[realmFileFolderURL URLByAppendingPathComponent:fileName isDirectory:NO] URLByAppendingPathExtension:realmFileExtension];
    
    NSError *folderCreationError;
    [[NSFileManager defaultManager] createDirectoryAtURL:realmFileFolderURL withIntermediateDirectories:YES attributes:nil error:&folderCreationError];
    
    if (folderCreationError)
    {
        NSLog(@"[MXScanRealmFileProvider] Fail to create Realm folder %@ with error: %@", realmFileFolderURL, folderCreationError);
    }
    
    realmConfiguration.fileURL = realmFileURL;
    realmConfiguration.deleteRealmIfMigrationNeeded = YES;

    // Manage only our objects in this realm 
    realmConfiguration.objectClasses = @[
                                         MXRealmEventScan.class,
                                         MXRealmMediaScan.class
                                         ];

    return realmConfiguration;
}

@end
