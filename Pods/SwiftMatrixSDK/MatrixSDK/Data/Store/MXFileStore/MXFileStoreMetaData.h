/*
 Copyright 2014 OpenMarket Ltd

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

#import "MXWellKnown.h"

@interface MXFileStoreMetaData : NSObject <NSCoding, NSCopying>

/**
 The home server name.
 */
@property (nonatomic) NSString *homeServer;

/**
 The obtained user id.
 */
@property (nonatomic) NSString *userId;

/**
 The token indicating from where to start listening event stream to get
 live events.
 */
@property (nonatomic) NSString *eventStreamToken;

/**
 The id of the filter being used in /sync requests.
 */
@property (nonatomic) NSString *syncFilterId;

/**
 The current version of the store.
 */
@property (nonatomic) NSUInteger version;

/**
 User account data
 */
@property (nonatomic) NSDictionary *userAccountData;

/**
 The homeserver .well-known.
 */
@property (nonatomic) MXWellKnown *homeserverWellknown;

@end
