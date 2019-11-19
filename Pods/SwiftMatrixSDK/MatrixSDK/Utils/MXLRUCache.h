/*
 Copyright 2016 OpenMarket Ltd

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

/**
 `MXLRUCache` is an LRU cache
 */
@interface MXLRUCache : NSObject

/**
 Create a LRU cache with a max number of cached object
 @param capacity the maximum number of cached items
 */
 
- (id)initWithCapacity:(NSUInteger)capacity;

/**
 Retrieve an object from its key.
 @param key the object key
 @return the cached object if it is found else nil
 */
- (NSObject*)get:(NSString*)key;

/**
 Put an object from its key.
 @param key the object key
 @param object the object to store
 */
- (void)put:(NSString*)key object:(NSObject*)object;

/**
 Clear the LRU cache.
 */
- (void)clear;

@end
