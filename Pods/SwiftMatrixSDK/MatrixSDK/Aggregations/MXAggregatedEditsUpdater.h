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

#import "MXStore.h"
#import "MXAggregationsStore.h"

NS_ASSUME_NONNULL_BEGIN

@interface MXAggregatedEditsUpdater : NSObject

- (instancetype)initWithMatrixSession:(MXSession *)mxSession
                     aggregationStore:(id<MXAggregationsStore>)store
                          matrixStore:(id<MXStore>)matrixStore;

#pragma mark - Requests
- (MXHTTPOperation*)replaceTextMessageEvent:(MXEvent*)event
                            withTextMessage:(nullable NSString*)text
                              formattedText:(nullable NSString*)formattedText
                             localEchoBlock:(nullable void (^)(MXEvent *localEcho))localEchoBlock
                                    success:(void (^)(NSString *eventId))success
                                    failure:(void (^)(NSError *error))failure;

#pragma mark - Data update listener
- (id)listenToEditsUpdateInRoom:(NSString *)roomId block:(void (^)(MXEvent* replaceEvent))block;
- (void)removeListener:(id)listener;

#pragma mark - Data update
- (void)handleReplace:(MXEvent *)replaceEvent;
//- (void)handleRedaction:(MXEvent *)event;     // TODO(@steve): phase:2. We do not need to handle redaction of an edit for MVP

@end

NS_ASSUME_NONNULL_END
