/*
 Copyright 2019 New Vector Ltd

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific languagMXWellKnowne governing permissions and
 limitations under the License.
 */

#import <Foundation/Foundation.h>

#import "MXJSONModel.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * https://matrix.org/docs/spec/client_server/r0.4.0.html#server-discovery
 *
 * {
 *     "base_url": "https://matrix.org"
 * }
 */
@interface MXWellKnownBaseConfig : MXJSONModel

@property (nonatomic) NSString *baseUrl;

@end

NS_ASSUME_NONNULL_END
