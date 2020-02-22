/*
 Copyright 2014 OpenMarket Ltd

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

#import "MXFileStoreMetaData.h"

@implementation MXFileStoreMetaData

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [self init];
    if (self)
    {
        NSDictionary *dict = [aDecoder decodeObjectForKey:@"dict"];
        _homeServer = dict[@"homeServer"];
        _userId = dict[@"userId"];
        _eventStreamToken = dict[@"eventStreamToken"];
        _syncFilterId = dict[@"syncFilterId"];
        _userAccountData = dict[@"userAccountData"];

        NSNumber *version = dict[@"version"];
        _version = [version unsignedIntegerValue];

        _homeserverWellknown = dict[@"wellknown"];
    }
    return self;
}

-(void)encodeWithCoder:(NSCoder *)aCoder
{
    // Mandatory, non-null, properties
    NSMutableDictionary *dict =[NSMutableDictionary dictionaryWithDictionary:
                                @{
                                  @"homeServer": _homeServer,
                                  @"userId": _userId,
                                  @"version": @(_version),
                                  }];

    // Nullable properties
    if (_eventStreamToken)
    {
        dict[@"eventStreamToken"] = _eventStreamToken;
    }
    if (_syncFilterId)
    {
        dict[@"syncFilterId"] = _syncFilterId;
    }
    if (_userAccountData)
    {
        dict[@"userAccountData"] = _userAccountData;
    }
    if (_homeserverWellknown)
    {
        dict[@"wellknown"] = _homeserverWellknown;
    }

    [aCoder encodeObject:dict forKey:@"dict"];
}

- (id)copyWithZone:(NSZone *)zone
{
    MXFileStoreMetaData *metaData = [[MXFileStoreMetaData allocWithZone:zone] init];

    metaData->_homeServer = [_homeServer copyWithZone:zone];
    metaData->_userId = [_userId copyWithZone:zone];
    metaData->_version = _version;
    metaData->_eventStreamToken = [_eventStreamToken copyWithZone:zone];
    metaData->_userAccountData = [_userAccountData copyWithZone:zone];
 
    return metaData;
}

@end
