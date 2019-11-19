/*
 Copyright 2019 New Vector Ltd
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

#import "MXReactionCount.h"
#import "MXReactionRelation.h"
#import "MXCredentials.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Store for aggregations data.
 */
@protocol MXAggregationsStore <NSObject>

/**
 Create a aggregations store for the passed credentials.

 @param credentials the credentials of the account.
 @return the store. Call the open method before using it.
 */
- (instancetype)initWithCredentials:(MXCredentials *)credentials;

#pragma mark - Reaction count

#pragma mark - Single object CRUD operations
- (void)addOrUpdateReactionCount:(MXReactionCount*)reactionCount onEvent:(NSString*)eventId inRoom:(NSString*)roomId;
- (BOOL)hasReactionCountsOnEvent:(NSString*)eventId;
- (nullable MXReactionCount*)reactionCountForReaction:(NSString*)reaction onEvent:(NSString*)eventId;
- (void)deleteReactionCountsForReaction:(NSString*)reaction onEvent:(NSString*)eventId;

#pragma mark - Batch operations
- (void)setReactionCounts:(NSArray<MXReactionCount*> *)reactionCounts onEvent:(NSString*)eventId inRoom:(NSString*)roomId;
- (nullable NSArray<MXReactionCount*> *)reactionCountsOnEvent:(NSString*)eventId;
- (void)deleteAllReactionCountsInRoom:(NSString*)roomId;


#pragma mark - Reaction count

#pragma mark - Single object CRUD operations
- (void)addReactionRelation:(MXReactionRelation*)relation inRoom:(NSString*)roomId;
- (nullable MXReactionRelation*)reactionRelationWithReactionEventId:(NSString*)reactionEventId;
- (void)deleteReactionRelation:(MXReactionRelation*)relation;

#pragma mark - Batch operations
- (nullable NSArray<MXReactionRelation*> *)reactionRelationsOnEvent:(NSString*)eventId;
- (void)deleteAllReactionRelationsInRoom:(NSString*)roomId;


#pragma - Global
- (void)deleteAll;

@end

NS_ASSUME_NONNULL_END
