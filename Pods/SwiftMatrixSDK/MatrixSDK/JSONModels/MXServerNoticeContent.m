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

#import "MXServerNoticeContent.h"

NSString *const kMXServerNoticeTypeUsageLimitReached = @"m.server_notice.usage_limit_reached";


@implementation MXServerNoticeContent

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXServerNoticeContent* serverNoticeUsageLimitContent = [MXServerNoticeContent new];
    if (serverNoticeUsageLimitContent)
    {
        MXJSONModelSetString(serverNoticeUsageLimitContent->_limitType, JSONDictionary[@"limit_type"]);
        MXJSONModelSetString(serverNoticeUsageLimitContent->_adminContact, JSONDictionary[@"admin_contact"]);
        MXJSONModelSetString(serverNoticeUsageLimitContent->_serverNoticeType, JSONDictionary[@"server_notice_type"]);
    }

    return serverNoticeUsageLimitContent;
}

- (BOOL)isServerNoticeUsageLimit
{
    return [kMXServerNoticeTypeUsageLimitReached isEqualToString:_serverNoticeType];
}

@end
