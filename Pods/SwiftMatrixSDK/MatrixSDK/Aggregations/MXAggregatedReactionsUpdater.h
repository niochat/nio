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

#import "MXAggregatedReactions.h"
#import "MXEventAnnotationChunk.h"

#import "MXStore.h"
#import "MXAggregationsStore.h"
#import "MXReactionCountChangeListener.h"

NS_ASSUME_NONNULL_BEGIN

@interface MXAggregatedReactionsUpdater : NSObject

- (instancetype)initWithMatrixSession:(MXSession *)mxSession aggregationStore:(id<MXAggregationsStore>)store;

#pragma mark - Requests
- (void)addReaction:(NSString*)reaction
           forEvent:(NSString*)eventId
             inRoom:(NSString*)roomId
            success:(void (^)(void))success
            failure:(void (^)(NSError *error))failure;
- (void)removeReaction:(NSString*)reaction
              forEvent:(NSString*)eventId
                inRoom:(NSString*)roomId
               success:(void (^)(void))success
               failure:(void (^)(NSError *error))failure;

#pragma mark - Data access
- (nullable MXAggregatedReactions *)aggregatedReactionsOnEvent:(NSString*)eventId inRoom:(NSString*)roomId;
- (nullable MXReactionCount*)reactionCountForReaction:(NSString*)reaction onEvent:(NSString*)eventId;

#pragma mark - Data update listener
- (id)listenToReactionCountUpdateInRoom:(NSString *)roomId block:(void (^)(NSDictionary<NSString *,MXReactionCountChange *> * _Nonnull))block;
- (void)removeListener:(id)listener;

#pragma mark - Data update
- (void)handleOriginalAggregatedDataOfEvent:(MXEvent *)event annotations:(MXEventAnnotationChunk*)annotations;
- (void)handleReaction:(MXEvent *)event direction:(MXTimelineDirection)direction;
- (void)handleRedaction:(MXEvent *)event;

- (void)resetDataInRoom:(NSString *)roomId;

@end

NS_ASSUME_NONNULL_END
