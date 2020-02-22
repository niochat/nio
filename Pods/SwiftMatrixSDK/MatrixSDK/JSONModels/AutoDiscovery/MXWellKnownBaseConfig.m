/*
 Copyright 2019 New Vector Ltd

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

#import "MXWellKnownBaseConfig.h"

@implementation MXWellKnownBaseConfig

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXWellKnownBaseConfig *wellKnownBaseConfig;

    NSString *baseUrl;
    MXJSONModelSetString(baseUrl, JSONDictionary[@"base_url"]);
    if (baseUrl)
    {
        // Trim the last slash to make the url usable
        if ([baseUrl hasSuffix:@"/"])
        {
            baseUrl = [baseUrl substringToIndex:baseUrl.length - 1];
        }

        wellKnownBaseConfig = [MXWellKnownBaseConfig new];
        wellKnownBaseConfig.baseUrl = baseUrl;
    }

    return wellKnownBaseConfig;
}


#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _baseUrl = [aDecoder decodeObjectForKey:@"base_url"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_baseUrl forKey:@"base_url"];
}

@end
