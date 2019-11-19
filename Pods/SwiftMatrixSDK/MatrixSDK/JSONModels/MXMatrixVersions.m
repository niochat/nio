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

#import "MXMatrixVersions.h"

const struct MXMatrixClientServerAPIVersionStruct MXMatrixClientServerAPIVersion = {
    .r0_0_1 = @"r0.0.1",
    .r0_1_0 = @"r0.1.0",
    .r0_2_0 = @"r0.2.0",
    .r0_3_0 = @"r0.3.0",
    .r0_4_0 = @"r0.4.0",
    .r0_5_0 = @"r0.5.0",
    .r0_6_0 = @"r0.6.0",
};

const struct MXMatrixVersionsFeatureStruct MXMatrixVersionsFeature = {
    .lazyLoadMembers = @"m.lazy_load_members",
    .requireIdentityServer = @"m.require_identity_server",
    .idAccessToken = @"m.id_access_token",
    .separateAddAndBind = @"m.separate_add_and_bind"
};

@implementation MXMatrixVersions

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXMatrixVersions *matrixVersions = [[MXMatrixVersions alloc] init];
    if (matrixVersions)
    {
        MXJSONModelSetArray(matrixVersions.versions, JSONDictionary[@"versions"]);
        MXJSONModelSetDictionary(matrixVersions.unstableFeatures, JSONDictionary[@"unstable_features"]);
    }
    return matrixVersions;
}

- (BOOL)supportLazyLoadMembers
{
    return [self.versions containsObject:MXMatrixClientServerAPIVersion.r0_5_0]
        || [self.unstableFeatures[MXMatrixVersionsFeature.lazyLoadMembers] boolValue];
}

- (BOOL)doesServerRequireIdentityServerParam
{
    // YES by default
    BOOL doesServerRequireIdentityServerParam = YES;

    if ([self.versions containsObject:MXMatrixClientServerAPIVersion.r0_6_0])
    {
        doesServerRequireIdentityServerParam = NO;
    }
    else if (self.unstableFeatures[MXMatrixVersionsFeature.requireIdentityServer])
    {
        doesServerRequireIdentityServerParam = [self.unstableFeatures[MXMatrixVersionsFeature.requireIdentityServer] boolValue];
    }

    return doesServerRequireIdentityServerParam;
}

- (BOOL)doesServerAcceptIdentityAccessToken
{
    return  [self.versions containsObject:MXMatrixClientServerAPIVersion.r0_6_0]
        || [self.unstableFeatures[MXMatrixVersionsFeature.idAccessToken] boolValue];
}

- (BOOL)doesServerSupportSeparateAddAndBind
{
    return  [self.versions containsObject:MXMatrixClientServerAPIVersion.r0_6_0]
        || [self.unstableFeatures[MXMatrixVersionsFeature.separateAddAndBind] boolValue];
}

@end
