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

#import <Foundation/Foundation.h>

#import "MXServerNoticeContent.h"

@class MXSession;

@protocol MXServerNoticesDelegate;

/**
 A `MXServerNotices` instance is responsible for listening to messages from the
 user homeserver.

 It implements https://github.com/matrix-org/matrix-doc/issues/1452.system where
 this communication channel is based on system alert rooms and their pinning events.
 */
@interface MXServerNotices : NSObject

/**
 Create the `MXServerNotices` instance.

 @param mxSession the mxSession to the home server.
 @return the newly created MXNotification instance.
 */
- (instancetype)initWithMatrixSession:(MXSession*)mxSession;

/**
 Stop checking homeserver notices.
 */
- (void)close;

/**
 If not nil, there is an outgoing usage limitation.
 */
@property (nonatomic, readonly) MXServerNoticeContent *usageLimit;

/**
 The delegate.
 */
@property (nonatomic, weak) id<MXServerNoticesDelegate> delegate;

@end


#pragma mark - MXServerNoticesDelegate

/**
 Delegate for `MXCall` object
 */
@protocol MXServerNoticesDelegate <NSObject>

/**
 Tells the delegate that there is a change in server notices

 @param serverNotices the instance that changes.
 */
- (void)serverNoticesDidChangeState:(MXServerNotices *)serverNotices;

@end
