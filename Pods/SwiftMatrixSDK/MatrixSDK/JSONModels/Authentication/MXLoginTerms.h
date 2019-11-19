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
#import "MXLoginPolicy.h"

NS_ASSUME_NONNULL_BEGIN

/**
 `MXLoginTerms` is the data model for kMXLoginFlowTypeTerms(m.login.terms) requested
 in an authentication flow
 */
@interface MXLoginTerms : MXJSONModel

/**
 Terms the end user must accept.

 policy id -> policy
 */
@property (nonatomic) NSDictionary<NSString*, MXLoginPolicy*> *policies;

/**
 Return a flat array of `MXLoginPolicyData` objects to display for a given language.

 @param language the code of the language to look for.
 @param defaultLanguage the default language code.
 @return all localised `MXLoginPolicyData` objects.
 */
- (NSArray<MXLoginPolicyData*> *)policiesDataForLanguage:(nullable NSString*)language defaultLanguage:(nullable NSString*)defaultLanguage;

@end

NS_ASSUME_NONNULL_END
