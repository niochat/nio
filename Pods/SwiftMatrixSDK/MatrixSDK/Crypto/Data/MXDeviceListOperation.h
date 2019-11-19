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

#import "MXSDKOptions.h"

#ifdef MX_CRYPTO

#import "MXHTTPOperation.h"

#import "MXDeviceInfo.h"
#import "MXCryptoConstants.h"
#import "MXUsersDevicesMap.h"

@class MXDeviceListOperationsPool;

/**
 `MXDeviceListOperation` is a hack over `MXHTTPOperation` that allows to have several
 `MXDeviceListOperation` instances that point to the same `MXHTTPOperation` instance
 managed by a `MXDeviceListOperationsPool` instance.

 This `MXHTTPOperation` will be cancelled only if all its children of `MXDeviceListOperationsPool`
 are cancelled.
 
 `MXDeviceListOperation` exposes the same interface as `MXHTTPOperation` to not break
 the operations chaining through the sdk. Especially, it has a cancel method.
 */
@interface MXDeviceListOperation : MXHTTPOperation

/**
 The users targeted for this operation.
 */
@property (nonatomic, readonly) NSArray<NSString*> *userIds;

/**
 The block called in case of success.
 */
@property (nonatomic, readonly) void (^success)(NSArray<NSString *> *succeededUserIds, NSArray<NSString *> *failedUserIds);

/**
The block called in case of failure.
 */
@property (nonatomic, readonly) void (^failure)(NSError *error);

/**
 Create a `MXDeviceListOperation` instance
 
 @param userIds users targeted for this operation.
 @param success the block called in case of success.
 @param failure the block called in case of failure.
 */
- (id)initWithUserIds:(NSArray<NSString*>*)userIds
              success:(void (^)(NSArray<NSString *> *succeededUserIds, NSArray<NSString *> *failedUserIds))success
              failure:(void (^)(NSError *error))failure;

/**
 Move the operation into a pool

 @param pool the `MXDeviceListOperationsPool` instance it will belong to.
 */
- (void)addToPool:(MXDeviceListOperationsPool*)pool;

@end

#endif
