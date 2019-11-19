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

#import "MXAggregatedReactions.h"

@implementation MXAggregatedReactions

- (nullable MXAggregatedReactions *)aggregatedReactionsWithNonZeroCount
{
    NSMutableArray *reactions = [NSMutableArray arrayWithCapacity:self.reactions.count];
    for (MXReactionCount *reactionCount in self.reactions)
    {
        if (reactionCount.count > 0)
        {
            [reactions addObject:reactionCount];
        }
    }

    MXAggregatedReactions *nonZeroCountAggregatedReactions;
    if (reactions.count)
    {
        nonZeroCountAggregatedReactions = [MXAggregatedReactions new];
        nonZeroCountAggregatedReactions.reactions = reactions;
    }

    return nonZeroCountAggregatedReactions;
}

@end
