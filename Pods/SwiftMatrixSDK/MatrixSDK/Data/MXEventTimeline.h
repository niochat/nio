/*
 Copyright 2016 OpenMarket Ltd
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

#import "MXEvent.h"
#import "MXRoomEventFilter.h"
#import "MXJSONModels.h"
#import "MXRoomState.h"
#import "MXHTTPOperation.h"

/**
 Prefix used to build fake invite event.
 */
FOUNDATION_EXPORT NSString *const kMXRoomInviteStateEventIdPrefix;

/**
 Block called when an event of the registered types has been handled in the timeline.
 This is a specialisation of the `MXOnEvent` block.

 @param event the new event.
 @param direction the origin of the event.
 @param roomState the room state right before the event.
 */
typedef void (^MXOnRoomEvent)(MXEvent *event, MXTimelineDirection direction, MXRoomState *roomState) NS_REFINED_FOR_SWIFT;

@class MXRoom;
@protocol MXStore;

/**
 A `MXEventTimeline` instance represents a contiguous sequence of events in a room.
 
 There are two kinds of timeline:

    - live timelines: they receive live events from the events stream. You can paginate
      backwards but not forwards. 
      All (live or backwards) events they receive are stored in the store of the current
      MXSession.

    - past timelines: they start in the past from an `initialEventId`. They are filled
      with events on calls of [MXEventTimeline paginate] in backwards or forwards direction.
      Events are stored in a in-memory store (MXMemoryStore) (@TODO: To be confirmed once they will be implemented). So, they are not permanent.
 */
@interface MXEventTimeline : NSObject

/**
 The id of this timeline.
 */
@property (nonatomic, readonly) NSString *timelineId;

/**
 The initial event id used to initialise the timeline.
 Nil in case of live timeline.
 */
@property (nonatomic, readonly) NSString *initialEventId;

/**
 Indicate if this timeline is a live one.
 */
@property (nonatomic, readonly) BOOL isLiveTimeline;

/**
 The room events filter which is applied during the history pagination.

 The default value can be nil. It depends if the lazy loading of room members
 is enabled or not.
 The filter can be modified but only before starting paginating, ie before calling one
 the resetPagination methods.
 */
@property (nonatomic, copy) MXRoomEventFilter *roomEventFilter;

/**
 The state of the room at the top most recent event of the timeline.
 */
@property (nonatomic, readonly) MXRoomState *state;


#pragma mark - Initialisation
/**
 Create a timeline instance for a room.

 If the timeline is live, the events will be stored to the MXSession instance store.
 Else, they will be only stored in memory and released on [MXEventTimeline destroy].

 @param room the room associated to the timeline
 @param initialEventId the initial event for the timeline. A nil value will create a live timeline.
 @return a MXEventTimeline instance.
 */
- (id)initWithRoom:(MXRoom*)room andInitialEventId:(NSString*)initialEventId;

/**
 Create a timeline instance for a room and force it to use the given MXStore to store events.

 @param room the room associated to the timeline
 @param initialEventId the initial event for the timeline. A nil value will create a live timeline.
 @param store the store to use to store timeline events.
 @return a MXEventTimeline instance.
 */
- (id)initWithRoom:(MXRoom*)room initialEventId:(NSString*)initialEventId andStore:(id<MXStore>)store;

/**
 Initialise the room evenTimeline state.

 @param stateEvents the state event.
 */
- (void)initialiseState:(NSArray<MXEvent*> *)stateEvents;

/**
 Reset the room evenTimeline state.

 @param roomState the new state to use.
 */
- (void)setState:(MXRoomState *)roomState;

/**
 Release RAM memory used by the timeline.
 */
- (void)destroy;


#pragma mark - Pagination
/**
 Check if this timelime can be extended.

 This returns true if we either have more events, or if we have a pagination
 token which means we can paginate in that direction. It does not necessarily
 mean that there are more events available in that direction at this time.
 
 canPaginate in forward direction has no meaning for a live timeline.

 @param direction MXTimelineDirectionBackwards to check if we can paginate backwards.
                  MXTimelineDirectionForwards to check if we can go forwards.
 @return true if we can paginate in the given direction.
 */
- (BOOL)canPaginate:(MXTimelineDirection)direction NS_REFINED_FOR_SWIFT;

/**
 Reset the pagination so that future calls to paginate start from the most recent
 event of the timeline.
 */
- (void)resetPagination;

/**
 Reset the pagination timelime and start loading the context around its `initialEventId`.
 The retrieved (backwards and forwards) events will be sent to registered listeners.

 @param limit the maximum number of messages to get around the initial event.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)resetPaginationAroundInitialEventWithLimit:(NSUInteger)limit
                                                       success:(void(^)(void))success
                                                       failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Get more messages.
 The retrieved events will be sent to registered listeners.
 
 Note it is not possible to paginate forwards on a live timeline.

 @param numItems the number of items to get.
 @param direction `MXTimelineDirectionForwards` or `MXTimelineDirectionBackwards`
 @param onlyFromStore if YES, return available events from the store, do not make
                      a pagination request to the homeserver.

 @param complete A block object called when the operation is complete.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance. This instance can be nil if no request
         to the homeserver is required.
 */
- (MXHTTPOperation*)paginate:(NSUInteger)numItems
                   direction:(MXTimelineDirection)direction
               onlyFromStore:(BOOL)onlyFromStore
                    complete:(void (^)(void))complete
                     failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Get the number of messages we can still back paginate from the store.
 It provides the count of events available without making a request to the home server.

 @return the count of remaining messages in store.
 */
- (NSUInteger)remainingMessagesForBackPaginationInStore;


#pragma mark - Server sync
/**
 For live timeline, update data according to the received /sync response.

 @param roomSync information to sync the room with the home server data
 */
- (void)handleJoinedRoomSync:(MXRoomSync*)roomSync;

/**
 For live timeline, update invited room state according to the received /sync response.

 @param invitedRoomSync information to update the room state.
 */
- (void)handleInvitedRoomSync:(MXInvitedRoomSync *)invitedRoomSync;

/**
 For live timeline, enrich lazy loaded state events with more state events.

 @param stateEvents state events to append.
 */
- (void)handleLazyLoadedStateEvents:(NSArray<MXEvent *> *)stateEvents;

#pragma mark - Events listeners
/**
 Register a listener to events of this timeline.

 @param onEvent the block that will called once a new event has been handled.
 @return a reference to use to unregister the listener
 */
- (id)listenToEvents:(MXOnRoomEvent)onEvent NS_REFINED_FOR_SWIFT;

/**
 Register a listener for some types of events.

 @param types an array of event types strings (MXEventTypeString) to listen to.
 @param onEvent the block that will called once a new event has been handled.
 @return a reference to use to unregister the listener
 */
- (id)listenToEventsOfTypes:(NSArray<MXEventTypeString> *)types onEvent:(MXOnRoomEvent)onEvent NS_REFINED_FOR_SWIFT;

/**
 Unregister a listener.

 @param listener the reference of the listener to remove.
 */
- (void)removeListener:(id)listener;

/**
 Unregister all listeners.
 */
- (void)removeAllListeners;

/**
 Notifiy all listeners of the timeline about the given event.
 
 @param event the event to notify.
 @param direction the event direction.
 */
- (void)notifyListeners:(MXEvent*)event direction:(MXTimelineDirection)direction;

@end
