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

#import "MXScanRealmInMemoryProvider.h"

#import "MXRealmEventScan.h"
#import "MXRealmMediaScan.h"

@interface MXScanRealmInMemoryProvider()

@property (nonatomic, strong) RLMRealmConfiguration *realmConfiguration;
@property (nonatomic, strong) NSString *antivirusServerDomain;

@end

@implementation MXScanRealmInMemoryProvider

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
        NSLog(@"[MXScanRealmInMemoryProvider] realmForUser gets error: %@", error);
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
    
    realmConfiguration.inMemoryIdentifier = antivirusServerDomain;
    realmConfiguration.deleteRealmIfMigrationNeeded = YES;

    // Manage only our objects in this realm 
    realmConfiguration.objectClasses = @[
                                         MXRealmEventScan.class,
                                         MXRealmMediaScan.class
                                         ];

    return realmConfiguration;
}

@end
