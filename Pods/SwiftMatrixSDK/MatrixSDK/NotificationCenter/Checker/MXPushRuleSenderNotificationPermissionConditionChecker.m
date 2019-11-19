/*
 Copyright 2017 Vector Creations Ltd
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

#import "MXPushRuleSenderNotificationPermissionConditionChecker.h"

#import "MXSession.h"

@interface MXPushRuleSenderNotificationPermissionConditionChecker ()
{
    MXSession *mxSession;
}
@end

@implementation MXPushRuleSenderNotificationPermissionConditionChecker

- (instancetype)initWithMatrixSession:(MXSession *)mxSession2
{
    self = [super init];
    if (self)
    {
        mxSession = mxSession2;
    }
    return self;
}

- (BOOL)isCondition:(MXPushRuleCondition*)condition satisfiedBy:(MXEvent*)event  roomState:(MXRoomState*)roomState withJsonDict:(NSDictionary*)contentAsJsonDict
{
    if (!event.eventId)
    {
        // Do not take into account the events without identifier (typing notifications, read receipts...)
        // in sender_notification_permission conditions, as they may be triggered a lot of times.
        return NO;
    }

    BOOL isSatisfied = NO;
    NSString *notifLevelKey;
    MXJSONModelSetString(notifLevelKey, condition.parameters[@"key"]);
    if (notifLevelKey)
    {
        MXRoom *room = [mxSession roomWithRoomId:event.roomId];
        if (room)
        {
            MXRoomPowerLevels *roomPowerLevels = roomState.powerLevels;
            NSInteger notifLevel = [roomPowerLevels minimumPowerLevelForNotifications:notifLevelKey defaultPower:50];
            NSInteger senderPowerLevel = [roomPowerLevels powerLevelOfUserWithUserID:event.sender];

            isSatisfied = (senderPowerLevel >= notifLevel);
        }
    }

    return isSatisfied;
}

@end
