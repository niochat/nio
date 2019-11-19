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

#import "MXInvite3PID.h"

@interface MXInvite3PID()
{
    NSMutableDictionary<NSString *, id> *dictionary;
}
@end

@implementation MXInvite3PID

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        dictionary = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)setIdentityServer:(NSString *)identityServer
{
    dictionary[@"id_server"] = identityServer;
    _identityServer = identityServer;
}

- (void)setMedium:(NSString *)medium
{
    dictionary[@"medium"] = medium;
    _medium = medium;
}

- (void)setAddress:(NSString *)address
{
    dictionary[@"address"] = address;
    _address = address;
}

- (NSDictionary<NSString *, id> *)dictionary
{
    if (dictionary.count == 3)
    {
        return  dictionary;
    }
    
    return nil;
}

@end
