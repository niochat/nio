/*
 Copyright 202O The Matrix.org Foundation C.I.C
 
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

NS_ASSUME_NONNULL_BEGIN

@interface MXThrottler : NSObject

/**
 Minimum interval for the throttled blocks will execute again.
 */
@property (nonatomic, readonly) NSTimeInterval minimumDelay;

/**
 Dispatch queue on which submitted blocks will be executed.
 */
@property (nonatomic, readonly) dispatch_queue_t queue;

/**
 Initializer without queue. Uses main queue.
 
 @param minimumDelay Minimum interval for the throttled blocks will execute again.
 @return Initialized instance
 */
- (instancetype)initWithMinimumDelay:(NSTimeInterval)minimumDelay;

/**
 Initializer with queue.
 
 @param minimumDelay Minimum interval for the throttled blocks will execute again.
 @param queue Dispatch queue on which submitted blocks will be executed.
 @return Initialized instance
 */
- (instancetype)initWithMinimumDelay:(NSTimeInterval)minimumDelay
                               queue:(dispatch_queue_t)queue;

/**
 Cancels all submitted blocks. If a block is currently being executed, does not have an affect on that.
 */
- (void)cancelAll;

/**
 Submits a block to be executed when throttling criteria is met.
 
 @param block Block to be executed.
 */
- (void)throttle:(dispatch_block_t)block;

@end

NS_ASSUME_NONNULL_END
