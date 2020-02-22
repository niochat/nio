/*
 Copyright 2019 New Vector Ltd

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
#import "MXDiscoveredClientConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface MXAutoDiscovery : NSObject

/**
 Create a `MXAutoDiscovery` instance.

 @param url the homeserver url (ex: "https://matrix.org").
 @return a `MXAutoDiscovery` instance.
 */
- (nullable instancetype)initWithUrl:(NSString *)url;

/**
 Create a `MXAutoDiscovery` instance.

 @param domain  homeserver domain (ex: "matrix.org" from userId "@user:matrix.org").
 @return a `MXAutoDiscovery` instance.
 */
- (nullable instancetype)initWithDomain:(NSString*)domain;

/**
 Find client config

 - do the .well-known request
 - validate homeserver url and identity server url if provide in .well-known result
 - return action and .well-known data

 @param complete A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)findClientConfig:(void (^)(MXDiscoveredClientConfig *discoveredClientConfig))complete
                             failure:(void (^)(NSError *error))failure;;

/**
 Get the wellknwon data of the homeserver.

 @param success A block object called when the operation succeeds. It provides
                the wellknown data.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)wellKnow:(void (^)(MXWellKnown *wellKnown))success
                     failure:(void (^)(NSError *error))failure;

@end

NS_ASSUME_NONNULL_END
