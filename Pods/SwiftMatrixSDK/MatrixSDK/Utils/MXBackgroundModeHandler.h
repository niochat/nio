/*
 Copyright 2017 Samuel Gallet
 Copyright 2017 Vector Creations Ltd
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

#ifndef MXBackgroundModeHandler_h
#define MXBackgroundModeHandler_h

#import <Foundation/Foundation.h>
#import "MXBackgroundTask.h"

typedef void (^MXBackgroundTaskExpirationHandler)(void);

NS_ASSUME_NONNULL_BEGIN

/**
 Interface to handle enabling background mode
 */
@protocol MXBackgroundModeHandler <NSObject>

- (id<MXBackgroundTask>)startBackgroundTaskWithName:(NSString *)name expirationHandler:(nullable MXBackgroundTaskExpirationHandler)expirationHandler;

@end

NS_ASSUME_NONNULL_END

#endif /* MXBackgroundModeHandler_h */
