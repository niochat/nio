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

#import "MXJSONModel.h"
#import "MXPusherData.h"

NS_ASSUME_NONNULL_BEGIN

@interface MXPusher : MXJSONModel

/**
 This is a unique identifier for this pusher.
 */
@property (nonatomic, readonly) NSString *pushkey;

/**
 The kind of pusher. "http" is a pusher that sends HTTP pokes.
 */
@property (nonatomic, readonly) NSString *kind;

/**
 This is a reverse-DNS style identifier for the application.
 */
@property (nonatomic, readonly) NSString *appId;

/**
 A string that will allow the user to identify what application owns this pusher.
 */
@property (nonatomic, readonly) NSString *appDisplayName;

/**
 A string that will allow the user to identify what device owns this pusher.
 */
@property (nonatomic, readonly) NSString *deviceDisplayName;

/**
 This string determines which set of device specific rules this pusher executes.
 */
@property (nonatomic, nullable, readonly) NSString *profileTag;

/**
 The preferred language for receiving notifications (e.g. 'en' or 'en-US').
 */
@property (nonatomic, readonly) NSString *lang;

/**
 A dictionary of information for the pusher implementation itself.
 */
@property (nonatomic, readonly) MXPusherData *data;

@end

NS_ASSUME_NONNULL_END
