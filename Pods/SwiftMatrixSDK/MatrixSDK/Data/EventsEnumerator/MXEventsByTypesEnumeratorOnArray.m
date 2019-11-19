/*
 Copyright 2016 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd

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

#import "MXEventsByTypesEnumeratorOnArray.h"

#import "MXEventsEnumeratorOnArray.h"

@interface MXEventsByTypesEnumeratorOnArray ()
{
    // The all-messages enumerator
    // Note: it would be much quicker to process directly `messages` but
    // the all-messages enumerator make this enumerator easy to implement.
    MXEventsEnumeratorOnArray *allMessagesEnumerator;

    // The event types to filter in
    NSArray *types;
}

@end

@implementation MXEventsByTypesEnumeratorOnArray

- (instancetype)initWithMessages:(NSArray<MXEvent *> *)messages andTypesIn:(NSArray *)theTypes
{
    self = [super init];
    if (self)
    {
        types = theTypes;
        allMessagesEnumerator = [[MXEventsEnumeratorOnArray alloc] initWithMessages:messages];
    }

    return self;
}

- (NSArray<MXEvent *> *)nextEventsBatch:(NSUInteger)eventsCount
{
    NSMutableArray *nextEvents;
    MXEvent *event;

    // Feed the array with matching events
    while ((event = self.nextEvent) && (nextEvents.count != eventsCount))
    {
        if (!nextEvents)
        {
            // Create the array only if there are events to return
            nextEvents = [NSMutableArray arrayWithCapacity:eventsCount];
        }

        [nextEvents addObject:event];
    }

    return nextEvents;
}

- (MXEvent *)nextEvent
{
    MXEvent *event, *nextEvent;

    // Loop until an event matches the criteria
    while ((event = [allMessagesEnumerator nextEvent]))
    {
        if (event.eventId && (!types || (NSNotFound != [types indexOfObject:event.type])))
        {
            nextEvent = event;
            break;
        }
    }

    return nextEvent;
}

- (NSUInteger)remaining
{
    // We are in the case of a filtered result, we can return NSUIntegerMax
    // because it would take too much time to compute.
    return NSUIntegerMax;
}

@end
