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

#import <Foundation/Foundation.h>
#import "MXJSONModel.h"

/**
 Matrix Client-Server API versions.
 */
struct MXMatrixClientServerAPIVersionStruct
{
    __unsafe_unretained NSString * const r0_0_1;
    __unsafe_unretained NSString * const r0_1_0;
    __unsafe_unretained NSString * const r0_2_0;
    __unsafe_unretained NSString * const r0_3_0;
    __unsafe_unretained NSString * const r0_4_0;
    __unsafe_unretained NSString * const r0_5_0;
    __unsafe_unretained NSString * const r0_6_0;
};
extern const struct MXMatrixClientServerAPIVersionStruct MXMatrixClientServerAPIVersion;

/**
 Features declared in the matrix specification.
 */
struct MXMatrixVersionsFeatureStruct
{
    // Room members lazy loading
    __unsafe_unretained NSString * const lazyLoadMembers;
    __unsafe_unretained NSString * const requireIdentityServer;
    __unsafe_unretained NSString * const idAccessToken;
    __unsafe_unretained NSString * const separateAddAndBind;
};
extern const struct MXMatrixVersionsFeatureStruct MXMatrixVersionsFeature;

/**
 `MXMatrixVersions` represents the versions of the Matrix specification supported
 by the home server.
 It is returned by the /versions API.
 */
@interface MXMatrixVersions : MXJSONModel

/**
 The versions supported by the server.
 */
@property (nonatomic) NSArray<NSString *> *versions;

/**
 The unstable features supported by the server.

 */
@property (nonatomic) NSDictionary<NSString*, NSNumber*> *unstableFeatures;

/**
 Check whether the server supports the room members lazy loading.
 */
@property (nonatomic, readonly) BOOL supportLazyLoadMembers;

/**
 Indicate if the `id_server` parameter is required when registering with an 3pid,
 adding a 3pid or resetting password.
 */
@property (nonatomic, readonly) BOOL doesServerRequireIdentityServerParam;

/**
 Indicate if the `id_access_token` parameter can be safely passed to the homeserver.
 Some homeservers may trigger errors if they are not prepared for the new parameter.
 */
@property (nonatomic, readonly) BOOL doesServerAcceptIdentityAccessToken;

/**
 Indicate if the server supports separate 3PID add and bind functions.
 This affects the sequence of API calls clients should use for these operations,
 so it's helpful to be able to check for support.
 */
@property (nonatomic, readonly) BOOL doesServerSupportSeparateAddAndBind;

@end
