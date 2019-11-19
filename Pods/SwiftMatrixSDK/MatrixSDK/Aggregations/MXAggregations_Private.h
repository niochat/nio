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

#import "MXAggregations.h"

@class MXSession, MXEvent;


NS_ASSUME_NONNULL_BEGIN

/**
 The `MXAggregations_Private` extension exposes internal operations.
 */
@interface MXAggregations ()

/**
 Constructor.

 @param mxSession the related 'MXSession'.
 */
- (instancetype)initWithMatrixSession:(MXSession *)mxSession;

/**
 Notify the aggregation manager for every events so that it can store
 aggregated data sent by the server.

 @param event the event received in a timeline.
 */
- (void)handleOriginalDataOfEvent:(MXEvent*)event;

/**
 Clear cached data for a room.

 Events for that rooms are no more part of our timelines.
 Because of gappy syncs, we cannot guarantee the data is up-to-date. So, erase it.
 We will get aggregated data again in bundled data when paginating events.
 */
- (void)resetDataInRoom:(NSString *)roomId;

@end

NS_ASSUME_NONNULL_END

