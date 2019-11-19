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

#import "MXAccountData.h"

@interface MXAccountData ()
{
    /**
     This dictionary stores "account_data" data in a flat manner.
     */
    NSMutableDictionary<NSString *, id> *accountDataDict;
}
@end

@implementation MXAccountData

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        accountDataDict = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)updateWithEvent:(NSDictionary<NSString *, id> *)event
{
    accountDataDict[event[@"type"]] = event[@"content"];
}

- (NSDictionary *)accountDataForEventType:(NSString*)eventType
{
    return accountDataDict[eventType];
}

- (NSDictionary<NSString *, id> *)accountData
{
    // Rebuild the dictionary as sent by the homeserver
    NSMutableArray<NSDictionary<NSString *, id> *> *events = [NSMutableArray array];
    for (NSString *type in accountDataDict)
    {
        [events addObject:@{
                            @"type": type,
                            @"content": accountDataDict[type]
                            }];
    }
    return @{@"events": events};
}

@end
