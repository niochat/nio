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

#import "MXAggregations.h"
#import "MXAggregations_Private.h"

#import "MXSession.h"
#import "MXTools.h"

#import "MXEventRelations.h"

#import "MXRealmAggregationsStore.h"
#import "MXAggregatedReactionsUpdater.h"
#import "MXAggregatedEditsUpdater.h"
#import "MXAggregatedReferencesUpdater.h"
#import "MXEventEditsListener.h"
#import "MXAggregationPaginatedResponse_Private.h"

@interface MXAggregations ()

@property (nonatomic, weak) MXSession *mxSession;
@property (nonatomic) id<MXAggregationsStore> store;
@property (nonatomic) MXAggregatedReactionsUpdater *aggregatedReactionsUpdater;
@property (nonatomic) MXAggregatedEditsUpdater *aggregatedEditsUpdater;
@property (nonatomic) MXAggregatedReferencesUpdater *aggregatedReferencesUpdater;

@end


@implementation MXAggregations

#pragma mark - Public methods -

#pragma mark - Reactions

- (void)addReaction:(NSString*)reaction
           forEvent:(NSString*)eventId
             inRoom:(NSString*)roomId
            success:(void (^)(void))success
            failure:(void (^)(NSError *error))failure
{
    [self.aggregatedReactionsUpdater addReaction:reaction forEvent:eventId inRoom:roomId success:success failure:failure];
}

- (void)removeReaction:(NSString*)reaction
              forEvent:(NSString*)eventId
                inRoom:(NSString*)roomId
               success:(void (^)(void))success
               failure:(void (^)(NSError *error))failure
{
    [self.aggregatedReactionsUpdater removeReaction:reaction forEvent:eventId inRoom:roomId success:success failure:failure];
}

- (nullable MXAggregatedReactions *)aggregatedReactionsOnEvent:(NSString*)eventId inRoom:(NSString*)roomId
{
    return [self.aggregatedReactionsUpdater aggregatedReactionsOnEvent:eventId inRoom:roomId];
}

- (id)listenToReactionCountUpdateInRoom:(NSString *)roomId block:(void (^)(NSDictionary<NSString *,MXReactionCountChange *> * _Nonnull))block
{
    return [self.aggregatedReactionsUpdater listenToReactionCountUpdateInRoom:roomId block:block];
}

- (void)removeListener:(id)listener
{
    if ([listener isKindOfClass:[MXReactionCountChangeListener class]])
    {
        [self.aggregatedReactionsUpdater removeListener:listener];
    }
    else if ([listener isKindOfClass:[MXEventEditsListener class]])
    {
        [self.aggregatedEditsUpdater removeListener:listener];
    }
}

- (MXHTTPOperation*)reactionsEventsForEvent:(NSString*)eventId
                                     inRoom:(NSString*)roomId
                                       from:(nullable NSString*)from
                                      limit:(NSUInteger)limit
                                    success:(void (^)(MXAggregationPaginatedResponse *paginatedResponse))success
                                    failure:(void (^)(NSError *error))failure
{
    return [self.mxSession.matrixRestClient relationsForEvent:eventId
                                                       inRoom:roomId
                                                 relationType:MXEventRelationTypeAnnotation
                                                    eventType:kMXEventTypeStringReaction
                                                         from:from                                                    
                                                        limit:limit
                                                      success:success
                                                      failure:failure];
}


#pragma mark - Edits

- (MXHTTPOperation*)replaceTextMessageEvent:(MXEvent*)event
                            withTextMessage:(nullable NSString*)text
                              formattedText:(nullable NSString*)formattedText
                             localEchoBlock:(nullable void (^)(MXEvent *localEcho))localEchoBlock
                                    success:(void (^)(NSString *eventId))success
                                    failure:(void (^)(NSError *error))failure
{
    return [self.aggregatedEditsUpdater replaceTextMessageEvent:event withTextMessage:text formattedText:formattedText localEchoBlock:localEchoBlock success:success failure:failure];
}

- (id)listenToEditsUpdateInRoom:(NSString *)roomId block:(void (^)(MXEvent* replaceEvent))block
{
    return [self.aggregatedEditsUpdater listenToEditsUpdateInRoom:roomId block:block];
}

- (MXHTTPOperation*)replaceEventsForEvent:(NSString*)eventId
                              isEncrypted:(BOOL)isEncrypted
                                   inRoom:(NSString*)roomId
                                     from:(nullable NSString*)from
                                    limit:(NSUInteger)limit
                                  success:(void (^)(MXAggregationPaginatedResponse *paginatedResponse))success
                                  failure:(void (^)(NSError *error))failure
{
    NSString *eventType = isEncrypted ? kMXEventTypeStringRoomEncrypted : kMXEventTypeStringRoomMessage;
    return [self.mxSession.matrixRestClient relationsForEvent:eventId inRoom:roomId relationType:MXEventRelationTypeReplace eventType:eventType from:from limit:limit success:success failure:failure];
}

- (MXHTTPOperation*)referenceEventsForEvent:(NSString*)eventId
                                     inRoom:(NSString*)roomId
                                       from:(nullable NSString*)from
                                      limit:(NSUInteger)limit
                                    success:(void (^)(MXAggregationPaginatedResponse *paginatedResponse))success
                                    failure:(void (^)(NSError *error))failure
{
    MXHTTPOperation* operation;
    
    void (^processPaginatedResponse)(MXAggregationPaginatedResponse *paginatedResponse) = ^(MXAggregationPaginatedResponse *paginatedResponse) {
        // Decrypt events if required
        NSArray<MXEvent *> *allEvents;
        if (paginatedResponse.originalEvent)
        {
            if (paginatedResponse.chunk)
            {
                allEvents = [paginatedResponse.chunk arrayByAddingObject:paginatedResponse.originalEvent];
            }
            else
            {
                allEvents = @[paginatedResponse.originalEvent];
            }
        }
        
        for (MXEvent *event in allEvents)
        {
            if (event.isEncrypted && !event.clearEvent)
            {
                [self.mxSession decryptEvent:event inTimeline:nil];
            }
        }
        
        success(paginatedResponse);
    };
    
    MXEvent *event = [self.mxSession.store eventWithEventId:eventId inRoom:roomId];
    
    if (!event)
    {
        operation = [self.mxSession.matrixRestClient relationsForEvent:eventId inRoom:roomId relationType:MXEventRelationTypeReference eventType:nil from:from limit:limit success:^(MXAggregationPaginatedResponse *paginatedResponse) {
            processPaginatedResponse(paginatedResponse);
        } failure:failure];
    }
    else
    {
        NSArray<MXEvent *> *referenceEvents = [self.mxSession.store relationsForEvent:eventId inRoom:roomId relationType:MXEventRelationTypeReference];

        MXAggregationPaginatedResponse *paginatedResponse = [[MXAggregationPaginatedResponse alloc] initWithOriginalEvent:event
                                                                                                                    chunk:referenceEvents
                                                                                                                nextBatch:nil];
        processPaginatedResponse(paginatedResponse);
    }

    return operation;
}

#pragma mark - Data

- (void)resetData
{
    [self.store deleteAll];
}


#pragma mark - SDK-Private methods -

- (instancetype)initWithMatrixSession:(MXSession *)mxSession
{
    self = [super init];
    if (self)
    {
        self.mxSession = mxSession;
        self.store = [[MXRealmAggregationsStore alloc] initWithCredentials:mxSession.matrixRestClient.credentials];

        self.aggregatedReactionsUpdater = [[MXAggregatedReactionsUpdater alloc] initWithMatrixSession:self.mxSession aggregationStore:self.store];
        self.aggregatedEditsUpdater = [[MXAggregatedEditsUpdater alloc] initWithMatrixSession:self.mxSession
                                                                             aggregationStore:self.store
                                                                                  matrixStore:mxSession.store];
        self.aggregatedReferencesUpdater = [[MXAggregatedReferencesUpdater alloc] initWithMatrixSession:self.mxSession
                                                                                           matrixStore:mxSession.store];

        [self registerListener];
    }

    return self;
}

- (void)handleOriginalDataOfEvent:(MXEvent *)event
{
    MXEventRelations *relations = event.unsignedData.relations;
    if (relations.annotation)
    {
        // TODO: Uncomment when reaction aggregation API will be updated.
        // [self.aggregatedReactionsUpdater handleOriginalAggregatedDataOfEvent:event annotations:relations.annotation];
    }
}

- (void)resetDataInRoom:(NSString *)roomId
{
    [self.aggregatedReactionsUpdater resetDataInRoom:roomId];
}


#pragma mark - Private methods

- (void)registerListener
{
    [self.mxSession listenToEvents:^(MXEvent *event, MXTimelineDirection direction, id customObject) {

        switch (event.eventType) {
            case MXEventTypeRoomMessage:
                if (direction == MXTimelineDirectionForwards
                    && [event.relatesTo.relationType isEqualToString:MXEventRelationTypeReplace])
                {
                    [self.aggregatedEditsUpdater handleReplace:event];
                }
                break;
            case MXEventTypeReaction:
                [self.aggregatedReactionsUpdater handleReaction:event direction:direction];
                break;
            case MXEventTypeRoomRedaction:
                if (direction == MXTimelineDirectionForwards)
                {
                    [self.aggregatedReactionsUpdater handleRedaction:event];
                }
                break;
            default:
                break;
        }

        if (direction == MXTimelineDirectionForwards
            && [event.relatesTo.relationType isEqualToString:MXEventRelationTypeReference])
        {
            [self.aggregatedReferencesUpdater handleReference:event];
        }
    }];
}

@end
