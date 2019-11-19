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

#import "MXFilter.h"

#import "MXJSONModel.h"

@implementation MXFilter

- (void)setTypes:(NSArray<NSString *> *)types
{
    dictionary[@"types"] = types;
}

- (NSArray<NSString *> *)types
{
    NSArray<NSString *> *types;
    MXJSONModelSetArray(types, dictionary[@"types"]);
    return types;
}


- (void)setNotTypes:(NSArray<NSString *> *)notTypes
{
    dictionary[@"not_types"] = notTypes;
}

- (NSArray<NSString *> *)notTypes
{
    NSArray<NSString *> *notTypes;
    MXJSONModelSetArray(notTypes, dictionary[@"not_types"]);
    return notTypes;
}


- (void)setSenders:(NSArray<NSString *> *)senders
{
    dictionary[@"senders"] = senders;
}

- (NSArray<NSString *> *)senders
{
    NSArray<NSString *> *senders;
    MXJSONModelSetArray(senders, dictionary[@"senders"]);
    return senders;
}


- (void)setNotSenders:(NSArray<NSString *> *)notSenders
{
    dictionary[@"not_senders"] = notSenders;
}

-(NSArray<NSString *> *)notSenders
{
    NSArray<NSString *> *notSenders;
    MXJSONModelSetArray(notSenders, dictionary[@"not_senders"]);
    return notSenders;
}


- (void)setLimit:(NSUInteger)limit
{
    dictionary[@"limit"] = [NSNumber numberWithUnsignedInteger:limit];
}

- (NSUInteger)limit
{
    NSUInteger limit = 10;  // Basic default value used by homeservers
    MXJSONModelSetUInteger(limit, dictionary[@"limit"]);
    return limit;
}

@end
