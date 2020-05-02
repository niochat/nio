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

#import "MXJSONModel.h"

NS_ASSUME_NONNULL_BEGIN


#pragma mark - Constants

//! Actions for secret sharing requests
extern const struct MXSecretShareRequestAction {
    __unsafe_unretained NSString *request;
    __unsafe_unretained NSString *requestCancellation;
} MXSecretShareRequestAction;


/**
 Sent by a client to request a secret from another device.
 */
@interface MXSecretShareRequest : MXJSONModel

/**
 The name of the secret that is being requested.
 Non nil if action is "request".
 */
@property (nonatomic, nullable) NSString *name;

/**
 One of ["request", "request_cancellation"].
 */
@property (nonatomic) NSString *action;

/**
 The ID of the device requesting the secret.
 */
@property (nonatomic) NSString *requestingDeviceId;

/**
 A random string uniquely identifying the request for a secret.
 */
@property (nonatomic) NSString *requestId;

@end

NS_ASSUME_NONNULL_END
