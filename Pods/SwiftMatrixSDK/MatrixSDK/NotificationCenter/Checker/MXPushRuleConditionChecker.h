/*
 Copyright 2015 OpenMarket Ltd

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

#import "MXJSONModels.h"
#import "MXEvent.h"

@class MXRoomState;

/**
 `MXNotificationCenter` delegates push rule condition check to class that implements
 `MXPushRuleConditionChecker`.
 */
@protocol MXPushRuleConditionChecker <NSObject>

/**
 Check if an event satisfies a rule condition.

 @param condition the condition.
 @param event the event to check.
 @param contentAsJsonDict the content as a dictionnary.
 @return YES if the event satisties the condition.
 */
- (BOOL)isCondition:(MXPushRuleCondition*)condition satisfiedBy:(MXEvent*)event roomState:(MXRoomState*)roomState withJsonDict:(NSDictionary*)contentAsJsonDict;

@end
