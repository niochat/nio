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

#import "MXDeviceListOperation.h"

#ifdef MX_CRYPTO

#import "MXDeviceListOperationsPool.h"

@interface MXDeviceListOperation ()
{
    MXDeviceListOperationsPool *pool;
}

@end

@implementation MXDeviceListOperation

- (id)initWithUserIds:(NSArray<NSString*>*)userIds
              success:(void (^)(NSArray<NSString *> *succeededUserIds, NSArray<NSString *> *failedUserIds))success
              failure:(void (^)(NSError *error))failure
{
    self = [super init];
    if (self)
    {
        _userIds = userIds;
        _success = success;
        _failure = failure;
    }
    return self;
}

- (void)addToPool:(MXDeviceListOperationsPool *)thePool
{
    NSParameterAssert(!pool);

    NSLog(@"[MXDeviceListOperation] addToPool: add operation: %p to pool %p", self, thePool);

    pool = thePool;
    [pool addOperation:self];
}

- (void)cancel
{
    [pool removeOperation:self];
}

#pragma mark - MXHTTPOperation methods forwarding

- (NSURLSessionDataTask *)operation
{
    return pool.httpOperation.operation;
}

- (void)setOperation:(NSURLSessionDataTask *)operation
{
    pool.httpOperation.operation = operation;
}

- (NSUInteger)age
{
    return pool.httpOperation.age;
}

- (NSUInteger)numberOfTries
{
    return pool.httpOperation.numberOfTries;
}

- (void)setNumberOfTries:(NSUInteger)numberOfTries
{
    pool.httpOperation.numberOfTries = numberOfTries;
}

- (NSUInteger)maxNumberOfTries
{
    return pool.httpOperation.maxNumberOfTries;
}

- (void)setMaxNumberOfTries:(NSUInteger)maxNumberOfTries
{
    pool.httpOperation.maxNumberOfTries = maxNumberOfTries;
}

- (NSUInteger)maxRetriesTime
{
    return pool.httpOperation.maxRetriesTime;
}

- (void)setMaxRetriesTime:(NSUInteger)maxRetriesTime
{
    pool.httpOperation.maxRetriesTime = maxRetriesTime;
}

@end

#endif
