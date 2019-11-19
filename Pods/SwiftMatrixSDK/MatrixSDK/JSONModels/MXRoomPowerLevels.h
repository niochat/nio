/*
 Copyright 2014 OpenMarket Ltd

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

#import "MXJSONModel.h"

#import "MXEvent.h"

/**
 `MXRoomPowerLevels` represents the content of a m.room.power_levels event.

 Such event provides information of the power levels attributed to the room members.
 It also defines minimum power level value a member must have to accomplish an action or 
 to send an event of a given type.
 */
@interface MXRoomPowerLevels : MXJSONModel

#pragma mark - Power levels of room members
/**
 The users who have a defined power level.
 The dictionary keys are user ids and the values, their power levels.
 */
@property (nonatomic) NSDictionary *users;

/**
 The default power level for users not listed in `users`.
 */
@property (nonatomic) NSInteger usersDefault;

/**
 Helper to get the power level of a member of the room.

 @param userId the id of the user.
 @return his power level.
 */
- (NSInteger)powerLevelOfUserWithUserID:(NSString*)userId;


#pragma mark - minimum power level for actions
/**
 The minimum power level to ban someone.
 */
@property (nonatomic) NSInteger ban;

/**
 The minimum power level to kick someone.
 */
@property (nonatomic) NSInteger kick;

/**
 The minimum power level to redact an event.
 */
@property (nonatomic) NSInteger redact;

/**
 The minimum power level to invite someone.
 */
@property (nonatomic) NSInteger invite;

/**
 The minimum power level for using sender_notification_permission notification condition ("@room").
 Notification key -> minimum power level
 */
@property (nonatomic) NSDictionary<NSString*, NSNumber*> *notifications;


#pragma mark - minimum power level for sending events
/**
 The event types for which a minimum power level has been defined.
 The dictionary keys are event type and the values, their minimum required power levels.
 */
@property (nonatomic) NSDictionary *events;

/**
 The default minimum power level to send an event as a message when its event type is not
 defined in `events`.
 */
@property (nonatomic) NSInteger eventsDefault;

/**
 The default minimum power level to send an event as a state event when its event
 type is not defined in `events`.
 */
@property (nonatomic) NSInteger stateDefault;

/**
 Helper to get the minimum power level the user must have to send an event of the given type 
 as a message.

 @param eventTypeString the type of event.
 @return the required minimum power level.
 */
- (NSInteger)minimumPowerLevelForSendingEventAsMessage:(MXEventTypeString)eventTypeString NS_REFINED_FOR_SWIFT;

/**
 Helper to get the minimum power level the user must have to send an event of the given type
 as a state event.

 @param eventTypeString the type of event.
 @return the required minimum power level.
 */
- (NSInteger)minimumPowerLevelForSendingEventAsStateEvent:(MXEventTypeString)eventTypeString NS_REFINED_FOR_SWIFT;

/**
 Helper to get the minimum power level the user must have to send conditional notifications (like "@room").

 @param key the notification key (like "room").
 @param defaultPower the default value to return if the information is not available.
 @return the required minimum power level.
 */
- (NSInteger)minimumPowerLevelForNotifications:(NSString*)key defaultPower:(NSInteger)defaultPower;

@end
