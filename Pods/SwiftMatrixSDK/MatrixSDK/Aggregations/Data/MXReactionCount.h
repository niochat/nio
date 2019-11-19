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

#import "MXReactionOperation.h"

NS_ASSUME_NONNULL_BEGIN

/**
 `MXReactionCount` provides number of reactions on a reaction.
 */
@interface MXReactionCount : NSObject

@property (nonatomic) NSString *reaction;
@property (nonatomic) NSUInteger count;
@property (nonatomic) uint64_t originServerTs;

// The id of the reaction event if our user has made this reaction
@property (nonatomic, nullable) NSString *myUserReactionEventId;

// YES if our user has made this reaction
@property (nonatomic, readonly) BOOL myUserHasReacted;


// List of pending operation requests on this reaction
// Note: self.count includes counts of them
@property (nonatomic) NSArray<MXReactionOperation*> *localEchoesOperations;

// YES if there are pending operations
@property (nonatomic, readonly) BOOL containsLocalEcho;

@end

NS_ASSUME_NONNULL_END
