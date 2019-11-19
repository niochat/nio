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
#import "MXLoginPolicyData.h"

NS_ASSUME_NONNULL_BEGIN

@interface MXLoginPolicy : MXJSONModel

/**
 Policy version
 */
@property (nonatomic) NSString *version;

/**
 Localised policy data to displayed to the end user.

 Language code (like "en") -> Policy data
 */
@property (nonatomic) NSDictionary<NSString*, MXLoginPolicyData*> *data;

@end

NS_ASSUME_NONNULL_END
