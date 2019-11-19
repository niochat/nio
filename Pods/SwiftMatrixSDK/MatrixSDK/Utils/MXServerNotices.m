/*
 Copyright 2018 New Vector Ltd

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

#import "MXServerNotices.h"

#import "MXSession.h"
#import "MXTools.h"

// We need to fetch each pinned message individually (if we don't already have it)
// so each pinned message may trigger a request. Limit the number per room for sanity.
// NB. this is just for server notices rather than pinned messages in general.
NSUInteger const kMXServerNoticesMaxPinnedNoticesPerRoom = 2;


@interface MXServerNotices ()
{
    MXSession *mxSession;

    /**
     The listener to events that can indicate a change in server notices.
     */
    id eventsListener;
}
@end

@implementation MXServerNotices

- (instancetype)initWithMatrixSession:(MXSession *)matrixSession
{
    self = [super init];
    if (self)
    {
        mxSession = matrixSession;
    }
    return self;
}

- (void)close
{
    if (eventsListener)
    {
        [mxSession removeListener:eventsListener];
        eventsListener = nil;
    }

    _delegate = nil;
    mxSession = nil;
}

- (void)setDelegate:(id<MXServerNoticesDelegate>)delegate
{
    _delegate = delegate;

    if (!eventsListener)
    {
        // m.room.pinned_events and m.tag are events to listen
        MXWeakify(self);
        eventsListener = [mxSession listenToEventsOfTypes:@[kMXEventTypeStringRoomPinnedEvents, kMXEventTypeStringRoomTag]
                                                  onEvent:^(MXEvent *event, MXTimelineDirection direction, id customObject)
                          {
                              MXStrongifyAndReturnIfNil(self);

                              if (direction == MXTimelineDirectionForwards)
                              {
                                  if (event.eventType == MXEventTypeRoomPinnedEvents)
                                  {
                                      // In case of pinned events, we are interested only by those
                                      // in system alert rooms
                                      for (MXRoom *serverNoticeRoom in [self->mxSession roomsWithTag:kMXRoomTagServerNotice])
                                      {
                                          if ([serverNoticeRoom.roomId isEqualToString:event.roomId])
                                          {
                                              [self checkState];
                                              break;
                                          }
                                      }
                                  }
                                  else
                                  {
                                      // In case of tags change, recompute from start
                                      [self checkState];
                                  }
                              }
                          }];

        // Get the current state
        [self checkState];
    }
}

#pragma mark - Private methods

/**
 Set the new usage limit and informs the delegate if necessary.

 @param usageLimit the new usage limit.
 */
- (void)setUsageLimit:(MXServerNoticeContent *)usageLimit
{
    if (_usageLimit != usageLimit)
    {
        _usageLimit = usageLimit;

        if (_delegate)
        {
            [_delegate serverNoticesDidChangeState:self];
        }
    }
}

/**
 Compute the current server notices state
 */
- (void)checkState
{
    // Check all pinning events of system alert rooms
    [self serverNoticePinnedEvents:^(NSArray<MXEvent *> *pinnedEvents) {

        for (MXEvent *pinnedEvent in pinnedEvents)
        {
            if (pinnedEvent.eventType == MXEventTypeRoomMessage
                && [pinnedEvent.content[@"msgtype"] isEqualToString:kMXMessageTypeServerNotice])
            {
                // For now, there is only one server notice, usage limit
                self.usageLimit = [MXServerNoticeContent modelFromJSON:pinnedEvent.content];
                break;
            }
        }
    }];
}

/**
 Return all pinned events in server notice rooms.

 @param complete A block object called when the operation completes.
*/
- (void)serverNoticePinnedEvents:(nonnull void (^)(NSArray<MXEvent *> *pinnedEvents))complete
{
    NSMutableArray<MXEvent*> *serverNoticePinnedEvents = [NSMutableArray array];

    dispatch_group_t group = dispatch_group_create();

    // Get server notice rooms
    for (MXRoom *serverNoticeRoom in [mxSession roomsWithTag:kMXRoomTagServerNotice])
    {
        dispatch_group_enter(group);

        // Get pinned events ids
        MXWeakify(self);
        [serverNoticeRoom state:^(MXRoomState *roomState) {
            MXStrongifyAndReturnIfNil(self);

            // Apply kMXServerNoticesMaxPinnedNoticesPerRoom rule
            NSArray<NSString*> *pinnedEventIds = roomState.pinnedEvents;
            if (pinnedEventIds.count > kMXServerNoticesMaxPinnedNoticesPerRoom)
            {
                pinnedEventIds = [pinnedEventIds subarrayWithRange:NSMakeRange(0, kMXServerNoticesMaxPinnedNoticesPerRoom)];
            }

            // Get pinned events
            for (NSString *pinnedEventId in pinnedEventIds)
            {
                dispatch_group_enter(group);
                [self->mxSession eventWithEventId:pinnedEventId inRoom:serverNoticeRoom.roomId success:^(MXEvent *event) {

                    [serverNoticePinnedEvents addObject:event];
                    dispatch_group_leave(group);

                } failure:^(NSError *error) {

                    NSLog(@"[MXServerNotices] Failed to get pinned event %@. Continue anyway", pinnedEventId);
                    dispatch_group_leave(group);
                }];
            }

            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        complete(serverNoticePinnedEvents);
    });
}

@end
