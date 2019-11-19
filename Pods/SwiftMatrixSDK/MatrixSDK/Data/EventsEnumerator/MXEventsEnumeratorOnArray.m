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

#import "MXEventsEnumeratorOnArray.h"

@interface MXEventsEnumeratorOnArray ()
{
    // The list of events to enumerate on.
    // The order is chronological: the first item is the oldest message.
    NSArray<MXEvent*> *messages;

    // This is the position from the end
    NSInteger paginationPosition;
}

@end

@implementation MXEventsEnumeratorOnArray

- (instancetype)initWithMessages:(NSArray<MXEvent*> *)theMessages
{
    self = [super init];
    if (self)
    {
        // Copy the array of events references to be protected against mutation of
        // theMessages.
        // No need of a deep copy as the events it contains are immutable.
        messages = [theMessages copy];
        paginationPosition = messages.count;
    }
    return self;
}

- (NSArray *)nextEventsBatch:(NSUInteger)eventsCount
{
    NSArray *batch;

    if (0 < paginationPosition)
    {
        if (eventsCount < paginationPosition)
        {
            // Return a slice of messages
            batch = [messages subarrayWithRange:NSMakeRange(paginationPosition - eventsCount, eventsCount)];
            paginationPosition -= eventsCount;
        }
        else
        {
            // Return the last slice of messages
            batch = [messages subarrayWithRange:NSMakeRange(0, paginationPosition)];
            paginationPosition = 0;
        }
    }

    return batch;
}

- (MXEvent *)nextEvent
{
    MXEvent *nextEvent = nil;

    if (0 < paginationPosition)
    {
        nextEvent = messages[paginationPosition - 1];
        paginationPosition--;
    }

    return nextEvent;
}

- (NSUInteger)remaining
{
    return paginationPosition;
}

@end
