/*
 Copyright 2019 New Vector Ltd

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific languagMXWellKnowne governing permissions and
 limitations under the License.
 */

#import "MXWellknownIntegrations.h"

@implementation MXWellknownIntegrations

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXWellknownIntegrations *integrations;

    NSArray<MXWellknownIntegrationsManager*> *managers;
    MXJSONModelSetMXJSONModelArray(managers, MXWellknownIntegrationsManager.class, JSONDictionary[@"managers"]);
    if (managers)
    {
        integrations = [MXWellknownIntegrations new];
        integrations.managers = managers;
    }

    return integrations;
}


#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _managers = [aDecoder decodeObjectForKey:@"managers"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_managers forKey:@"managers"];
}

@end



@implementation MXWellknownIntegrationsManager

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXWellknownIntegrationsManager *manager;

    NSString *apiUrl;
    MXJSONModelSetString(apiUrl, JSONDictionary[@"api_url"]);

    if (apiUrl)
    {
        manager = [MXWellknownIntegrationsManager new];
        manager.apiUrl = apiUrl;

        MXJSONModelSetString(manager.uiUrl, JSONDictionary[@"ui_url"]);
    }

    return manager;
}


#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _apiUrl = [aDecoder decodeObjectForKey:@"api_url"];
        _uiUrl = [aDecoder decodeObjectForKey:@"ui_url"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_apiUrl forKey:@"api_url"];
    [aCoder encodeObject:_uiUrl forKey:@"ui_url"];
}

@end

