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

#import "MXNotificationCenter.h"

#import "MXSession.h"
#import "MXTools.h"
#import "MXPushRuleEventMatchConditionChecker.h"
#import "MXPushRuleDisplayNameCondtionChecker.h"
#import "MXPushRuleRoomMemberCountConditionChecker.h"
#import "MXPushRuleSenderNotificationPermissionConditionChecker.h"

NSString *const kMXNotificationCenterWillUpdateRules = @"kMXNotificationCenterWillUpdateRules";
NSString *const kMXNotificationCenterDidUpdateRules = @"kMXNotificationCenterDidUpdateRules";
NSString *const kMXNotificationCenterDidFailRulesUpdate = @"kMXNotificationCenterDidFailRulesUpdate";
NSString *const kMXNotificationCenterErrorKey = @"kMXNotificationCenterErrorKey";

NSString *const kMXNotificationCenterDisableAllNotificationsRuleID = @".m.rule.master";
NSString *const kMXNotificationCenterContainUserNameRuleID = @".m.rule.contains_user_name";
NSString *const kMXNotificationCenterContainDisplayNameRuleID = @".m.rule.contains_display_name";
NSString *const kMXNotificationCenterOneToOneRoomRuleID = @".m.rule.room_one_to_one";
NSString *const kMXNotificationCenterInviteMeRuleID = @".m.rule.invite_for_me";
NSString *const kMXNotificationCenterMemberEventRuleID = @".m.rule.member_event";
NSString *const kMXNotificationCenterCallRuleID = @".m.rule.call";
NSString *const kMXNotificationCenterSuppressBotsNotificationsRuleID = @".m.rule.suppress_notices";
NSString *const kMXNotificationCenterAllOtherRoomMessagesRuleID = @".m.rule.message";
//NSString *const kMXNotificationCenterRuleID_fallback = @".m.rule.fallback";

@interface MXNotificationCenter ()
{
    /**
     The Matrix session to make be able to make Home Server requests.
     */
    MXSession *mxSession;

    /**
     The list of notifications listeners.
     */
    NSMutableArray *notificationListeners;

    /**
     The list of condition checkers.
     The keys are the condition kinds and the values, the `MXPushRuleConditionChecker` objects
     to use to validate a condition.
     */
    NSMutableDictionary *conditionCheckers;

    /**
     Keep the reference on the event_match condition as it can reuse to check Content, Room and Sender rules.
    */
    MXPushRuleEventMatchConditionChecker *eventMatchConditionChecker;
}
@end

@implementation MXNotificationCenter
@synthesize flatRules;

- (instancetype)initWithMatrixSession:(MXSession *)mxSession2
{
    self = [super init];
    if (self)
    {
        mxSession = mxSession2;
        notificationListeners = [NSMutableArray array];

        conditionCheckers = [NSMutableDictionary dictionary];

        // Define condition checkers for default Matrix conditions
        eventMatchConditionChecker = [[MXPushRuleEventMatchConditionChecker alloc] init];
        [self setChecker:eventMatchConditionChecker forConditionKind:kMXPushRuleConditionStringEventMatch];

        MXPushRuleDisplayNameCondtionChecker *displayNameCondtionChecker = [[MXPushRuleDisplayNameCondtionChecker alloc] initWithMatrixSession:mxSession];
        [self setChecker:displayNameCondtionChecker forConditionKind:kMXPushRuleConditionStringContainsDisplayName];

        MXPushRuleRoomMemberCountConditionChecker *roomMemberCountConditionChecker = [[MXPushRuleRoomMemberCountConditionChecker alloc] initWithMatrixSession:mxSession];
        [self setChecker:roomMemberCountConditionChecker forConditionKind:kMXPushRuleConditionStringRoomMemberCount];

        MXPushRuleSenderNotificationPermissionConditionChecker *notificationPermissionConditionChecker = [[MXPushRuleSenderNotificationPermissionConditionChecker alloc] initWithMatrixSession:mxSession];
        [self setChecker:notificationPermissionConditionChecker forConditionKind:kMXPushRuleConditionStringSenderNotificationPermission];

        // Catch all live events sent from other users to check if we need to notify them
        MXWeakify(self);
        [mxSession listenToEvents:^(MXEvent *event, MXTimelineDirection direction, id customObject) {
            MXStrongifyAndReturnIfNil(self);

            if (MXTimelineDirectionForwards == direction
                && NO == [event.sender isEqualToString:self->mxSession.matrixRestClient.credentials.userId])
            {
                [self shouldNotify:event roomState:customObject];
            }
        }];
    }
    return self;
}

- (MXHTTPOperation *)refreshRules:(void (^)(void))success failure:(void (^)(NSError *))failure
{
    return [mxSession.matrixRestClient pushRules:^(MXPushRulesResponse *pushRules) {

        [self handlePushRulesResponse:pushRules];

        if (success)
        {
            success();
        }
        
    } failure:^(NSError *error) {
        NSLog(@"[MXNotificationCenter] Cannot retrieve push rules from the home server");

        if (failure)
        {
            failure(error);
        }
    }];
}

- (void)handlePushRulesResponse:(MXPushRulesResponse*)pushRules
{
    _rules = pushRules;

    @synchronized(self)
    {
        flatRules = [NSMutableArray array];

        // Add rules by their priority

        // @TODO: manage device rules

        // Global rules
        [flatRules addObjectsFromArray:pushRules.global.override];
        [flatRules addObjectsFromArray:pushRules.global.content];
        [flatRules addObjectsFromArray:pushRules.global.room];
        [flatRules addObjectsFromArray:pushRules.global.sender];
        [flatRules addObjectsFromArray:pushRules.global.underride];
    }
}

- (void)setChecker:(id<MXPushRuleConditionChecker>)checker forConditionKind:(MXPushRuleConditionString)conditionKind
{
    [conditionCheckers setObject:checker forKey:conditionKind];
}

- (MXPushRule *)ruleMatchingEvent:(MXEvent *)event roomState:(MXRoomState*)roomState
{
    MXPushRule *theRule = nil;

    // Consider only events from other users
    if (NO == [event.sender isEqualToString:mxSession.matrixRestClient.credentials.userId])
    {
        NSDictionary *JSONDictionary = nil;
        
        @synchronized(self)
        {
            // Check rules one by one according to their priorities
            for (MXPushRule *rule in flatRules)
            {
                // Skip disabled rules
                if (!rule.enabled)
                {
                    continue;
                }
                
                if (!JSONDictionary)
                {
                    JSONDictionary = event.JSONDictionary;
                }
                
                BOOL conditionsOk = YES;
                
                // The test depends of the kind of the rule
                switch (rule.kind)
                {
                    case MXPushRuleKindOverride:
                    case MXPushRuleKindUnderride:
                    {
                        // Check all conditions described by the rule
                        // If there is no condition, the rule must be applied
                        conditionsOk = YES;
                        
                        for (MXPushRuleCondition *condition in rule.conditions)
                        {
                            id<MXPushRuleConditionChecker> checker = [conditionCheckers valueForKey:condition.kind];
                            if (checker)
                            {
                                conditionsOk = [checker isCondition:condition satisfiedBy:event roomState:roomState withJsonDict:JSONDictionary];
                                if (NO == conditionsOk)
                                {
                                    // Do not need to go further
                                    break;
                                }
                            }
                            else
                            {
                                NSLog(@"[MXNotificationCenter] Warning: There is no MXPushRuleConditionChecker to check condition of kind: %@", condition.kind);
                                conditionsOk = NO;
                            }
                        }
                        break;
                    }
                        
                    case MXPushRuleKindContent:
                    {
                        // Content rules are rules on the "content.body" field
                        // Tranlate this into a fake condition
                        MXPushRuleCondition *equivalentCondition = [[MXPushRuleCondition alloc] init];
                        equivalentCondition.kindType = MXPushRuleConditionTypeEventMatch;
                        equivalentCondition.parameters = @{
                                                           @"key": @"content.body",
                                                           @"pattern": rule.pattern
                                                           };
                        
                        conditionsOk = [eventMatchConditionChecker isCondition:equivalentCondition satisfiedBy:event roomState:roomState withJsonDict:JSONDictionary];
                        break;
                    }
                        
                    case MXPushRuleKindRoom:
                    {
                        // Room rules are rules on the "room_id" field
                        // Translate this into a fake condition
                        MXPushRuleCondition *equivalentCondition = [[MXPushRuleCondition alloc] init];
                        equivalentCondition.kindType = MXPushRuleConditionTypeEventMatch;
                        equivalentCondition.parameters = @{
                                                           @"key": @"room_id",
                                                           @"pattern": rule.ruleId
                                                           };
                        
                        conditionsOk = [eventMatchConditionChecker isCondition:equivalentCondition satisfiedBy:event roomState:roomState withJsonDict:JSONDictionary];
                        break;
                    }
                        
                    case MXPushRuleKindSender:
                    {
                        // Sender rules are rules on the "user_id" field
                        // Translate this into a fake condition
                        MXPushRuleCondition *equivalentCondition = [[MXPushRuleCondition alloc] init];
                        equivalentCondition.kindType = MXPushRuleConditionTypeEventMatch;
                        equivalentCondition.parameters = @{
                                                           @"key": @"user_id",
                                                           @"pattern": rule.ruleId
                                                           };
                        
                        conditionsOk = [eventMatchConditionChecker isCondition:equivalentCondition satisfiedBy:event roomState:roomState withJsonDict:JSONDictionary];
                        break;
                    }
                }
                
                if (conditionsOk)
                {
                    theRule = rule;
                    break;
                }
            }
        }
    }

    return theRule;
}

- (MXPushRule*)ruleById:(NSString*)pushRuleId
{
    @synchronized(self)
    {
        for (MXPushRule *rule in flatRules)
        {
            if ([rule.ruleId isEqualToString:pushRuleId])
            {
                return rule;
            }
        }
    }
    
    return  nil;
}

#pragma mark - Push notification listeners
- (id)listenToNotifications:(MXOnNotification)onNotification
{
    MXOnNotification onNotificationCopy = onNotification;
    [notificationListeners addObject:onNotificationCopy];
    return onNotificationCopy;
}

- (void)removeListener:(id)listener
{
    [notificationListeners removeObject:listener];
}

- (void)removeAllListeners
{
    [notificationListeners removeAllObjects];
}

// Notify all listeners
- (void)notifyListeners:(MXEvent*)event roomState:(MXRoomState*)roomState rule:(MXPushRule*)rule
{
    // Make a copy to manage the case where a listener has been removed while calling the blocks
    NSArray* listeners = [notificationListeners copy];
    for (MXOnNotification listener in listeners)
    {
        if (NSNotFound != [notificationListeners indexOfObject:listener])
        {
            listener(event, roomState, rule);
        }
    }
}

#pragma mark - Push rules handling
- (void)removeRule:(MXPushRule*)pushRule
{
    if (pushRule)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXNotificationCenterWillUpdateRules object:self userInfo:nil];

        MXWeakify(self);
        [mxSession.matrixRestClient removePushRule:pushRule.ruleId scope:pushRule.scope kind:pushRule.kind success:^{
            MXStrongifyAndReturnIfNil(self);
            
            @synchronized(self)
            {
                // Remove locally the rule
                
                // Caution: only global rules are handled presenly
                for (NSUInteger index = 0; index < self->flatRules.count; index++)
                {
                    MXPushRule *rule = self->flatRules[index];
                    
                    if ([rule.ruleId isEqualToString:pushRule.ruleId])
                    {
                        [self->flatRules removeObjectAtIndex:index];
                        
                        NSMutableArray *updatedArray;
                        switch (rule.kind)
                        {
                            case MXPushRuleKindOverride:
                            {
                                updatedArray = [NSMutableArray arrayWithArray:self.rules.global.override];
                                [updatedArray removeObject:rule];
                                self.rules.global.override = updatedArray;
                                break;
                            }
                            case MXPushRuleKindContent:
                            {
                                updatedArray = [NSMutableArray arrayWithArray:self.rules.global.content];
                                [updatedArray removeObject:rule];
                                self.rules.global.content = updatedArray;
                                break;
                            }
                            case MXPushRuleKindRoom:
                            {
                                updatedArray = [NSMutableArray arrayWithArray:self.rules.global.room];
                                [updatedArray removeObject:rule];
                                self.rules.global.room = updatedArray;
                                break;
                            }
                            case MXPushRuleKindSender:
                            {
                                updatedArray = [NSMutableArray arrayWithArray:self.rules.global.sender];
                                [updatedArray removeObject:rule];
                                self.rules.global.sender = updatedArray;
                                break;
                            }
                            case MXPushRuleKindUnderride:
                            {
                                updatedArray = [NSMutableArray arrayWithArray:self.rules.global.underride];
                                [updatedArray removeObject:rule];
                                self.rules.global.underride = updatedArray;
                                break;
                            }
                        }
                        
                        break;
                    }
                }
            }

            [[NSNotificationCenter defaultCenter] postNotificationName:kMXNotificationCenterDidUpdateRules object:self userInfo:nil];
            
        } failure:^(NSError *error) {
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXNotificationCenterDidFailRulesUpdate object:self userInfo:@{kMXNotificationCenterErrorKey:error}];
            
        }];
    }
}

- (void)enableRule:(MXPushRule*)pushRule isEnabled:(BOOL)enable
{
    if (pushRule)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXNotificationCenterWillUpdateRules object:self userInfo:nil];

        MXWeakify(self);
        [mxSession.matrixRestClient enablePushRule:pushRule.ruleId scope:pushRule.scope kind:pushRule.kind enable:enable success:^{
            MXStrongifyAndReturnIfNil(self);
            
            @synchronized(self)
            {
                // Update locally the rules
                
                // Caution: only global rules are handled presenly
                for (NSUInteger index = 0; index < self->flatRules.count; index++)
                {
                    MXPushRule *rule = self->flatRules[index];
                    
                    if ([rule.ruleId isEqualToString:pushRule.ruleId])
                    {
                        rule.enabled = enable;
                        break;
                    }
                }
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXNotificationCenterDidUpdateRules object:self userInfo:nil];
            
        } failure:^(NSError *error) {
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXNotificationCenterDidFailRulesUpdate object:self userInfo:@{kMXNotificationCenterErrorKey:error}];
            
        }];
    }
}

- (void)addContentRule:(NSString *)pattern
                notify:(BOOL)notify
                 sound:(BOOL)sound
             highlight:(BOOL)highlight
{
    // Compute rule id from pattern
    NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890_"];
    set = [set invertedSet];
    NSString *ruleId = [[pattern componentsSeparatedByCharactersInSet:set] componentsJoinedByString:@""];
    
    // Check whether the ruleId is unique
    if ([self ruleById:ruleId])
    {
        NSInteger index = 1;
        NSMutableString *mutableRuleId = [NSMutableString stringWithFormat:@"%@%ld", ruleId, (long)index];
        while ([self ruleById:mutableRuleId])
        {
            index++;
            mutableRuleId = [NSMutableString stringWithFormat:@"%@%ld", ruleId, (long)index];
        }
        ruleId = mutableRuleId;
    }
    
    [self addRuleWithId:ruleId kind:MXPushRuleKindContent pattern:pattern conditions:nil notify:notify sound:sound highlight:highlight];
}

- (void)addRoomRule:(NSString *)roomId
             notify:(BOOL)notify
              sound:(BOOL)sound
          highlight:(BOOL)highlight
{
    [self addRuleWithId:roomId kind:MXPushRuleKindRoom pattern:nil conditions:nil notify:notify sound:sound highlight:highlight];
}

- (void)addSenderRule:(NSString *)senderId
               notify:(BOOL)notify
                sound:(BOOL)sound
            highlight:(BOOL)highlight
{
    [self addRuleWithId:senderId kind:MXPushRuleKindSender pattern:nil conditions:nil notify:notify sound:sound highlight:highlight];
}

- (void)addOverrideRuleWithId:(NSString*)ruleId
                   conditions:(NSArray<NSDictionary *> *)conditions
                       notify:(BOOL)notify
                        sound:(BOOL)sound
                    highlight:(BOOL)highlight
{
    [self addRuleWithId:ruleId kind:MXPushRuleKindOverride pattern:nil conditions:conditions notify:notify sound:sound highlight:highlight];
}

- (void)addRuleWithId:(NSString*)ruleId
                 kind:(MXPushRuleKind)kind
              pattern:(NSString *)pattern
           conditions:(NSArray<NSDictionary *> *)conditions
                notify:(BOOL)notify
                 sound:(BOOL)sound
             highlight:(BOOL)highlight
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXNotificationCenterWillUpdateRules object:self userInfo:nil];
    
    NSMutableArray *actions = [NSMutableArray array];
    if (notify)
    {
        [actions addObject:@"notify"];
    }
    else
    {
        [actions addObject:@"dont_notify"];
    }
    
    if (sound)
    {
        [actions addObject:@{@"set_tweak": @"sound", @"value": @"default"}];
    }
    
    if (highlight)
    {
        [actions addObject:@{@"set_tweak": @"highlight"}];
    }
    
    [mxSession.matrixRestClient addPushRule:ruleId scope:kMXPushRuleScopeStringGlobal kind:kind actions:actions pattern:pattern conditions:conditions success:^{
        
        // Refresh locally rules
        [self refreshRules:^{
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXNotificationCenterDidUpdateRules object:self userInfo:nil];
        } failure:^(NSError *error) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXNotificationCenterDidFailRulesUpdate object:self userInfo:@{kMXNotificationCenterErrorKey:error}];
        }];
        
    } failure:^(NSError *error) {
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXNotificationCenterDidFailRulesUpdate object:self userInfo:@{kMXNotificationCenterErrorKey:error}];
        
    }];
}


#pragma mark - Private methods
// Check if the event should be notified to the listeners
- (void)shouldNotify:(MXEvent*)event roomState:(MXRoomState*)roomState
{
    // Check for notifications only if we have listeners
    if (notificationListeners.count)
    {
        MXPushRule *rule = [self ruleMatchingEvent:event roomState:roomState];
        if (rule)
        {
            // Make sure this is not a rule to prevent from generating a notification
            BOOL actionNotify = YES;
            if (1 == rule.actions.count)
            {
                MXPushRuleAction *action = rule.actions[0];
                if ([action.action isEqualToString:kMXPushRuleActionStringDontNotify])
                {
                    actionNotify = NO;
                }
            }

            if (actionNotify)
            {
                // All conditions have been satisfied, notify listeners
                [self notifyListeners:event roomState:roomState rule:rule];
            }
        }
    }
}

@end
