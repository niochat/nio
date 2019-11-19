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

#import "MXDeviceVerificationTransaction.h"
#import "MXDeviceVerificationTransaction_Private.h"

#import "MXDeviceVerificationManager_Private.h"
#import "MXCrypto_Private.h"
#import "MXKeyVerificationStart.h"

#import "MXTools.h"


#pragma mark - Constants
NSString * const MXDeviceVerificationTransactionDidChangeNotification = @"MXDeviceVerificationTransactionDidChangeNotification";


@implementation MXDeviceVerificationTransaction

- (instancetype)initWithOtherDevice:(MXDeviceInfo*)otherDevice andManager:(MXDeviceVerificationManager*)manager;
{
    self = [self init];
    if (self)
    {
        _manager = manager;
        _otherDevice = otherDevice;
        _transactionId = [MXDeviceVerificationTransaction createUniqueIdWithOtherUser:self.otherUserId otherDevice:self.otherDeviceId myUser:manager.crypto.mxSession.matrixRestClient.credentials];
        _creationDate = [NSDate date];
    }
    return self;
}

- (nullable instancetype)initWithOtherDevice:(MXDeviceInfo*)otherDevice startEvent:(MXEvent *)event andManager:(MXDeviceVerificationManager *)manager
{
    MXKeyVerificationStart *startContent;
    MXJSONModelSetMXJSONModel(startContent, MXKeyVerificationStart, event.content);
    if (!startContent || !startContent.isValid)
    {
        NSLog(@"[MXDeviceVerificationTransaction]: ERROR: Invalid start event: %@", event);
        return nil;
    }

    self = [self initWithOtherDevice:otherDevice andManager:manager];
    if (self)
    {
        _startContent = startContent;
        _transactionId = _startContent.transactionId;

        // It would have been nice to timeout from the event creation date
        // but we do not receive the information. originServerTs = 0
        // So, use the time when we receive it instead
        //_creationDate = [NSDate dateWithTimeIntervalSince1970: (event.originServerTs / 1000)];
    }
    return self;
}

- (NSString *)otherUserId
{
    return _otherDevice.userId;
}

- (NSString *)otherDeviceId
{
    return _otherDevice.deviceId;
}

- (void)cancelWithCancelCode:(MXTransactionCancelCode *)code
{
    dispatch_async(self.manager.crypto.decryptionQueue,^{
        [self cancelWithCancelCodeFromCryptoQueue:code];
    });
}

- (void)cancelWithCancelCodeFromCryptoQueue:(MXTransactionCancelCode *)code
{
    [self.manager cancelTransaction:self code:code];
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
        [[NSNotificationCenter defaultCenter] postNotificationName:MXDeviceVerificationTransactionDidChangeNotification object:self userInfo:nil];
    });
}

- (void)handleAccept:(MXKeyVerificationAccept*)acceptContent
{
    // Must be handled by the specific implementation
    NSAssert(NO, @"%@ does not implement handleAccept", self.class);
}

- (void)handleCancel:(MXKeyVerificationCancel*)cancelContent
{
    // Must be handled by the specific implementation
    NSAssert(NO, @"%@ does not implement handleCancel", self.class);
}

- (void)handleKey:(MXKeyVerificationKey*)keyContent
{
    // Must be handled by the specific implementation
    NSAssert(NO, @"%@ does not implement handleKey", self.class);
}

- (void)handleMac:(MXKeyVerificationMac*)macContent
{
    // Must be handled by the specific implementation
    NSAssert(NO, @"%@ does not implement handleMac", self.class);
}


+ (NSString*)createUniqueIdWithOtherUser:(NSString*)otherUser otherDevice:(NSString*)otherDevice myUser:(MXCredentials*)myUser
{
    return [NSString stringWithFormat:@"%@:%@|%@:%@|%@",
            myUser.userId, myUser.deviceId,
            otherUser, otherDevice,
            [MXTools generateTransactionId]];
}

@end
