/*
 Copyright 2016 OpenMarket Ltd
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

#import "MXOlmEncryption.h"

#import "MXCryptoAlgorithms.h"
#import "MXCrypto_Private.h"

#ifdef MX_CRYPTO

#import "MXTools.h"

@interface MXOlmEncryption ()
{
    MXCrypto *crypto;

    // The id of the room we will be sending to.
    NSString *roomId;
}

@end


@implementation MXOlmEncryption

+ (void)load
{
    // Register this class as the encryptor for olm
    [[MXCryptoAlgorithms sharedAlgorithms] registerEncryptorClass:MXOlmEncryption.class forAlgorithm:kMXCryptoOlmAlgorithm];
}


#pragma mark - MXEncrypting
- (instancetype)initWithCrypto:(MXCrypto *)theCrypto andRoom:(NSString *)theRoomId
{
    self = [super init];
    if (self)
    {
        crypto = theCrypto;
        roomId = theRoomId;
    }
    return self;
}

- (MXHTTPOperation*)encryptEventContent:(NSDictionary*)eventContent eventType:(MXEventTypeString)eventType
                               forUsers:(NSArray<NSString*>*)users
                                success:(void (^)(NSDictionary *encryptedContent))success
                                failure:(void (^)(NSError *error))failure
{
    MXWeakify(self);
    return [self ensureSessionForUsers:users success:^(NSObject *sessionInfo) {
        MXStrongifyAndReturnIfNil(self);

        NSMutableArray *participantDevices = [NSMutableArray array];

        for (NSString *userId in users)
        {
            NSArray<MXDeviceInfo *> *devices = [self->crypto.deviceList storedDevicesForUser:userId];
            for (MXDeviceInfo *device in devices)
            {
                if ([device.identityKey isEqualToString:self->crypto.olmDevice.deviceCurve25519Key])
                {
                    // Don't bother setting up session to ourself
                    continue;
                }

                if (device.trustLevel.localVerificationStatus == MXDeviceBlocked)
                {
                    // Don't bother setting up sessions with blocked users
                    continue;
                }

                [participantDevices addObject:device];
            }
        }

        NSDictionary *encryptedMessage = [self->crypto encryptMessage:@{
                                                                        @"room_id": self->roomId,
                                                                        @"type": eventType,
                                                                        @"content": eventContent
                                                                        }
                                                           forDevices:participantDevices];
        success(encryptedMessage);

    } failure:failure];
}

- (MXHTTPOperation*)ensureSessionForUsers:(NSArray<NSString*>*)users
                                  success:(void (^)(NSObject *sessionInfo))success
                                  failure:(void (^)(NSError *error))failure
{
    // TODO: Avoid to do this request for every message. Instead, manage a queue of messages waiting for encryption
    // XXX: This class is not used so fix it later
    MXWeakify(self);
    MXHTTPOperation *operation;
    operation = [crypto.deviceList downloadKeys:users forceDownload:NO success:^(MXUsersDevicesMap<MXDeviceInfo *> *usersDevicesInfoMap, NSDictionary<NSString *,MXCrossSigningInfo *> *crossSigningKeysMap) {

        MXStrongifyAndReturnIfNil(self);

        MXHTTPOperation *operation2 = [self->crypto ensureOlmSessionsForUsers:users success:^(MXUsersDevicesMap<MXOlmSessionResult *> *results) {
            success(nil);
        } failure:failure];

        [operation mutateTo:operation2];

    } failure:failure];

    return operation;
}

- (MXHTTPOperation*)reshareKey:(NSString*)sessionId
                      withUser:(NSString*)userId
                     andDevice:(NSString*)deviceId
                     senderKey:(NSString*)senderKey
                       success:(void (^)(void))success
                       failure:(void (^)(NSError *error))failure
{
    // No need for olm
    return nil;
}

@end

#endif
