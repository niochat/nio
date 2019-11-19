/*
 Copyright 2015 OpenMarket Ltd
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

#import "MXPushRuleRoomMemberCountConditionChecker.h"

#import "MXSession.h"

@interface MXPushRuleRoomMemberCountConditionChecker ()
{
    MXSession *mxSession;

    /**
     The regular expressions to extract operand and value from the "is" parameter (ex: ">=2")
     */
    NSRegularExpression *opRegex;
    NSRegularExpression *valueRegex;
}

@end

@implementation MXPushRuleRoomMemberCountConditionChecker

- (instancetype)initWithMatrixSession:(MXSession *)mxSession2
{
    self = [super init];
    if (self)
    {
        mxSession = mxSession2;
        opRegex = [NSRegularExpression regularExpressionWithPattern:@"^([=<>]*)"
                                                            options:0 error:nil];
        valueRegex = [NSRegularExpression regularExpressionWithPattern:@"([0-9]*)$"
                                                               options:0 error:nil];
    }
    return self;
}

- (BOOL)isCondition:(MXPushRuleCondition*)condition satisfiedBy:(MXEvent*)event roomState:(MXRoomState*)roomState withJsonDict:(NSDictionary*)contentAsJsonDict
{
    if (!event.eventId)
    {
        // Do not take into account the events without identifier (typing notifications, read receipts...)
        // in room_member_count conditions, as they may be triggered a lot of times.
        return NO;
    }

    BOOL isSatisfied = NO;
    NSString *is;
    MXJSONModelSetString(is, condition.parameters[@"is"]);
    if (is)
    {
        // Extract the operand and the value from the is parameter
        NSString *op, *stringValue;

        NSRange range = [opRegex rangeOfFirstMatchInString:is options:0 range:NSMakeRange(0, is.length)];
        if (range.length)
        {
            op = [is substringWithRange:range];
        }

        range = [valueRegex rangeOfFirstMatchInString:is options:0 range:NSMakeRange(0, is.length)];
        if (range.length)
        {
            stringValue = [is substringWithRange:range];
        }

        if (stringValue)
        {
            NSInteger value = [[is substringWithRange:range] integerValue];

            // Check the targeted room member count against value
            MXRoom *room = [mxSession roomWithRoomId:event.roomId];
            
            // sanity checks
            if (room && room.summary)
            {
                if (nil == op || [op isEqualToString:@"=="])
                {
                    isSatisfied = (value == room.summary.membersCount.members);
                }
                else if ([op isEqualToString:@"<"])
                {
                    isSatisfied = (value < room.summary.membersCount.members);
                }
                else if ([op isEqualToString:@">"])
                {
                    isSatisfied = (value > room.summary.membersCount.members);
                }
                else if ([op isEqualToString:@">="])
                {
                    isSatisfied = (value >= room.summary.membersCount.members);
                }
                else if ([op isEqualToString:@"<="])
                {
                    isSatisfied = (value <= room.summary.membersCount.members);
                }
            }
        }
    }
    return isSatisfied;
}

@end
