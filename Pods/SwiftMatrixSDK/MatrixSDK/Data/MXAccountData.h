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

#import <Foundation/Foundation.h>

/**
 `MXAccountData` holds the user account data.
 
 Account data contains infomation like the push rules and the ignored users list.
 It is fully or partially updated on homeserver `/sync` response.

 The main purpose of this class is to maintain the data with partial update.
 */
@interface MXAccountData : NSObject

/**
 Update the account data with the passed event.
 
 @param event one event of the "account_data" field of a `/sync` response.
 */
- (void)updateWithEvent:(NSDictionary*)event;

/**
 Get account data event by event type.

 @param eventType The event type being queried.
 @return the user account_data event of given type, if any.
 */
- (NSDictionary *)accountDataForEventType:(NSString*)eventType;

/**
 The account data as sent by the homeserver /sync response.
 */
@property (nonatomic, readonly) NSDictionary<NSString *, id> *accountData;

@end
