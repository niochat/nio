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

#import "MXRealmAggregationsMapper.h"

@implementation MXRealmAggregationsMapper

- (MXReactionCount*)reactionCountFromRealmReactionCount:(MXRealmReactionCount*)realmReactionCount
{
    MXReactionCount *reactionCount = [MXReactionCount new];
    reactionCount.reaction = realmReactionCount.reaction;
    reactionCount.count = realmReactionCount.count;
    reactionCount.originServerTs = realmReactionCount.originServerTs;
    reactionCount.myUserReactionEventId = realmReactionCount.myUserReactionEventId;

    return reactionCount;
}

- (MXRealmReactionCount*)realmReactionCountFromReactionCount:(MXReactionCount*)reactionCount onEvent:(NSString*)eventId inRoomd:(NSString*)roomId
{
    MXRealmReactionCount *realmReactionCount= [MXRealmReactionCount new];
    realmReactionCount.eventId = eventId;
    realmReactionCount.roomId = roomId;
    realmReactionCount.reaction = reactionCount.reaction;
    realmReactionCount.count = reactionCount.count;
    realmReactionCount.originServerTs = reactionCount.originServerTs;
    realmReactionCount.myUserReactionEventId = reactionCount.myUserReactionEventId;
    realmReactionCount.primaryKey = [MXRealmReactionCount primaryKeyFromEventId:eventId
                                                                    andReaction:reactionCount.reaction];

    return realmReactionCount;
}

- (MXReactionRelation*)reactionRelationFromRealmReactionRelation:(MXRealmReactionRelation*)realmReactionRelation
{
    MXReactionRelation *reactionRelation = [MXReactionRelation new];
    reactionRelation.reaction = realmReactionRelation.reaction;
    reactionRelation.eventId = realmReactionRelation.eventId;
    reactionRelation.reactionEventId = realmReactionRelation.reactionEventId;
    reactionRelation.originServerTs = realmReactionRelation.originServerTs;

    return reactionRelation;
}

- (MXRealmReactionRelation*)realmReactionRelationFromReactionRelation:(MXReactionRelation*)reactionRelation inRoomd:(NSString*)roomId
{
    MXRealmReactionRelation *realmReactionRelation= [MXRealmReactionRelation new];
    realmReactionRelation.reaction = reactionRelation.reaction;
    realmReactionRelation.eventId = reactionRelation.eventId;
    realmReactionRelation.reactionEventId = reactionRelation.reactionEventId;
    realmReactionRelation.originServerTs = reactionRelation.originServerTs;
    realmReactionRelation.roomId = roomId;
    realmReactionRelation.primaryKey = [MXRealmReactionRelation primaryKeyFromEventId:reactionRelation.eventId
                                                                   andReactionEventId:reactionRelation.reactionEventId];

    return realmReactionRelation;
}

@end
