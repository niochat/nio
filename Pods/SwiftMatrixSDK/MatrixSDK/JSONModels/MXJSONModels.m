/*
 Copyright 2014 OpenMarket Ltd
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

#import "MXJSONModels.h"

#import "MXEvent.h"
#import "MXUser.h"
#import "MXTools.h"
#import "MXUsersDevicesMap.h"
#import "MXDeviceInfo.h"
#import "MXCrossSigningInfo_Private.h"
#import "MXKey.h"

@implementation MXPublicRoom

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXPublicRoom *publicRoom = [[MXPublicRoom alloc] init];
    if (publicRoom)
    {
        NSDictionary *sanitisedJSONDictionary = [MXJSONModel removeNullValuesInJSON:JSONDictionary];

        MXJSONModelSetString(publicRoom.roomId , sanitisedJSONDictionary[@"room_id"]);
        MXJSONModelSetString(publicRoom.name , sanitisedJSONDictionary[@"name"]);
        MXJSONModelSetArray(publicRoom.aliases , sanitisedJSONDictionary[@"aliases"]);
        MXJSONModelSetString(publicRoom.canonicalAlias , sanitisedJSONDictionary[@"canonical_alias"]);
        MXJSONModelSetString(publicRoom.topic , sanitisedJSONDictionary[@"topic"]);
        MXJSONModelSetInteger(publicRoom.numJoinedMembers, sanitisedJSONDictionary[@"num_joined_members"]);
        MXJSONModelSetBoolean(publicRoom.worldReadable, sanitisedJSONDictionary[@"world_readable"]);
        MXJSONModelSetBoolean(publicRoom.guestCanJoin, sanitisedJSONDictionary[@"guest_can_join"]);
        MXJSONModelSetString(publicRoom.avatarUrl , sanitisedJSONDictionary[@"avatar_url"]);
    }

    return publicRoom;
}

- (NSString *)displayname
{
    NSString *displayname = self.name;
    
    if (!displayname.length)
    {
        if (self.aliases && 0 < self.aliases.count)
        {
            // TODO(same as in webclient code): select the smarter alias from the array
            displayname = self.aliases[0];
        }
        else
        {
            NSLog(@"[MXPublicRoom] Warning: room id leak for %@", self.roomId);
            displayname = self.roomId;
        }
    }
    else if ([displayname hasPrefix:@"#"] == NO && self.aliases.count)
    {
        displayname = [NSString stringWithFormat:@"%@ (%@)", displayname, self.aliases[0]];
    }
    
    return displayname;
}
@end


@implementation MXPublicRoomsResponse

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXPublicRoomsResponse *publicRoomsResponse = [[MXPublicRoomsResponse alloc] init];
    if (publicRoomsResponse)
    {
        MXJSONModelSetMXJSONModelArray(publicRoomsResponse.chunk, MXPublicRoom, JSONDictionary[@"chunk"]);
        MXJSONModelSetString(publicRoomsResponse.nextBatch , JSONDictionary[@"next_batch"]);
        MXJSONModelSetUInteger(publicRoomsResponse.totalRoomCountEstimate , JSONDictionary[@"total_room_count_estimate"]);
    }

    return publicRoomsResponse;
}
@end


@implementation MXThirdPartyProtocolInstance

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXThirdPartyProtocolInstance *thirdpartyProtocolInstance = [[MXThirdPartyProtocolInstance alloc] init];
    if (thirdpartyProtocolInstance)
    {
        MXJSONModelSetString(thirdpartyProtocolInstance.networkId, JSONDictionary[@"network_id"]);
        MXJSONModelSetDictionary(thirdpartyProtocolInstance.fields, JSONDictionary[@"fields"]);
        MXJSONModelSetString(thirdpartyProtocolInstance.instanceId, JSONDictionary[@"instance_id"]);
        MXJSONModelSetString(thirdpartyProtocolInstance.desc, JSONDictionary[@"desc"]);
        MXJSONModelSetString(thirdpartyProtocolInstance.botUserId, JSONDictionary[@"bot_user_id"]);
        MXJSONModelSetString(thirdpartyProtocolInstance.icon, JSONDictionary[@"icon"]);
    }

    return thirdpartyProtocolInstance;
}

@end


@implementation MXThirdPartyProtocol

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXThirdPartyProtocol *thirdpartyProtocol = [[MXThirdPartyProtocol alloc] init];
    if (thirdpartyProtocol)
    {
        MXJSONModelSetArray(thirdpartyProtocol.userFields, JSONDictionary[@"user_fields"]);
        MXJSONModelSetArray(thirdpartyProtocol.locationFields, JSONDictionary[@"location_fields"]);
        MXJSONModelSetDictionary(thirdpartyProtocol.fieldTypes, JSONDictionary[@"field_types"]);
        MXJSONModelSetMXJSONModelArray(thirdpartyProtocol.instances, MXThirdPartyProtocolInstance, JSONDictionary[@"instances"])
    }

    return thirdpartyProtocol;
}

@end


@implementation MXThirdpartyProtocolsResponse

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXThirdpartyProtocolsResponse *thirdpartyProtocolsResponse = [[MXThirdpartyProtocolsResponse alloc] init];
    if (thirdpartyProtocolsResponse)
    {
        NSMutableDictionary *protocols = [NSMutableDictionary dictionary];
        for (NSString *protocolName in JSONDictionary)
        {
            MXJSONModelSetMXJSONModel(protocols[protocolName], MXThirdPartyProtocol, JSONDictionary[protocolName]);
        }

        thirdpartyProtocolsResponse.protocols = protocols;
    }

    return thirdpartyProtocolsResponse;
}

@end


NSString *const kMXLoginFlowTypePassword = @"m.login.password";
NSString *const kMXLoginFlowTypeRecaptcha = @"m.login.recaptcha";
NSString *const kMXLoginFlowTypeOAuth2 = @"m.login.oauth2";
NSString *const kMXLoginFlowTypeCAS = @"m.login.cas";
NSString *const kMXLoginFlowTypeSSO = @"m.login.sso";
NSString *const kMXLoginFlowTypeEmailIdentity = @"m.login.email.identity";
NSString *const kMXLoginFlowTypeToken = @"m.login.token";
NSString *const kMXLoginFlowTypeDummy = @"m.login.dummy";
NSString *const kMXLoginFlowTypeEmailCode = @"m.login.email.code";
NSString *const kMXLoginFlowTypeMSISDN = @"m.login.msisdn";
NSString *const kMXLoginFlowTypeTerms = @"m.login.terms";

NSString *const kMXLoginIdentifierTypeUser = @"m.id.user";
NSString *const kMXLoginIdentifierTypeThirdParty = @"m.id.thirdparty";
NSString *const kMXLoginIdentifierTypePhone = @"m.id.phone";

@implementation MXLoginFlow

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXLoginFlow *loginFlow = [[MXLoginFlow alloc] init];
    if (loginFlow)
    {
        MXJSONModelSetString(loginFlow.type, JSONDictionary[@"type"]);
        MXJSONModelSetArray(loginFlow.stages, JSONDictionary[@"stages"]);
    }
    
    return loginFlow;
}

@end

@implementation MXAuthenticationSession

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXAuthenticationSession *authSession = [[MXAuthenticationSession alloc] init];
    if (authSession)
    {
        MXJSONModelSetArray(authSession.completed, JSONDictionary[@"completed"]);
        MXJSONModelSetString(authSession.session, JSONDictionary[@"session"]);
        MXJSONModelSetDictionary(authSession.params, JSONDictionary[@"params"]);
        
        authSession.flows = [MXLoginFlow modelsFromJSON:JSONDictionary[@"flows"]];
    }
    
    return authSession;
}

@end

@implementation MXLoginResponse

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXLoginResponse *loginResponse = [[MXLoginResponse alloc] init];
    if (loginResponse)
    {
        MXJSONModelSetString(loginResponse.homeserver, JSONDictionary[@"home_server"]);
        MXJSONModelSetString(loginResponse.userId, JSONDictionary[@"user_id"]);
        MXJSONModelSetString(loginResponse.accessToken, JSONDictionary[@"access_token"]);
        MXJSONModelSetString(loginResponse.deviceId, JSONDictionary[@"device_id"]);
        MXJSONModelSetMXJSONModel(loginResponse.wellknown, MXWellKnown, JSONDictionary[@"well_known"]);
    }

    return loginResponse;
}

@end

@implementation MXThirdPartyIdentifier

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXThirdPartyIdentifier *thirdPartyIdentifier = [[MXThirdPartyIdentifier alloc] init];
    if (thirdPartyIdentifier)
    {
        MXJSONModelSetString(thirdPartyIdentifier.medium, JSONDictionary[@"medium"]);
        MXJSONModelSetString(thirdPartyIdentifier.address, JSONDictionary[@"address"]);
        MXJSONModelSetUInt64(thirdPartyIdentifier.validatedAt, JSONDictionary[@"validated_at"]);
        MXJSONModelSetUInt64(thirdPartyIdentifier.addedAt, JSONDictionary[@"added_at"]);
    }

    return thirdPartyIdentifier;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _medium = [aDecoder decodeObjectForKey:@"medium"];
        _address = [aDecoder decodeObjectForKey:@"address"];
        _validatedAt = [((NSNumber*)[aDecoder decodeObjectForKey:@"validatedAt"]) unsignedLongLongValue];
        _addedAt = [((NSNumber*)[aDecoder decodeObjectForKey:@"addedAt"]) unsignedLongLongValue];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_medium forKey:@"medium"];
    [aCoder encodeObject:_address forKey:@"address"];
    [aCoder encodeObject:@(_validatedAt) forKey:@"validatedAt"];
    [aCoder encodeObject:@(_addedAt) forKey:@"addedAt"];
}

@end

@implementation MXCreateRoomResponse

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXCreateRoomResponse *createRoomResponse = [[MXCreateRoomResponse alloc] init];
    if (createRoomResponse)
    {
        MXJSONModelSetString(createRoomResponse.roomId, JSONDictionary[@"room_id"]);
        MXJSONModelSetString(createRoomResponse.roomAlias, JSONDictionary[@"room_alias"]);
    }

    return createRoomResponse;
}

@end

@implementation MXPaginationResponse

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXPaginationResponse *paginationResponse = [[MXPaginationResponse alloc] init];
    if (paginationResponse)
    {
        MXJSONModelSetMXJSONModelArray(paginationResponse.chunk, MXEvent, JSONDictionary[@"chunk"]);
        MXJSONModelSetMXJSONModelArray(paginationResponse.state, MXEvent, JSONDictionary[@"state"]);
        MXJSONModelSetString(paginationResponse.start, JSONDictionary[@"start"]);
        MXJSONModelSetString(paginationResponse.end, JSONDictionary[@"end"]);

        // Have the same behavior as before when JSON was parsed by Mantle: return an empty chunk array
        // rather than nil
        if (!paginationResponse.chunk)
        {
            paginationResponse.chunk = [NSArray array];
        }
    }

    return paginationResponse;
}

@end

@implementation MXRoomMemberEventContent

// Decoding room member events is sensible when loading state events from cache as the SDK
// needs to decode plenty of them.
// A direct JSON decoding improves speed by 4x.
+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXRoomMemberEventContent *roomMemberEventContent = [[MXRoomMemberEventContent alloc] init];
    if (roomMemberEventContent)
    {
        JSONDictionary = [MXJSONModel removeNullValuesInJSON:JSONDictionary];
        MXJSONModelSetString(roomMemberEventContent.displayname, JSONDictionary[@"displayname"]);
        MXJSONModelSetString(roomMemberEventContent.avatarUrl, JSONDictionary[@"avatar_url"]);
        MXJSONModelSetString(roomMemberEventContent.membership, JSONDictionary[@"membership"]);

        if (JSONDictionary[@"third_party_invite"] && JSONDictionary[@"third_party_invite"][@"signed"])
        {
            MXJSONModelSetString(roomMemberEventContent.thirdPartyInviteToken, JSONDictionary[@"third_party_invite"][@"signed"][@"token"]);
        }
    }

    return roomMemberEventContent;
}

@end


NSString *const kMXRoomTagFavourite = @"m.favourite";
NSString *const kMXRoomTagLowPriority = @"m.lowpriority";
NSString *const kMXRoomTagServerNotice = @"m.server_notice";

@interface MXRoomTag()
{
    NSNumber* _parsedOrder;
}
@end

@implementation MXRoomTag

- (id)initWithName:(NSString *)name andOrder:(NSString *)order
{
    self = [super init];
    if (self)
    {
        _name = name;
        _order = order;
        _parsedOrder = nil;
    }
    return self;
}

+ (NSDictionary<NSString *,MXRoomTag *> *)roomTagsWithTagEvent:(MXEvent *)event
{
    NSMutableDictionary *tags = [NSMutableDictionary dictionary];

    NSDictionary *tagsContent;
    MXJSONModelSetDictionary(tagsContent, event.content[@"tags"]);

    for (NSString *tagName in tagsContent)
    {
        NSDictionary *tagDict;
        MXJSONModelSetDictionary(tagDict, tagsContent[tagName]);

        if (tagDict)
        {
            NSString *order = tagDict[@"order"];

            // Be robust if the server sends an integer tag order
            // Do some cleaning if the order is a number (and do nothing if the order is a string)
            if ([order isKindOfClass:NSNumber.class])
            {
                NSLog(@"[MXRoomTag] Warning: the room tag order is an number value not a string in this event: %@", event);

                NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
                [formatter setMaximumFractionDigits:16];
                [formatter setMinimumFractionDigits:0];
                [formatter setDecimalSeparator:@"."];
                [formatter setGroupingSeparator:@""];

                order = [formatter stringFromNumber:tagDict[@"order"]];

                if (order)
                {
                    NSNumber *value = [formatter numberFromString:order];
                    if (!value)
                    {
                        // Manage numbers with ',' decimal separator
                        [formatter setDecimalSeparator:@","];
                        value = [formatter numberFromString:order];
                        [formatter setDecimalSeparator:@"."];
                    }

                    if (value)
                    {
                        // remove trailing 0
                        // in some cases, the order is 0.00000 ("%f" formatter");
                        // with this method, it becomes "0".
                        order = [formatter stringFromNumber:value];
                    }
                }
            }
            
            tags[tagName] = [[MXRoomTag alloc] initWithName:tagName andOrder:order];
        }
    }
    return tags;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _name = [aDecoder decodeObjectForKey:@"name"];
        _order = [aDecoder decodeObjectForKey:@"order"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_name forKey:@"name"];
    [aCoder encodeObject:_order forKey:@"order"];
}

- (NSNumber*)parsedOrder
{
    if (!_parsedOrder && _order)
    {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        [formatter setMaximumFractionDigits:16];
        [formatter setMinimumFractionDigits:0];
        [formatter setDecimalSeparator:@","];
        [formatter setGroupingSeparator:@""];
        
        // assume that the default separator is the '.'.
        [formatter setDecimalSeparator:@"."];
        
        _parsedOrder = [formatter numberFromString:_order];
        
        if (!_parsedOrder)
        {
            // check again with ',' as decimal separator.
            [formatter setDecimalSeparator:@","];
            _parsedOrder = [formatter numberFromString:_order];
        }
    }
    
    return _parsedOrder;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MXRoomTag: %p> %@: %@", self, _name, _order];
}

@end

NSString *const kMXPresenceOnline = @"online";
NSString *const kMXPresenceUnavailable = @"unavailable";
NSString *const kMXPresenceOffline = @"offline";

@implementation MXPresenceEventContent

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXPresenceEventContent *presenceEventContent = [[MXPresenceEventContent alloc] init];
    if (presenceEventContent)
    {
        MXJSONModelSetString(presenceEventContent.userId, JSONDictionary[@"user_id"]);
        MXJSONModelSetString(presenceEventContent.displayname, JSONDictionary[@"displayname"]);
        MXJSONModelSetString(presenceEventContent.avatarUrl, JSONDictionary[@"avatar_url"]);
        MXJSONModelSetUInteger(presenceEventContent.lastActiveAgo, JSONDictionary[@"last_active_ago"]);
        MXJSONModelSetString(presenceEventContent.presence, JSONDictionary[@"presence"]);
        MXJSONModelSetString(presenceEventContent.statusMsg, JSONDictionary[@"status_msg"]);
        if (JSONDictionary[@"currently_active"])
        {
            MXJSONModelSetBoolean(presenceEventContent.currentlyActive, JSONDictionary[@"currently_active"]);
        }

        presenceEventContent.presenceStatus = [MXTools presence:presenceEventContent.presence];
    }
    return presenceEventContent;
}

@end


@implementation MXPresenceResponse

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXPresenceResponse *presenceResponse = [[MXPresenceResponse alloc] init];
    if (presenceResponse)
    {
        MXJSONModelSetUInteger(presenceResponse.lastActiveAgo, JSONDictionary[@"last_active_ago"]);
        MXJSONModelSetString(presenceResponse.presence, JSONDictionary[@"presence"]);
        MXJSONModelSetString(presenceResponse.statusMsg, JSONDictionary[@"status_msg"]);

        presenceResponse.presenceStatus = [MXTools presence:presenceResponse.presence];
    }
    return presenceResponse;
}

@end


@interface MXOpenIdToken ()

// Shorcut to retrieve the original JSON as `MXOpenIdToken` data is often directly injected in
// another request
@property (nonatomic) NSDictionary *json;

@end

@implementation MXOpenIdToken

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXOpenIdToken *openIdToken = [[MXOpenIdToken alloc] init];
    if (openIdToken)
    {
        MXJSONModelSetString(openIdToken.tokenType, JSONDictionary[@"token_type"]);
        MXJSONModelSetString(openIdToken.matrixServerName, JSONDictionary[@"matrix_server_name"]);
        MXJSONModelSetString(openIdToken.accessToken, JSONDictionary[@"access_token"]);
        MXJSONModelSetUInt64(openIdToken.expiresIn, JSONDictionary[@"expires_in"]);

        MXJSONModelSetDictionary(openIdToken.json, JSONDictionary);
    }
    return openIdToken;
}

- (NSDictionary *)JSONDictionary
{
    return _json;
}

@end


NSString *const kMXPushRuleActionStringNotify       = @"notify";
NSString *const kMXPushRuleActionStringDontNotify   = @"dont_notify";
NSString *const kMXPushRuleActionStringCoalesce     = @"coalesce";
NSString *const kMXPushRuleActionStringSetTweak     = @"set_tweak";

NSString *const kMXPushRuleConditionStringEventMatch                    = @"event_match";
NSString *const kMXPushRuleConditionStringProfileTag                    = @"profile_tag";
NSString *const kMXPushRuleConditionStringContainsDisplayName           = @"contains_display_name";
NSString *const kMXPushRuleConditionStringRoomMemberCount               = @"room_member_count";
NSString *const kMXPushRuleConditionStringSenderNotificationPermission  = @"sender_notification_permission";


@implementation MXPushRule

+ (NSArray *)modelsFromJSON:(NSArray *)JSONDictionaries withScope:(NSString *)scope andKind:(MXPushRuleKind)kind
{
    NSArray <MXPushRule*> *pushRules;
    MXJSONModelSetMXJSONModelArray(pushRules, self.class, JSONDictionaries);

    for (MXPushRule *pushRule in pushRules)
    {
        pushRule.scope = scope;
        pushRule.kind = kind;
    }

    return pushRules;
}

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXPushRule *pushRule = [[MXPushRule alloc] init];
    if (pushRule)
    {
        MXJSONModelSetString(pushRule.ruleId, JSONDictionary[@"rule_id"]);
        MXJSONModelSetBoolean(pushRule.isDefault, JSONDictionary[@"default"]);
        MXJSONModelSetBoolean(pushRule.enabled, JSONDictionary[@"enabled"]);
        MXJSONModelSetString(pushRule.pattern, JSONDictionary[@"pattern"]);
        MXJSONModelSetMXJSONModelArray(pushRule.conditions, MXPushRuleCondition, JSONDictionary[@"conditions"]);

        // Decode actions
        NSMutableArray *actions = [NSMutableArray array];
        for (NSObject *rawAction in JSONDictionary[@"actions"])
        {
            // According to the push rules specification
            // The action field can a string or dictionary, translate both into
            // a MXPushRuleAction object
            MXPushRuleAction *action = [[MXPushRuleAction alloc] init];

            if ([rawAction isKindOfClass:[NSString class]])
            {
                action.action = [rawAction copy];

                // If possible, map it to an action type
                if ([action.action isEqualToString:kMXPushRuleActionStringNotify])
                {
                    action.actionType = MXPushRuleActionTypeNotify;
                }
                else if ([action.action isEqualToString:kMXPushRuleActionStringDontNotify])
                {
                    action.actionType = MXPushRuleActionTypeDontNotify;
                }
                else if ([action.action isEqualToString:kMXPushRuleActionStringCoalesce])
                {
                    action.actionType = MXPushRuleActionTypeCoalesce;
                }
            }
            else if ([rawAction isKindOfClass:[NSDictionary class]])
            {
                action.parameters = (NSDictionary*)rawAction;

                // The
                if (NSNotFound != [action.parameters.allKeys indexOfObject:kMXPushRuleActionStringSetTweak])
                {
                    action.action = kMXPushRuleActionStringSetTweak;
                    action.actionType = MXPushRuleActionTypeSetTweak;
                }
            }

            [actions addObject:action];
        }

        pushRule.actions = actions;
    }

    return pushRule;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MXPushRule: %p> ruleId: %@ - isDefault: %@ - enabled: %@ - actions: %@", self, _ruleId, @(_isDefault), @(_enabled), _actions];
}

@end

@implementation MXPushRuleAction

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _actionType = MXPushRuleActionTypeCustom;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MXPushRuleAction: %p> action: %@ - parameters: %@", self, _action, _parameters];
}

@end

@implementation MXPushRuleCondition

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXPushRuleCondition *condition = [[MXPushRuleCondition alloc] init];
    if (condition)
    {
        MXJSONModelSetString(condition.kind, JSONDictionary[@"kind"]);

        // MXPushRuleCondition.parameters are all other JSON objects which keys is not `kind`
        NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithDictionary:JSONDictionary];
        [parameters removeObjectForKey:@"kind"];
        condition.parameters = parameters;
    }
    return condition;
}

- (void)setKind:(MXPushRuleConditionString)kind
{
    _kind = kind;

    if ([_kind isEqualToString:kMXPushRuleConditionStringEventMatch])
    {
        _kindType = MXPushRuleConditionTypeEventMatch;
    }
    else if ([_kind isEqualToString:kMXPushRuleConditionStringProfileTag])
    {
        _kindType = MXPushRuleConditionTypeProfileTag;
    }
    else if ([_kind isEqualToString:kMXPushRuleConditionStringContainsDisplayName])
    {
        _kindType = MXPushRuleConditionTypeContainsDisplayName;
    }
    else if ([_kind isEqualToString:kMXPushRuleConditionStringRoomMemberCount])
    {
        _kindType = MXPushRuleConditionTypeRoomMemberCount;
    }
    else if ([_kind isEqualToString:kMXPushRuleConditionStringSenderNotificationPermission])
    {
        _kindType = MXPushRuleConditionTypeSenderNotificationPermission;
    }
    else
    {
        _kindType = MXPushRuleConditionTypeCustom;
    }
}

- (void)setKindType:(MXPushRuleConditionType)kindType
{
    _kindType = kindType;

    switch (_kindType)
    {
        case MXPushRuleConditionTypeEventMatch:
            _kind = kMXPushRuleConditionStringEventMatch;
            break;

        case MXPushRuleConditionTypeProfileTag:
            _kind = kMXPushRuleConditionStringProfileTag;
            break;

        case MXPushRuleConditionTypeContainsDisplayName:
            _kind = kMXPushRuleConditionStringContainsDisplayName;
            break;

        case MXPushRuleConditionTypeRoomMemberCount:
            _kind = kMXPushRuleConditionStringRoomMemberCount;
            break;

        case MXPushRuleConditionTypeSenderNotificationPermission:
            _kind = kMXPushRuleConditionStringSenderNotificationPermission;
            break;

        default:
            break;
    }
}

@end

@implementation MXPushRulesSet

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary withScope:(NSString*)scope
{
    MXPushRulesSet *pushRulesSet = [[MXPushRulesSet alloc] init];
    if (pushRulesSet)
    {
        pushRulesSet.override = [MXPushRule modelsFromJSON:JSONDictionary[@"override"] withScope:scope andKind:MXPushRuleKindOverride];
        pushRulesSet.content = [MXPushRule modelsFromJSON:JSONDictionary[@"content"] withScope:scope andKind:MXPushRuleKindContent];
        pushRulesSet.room = [MXPushRule modelsFromJSON:JSONDictionary[@"room"] withScope:scope andKind:MXPushRuleKindRoom];
        pushRulesSet.sender = [MXPushRule modelsFromJSON:JSONDictionary[@"sender"] withScope:scope andKind:MXPushRuleKindSender];
        pushRulesSet.underride = [MXPushRule modelsFromJSON:JSONDictionary[@"underride"] withScope:scope andKind:MXPushRuleKindUnderride];
    }

    return pushRulesSet;
}

@end

@interface MXPushRulesResponse ()
{
    // The dictionary sent by the homeserver.
    NSDictionary *JSONDictionary;
}
@end
@implementation MXPushRulesResponse

NSString *const kMXPushRuleScopeStringGlobal = @"global";
NSString *const kMXPushRuleScopeStringDevice = @"device";

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXPushRulesResponse *pushRulesResponse = [[MXPushRulesResponse alloc] init];
    if (pushRulesResponse)
    {
        if ([JSONDictionary[kMXPushRuleScopeStringGlobal] isKindOfClass:NSDictionary.class])
        {
            pushRulesResponse.global = [MXPushRulesSet modelFromJSON:JSONDictionary[kMXPushRuleScopeStringGlobal] withScope:kMXPushRuleScopeStringGlobal];
        }

        // TODO support device rules

        pushRulesResponse->JSONDictionary = JSONDictionary;
    }

    return pushRulesResponse;
}

- (NSDictionary *)JSONDictionary
{
    return JSONDictionary;
}

@end


#pragma mark - Context
#pragma mark -
/**
 `MXEventContext` represents to the response to the /context request.
 */
@implementation MXEventContext

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXEventContext *eventContext = [[MXEventContext alloc] init];
    if (eventContext)
    {
        MXJSONModelSetMXJSONModel(eventContext.event, MXEvent, JSONDictionary[@"event"]);
        MXJSONModelSetString(eventContext.start, JSONDictionary[@"start"]);
        MXJSONModelSetMXJSONModelArray(eventContext.eventsBefore, MXEvent, JSONDictionary[@"events_before"]);
        MXJSONModelSetMXJSONModelArray(eventContext.eventsAfter, MXEvent, JSONDictionary[@"events_after"]);
        MXJSONModelSetString(eventContext.end, JSONDictionary[@"end"]);
        MXJSONModelSetMXJSONModelArray(eventContext.state, MXEvent, JSONDictionary[@"state"]);
    }

    return eventContext;
}
@end


#pragma mark - Search
#pragma mark -

@implementation MXSearchUserProfile

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXSearchUserProfile *searchUserProfile = [[MXSearchUserProfile alloc] init];
    if (searchUserProfile)
    {
        MXJSONModelSetString(searchUserProfile.avatarUrl, JSONDictionary[@"avatar_url"]);
        MXJSONModelSetString(searchUserProfile.displayName, JSONDictionary[@"displayname"]);
    }

    return searchUserProfile;
}

@end

@implementation MXSearchEventContext

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXSearchEventContext *searchEventContext = [[MXSearchEventContext alloc] init];
    if (searchEventContext)
    {
        MXJSONModelSetString(searchEventContext.start, JSONDictionary[@"start"]);
        MXJSONModelSetString(searchEventContext.end, JSONDictionary[@"end"]);

        MXJSONModelSetMXJSONModelArray(searchEventContext.eventsBefore, MXEvent, JSONDictionary[@"events_before"]);
        MXJSONModelSetMXJSONModelArray(searchEventContext.eventsAfter, MXEvent, JSONDictionary[@"events_after"]);

        NSMutableDictionary<NSString*, MXSearchUserProfile*> *profileInfo = [NSMutableDictionary dictionary];
        for (NSString *userId in JSONDictionary[@"profile_info"])
        {
            MXJSONModelSetMXJSONModel(profileInfo[userId], MXSearchUserProfile, JSONDictionary[@"profile_info"][userId]);
        }
        searchEventContext.profileInfo = profileInfo;
    }

    return searchEventContext;
}

@end

@implementation MXSearchResult

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXSearchResult *searchResult = [[MXSearchResult alloc] init];
    if (searchResult)
    {
        MXJSONModelSetMXJSONModel(searchResult.result, MXEvent, JSONDictionary[@"result"]);
        MXJSONModelSetInteger(searchResult.rank, JSONDictionary[@"rank"]);
        MXJSONModelSetMXJSONModel(searchResult.context, MXSearchEventContext, JSONDictionary[@"context"]);
    }

    return searchResult;
}

@end

@implementation MXSearchGroupContent

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXSearchGroupContent *searchGroupContent = [[MXSearchGroupContent alloc] init];
    if (searchGroupContent)
    {
        MXJSONModelSetInteger(searchGroupContent.order, JSONDictionary[@"order"]);
        NSAssert(NO, @"What is results?");
        searchGroupContent.results = nil;   // TODO_SEARCH
        MXJSONModelSetString(searchGroupContent.nextBatch, JSONDictionary[@"next_batch"]);
    }

    return searchGroupContent;
}

@end

@implementation MXSearchGroup

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXSearchGroup *searchGroup = [[MXSearchGroup alloc] init];
    if (searchGroup)
    {
        NSMutableDictionary<NSString*, MXSearchGroupContent*> *group = [NSMutableDictionary dictionary];
        for (NSString *key in JSONDictionary[@"state"])
        {
            MXJSONModelSetMXJSONModel(group[key], MXSearchGroupContent, JSONDictionary[@"key"][key]);
        }
        searchGroup.group = group;
    }

    return searchGroup;
}

@end

@implementation MXSearchRoomEventResults

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXSearchRoomEventResults *searchRoomEventResults = [[MXSearchRoomEventResults alloc] init];
    if (searchRoomEventResults)
    {
        MXJSONModelSetUInteger(searchRoomEventResults.count, JSONDictionary[@"count"]);
        MXJSONModelSetMXJSONModelArray(searchRoomEventResults.results, MXSearchResult, JSONDictionary[@"results"]);
        MXJSONModelSetString(searchRoomEventResults.nextBatch, JSONDictionary[@"next_batch"]);

        NSMutableDictionary<NSString*, MXSearchGroup*> *groups = [NSMutableDictionary dictionary];
        for (NSString *groupId in JSONDictionary[@"groups"])
        {
            MXJSONModelSetMXJSONModel(groups[groupId], MXSearchGroup, JSONDictionary[@"groups"][groupId]);
        }
        searchRoomEventResults.groups = groups;

        NSMutableDictionary<NSString*, NSArray<MXEvent*> *> *state = [NSMutableDictionary dictionary];
        for (NSString *roomId in JSONDictionary[@"state"])
        {
            MXJSONModelSetMXJSONModelArray(state[roomId], MXEvent, JSONDictionary[@"state"][roomId]);
        }
        searchRoomEventResults.state = state;
    }

    return searchRoomEventResults;
}

@end

@implementation MXSearchCategories

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXSearchCategories *searchCategories = [[MXSearchCategories alloc] init];
    if (searchCategories)
    {
        MXJSONModelSetMXJSONModel(searchCategories.roomEvents, MXSearchRoomEventResults, JSONDictionary[@"room_events"]);
    }

    return searchCategories;
}

@end

@implementation MXSearchResponse

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXSearchResponse *searchResponse = [[MXSearchResponse alloc] init];
    if (searchResponse)
    {
        NSDictionary *sanitisedJSONDictionary = [MXJSONModel removeNullValuesInJSON:JSONDictionary];
        MXJSONModelSetMXJSONModel(searchResponse.searchCategories, MXSearchCategories, sanitisedJSONDictionary[@"search_categories"]);
    }

    return searchResponse;
}

@end

@implementation MXUserSearchResponse

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXUserSearchResponse *userSearchResponse = [[MXUserSearchResponse alloc] init];
    if (userSearchResponse)
    {
        MXJSONModelSetBoolean(userSearchResponse.limited, JSONDictionary[@"limited"]);
        MXJSONModelSetMXJSONModelArray(userSearchResponse.results, MXUser, JSONDictionary[@"results"]);
    }

    return userSearchResponse;
}

@end


#pragma mark - Server sync
#pragma mark -

@implementation MXRoomInitialSync

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXRoomInitialSync *initialSync = [[MXRoomInitialSync alloc] init];
    if (initialSync)
    {
        MXJSONModelSetString(initialSync.roomId, JSONDictionary[@"room_id"]);
        MXJSONModelSetMXJSONModel(initialSync.messages, MXPaginationResponse, JSONDictionary[@"messages"]);
        MXJSONModelSetMXJSONModelArray(initialSync.state, MXEvent, JSONDictionary[@"state"]);
        MXJSONModelSetMXJSONModelArray(initialSync.accountData, MXEvent, JSONDictionary[@"account_data"]);
        MXJSONModelSetString(initialSync.membership, JSONDictionary[@"membership"]);
        MXJSONModelSetString(initialSync.visibility, JSONDictionary[@"visibility"]);
        MXJSONModelSetString(initialSync.inviter, JSONDictionary[@"inviter"]);
        MXJSONModelSetMXJSONModel(initialSync.invite, MXEvent, JSONDictionary[@"invite"]);
        MXJSONModelSetMXJSONModelArray(initialSync.presence, MXEvent, JSONDictionary[@"presence"]);
        MXJSONModelSetMXJSONModelArray(initialSync.receipts, MXEvent, JSONDictionary[@"receipts"]);
    }

    return initialSync;
}

@end

@implementation MXRoomSyncState

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXRoomSyncState *roomSyncState = [[MXRoomSyncState alloc] init];
    if (roomSyncState)
    {
        MXJSONModelSetMXJSONModelArray(roomSyncState.events, MXEvent, JSONDictionary[@"events"]);
    }
    return roomSyncState;
}

@end

@implementation MXRoomSyncTimeline

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXRoomSyncTimeline *roomSyncTimeline = [[MXRoomSyncTimeline alloc] init];
    if (roomSyncTimeline)
    {
        MXJSONModelSetMXJSONModelArray(roomSyncTimeline.events, MXEvent, JSONDictionary[@"events"]);
        MXJSONModelSetBoolean(roomSyncTimeline.limited , JSONDictionary[@"limited"]);
        MXJSONModelSetString(roomSyncTimeline.prevBatch, JSONDictionary[@"prev_batch"]);
    }
    return roomSyncTimeline;
}

@end

@implementation MXRoomSyncEphemeral

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXRoomSyncEphemeral *roomSyncEphemeral = [[MXRoomSyncEphemeral alloc] init];
    if (roomSyncEphemeral)
    {
        MXJSONModelSetMXJSONModelArray(roomSyncEphemeral.events, MXEvent, JSONDictionary[@"events"]);
    }
    return roomSyncEphemeral;
}

@end

@implementation MXRoomSyncAccountData

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXRoomSyncAccountData *roomSyncAccountData = [[MXRoomSyncAccountData alloc] init];
    if (roomSyncAccountData)
    {
        MXJSONModelSetMXJSONModelArray(roomSyncAccountData.events, MXEvent, JSONDictionary[@"events"]);
    }
    return roomSyncAccountData;
}

@end

@implementation MXRoomInviteState

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXRoomInviteState *roomInviteState = [[MXRoomInviteState alloc] init];
    if (roomInviteState)
    {
        MXJSONModelSetMXJSONModelArray(roomInviteState.events, MXEvent, JSONDictionary[@"events"]);
    }
    return roomInviteState;
}

@end

@implementation MXRoomSyncUnreadNotifications

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXRoomSyncUnreadNotifications *roomSyncUnreadNotifications = [[MXRoomSyncUnreadNotifications alloc] init];
    if (roomSyncUnreadNotifications)
    {
        MXJSONModelSetUInteger(roomSyncUnreadNotifications.notificationCount, JSONDictionary[@"notification_count"]);
        MXJSONModelSetUInteger(roomSyncUnreadNotifications.highlightCount, JSONDictionary[@"highlight_count"]);
    }
    return roomSyncUnreadNotifications;
}

@end

@implementation MXRoomSyncSummary

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _joinedMemberCount = -1;
        _invitedMemberCount = -1;
    }
    return self;
}

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXRoomSyncSummary *roomSyncSummary;

    if (JSONDictionary.count)
    {
        roomSyncSummary = [MXRoomSyncSummary new];
        if (roomSyncSummary)
        {
            MXJSONModelSetArray(roomSyncSummary.heroes, JSONDictionary[@"m.heroes"]);
            MXJSONModelSetUInteger(roomSyncSummary.joinedMemberCount, JSONDictionary[@"m.joined_member_count"]);
            MXJSONModelSetUInteger(roomSyncSummary.invitedMemberCount, JSONDictionary[@"m.invited_member_count"]);
        }
    }
    return roomSyncSummary;
}

@end


@implementation MXRoomSync

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXRoomSync *roomSync = [[MXRoomSync alloc] init];
    if (roomSync)
    {
        MXJSONModelSetMXJSONModel(roomSync.state, MXRoomSyncState, JSONDictionary[@"state"]);
        MXJSONModelSetMXJSONModel(roomSync.timeline, MXRoomSyncTimeline, JSONDictionary[@"timeline"]);
        MXJSONModelSetMXJSONModel(roomSync.ephemeral, MXRoomSyncEphemeral, JSONDictionary[@"ephemeral"]);
        MXJSONModelSetMXJSONModel(roomSync.accountData, MXRoomSyncAccountData, JSONDictionary[@"account_data"]);
        MXJSONModelSetMXJSONModel(roomSync.unreadNotifications, MXRoomSyncUnreadNotifications, JSONDictionary[@"unread_notifications"]);
        MXJSONModelSetMXJSONModel(roomSync.summary, MXRoomSyncSummary, JSONDictionary[@"summary"]);
    }
    return roomSync;
}

@end

@implementation MXInvitedRoomSync

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXInvitedRoomSync *invitedRoomSync = [[MXInvitedRoomSync alloc] init];
    if (invitedRoomSync)
    {
        MXJSONModelSetMXJSONModel(invitedRoomSync.inviteState, MXRoomInviteState, JSONDictionary[@"invite_state"]);
    }
    return invitedRoomSync;
}

@end

#pragma mark - Group
#pragma mark -

@implementation MXGroupSyncProfile

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXGroupSyncProfile *groupProfile = [[MXGroupSyncProfile alloc] init];
    if (groupProfile)
    {
        MXJSONModelSetString(groupProfile.name, JSONDictionary[@"name"]);
        MXJSONModelSetString(groupProfile.avatarUrl, JSONDictionary[@"avatar_url"]);
    }
    
    return groupProfile;
}

@end

@implementation MXInvitedGroupSync

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXInvitedGroupSync *invitedGroupSync = [[MXInvitedGroupSync alloc] init];
    if (invitedGroupSync)
    {
        MXJSONModelSetString(invitedGroupSync.inviter, JSONDictionary[@"inviter"]);
        MXJSONModelSetMXJSONModel(invitedGroupSync.profile, MXGroupSyncProfile, JSONDictionary[@"profile"]);
    }
    return invitedGroupSync;
}

@end

@implementation MXPresenceSyncResponse

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXPresenceSyncResponse *presenceSyncResponse = [[MXPresenceSyncResponse alloc] init];
    if (presenceSyncResponse)
    {
        MXJSONModelSetMXJSONModelArray(presenceSyncResponse.events, MXEvent, JSONDictionary[@"events"]);
    }
    return presenceSyncResponse;
}

@end

@implementation MXToDeviceSyncResponse

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXToDeviceSyncResponse *toDeviceSyncResponse = [[MXToDeviceSyncResponse alloc] init];
    if (toDeviceSyncResponse)
    {
        MXJSONModelSetMXJSONModelArray(toDeviceSyncResponse.events, MXEvent, JSONDictionary[@"events"]);
    }
    return toDeviceSyncResponse;
}

@end

@implementation MXDeviceListResponse

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXDeviceListResponse *deviceListResponse = [[MXDeviceListResponse alloc] init];
    if (deviceListResponse)
    {
        MXJSONModelSetArray(deviceListResponse.changed, JSONDictionary[@"changed"]);
        MXJSONModelSetArray(deviceListResponse.left, JSONDictionary[@"left"]);
    }
    return deviceListResponse;
}

@end

@implementation MXRoomsSyncResponse

// Indeed the values in received dictionaries are JSON dictionaries. We convert them in
// MXRoomSync or MXInvitedRoomSync objects.
+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXRoomsSyncResponse *roomsSync = [[MXRoomsSyncResponse alloc] init];
    if (roomsSync)
    {
        NSMutableDictionary *mxJoin = [NSMutableDictionary dictionary];
        for (NSString *roomId in JSONDictionary[@"join"])
        {
            MXJSONModelSetMXJSONModel(mxJoin[roomId], MXRoomSync, JSONDictionary[@"join"][roomId]);
        }
        roomsSync.join = mxJoin;
        
        NSMutableDictionary *mxInvite = [NSMutableDictionary dictionary];
        for (NSString *roomId in JSONDictionary[@"invite"])
        {
            MXJSONModelSetMXJSONModel(mxInvite[roomId], MXInvitedRoomSync, JSONDictionary[@"invite"][roomId]);
        }
        roomsSync.invite = mxInvite;
        
        NSMutableDictionary *mxLeave = [NSMutableDictionary dictionary];
        for (NSString *roomId in JSONDictionary[@"leave"])
        {
            MXJSONModelSetMXJSONModel(mxLeave[roomId], MXRoomSync, JSONDictionary[@"leave"][roomId]);
        }
        roomsSync.leave = mxLeave;
    }
    
    return roomsSync;
}

@end

@implementation MXGroupsSyncResponse

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXGroupsSyncResponse *groupsSync = [[MXGroupsSyncResponse alloc] init];
    if (groupsSync)
    {
        NSObject *joinedGroups = JSONDictionary[@"join"];
        if ([joinedGroups isKindOfClass:[NSDictionary class]])
        {
            groupsSync.join = [NSArray arrayWithArray:((NSDictionary*)joinedGroups).allKeys];
        }
        
        NSMutableDictionary *mxInvite = [NSMutableDictionary dictionary];
        for (NSString *groupId in JSONDictionary[@"invite"])
        {
            MXJSONModelSetMXJSONModel(mxInvite[groupId], MXInvitedGroupSync, JSONDictionary[@"invite"][groupId]);
        }
        groupsSync.invite = mxInvite;
        
        NSObject *leftGroups = JSONDictionary[@"leave"];
        if ([leftGroups isKindOfClass:[NSDictionary class]])
        {
            groupsSync.leave = [NSArray arrayWithArray:((NSDictionary*)leftGroups).allKeys];
        }
    }
    
    return groupsSync;
}

@end

@implementation MXSyncResponse

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXSyncResponse *syncResponse = [[MXSyncResponse alloc] init];
    if (syncResponse)
    {
        MXJSONModelSetDictionary(syncResponse.accountData, JSONDictionary[@"account_data"])
        MXJSONModelSetString(syncResponse.nextBatch, JSONDictionary[@"next_batch"]);
        MXJSONModelSetMXJSONModel(syncResponse.presence, MXPresenceSyncResponse, JSONDictionary[@"presence"]);
        MXJSONModelSetMXJSONModel(syncResponse.toDevice, MXToDeviceSyncResponse, JSONDictionary[@"to_device"]);
        MXJSONModelSetMXJSONModel(syncResponse.deviceLists, MXDeviceListResponse, JSONDictionary[@"device_lists"]);
        MXJSONModelSetDictionary(syncResponse.deviceOneTimeKeysCount, JSONDictionary[@"device_one_time_keys_count"])
        MXJSONModelSetMXJSONModel(syncResponse.rooms, MXRoomsSyncResponse, JSONDictionary[@"rooms"]);
        MXJSONModelSetMXJSONModel(syncResponse.groups, MXGroupsSyncResponse, JSONDictionary[@"groups"]);
    }

    return syncResponse;
}

@end

#pragma mark - Voice over IP
#pragma mark -

@implementation MXCallSessionDescription

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXCallSessionDescription *callSessionDescription = [[MXCallSessionDescription alloc] init];
    if (callSessionDescription)
    {
        MXJSONModelSetString(callSessionDescription.type, JSONDictionary[@"type"]);
        MXJSONModelSetString(callSessionDescription.sdp, JSONDictionary[@"sdp"]);
    }

    return callSessionDescription;
}

@end

@implementation MXCallInviteEventContent

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXCallInviteEventContent *callInviteEventContent = [[MXCallInviteEventContent alloc] init];
    if (callInviteEventContent)
    {
        MXJSONModelSetString(callInviteEventContent.callId, JSONDictionary[@"call_id"]);
        MXJSONModelSetMXJSONModel(callInviteEventContent.offer, MXCallSessionDescription, JSONDictionary[@"offer"]);
        MXJSONModelSetUInteger(callInviteEventContent.version, JSONDictionary[@"version"]);
        MXJSONModelSetUInteger(callInviteEventContent.lifetime, JSONDictionary[@"lifetime"]);
    }

    return callInviteEventContent;
}

- (BOOL)isVideoCall
{
    return (NSNotFound != [self.offer.sdp rangeOfString:@"m=video"].location);
}

@end

@implementation MXCallCandidate

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXCallCandidate *callCandidate = [[MXCallCandidate alloc] init];
    if (callCandidate)
    {
        MXJSONModelSetString(callCandidate.sdpMid, JSONDictionary[@"sdpMid"]);
        MXJSONModelSetUInteger(callCandidate.sdpMLineIndex, JSONDictionary[@"sdpMLineIndex"]);
        MXJSONModelSetString(callCandidate.candidate, JSONDictionary[@"candidate"]);
    }

    return callCandidate;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];
    
    JSONDictionary[@"sdpMid"] = _sdpMid;
    JSONDictionary[@"sdpMLineIndex"] = @(_sdpMLineIndex);
    JSONDictionary[@"candidate"] = _candidate;
    
    return JSONDictionary;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MXCallCandidate: %p> %@ - %tu - %@", self, _sdpMid, _sdpMLineIndex, _candidate];
}

@end

@implementation MXCallCandidatesEventContent

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXCallCandidatesEventContent *callCandidatesEventContent = [[MXCallCandidatesEventContent alloc] init];
    if (callCandidatesEventContent)
    {
        MXJSONModelSetString(callCandidatesEventContent.callId, JSONDictionary[@"call_id"]);
        MXJSONModelSetUInteger(callCandidatesEventContent.version, JSONDictionary[@"version"]);
        MXJSONModelSetMXJSONModelArray(callCandidatesEventContent.candidates, MXCallCandidate, JSONDictionary[@"candidates"]);
    }

    return callCandidatesEventContent;
}

@end

@implementation MXCallAnswerEventContent

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXCallAnswerEventContent *callAnswerEventContent = [[MXCallAnswerEventContent alloc] init];
    if (callAnswerEventContent)
    {
        MXJSONModelSetString(callAnswerEventContent.callId, JSONDictionary[@"call_id"]);
        MXJSONModelSetUInteger(callAnswerEventContent.version, JSONDictionary[@"version"]);
        MXJSONModelSetMXJSONModel(callAnswerEventContent.answer, MXCallSessionDescription, JSONDictionary[@"answer"]);
    }

    return callAnswerEventContent;
}

@end

@implementation MXCallHangupEventContent

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXCallHangupEventContent *callHangupEventContent = [[MXCallHangupEventContent alloc] init];
    if (callHangupEventContent)
    {
        MXJSONModelSetString(callHangupEventContent.callId, JSONDictionary[@"call_id"]);
        MXJSONModelSetUInteger(callHangupEventContent.version, JSONDictionary[@"version"]);
    }

    return callHangupEventContent;
}

@end

@implementation MXTurnServerResponse

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXTurnServerResponse *turnServerResponse = [[MXTurnServerResponse alloc] init];
    if (turnServerResponse)
    {
        MXJSONModelSetString(turnServerResponse.username, JSONDictionary[@"username"]);
        MXJSONModelSetString(turnServerResponse.password, JSONDictionary[@"password"]);
        MXJSONModelSetArray(turnServerResponse.uris, JSONDictionary[@"uris"]);
        MXJSONModelSetUInteger(turnServerResponse.ttl, JSONDictionary[@"ttl"]);
    }

    return turnServerResponse;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _ttlExpirationLocalTs = -1;
    }
    return self;
}

- (void)setTtl:(NSUInteger)ttl
{
    if (-1 == _ttlExpirationLocalTs)
    {
        NSTimeInterval d = [[NSDate date] timeIntervalSince1970];
        _ttlExpirationLocalTs = (d + ttl) * 1000 ;
    }
}

- (NSUInteger)ttl
{
    NSUInteger ttl = 0;
    if (-1 != _ttlExpirationLocalTs)
    {
        ttl = (NSUInteger)(_ttlExpirationLocalTs / 1000 - (uint64_t)[[NSDate date] timeIntervalSince1970]);
    }
    return ttl;
}

@end


#pragma mark - Crypto

@implementation MXKeysUploadResponse

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXKeysUploadResponse *keysUploadResponse = [[MXKeysUploadResponse alloc] init];
    if (keysUploadResponse)
    {
        MXJSONModelSetDictionary(keysUploadResponse.oneTimeKeyCounts, JSONDictionary[@"one_time_key_counts"]);
    }
    return keysUploadResponse;
}

- (NSUInteger)oneTimeKeyCountsForAlgorithm:(NSString *)algorithm
{
    return [((NSNumber*)_oneTimeKeyCounts[algorithm]) unsignedIntegerValue];
}

@end

@implementation MXKeysQueryResponse

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXKeysQueryResponse *keysQueryResponse = [[MXKeysQueryResponse alloc] init];
    if (keysQueryResponse)
    {
        // Devices keys
        NSMutableDictionary *map = [NSMutableDictionary dictionary];

        if ([JSONDictionary isKindOfClass:NSDictionary.class])
        {
            for (NSString *userId in JSONDictionary[@"device_keys"])
            {
                if ([JSONDictionary[@"device_keys"][userId] isKindOfClass:NSDictionary.class])
                {
                    map[userId] = [NSMutableDictionary dictionary];

                    for (NSString *deviceId in JSONDictionary[@"device_keys"][userId])
                    {
                        MXDeviceInfo *deviceInfo;
                        MXJSONModelSetMXJSONModel(deviceInfo, MXDeviceInfo, JSONDictionary[@"device_keys"][userId][deviceId]);

                        map[userId][deviceId] = deviceInfo;
                    }
                }
            }
        }

        keysQueryResponse.deviceKeys = [[MXUsersDevicesMap<MXDeviceInfo*> alloc] initWithMap:map];

        MXJSONModelSetDictionary(keysQueryResponse.failures, JSONDictionary[@"failures"]);

        // Extract cross-signing keys
        NSMutableDictionary *crossSigningKeys = [NSMutableDictionary dictionary];

        // Gather all of them by type by user
        NSDictionary<NSString*, NSDictionary<NSString*, MXCrossSigningKey*>*> *allKeys =
        @{
          MXCrossSigningKeyType.master: [self extractUserKeysFromJSON:JSONDictionary[@"master_keys"]] ?: @{},
          MXCrossSigningKeyType.selfSigning: [self extractUserKeysFromJSON:JSONDictionary[@"self_signing_keys"]] ?: @{},
          MXCrossSigningKeyType.userSigning: [self extractUserKeysFromJSON:JSONDictionary[@"user_signing_keys"]] ?: @{},
          };

        // Package them into a `userId -> MXCrossSigningInfo` dictionary
        for (NSString *keyType in allKeys)
        {
            NSDictionary<NSString*, MXCrossSigningKey*> *keys = allKeys[keyType];
            for (NSString *userId in keys)
            {
                MXCrossSigningInfo *crossSigningInfo = crossSigningKeys[userId];
                if (!crossSigningInfo)
                {
                    crossSigningInfo = [[MXCrossSigningInfo alloc] initWithUserId:userId];
                    crossSigningKeys[userId] = crossSigningInfo;
                }

                [crossSigningInfo addCrossSigningKey:keys[userId] type:keyType];
            }
        }

        keysQueryResponse.crossSigningKeys = crossSigningKeys;
    }

    return keysQueryResponse;
}

+ (NSDictionary<NSString*, MXCrossSigningKey*>*)extractUserKeysFromJSON:(NSDictionary *)keysJSONDictionary
{
    NSMutableDictionary<NSString*, MXCrossSigningKey*> *keys = [NSMutableDictionary dictionary];
    for (NSString *userId in keysJSONDictionary)
    {
        MXCrossSigningKey *key;
        MXJSONModelSetMXJSONModel(key, MXCrossSigningKey, keysJSONDictionary[userId]);
        if (key)
        {
            keys[userId] = key;
        }
    }

    if (!keys.count)
    {
        keys = nil;
    }

    return keys;
}

@end

@implementation MXKeysClaimResponse

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXKeysClaimResponse *keysClaimResponse = [[MXKeysClaimResponse alloc] init];
    if (keysClaimResponse)
    {
        NSMutableDictionary *map = [NSMutableDictionary dictionary];

        if ([JSONDictionary isKindOfClass:NSDictionary.class])
        {
            for (NSString *userId in JSONDictionary[@"one_time_keys"])
            {
                if ([JSONDictionary[@"one_time_keys"][userId] isKindOfClass:NSDictionary.class])
                {
                    for (NSString *deviceId in JSONDictionary[@"one_time_keys"][userId])
                    {
                        MXKey *key;
                        MXJSONModelSetMXJSONModel(key, MXKey, JSONDictionary[@"one_time_keys"][userId][deviceId]);

                        if (!map[userId])
                        {
                            map[userId] = [NSMutableDictionary dictionary];
                        }
                        map[userId][deviceId] = key;
                    }
                }
            }
        }

        keysClaimResponse.oneTimeKeys = [[MXUsersDevicesMap<MXKey*> alloc] initWithMap:map];

        MXJSONModelSetDictionary(keysClaimResponse.failures, JSONDictionary[@"failures"]);
    }
    
    return keysClaimResponse;
}

@end

#pragma mark - Device Management

@implementation MXDevice

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXDevice *device = [[MXDevice alloc] init];
    if (device)
    {
        MXJSONModelSetString(device.deviceId, JSONDictionary[@"device_id"]);
        MXJSONModelSetString(device.displayName, JSONDictionary[@"display_name"]);
        MXJSONModelSetString(device.lastSeenIp, JSONDictionary[@"last_seen_ip"]);
        MXJSONModelSetUInt64(device.lastSeenTs, JSONDictionary[@"last_seen_ts"]);
    }
    
    return device;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _deviceId = [aDecoder decodeObjectForKey:@"device_id"];
        _displayName = [aDecoder decodeObjectForKey:@"display_name"];
        _lastSeenIp = [aDecoder decodeObjectForKey:@"last_seen_ip"];
        _lastSeenTs = [((NSNumber*)[aDecoder decodeObjectForKey:@"last_seen_ts"]) unsignedLongLongValue];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_deviceId forKey:@"device_id"];
    if (_displayName)
    {
        [aCoder encodeObject:_displayName forKey:@"display_name"];
    }
    [aCoder encodeObject:_lastSeenIp forKey:@"last_seen_ip"];
    [aCoder encodeObject:@(_lastSeenTs) forKey:@"last_seen_ts"];
}

@end

#pragma mark - Groups (Communities)

@implementation MXGroupProfile

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXGroupProfile *profile = [[MXGroupProfile alloc] init];
    if (profile)
    {
        JSONDictionary = [MXJSONModel removeNullValuesInJSON:JSONDictionary];
        MXJSONModelSetString(profile.shortDescription, JSONDictionary[@"short_description"]);
        MXJSONModelSetBoolean(profile.isPublic, JSONDictionary[@"is_public"]);
        MXJSONModelSetString(profile.avatarUrl, JSONDictionary[@"avatar_url"]);
        MXJSONModelSetString(profile.name, JSONDictionary[@"name"]);
        MXJSONModelSetString(profile.longDescription, JSONDictionary[@"long_description"]);
    }
    
    return profile;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (![object isKindOfClass:MXGroupProfile.class])
        return NO;
    
    MXGroupProfile *profile = (MXGroupProfile *)object;
    
    if (profile.isPublic != _isPublic)
    {
        return NO;
    }
    
    if ((profile.shortDescription || _shortDescription) && ![profile.shortDescription isEqualToString:_shortDescription])
    {
        return NO;
    }
    
    if ((profile.longDescription || _longDescription) && ![profile.longDescription isEqualToString:_longDescription])
    {
        return NO;
    }
    
    if ((profile.avatarUrl || _avatarUrl) && ![profile.avatarUrl isEqualToString:_avatarUrl])
    {
        return NO;
    }
    
    if ((profile.name || _name) && ![profile.name isEqualToString:_name])
    {
        return NO;
    }
    
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _shortDescription = [aDecoder decodeObjectForKey:@"short_description"];
        _isPublic = [aDecoder decodeBoolForKey:@"is_public"];
        _avatarUrl = [aDecoder decodeObjectForKey:@"avatar_url"];
        _name = [aDecoder decodeObjectForKey:@"name"];
        _longDescription = [aDecoder decodeObjectForKey:@"long_description"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (_shortDescription)
    {
        [aCoder encodeObject:_shortDescription forKey:@"short_description"];
    }
    [aCoder encodeBool:_isPublic forKey:@"is_public"];
    if (_avatarUrl)
    {
        [aCoder encodeObject:_avatarUrl forKey:@"avatar_url"];
    }
    if (_name)
    {
        [aCoder encodeObject:_name forKey:@"name"];
    }
    if (_longDescription)
    {
        [aCoder encodeObject:_longDescription forKey:@"long_description"];
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    MXGroupProfile *profile = [[[self class] allocWithZone:zone] init];
    
    profile.shortDescription = [_shortDescription copyWithZone:zone];
    profile.isPublic = _isPublic;
    profile.avatarUrl = [_avatarUrl copyWithZone:zone];
    profile.name = [_name copyWithZone:zone];
    profile.longDescription = [_longDescription copyWithZone:zone];
    
    return profile;
}

@end

@implementation MXGroupSummaryUsersSection

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXGroupSummaryUsersSection *usersSection = [[MXGroupSummaryUsersSection alloc] init];
    if (usersSection)
    {
        MXJSONModelSetUInteger(usersSection.totalUserCountEstimate, JSONDictionary[@"total_user_count_estimate"]);
        MXJSONModelSetArray(usersSection.users, JSONDictionary[@"users"]);
        MXJSONModelSetDictionary(usersSection.roles, JSONDictionary[@"roles"]);
    }
    
    return usersSection;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (![object isKindOfClass:MXGroupSummaryUsersSection.class])
        return NO;
    
    MXGroupSummaryUsersSection *users = (MXGroupSummaryUsersSection *)object;
    
    if (users.totalUserCountEstimate != _totalUserCountEstimate)
    {
        return NO;
    }
    
    if ((users.users || _users) && ![users.users isEqualToArray:_users])
    {
        return NO;
    }
    
    if ((users.roles || _roles) && ![users.roles isEqualToDictionary:_roles])
    {
        return NO;
    }
    
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _totalUserCountEstimate = [(NSNumber*)[aDecoder decodeObjectForKey:@"total_user_count_estimate"] unsignedIntegerValue];
        _users = [aDecoder decodeObjectForKey:@"users"];
        _roles = [aDecoder decodeObjectForKey:@"roles"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:@(_totalUserCountEstimate) forKey:@"total_user_count_estimate"];
    if (_users)
    {
        [aCoder encodeObject:_users forKey:@"users"];
    }
    if (_roles)
    {
        [aCoder encodeObject:_roles forKey:@"roles"];
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    MXGroupSummaryUsersSection *usersSection = [[[self class] allocWithZone:zone] init];
    
    usersSection.totalUserCountEstimate = _totalUserCountEstimate;
    usersSection.users = [[NSArray allocWithZone:zone] initWithArray:_users copyItems:YES];
    usersSection.roles = [[NSMutableDictionary allocWithZone:zone] initWithDictionary:_roles copyItems:YES];
    
    return usersSection;
}

@end

@implementation MXGroupSummaryUser

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXGroupSummaryUser *user = [[MXGroupSummaryUser alloc] init];
    if (user)
    {
        MXJSONModelSetString(user.membership, JSONDictionary[@"membership"]);
        MXJSONModelSetBoolean(user.isPublicised, JSONDictionary[@"is_publicised"]);
        MXJSONModelSetBoolean(user.isPublic, JSONDictionary[@"is_public"]);
        MXJSONModelSetBoolean(user.isPrivileged, JSONDictionary[@"is_privileged"]);
    }
    
    return user;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (![object isKindOfClass:MXGroupSummaryUser.class])
        return NO;
    
    MXGroupSummaryUser *user = (MXGroupSummaryUser *)object;
    
    if (user.isPublic != _isPublic)
    {
        return NO;
    }
    
    if ((user.membership || _membership) && ![user.membership isEqualToString:_membership])
    {
        return NO;
    }
    
    if (user.isPublicised != _isPublicised)
    {
        return NO;
    }
    
    if (user.isPrivileged != _isPrivileged)
    {
        return NO;
    }
    
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _membership = [aDecoder decodeObjectForKey:@"membership"];
        _isPublicised = [aDecoder decodeBoolForKey:@"is_publicised"];
        _isPublic = [aDecoder decodeBoolForKey:@"is_public"];
        _isPrivileged = [aDecoder decodeBoolForKey:@"is_privileged"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (_membership)
    {
        [aCoder encodeObject:_membership forKey:@"membership"];
    }
    [aCoder encodeBool:_isPublicised forKey:@"is_publicised"];
    [aCoder encodeBool:_isPublic forKey:@"is_public"];
    [aCoder encodeBool:_isPrivileged forKey:@"is_privileged"];
}

- (id)copyWithZone:(NSZone *)zone
{
    MXGroupSummaryUser *user = [[[self class] allocWithZone:zone] init];
    
    user.isPublicised = _isPublicised;
    user.membership = [_membership copyWithZone:zone];
    
    return user;
}

@end

@implementation MXGroupSummaryRoomsSection

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXGroupSummaryRoomsSection *roomsSection = [[MXGroupSummaryRoomsSection alloc] init];
    if (roomsSection)
    {
        MXJSONModelSetUInteger(roomsSection.totalRoomCountEstimate, JSONDictionary[@"total_room_count_estimate"]);
        MXJSONModelSetArray(roomsSection.rooms, JSONDictionary[@"rooms"]);
        MXJSONModelSetDictionary(roomsSection.categories, JSONDictionary[@"categories"]);
    }
    
    return roomsSection;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (![object isKindOfClass:MXGroupSummaryRoomsSection.class])
        return NO;
    
    MXGroupSummaryRoomsSection *rooms = (MXGroupSummaryRoomsSection *)object;
    
    if (rooms.totalRoomCountEstimate != _totalRoomCountEstimate)
    {
        return NO;
    }
    
    if ((rooms.rooms || _rooms) && ![rooms.rooms isEqualToArray:_rooms])
    {
        return NO;
    }
    
    if ((rooms.categories || _categories) && ![rooms.categories isEqualToDictionary:_categories])
    {
        return NO;
    }
    
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _totalRoomCountEstimate = [(NSNumber*)[aDecoder decodeObjectForKey:@"total_room_count_estimate"] unsignedIntegerValue];
        _rooms = [aDecoder decodeObjectForKey:@"rooms"];
        _categories = [aDecoder decodeObjectForKey:@"categories"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:@(_totalRoomCountEstimate) forKey:@"total_room_count_estimate"];
    if (_rooms)
    {
        [aCoder encodeObject:_rooms forKey:@"rooms"];
    }
    if (_categories)
    {
        [aCoder encodeObject:_categories forKey:@"categories"];
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    MXGroupSummaryRoomsSection *roomsSection = [[[self class] allocWithZone:zone] init];
    
    roomsSection.totalRoomCountEstimate = _totalRoomCountEstimate;
    roomsSection.rooms = [[NSArray allocWithZone:zone] initWithArray:_rooms copyItems:YES];
    roomsSection.categories = [[NSMutableDictionary allocWithZone:zone] initWithDictionary:_categories copyItems:YES];
    
    return roomsSection;
}

@end

@implementation MXGroupSummary

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXGroupSummary *summary = [[MXGroupSummary alloc] init];
    if (summary)
    {
        MXJSONModelSetMXJSONModel(summary.profile, MXGroupProfile, JSONDictionary[@"profile"]);
        MXJSONModelSetMXJSONModel(summary.usersSection, MXGroupSummaryUsersSection, JSONDictionary[@"users_section"]);
        MXJSONModelSetMXJSONModel(summary.user, MXGroupSummaryUser, JSONDictionary[@"user"]);
        MXJSONModelSetMXJSONModel(summary.roomsSection, MXGroupSummaryRoomsSection, JSONDictionary[@"rooms_section"]);
    }
    
    return summary;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (![object isKindOfClass:MXGroupSummary.class])
        return NO;
    
    MXGroupSummary *summary = (MXGroupSummary *)object;
    
    if (![summary.profile isEqual:_profile])
    {
        return NO;
    }
    
    if (![summary.user isEqual:_user])
    {
        return NO;
    }
    
    if (![summary.usersSection isEqual:_usersSection])
    {
        return NO;
    }
    
    if (![summary.roomsSection isEqual:_roomsSection])
    {
        return NO;
    }
    
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _profile = [aDecoder decodeObjectForKey:@"profile"];
        _usersSection = [aDecoder decodeObjectForKey:@"users_section"];
        _user = [aDecoder decodeObjectForKey:@"user"];
        _roomsSection = [aDecoder decodeObjectForKey:@"rooms_section"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (_profile)
    {
        [aCoder encodeObject:_profile forKey:@"profile"];
    }
    if (_usersSection)
    {
        [aCoder encodeObject:_usersSection forKey:@"users_section"];
    }
    if (_user)
    {
        [aCoder encodeObject:_user forKey:@"user"];
    }
    if (_roomsSection)
    {
        [aCoder encodeObject:_roomsSection forKey:@"rooms_section"];
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    MXGroupSummary *summary = [[[self class] allocWithZone:zone] init];
    
    summary.profile = [_profile copyWithZone:zone];
    summary.usersSection = [_usersSection copyWithZone:zone];
    summary.user = [_user copyWithZone:zone];
    summary.roomsSection = [_roomsSection copyWithZone:zone];
    
    return summary;
}

@end

@implementation MXGroupRoom

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXGroupRoom *room = [[MXGroupRoom alloc] init];
    if (room)
    {
        MXJSONModelSetString(room.canonicalAlias, JSONDictionary[@"canonical_alias"]);
        MXJSONModelSetString(room.roomId, JSONDictionary[@"room_id"]);
        MXJSONModelSetString(room.name, JSONDictionary[@"name"]);
        MXJSONModelSetString(room.topic, JSONDictionary[@"topic"]);
        MXJSONModelSetUInteger(room.numJoinedMembers, JSONDictionary[@"num_joined_members"]);
        MXJSONModelSetBoolean(room.worldReadable, JSONDictionary[@"world_readable"]);
        MXJSONModelSetBoolean(room.guestCanJoin, JSONDictionary[@"guest_can_join"]);
        MXJSONModelSetString(room.avatarUrl, JSONDictionary[@"avatar_url"]);
        MXJSONModelSetBoolean(room.isPublic, JSONDictionary[@"is_public"]);
    }
    
    return room;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (![object isKindOfClass:MXGroupRoom.class])
        return NO;
    
    MXGroupRoom *room = (MXGroupRoom *)object;
    
    if (room.isPublic != _isPublic)
    {
        return NO;
    }
    if (room.numJoinedMembers != _numJoinedMembers)
    {
        return NO;
    }
    if (room.worldReadable != _worldReadable)
    {
        return NO;
    }
    if (room.guestCanJoin != _guestCanJoin)
    {
        return NO;
    }
    if ((room.canonicalAlias || _canonicalAlias) && ![room.canonicalAlias isEqualToString:_canonicalAlias])
    {
        return NO;
    }
    if ((room.roomId || _roomId) && ![room.roomId isEqualToString:_roomId])
    {
        return NO;
    }
    if ((room.name || _name) && ![room.name isEqualToString:_name])
    {
        return NO;
    }
    if ((room.topic || _topic) && ![room.topic isEqualToString:_topic])
    {
        return NO;
    }
    if ((room.avatarUrl || _avatarUrl) && ![room.avatarUrl isEqualToString:_avatarUrl])
    {
        return NO;
    }
    
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _canonicalAlias = [aDecoder decodeObjectForKey:@"canonical_alias"];
        _roomId = [aDecoder decodeObjectForKey:@"room_id"];
        _name = [aDecoder decodeObjectForKey:@"name"];
        _topic = [aDecoder decodeObjectForKey:@"topic"];
        _numJoinedMembers = [(NSNumber*)[aDecoder decodeObjectForKey:@"num_joined_members"] unsignedIntegerValue];
        _worldReadable = [aDecoder decodeBoolForKey:@"world_readable"];
        _guestCanJoin = [aDecoder decodeBoolForKey:@"guest_can_join"];
        _avatarUrl = [aDecoder decodeObjectForKey:@"avatar_url"];
        _isPublic = [aDecoder decodeBoolForKey:@"is_public"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (_canonicalAlias)
    {
        [aCoder encodeObject:_canonicalAlias forKey:@"canonical_alias"];
    }
    [aCoder encodeObject:_roomId forKey:@"room_id"];
    if (_name)
    {
        [aCoder encodeObject:_name forKey:@"name"];
    }
    if (_topic)
    {
        [aCoder encodeObject:_topic forKey:@"topic"];
    }
    [aCoder encodeObject:@(_numJoinedMembers) forKey:@"num_joined_members"];
    [aCoder encodeBool:_worldReadable forKey:@"world_readable"];
    [aCoder encodeBool:_guestCanJoin forKey:@"guest_can_join"];
    if (_avatarUrl)
    {
        [aCoder encodeObject:_avatarUrl forKey:@"avatar_url"];
    }
    [aCoder encodeBool:_isPublic forKey:@"is_public"];
}

- (id)copyWithZone:(NSZone *)zone
{
    MXGroupRoom *room = [[[self class] allocWithZone:zone] init];
    
    room.canonicalAlias = [_canonicalAlias copyWithZone:zone];
    room.roomId = [_roomId copyWithZone:zone];
    room.name = [_name copyWithZone:zone];
    room.topic = [_topic copyWithZone:zone];
    room.avatarUrl = [_avatarUrl copyWithZone:zone];
    room.numJoinedMembers = _numJoinedMembers;
    room.worldReadable = _worldReadable;
    room.guestCanJoin = _guestCanJoin;
    room.isPublic = _isPublic;
    
    return room;
}

@end

@implementation MXGroupRooms

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXGroupRooms *rooms = [[MXGroupRooms alloc] init];
    if (rooms)
    {
        MXJSONModelSetUInteger(rooms.totalRoomCountEstimate, JSONDictionary[@"total_room_count_estimate"]);
        MXJSONModelSetMXJSONModelArray(rooms.chunk, MXGroupRoom, JSONDictionary[@"chunk"]);
    }
    
    return rooms;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (![object isKindOfClass:MXGroupRooms.class])
        return NO;
    
    MXGroupRooms *rooms = (MXGroupRooms *)object;
    
    if (rooms.totalRoomCountEstimate != _totalRoomCountEstimate)
    {
        return NO;
    }
    if ((rooms.chunk || _chunk) && ![rooms.chunk isEqualToArray:_chunk])
    {
        return NO;
    }
    
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _totalRoomCountEstimate = [(NSNumber*)[aDecoder decodeObjectForKey:@"total_room_count_estimate"] unsignedIntegerValue];
        _chunk = [aDecoder decodeObjectForKey:@"chunk"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:@(_totalRoomCountEstimate) forKey:@"total_room_count_estimate"];
    if (_chunk)
    {
        [aCoder encodeObject:_chunk forKey:@"chunk"];
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    MXGroupRooms *rooms = [[[self class] allocWithZone:zone] init];
    
    rooms.totalRoomCountEstimate = _totalRoomCountEstimate;
    rooms.chunk = [[NSArray allocWithZone:zone] initWithArray:_chunk copyItems:YES];
    
    return rooms;
}

@end

@implementation MXGroupUser

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXGroupUser *user = [[MXGroupUser alloc] init];
    if (user)
    {
        MXJSONModelSetString(user.displayname, JSONDictionary[@"displayname"]);
        MXJSONModelSetString(user.userId, JSONDictionary[@"user_id"]);
        MXJSONModelSetBoolean(user.isPrivileged, JSONDictionary[@"is_privileged"]);
        MXJSONModelSetString(user.avatarUrl, JSONDictionary[@"avatar_url"]);
        MXJSONModelSetBoolean(user.isPublic, JSONDictionary[@"is_public"]);
    }
    
    return user;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (![object isKindOfClass:MXGroupUser.class])
        return NO;
    
    MXGroupUser *user = (MXGroupUser *)object;
    
    if (user.isPublic != _isPublic)
    {
        return NO;
    }
    if (user.isPrivileged != _isPrivileged)
    {
        return NO;
    }
    if ((user.userId || _userId) && ![user.userId isEqualToString:_userId])
    {
        return NO;
    }
    if ((user.displayname || _displayname) && ![user.displayname isEqualToString:_displayname])
    {
        return NO;
    }
    if ((user.avatarUrl || _avatarUrl) && ![user.avatarUrl isEqualToString:_avatarUrl])
    {
        return NO;
    }
    
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _displayname = [aDecoder decodeObjectForKey:@"displayname"];
        _userId = [aDecoder decodeObjectForKey:@"user_id"];
        _isPrivileged = [aDecoder decodeBoolForKey:@"is_privileged"];
        _avatarUrl = [aDecoder decodeObjectForKey:@"avatar_url"];
        _isPublic = [aDecoder decodeBoolForKey:@"is_public"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (_displayname)
    {
        [aCoder encodeObject:_displayname forKey:@"displayname"];
    }
    [aCoder encodeObject:_userId forKey:@"user_id"];
    [aCoder encodeBool:_isPrivileged forKey:@"is_privileged"];
    if (_avatarUrl)
    {
        [aCoder encodeObject:_avatarUrl forKey:@"avatar_url"];
    }
    [aCoder encodeBool:_isPublic forKey:@"is_public"];
}

- (id)copyWithZone:(NSZone *)zone
{
    MXGroupUser *user = [[[self class] allocWithZone:zone] init];
    
    user.displayname = [_displayname copyWithZone:zone];
    user.userId = [_userId copyWithZone:zone];
    user.avatarUrl = [_avatarUrl copyWithZone:zone];
    user.isPrivileged = _isPrivileged;
    user.isPublic = _isPublic;
    
    return user;
}

@end

@implementation MXGroupUsers

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXGroupUsers *users = [[MXGroupUsers alloc] init];
    if (users)
    {
        MXJSONModelSetUInteger(users.totalUserCountEstimate, JSONDictionary[@"total_user_count_estimate"]);
        MXJSONModelSetMXJSONModelArray(users.chunk, MXGroupUser, JSONDictionary[@"chunk"]);
    }
    
    return users;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (![object isKindOfClass:MXGroupUsers.class])
        return NO;
    
    MXGroupUsers *users = (MXGroupUsers *)object;
    
    if (users.totalUserCountEstimate != _totalUserCountEstimate)
    {
        return NO;
    }
    
    if ((users.chunk || _chunk) && ![users.chunk isEqualToArray:_chunk])
    {
        return NO;
    }
    
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _totalUserCountEstimate = [(NSNumber*)[aDecoder decodeObjectForKey:@"total_user_count_estimate"] unsignedIntegerValue];
        _chunk = [aDecoder decodeObjectForKey:@"chunk"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:@(_totalUserCountEstimate) forKey:@"total_user_count_estimate"];
    if (_chunk)
    {
        [aCoder encodeObject:_chunk forKey:@"chunk"];
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    MXGroupUsers *users = [[[self class] allocWithZone:zone] init];
    
    users.totalUserCountEstimate = _totalUserCountEstimate;
    users.chunk = [[NSArray allocWithZone:zone] initWithArray:_chunk copyItems:YES];
    
    return users;
}

@end
