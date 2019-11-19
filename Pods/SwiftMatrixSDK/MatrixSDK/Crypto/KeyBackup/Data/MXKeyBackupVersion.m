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

#import "MXKeyBackupVersion.h"

@implementation MXKeyBackupVersion

- (nullable instancetype)initWithJSON:(NSDictionary *)JSONDictionary
{
    self = [super init];
    if (self)
    {
        MXJSONModelSetString(_algorithm, JSONDictionary[@"algorithm"]);
        MXJSONModelSetDictionary(_authData, JSONDictionary[@"auth_data"]);
        MXJSONModelSetString(_version, JSONDictionary[@"version"]);
    }

    // nonnull checks
    if (!_algorithm || !_authData)
    {
        return nil;
    }

    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MXKeyBackupVersion: %p> version: %@ - algorithm: %@", self, _version, _algorithm];
}

#pragma mark - MXJSONModel

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    return [[MXKeyBackupVersion alloc] initWithJSON:JSONDictionary];
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];

    JSONDictionary[@"algorithm"] = _algorithm;
    JSONDictionary[@"auth_data"] = _authData;
    if (_version)
    {
        JSONDictionary[@"version"] = _version;
    }

    return JSONDictionary;
}


#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MXKeyBackupVersion *keyBackupVersion = [MXKeyBackupVersion new];

    keyBackupVersion.algorithm = [_algorithm copyWithZone:zone];
    keyBackupVersion.authData = [_authData copyWithZone:zone];
    keyBackupVersion.version = [_version copyWithZone:zone];

    return keyBackupVersion;
}

@end
