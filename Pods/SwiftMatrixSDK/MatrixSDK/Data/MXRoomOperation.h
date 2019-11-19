/*
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

#import <Foundation/Foundation.h>

#import "MXHTTPOperation.h"

/**
 A `MXRoomOperation` instance represents a room message (text, image, ...) sending
 operation requested by the end user.
 In order to preserve messages order, these operations requests are stored in a
 FIFO and executed one after the other.
 */
@interface MXRoomOperation : NSObject

/**
 The block that will execute the operation.
 */
@property (nonatomic) void (^block)(void);

/**
 The current HTTP request being executed.

 Some MXRoomOperation may do several HTTP requests so that this reference can
 mutate.
 */
@property (nonatomic) MXHTTPOperation *operation;

/**
 Room message (text, image, ...) sending operations create local echo event.
 This is the id of this event.
 */
@property (nonatomic) NSString *localEventId;

/**
 Cancel status.
 */
@property (nonatomic, readonly, getter=isCancelled) BOOL canceled;

/**
 Mark the operation as cancelled.
 Cancel the HTTP request is any.
 */
- (void)cancel;

@end
