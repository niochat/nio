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

#import "MXKeyVerificationTransaction.h"
#import "MXKeyVerificationTransaction_Private.h"

#import "MXKeyVerificationManager_Private.h"
#import "MXCrypto_Private.h"

#import "MXTools.h"


#pragma mark - Constants
NSString * const MXKeyVerificationTransactionDidChangeNotification = @"MXKeyVerificationTransactionDidChangeNotification";


@implementation MXKeyVerificationTransaction

- (instancetype)initWithOtherDevice:(MXDeviceInfo*)otherDevice andManager:(MXKeyVerificationManager*)manager;
{
    self = [self init];
    if (self)
    {
        _manager = manager;
        _otherDevice = otherDevice;
        _transactionId = [MXKeyVerificationTransaction createUniqueIdWithOtherUser:self.otherUserId otherDevice:self.otherDeviceId myUser:manager.crypto.mxSession.matrixRestClient.credentials];
        _creationDate = [NSDate date];
    }
    return self;
}

- (void)setDirectMessageTransportInRoom:(NSString *)roomId originalEvent:(NSString *)eventId
{
    _transport = MXKeyVerificationTransportDirectMessage;
    _dmRoomId = roomId;
    _dmEventId = eventId;

    // The original event id is used as the transaction id
    _transactionId = eventId;
}

- (NSString *)otherUserId
{
    return _otherDevice.userId;
}

- (NSString *)otherDeviceId
{
    return _otherDevice.deviceId;
}

- (void)cancelWithCancelCode:(MXTransactionCancelCode*)code
{
    // Must be handled by the specific implementation
    NSAssert(NO, @"%@ does not implement cancelWithCancelCode", self.class);
}

- (void)cancelWithCancelCode:(MXTransactionCancelCode *)code
                     success:(void (^)(void))success
                     failure:(void (^)(NSError *error))failure
{
    dispatch_async(self.manager.crypto.cryptoQueue,^{
        [self.manager cancelTransaction:self code:code success:success failure:failure];
    });
}

- (MXHTTPOperation*)sendToOther:(NSString*)eventType content:(NSDictionary*)content
                        success:(void (^)(void))success
                        failure:(void (^)(NSError *error))failure
{
    return [_manager sendToOtherInTransaction:self eventType:eventType content:content success:success failure:failure];
}

- (void)didUpdateState
{
    dispatch_async(dispatch_get_main_queue(),^{
        [[NSNotificationCenter defaultCenter] postNotificationName:MXKeyVerificationTransactionDidChangeNotification object:self userInfo:nil];
    });
}

- (void)handleCancel:(MXKeyVerificationCancel*)cancelContent
{
    // Must be handled by the specific implementation
    NSAssert(NO, @"%@ does not implement handleCancel", self.class);
}

+ (NSString*)createUniqueIdWithOtherUser:(NSString*)otherUser otherDevice:(NSString*)otherDevice myUser:(MXCredentials*)myUser
{
    return [NSString stringWithFormat:@"%@:%@|%@:%@|%@",
            myUser.userId, myUser.deviceId,
            otherUser, otherDevice,
            [MXTools generateTransactionId]];
}

@end
