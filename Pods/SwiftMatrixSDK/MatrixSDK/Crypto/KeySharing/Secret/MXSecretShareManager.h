/*
 Copyright 2020 The Matrix.org Foundation C.I.C
 
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

#import <Foundation/Foundation.h>

#import "MXHTTPOperation.h"

@class MXCrypto;

NS_ASSUME_NONNULL_BEGIN


#pragma mark - Constants

//! Secret identifiers
extern const struct MXSecretId {
    __unsafe_unretained NSString *crossSigningMaster;
    __unsafe_unretained NSString *crossSigningSelfSigning;
    __unsafe_unretained NSString *crossSigningUserSigning;
    __unsafe_unretained NSString *keyBackup;

} MXSecretId;


/**
 Secret sharing manager.
 
 See https://github.com/uhoreg/matrix-doc/blob/ssss/proposals/1946-secure_server-side_storage.md#sharing.
 */
@interface MXSecretShareManager : NSObject

/**
 Request a secret from other user's devices.

 @param secretId the id of the secret
 @param deviceIds ids of device to make request. Nil to request all.
 
 @param success A block object called when the operation succeeds. It provides the id of the request.
 @param onSecretReceived A block called when the secret has been received from another device.
                         Must return YES if the secret is valid.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation *)requestSecret:(NSString*)secretId
                       toDeviceIds:(nullable NSArray<NSString*>*)deviceIds
                           success:(void (^)(NSString *requestId))success
                  onSecretReceived:(BOOL (^)(NSString *secret))onSecretReceived
                           failure:(void (^)(NSError *error))failure;

/**
 Cancel a secret request.
 
 @param requestId the id of the request.
 
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation *)cancelRequestWithRequestId:(NSString*)requestId
                                        success:(void (^)(void))success
                                        failure:(void (^)(NSError *error))failure;

@end

NS_ASSUME_NONNULL_END
