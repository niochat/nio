/*
 Copyright 2014 OpenMarket Ltd
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

#import "MXMyUser.h"

#import "MXSession.h"
#import "MXTools.h"

@interface MXMyUser ()
@end

@implementation MXMyUser

- (instancetype)initWithUserId:(NSString *)userId andDisplayname:(NSString *)displayname andAvatarUrl:(NSString *)avatarUrl
{
    self = [super initWithUserId:userId];
    if (self)
    {
        _displayname = [displayname copy];
        _avatarUrl = [avatarUrl copy];
    }
    return self;
}

- (void)setDisplayName:(NSString *)displayname success:(void (^)(void))success failure:(void (^)(NSError *))failure
{
    MXWeakify(self);
    [self.mxSession.matrixRestClient setDisplayName:displayname success:^{
        MXStrongifyAndReturnIfNil(self);

        // Update the information right now
        self->_displayname = [displayname copy];

        [self.mxSession.store storeUser:self];
        if ([self.mxSession.store respondsToSelector:@selector(commit)])
        {
            [self.mxSession.store commit];
        }

        if (success)
        {
            success();
        }

    } failure:^(NSError *error) {
        if (failure)
        {
            failure(error);
        }
    }];
}

- (void)setAvatarUrl:(NSString *)avatarUrl success:(void (^)(void))success failure:(void (^)(NSError *))failure
{
    MXWeakify(self);
    [_mxSession.matrixRestClient setAvatarUrl:avatarUrl success:^{
        MXStrongifyAndReturnIfNil(self);

        // Update the information right now
        self->_avatarUrl = [avatarUrl copy];

        [self.mxSession.store storeUser:self];
        if ([self.mxSession.store respondsToSelector:@selector(commit)])
        {
            [self.mxSession.store commit];
        }

        if (success)
        {
            success();
        }

    } failure:^(NSError *error) {
        if (failure)
        {
            failure(error);
        }
    }];
}

- (void)setPresence:(MXPresence)presence andStatusMessage:(NSString *)statusMessage success:(void (^)(void))success failure:(void (^)(NSError *))failure
{
    MXWeakify(self);
    [_mxSession.matrixRestClient setPresence:presence andStatusMessage:statusMessage success:^{
        MXStrongifyAndReturnIfNil(self);

        // Update the information right now
        self->_presence = presence;
        self->_statusMsg = [statusMessage copy];

        [self.mxSession.store storeUser:self];
        if ([self.mxSession.store respondsToSelector:@selector(commit)])
        {
            [self.mxSession.store commit];
        }

        if (success)
        {
            success();
        }

    } failure:^(NSError *error) {
        if (failure)
        {
            failure(error);
        }
    }];
}

@end
