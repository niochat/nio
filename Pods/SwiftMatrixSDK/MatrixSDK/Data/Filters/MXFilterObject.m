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

#import "MXFilterObject.h"

#import "MXTools.h"

@implementation MXFilterObject

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        dictionary = [NSMutableDictionary dictionary];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)theDictionary
{
    self = [super init];
    if (self)
    {
        dictionary = [NSMutableDictionary dictionaryWithDictionary:theDictionary];
    }
    return self;
}

- (NSDictionary<NSString *, id>*)dictionary
{
    return dictionary;
}

- (NSString *)jsonString
{
    return [MXTools serialiseJSONObject:self.dictionary];
}

- (NSString *)description
{
    return dictionary.description;
}

@end
