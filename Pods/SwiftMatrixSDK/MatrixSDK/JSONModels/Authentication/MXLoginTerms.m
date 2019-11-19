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

#import "MXLoginTerms.h"

@implementation MXLoginTerms

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXLoginTerms *loginTerms = [MXLoginTerms new];
    if (loginTerms)
    {
        NSMutableDictionary<NSString*, MXLoginPolicy*> *policies = [NSMutableDictionary dictionary];

        for (NSString *policyId in JSONDictionary[@"policies"])
        {
            MXLoginPolicy *loginPolicy;
            MXJSONModelSetMXJSONModel(loginPolicy, MXLoginPolicy.class, JSONDictionary[@"policies"][policyId]);

            if (loginPolicy)
            {
                policies[policyId] = loginPolicy;
            }
        }

        loginTerms.policies = policies;
    }

    return loginTerms;
}

- (NSArray<MXLoginPolicyData*> *)policiesDataForLanguage:(nullable NSString*)language defaultLanguage:(nullable NSString*)defaultLanguage
{
    NSMutableArray<MXLoginPolicyData*> *policies = [NSMutableArray array];

    for (MXLoginPolicy *loginPolicy in _policies.allValues)
    {
        // Find the localised policy data that matches the requested language
        MXLoginPolicyData *loginPolicyData = loginPolicy.data[language];
        if (!loginPolicyData)
        {
            // Fallback on Default
            loginPolicyData = loginPolicy.data[defaultLanguage];
        }
        if (!loginPolicyData)
        {
            // Then, the first data found in the server response
            loginPolicyData = loginPolicy.data.allValues.firstObject;
        }

        if (loginPolicyData)
        {
            [policies addObject:loginPolicyData];
        }
    }

    return policies;
}

@end
