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

#import "MXDeviceListOperation.h"

@class MXCrypto;

/**
 `MXDeviceListOperationsPool` manages a pool of `MXDeviceListOperation` operations
 in order to gather keys downloads into one single `MXHTTPOperation` query.
 */
@interface MXDeviceListOperationsPool : NSObject

/**
 The pool of operations.
 */
@property (nonatomic, readonly) NSMutableArray<MXDeviceListOperation*> *operations;

/**
 The current http request.
 */
@property (nonatomic, readonly) MXHTTPOperation *httpOperation;

/**
 The list of users targetted by sub operations.
 */
@property (nonatomic, readonly) NSSet<NSString*> *userIds;


/**
 Create a `MXDeviceListOperation` instance

 @param crypto the crypto module.
 */

- (id)initWithCrypto:(MXCrypto *)crypto;

/**
 Add/Remove an operation to/from the pool.
 
 @param operation the operation.
 */
- (void)addOperation:(MXDeviceListOperation *)operation;
- (void)removeOperation:(MXDeviceListOperation *)operation;

/**
 Launch the download request for all users identified by all MXDeviceListOperation children.
 */
- (void)downloadKeys:(NSString *)token complete:(void (^)(NSDictionary<NSString *, NSDictionary *> *failedUserIds))complete;

@end

#endif
