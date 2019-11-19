/*
 Copyright 2015 OpenMarket Ltd
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

#import "MXSDKOptions.h"

static MXSDKOptions *sharedOnceInstance = nil;

@implementation MXSDKOptions

+ (MXSDKOptions *)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sharedOnceInstance = [[self alloc] init]; });
    return sharedOnceInstance;
}

#pragma mark - Initializations -

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _disableIdenticonUseForUserAvatar = NO;
        _enableCryptoWhenStartingMXSession = NO;
        _mediaCacheAppVersion = 0;
        _applicationGroupIdentifier = nil;
    }
    
    return self;
}

@end
