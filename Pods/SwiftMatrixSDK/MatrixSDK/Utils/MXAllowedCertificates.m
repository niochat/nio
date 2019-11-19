/*
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

#import "MXAllowedCertificates.h"

@interface MXAllowedCertificates ()
{
    NSMutableSet<NSData*> *certificates;
}

@end

@implementation MXAllowedCertificates
@synthesize certificates;

+ (MXAllowedCertificates *)sharedInstance
{
    static MXAllowedCertificates *sharedOnceInstance;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedOnceInstance = [[MXAllowedCertificates alloc] init];
    });

    return sharedOnceInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        certificates = [NSMutableSet set];
    }
    return self;
}

- (void)addCertificate:(NSData *)certificate
{
    if (![self isCertificateAllowed:certificate])
    {
        [certificates addObject:certificate];
    }
}

- (BOOL)isCertificateAllowed:(NSData *)certificate
{
    BOOL allowed = NO;

    for (NSData *allowedCertificate in certificates)
    {
        if ([allowedCertificate isEqualToData:certificate])
        {
            allowed = YES;
            break;
        }
    }

    return allowed;
}

- (void)reset
{
    [certificates removeAllObjects];
}

@end
