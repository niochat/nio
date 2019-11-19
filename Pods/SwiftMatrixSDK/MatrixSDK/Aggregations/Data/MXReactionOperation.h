/*
 Copyright 2019 The Matrix.org Foundation C.I.C

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

/**
 A `MXReactionOperation` represents a pending operation on a reaction on a event.
 The `MXReactionOperation` exists while the operation has not been acknowledged
 by the homeserver, ie while we have not received the reaction event back from
 the event stream.
 */
@interface MXReactionOperation : NSObject

@property (nonatomic) NSString *eventId;
@property (nonatomic) NSString *reaction;
@property (nonatomic) uint64_t originServerTs;
@property (nonatomic) BOOL isAddOperation;

@property (nonatomic) void (^block)(BOOL requestAlreadyPending);

@end

NS_ASSUME_NONNULL_END
