/*
 Copyright 2016 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2020 The Matrix.org Foundation C.I.C

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

#import "MXMegolmDecryption.h"

#ifdef MX_CRYPTO

#import "MXCryptoAlgorithms.h"
#import "MXCrypto_Private.h"
#import "MXTools.h"

@interface MXMegolmDecryption ()
{
    // The crypto module
    MXCrypto *crypto;

    // The olm device interface
    MXOlmDevice *olmDevice;

    // Events which we couldn't decrypt due to unknown sessions / indexes: map from
    // senderKey|sessionId to timelines to list of MatrixEvents
    NSMutableDictionary<NSString* /* senderKey|sessionId */,
        NSMutableDictionary<NSString* /* timelineId */,
            NSMutableDictionary<NSString* /* eventId */, MXEvent*>*>*> *pendingEvents;
}
@end

@implementation MXMegolmDecryption

+ (void)load
{
    // Register this class as the decryptor for olm
    [[MXCryptoAlgorithms sharedAlgorithms] registerDecryptorClass:MXMegolmDecryption.class forAlgorithm:kMXCryptoMegolmAlgorithm];
}

#pragma mark - MXDecrypting
- (instancetype)initWithCrypto:(MXCrypto *)theCrypto
{
    self = [super init];
    if (self)
    {
        crypto = theCrypto;
        olmDevice = theCrypto.olmDevice;
        pendingEvents = [NSMutableDictionary dictionary];
    }
    return self;
}

- (MXEventDecryptionResult *)decryptEvent:(MXEvent*)event inTimeline:(NSString*)timeline error:(NSError** )error;
{
    MXEventDecryptionResult *result;
    NSString *senderKey, *ciphertext, *sessionId;

    MXJSONModelSetString(senderKey, event.content[@"sender_key"]);
    MXJSONModelSetString(ciphertext, event.content[@"ciphertext"]);
    MXJSONModelSetString(sessionId, event.content[@"session_id"]);

    if (!senderKey || !sessionId || !ciphertext)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:MXDecryptingErrorDomain
                                         code:MXDecryptingErrorMissingFieldsCode
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: MXDecryptingErrorMissingFieldsReason
                                                }];
        }
        return nil;
    }

    NSError *olmError;
    MXDecryptionResult *olmResult = [olmDevice decryptGroupMessage:ciphertext roomId:event.roomId inTimeline:timeline sessionId:sessionId senderKey:senderKey error:&olmError];

    if (olmResult)
    {
        result = [[MXEventDecryptionResult alloc] init];

        result.clearEvent = olmResult.payload;
        result.senderCurve25519Key = olmResult.senderKey;
        result.claimedEd25519Key = olmResult.keysClaimed[@"ed25519"];
        result.forwardingCurve25519KeyChain = olmResult.forwardingCurve25519KeyChain;
    }
    else
    {
        if ([olmError.domain isEqualToString:OLMErrorDomain])
        {
            // Manage OLMKit error
            if ([olmError.localizedDescription isEqualToString:@"UNKNOWN_MESSAGE_INDEX"])
            {
                // Do nothing more on the calling thread
                dispatch_async(crypto.cryptoQueue, ^{
                    [self addEventToPendingList:event inTimeline:timeline];
                });
            }

            // Package olm error into MXDecryptingErrorDomain
            olmError = [NSError errorWithDomain:MXDecryptingErrorDomain
                                           code:MXDecryptingErrorOlmCode
                                       userInfo:@{
                                                  NSLocalizedDescriptionKey: [NSString stringWithFormat:MXDecryptingErrorOlm, olmError.localizedDescription],
                                                  NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:MXDecryptingErrorOlmReason, ciphertext, olmError]
                                                  }];
        }
        else if ([olmError.domain isEqualToString:MXDecryptingErrorDomain] && olmError.code == MXDecryptingErrorUnknownInboundSessionIdCode)
        {
            // Do nothing more on the calling thread
            dispatch_async(crypto.cryptoQueue, ^{
                [self addEventToPendingList:event inTimeline:timeline];
            });
        }

        if (error)
        {
            *error = olmError;
        }
    }

    return result;
}

/**
 Add an event to the list of those we couldn't decrypt the first time we
 saw them.
 
 @param event the event to try to decrypt later.
 */
- (void)addEventToPendingList:(MXEvent*)event inTimeline:(NSString*)timelineId
{
    NSDictionary *content = event.wireContent;
    NSString *k = [NSString stringWithFormat:@"%@|%@", content[@"sender_key"], content[@"session_id"]];

    if (!timelineId)
    {
        timelineId = @"";
    }

    if (!pendingEvents[k])
    {
        pendingEvents[k] = [NSMutableDictionary dictionary];
    }

    if (!pendingEvents[k][timelineId])
    {
        pendingEvents[k][timelineId] = [NSMutableDictionary dictionary];
    }
    
    if (!pendingEvents[k][timelineId][event.eventId])
    {
        NSLog(@"[MXMegolmDecryption] addEventToPendingList: %@ in %@ for %@", event.eventId, event.roomId, k);
        pendingEvents[k][timelineId][event.eventId] = event;
        
        [self requestKeysForEvent:event];
    }
}

- (void)onRoomKeyEvent:(MXEvent *)event
{
    NSDictionary *content = event.content;
    NSString *roomId, *sessionId, *sessionKey;

    MXJSONModelSetString(roomId, content[@"room_id"]);
    MXJSONModelSetString(sessionId, content[@"session_id"]);
    MXJSONModelSetString(sessionKey, content[@"session_key"]);

    if (!roomId || !sessionId || !sessionKey)
    {
        NSLog(@"[MXMegolmDecryption] onRoomKeyEvent: ERROR: Key event is missing fields");
        return;
    }

    NSString *senderKey = event.senderKey;
    if (!senderKey)
    {
        NSLog(@"[MXMegolmDecryption] onRoomKeyEvent: ERROR: Key event has no sender key (not encrypted?)");
        return;
    }

    NSArray<NSString*> *forwardingKeyChain;
    BOOL exportFormat = NO;
    NSDictionary *keysClaimed;

    if (event.eventType == MXEventTypeRoomForwardedKey)
    {
        exportFormat = YES;

        MXJSONModelSetArray(forwardingKeyChain, content[@"forwarding_curve25519_key_chain"]);
        if (!forwardingKeyChain)
        {
            forwardingKeyChain = @[];
        }

        // copy content before we modify it
        NSMutableArray *forwardingKeyChain2 = [NSMutableArray arrayWithArray:forwardingKeyChain];
        [forwardingKeyChain2 addObject:senderKey];
        forwardingKeyChain = forwardingKeyChain2;

        MXJSONModelSetString(senderKey, content[@"sender_key"]);
        if (!senderKey)
        {
            NSLog(@"[MXMegolmDecryption] onRoomKeyEvent: ERROR: forwarded_room_key event is missing sender_key field");
            return;
        }

        NSString *ed25519Key;
        MXJSONModelSetString(ed25519Key, content[@"sender_claimed_ed25519_key"]);
        if (!ed25519Key)
        {
            NSLog(@"[MXMegolmDecryption] onRoomKeyEvent: ERROR: forwarded_room_key_event is missing sender_claimed_ed25519_key field");
            return;
        }

        keysClaimed = @{
                        @"ed25519": ed25519Key
                        };
    }
    else
    {
        keysClaimed = event.keysClaimed;
    }

    NSLog(@"[MXMegolmDecryption] onRoomKeyEvent: Adding key for megolm session %@|%@ from %@ event", senderKey, sessionId, event.type);

    [olmDevice addInboundGroupSession:sessionId sessionKey:sessionKey roomId:roomId senderKey:senderKey forwardingCurve25519KeyChain:forwardingKeyChain keysClaimed:keysClaimed exportFormat:exportFormat];

    [crypto.backup maybeSendKeyBackup];

    MXWeakify(self);
    [self retryDecryption:senderKey sessionId:content[@"session_id"] complete:^(BOOL allDecrypted) {
        MXStrongifyAndReturnIfNil(self);

        if (allDecrypted)
        {
            // cancel any outstanding room key requests for this session
            [self->crypto cancelRoomKeyRequest:@{
                                                 @"algorithm": content[@"algorithm"],
                                                 @"room_id": content[@"room_id"],
                                                 @"session_id": content[@"session_id"],
                                                 @"sender_key": senderKey
                                                 }];
        }
    }];
}

- (void)didImportRoomKey:(MXOlmInboundGroupSession *)session
{
    // Have another go at decrypting events sent with this session
    MXWeakify(self);
    [self retryDecryption:session.senderKey sessionId:session.session.sessionIdentifier complete:^(BOOL allDecrypted) {
        MXStrongifyAndReturnIfNil(self);

        if (allDecrypted)
        {
            // cancel any outstanding room key requests for this session
            [self->crypto cancelRoomKeyRequest:@{
                                                 @"algorithm": kMXCryptoMegolmAlgorithm,
                                                 @"room_id": session.roomId,
                                                 @"session_id": session.session.sessionIdentifier,
                                                 @"sender_key": session.senderKey
                                                 }];
        }
    }];
}

- (BOOL)hasKeysForKeyRequest:(MXIncomingRoomKeyRequest*)keyRequest
{
    NSDictionary *body = keyRequest.requestBody;

    NSString *roomId, *senderKey, *sessionId;
    MXJSONModelSetString(roomId, body[@"room_id"]);
    MXJSONModelSetString(senderKey, body[@"sender_key"]);
    MXJSONModelSetString(sessionId, body[@"session_id"]);

    if (roomId && senderKey && sessionId)
    {
        return [olmDevice hasInboundSessionKeys:roomId senderKey:senderKey sessionId:sessionId];
    }

    return NO;
}

- (MXHTTPOperation*)shareKeysWithDevice:(MXIncomingRoomKeyRequest*)keyRequest
                                success:(void (^)(void))success
                                failure:(void (^)(NSError *error))failure
{
    NSString *userId = keyRequest.userId;
    NSString *deviceId = keyRequest.deviceId;
    MXDeviceInfo *deviceInfo = [crypto.deviceList storedDevice:userId deviceId:deviceId];
    NSDictionary *body = keyRequest.requestBody;

    MXHTTPOperation *operation;
    MXWeakify(self);
    operation = [crypto ensureOlmSessionsForDevices:@{
                                          userId: @[deviceInfo]
                                          }
                                              force:NO
                                success:^(MXUsersDevicesMap<MXOlmSessionResult *> *results)
     {
         MXStrongifyAndReturnIfNil(self);

         MXOlmSessionResult *olmSessionResult = [results objectForDevice:deviceId forUser:userId];
         if (!olmSessionResult.sessionId)
         {
             // no session with this device, probably because there
             // were no one-time keys.
             //
             // ensureOlmSessionsForUsers has already done the logging,
             // so just skip it.
             if (success)
             {
                 success();
             }
             return;
         }

         NSString *roomId, *senderKey, *sessionId;
         MXJSONModelSetString(roomId, body[@"room_id"]);
         MXJSONModelSetString(senderKey, body[@"sender_key"]);
         MXJSONModelSetString(sessionId, body[@"session_id"]);

         NSLog(@"[MXMegolmDecryption] shareKeysWithDevice: sharing keys for session %@|%@ with device %@:%@", senderKey, sessionId, userId, deviceId);

         NSDictionary *payload = [self->crypto buildMegolmKeyForwardingMessage:roomId senderKey:senderKey sessionId:sessionId chainIndex:nil];

         MXDeviceInfo *deviceInfo = olmSessionResult.device;

         MXUsersDevicesMap<NSDictionary*> *contentMap = [[MXUsersDevicesMap alloc] init];
         [contentMap setObject:[self->crypto encryptMessage:payload forDevices:@[deviceInfo]]
                       forUser:userId andDevice:deviceId];

         MXHTTPOperation *operation2 = [self->crypto.matrixRestClient sendToDevice:kMXEventTypeStringRoomEncrypted contentMap:contentMap txnId:nil success:success failure:failure];
         [operation mutateTo:operation2];

     } failure:failure];

    return operation;
}

#pragma mark - Private methods

/**
 Have another go at decrypting events after we receive a key.

 @param senderKey the sender key.
 @param sessionId the session id.
 @param complete allDecrypted.
 */
- (void)retryDecryption:(NSString*)senderKey sessionId:(NSString*)sessionId complete:(void (^)(BOOL allDecrypted))complete;
{
    __block BOOL allDecrypted = YES;
    dispatch_group_t group = dispatch_group_create();

    NSString *k = [NSString stringWithFormat:@"%@|%@", senderKey, sessionId];
    NSDictionary<NSString*, NSDictionary<NSString*,MXEvent*>*> *pending = pendingEvents[k];
    if (pending)
    {
        // Have another go at decrypting events sent with this session.
        [pendingEvents removeObjectForKey:k];

        for (NSString *timelineId in pending)
        {
            for (MXEvent *event in pending[timelineId].allValues)
            {
                if (event.clearEvent)
                {
                    // This can happen when the event is in several timelines
                    NSLog(@"[MXMegolmDecryption] retryDecryption: %@ already decrypted", event.eventId);
                }
                else
                {
                    // Decrypt on the current thread (Must be MXCrypto.cryptoQueue)
                    NSError *error;
                    MXEventDecryptionResult *result = [self decryptEvent:event inTimeline:(timelineId.length ? timelineId : nil) error:&error];
                    
                    // And set the result on the main thread to be compatible with other modules
                    dispatch_group_enter(group);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (result)
                        {
                            if (event.clearEvent)
                            {
                                // This can happen when the event is in several timelines
                                NSLog(@"[MXMegolmDecryption] retryDecryption: %@ already decrypted on main thread", event.eventId);
                            }
                            else
                            {
                                [event setClearData:result];
                            }
                        }
                        else if (error)
                        {
                            NSLog(@"[MXMegolmDecryption] retryDecryption: Still can't decrypt %@. Error: %@", event.eventId, event.decryptionError);
                            event.decryptionError = error;
                            allDecrypted = NO;
                        }
                        
                        dispatch_group_leave(group);
                    });

                }
            }
        }
    }

    dispatch_group_notify(group, crypto.cryptoQueue, ^{
        complete(allDecrypted);
    });
}

- (void)requestKeysForEvent:(MXEvent*)event
{
    NSString *sender = event.sender;
    NSDictionary *wireContent = event.wireContent;

    NSString *myUserId = crypto.matrixRestClient.credentials.userId;

    // send the request to all of our own devices, and the
    // original sending device if it wasn't us.
    NSMutableArray<NSDictionary<NSString*, NSString*> *> *recipients = [NSMutableArray array];
    [recipients addObject:@{
                            @"userId": myUserId,
                            @"deviceId": @"*"
                            }];

    if (![sender isEqualToString:myUserId])
    {
        NSString *deviceId;
        MXJSONModelSetString(deviceId, wireContent[@"device_id"]);

        if (sender && deviceId)
        {
            [recipients addObject:@{
                                    @"userId": sender,
                                    @"deviceId": deviceId
                                    }];
        }
        else
        {
            NSLog(@"[MXMegolmDecryption] requestKeysForEvent: ERROR: missing fields for recipients in event %@", event);
        }
    }

    NSString *algorithm, *senderKey, *sessionId;
    MXJSONModelSetString(algorithm, wireContent[@"algorithm"]);
    MXJSONModelSetString(senderKey, wireContent[@"sender_key"]);
    MXJSONModelSetString(sessionId, wireContent[@"session_id"]);

    if (algorithm && senderKey && sessionId)
    {
        [crypto requestRoomKey:@{
                                 @"room_id": event.roomId,
                                 @"algorithm": algorithm,
                                 @"sender_key": senderKey,
                                 @"session_id": sessionId
                                 }
                    recipients:recipients];
    }
    else
    {
        NSLog(@"[MXMegolmDecryption] requestKeysForEvent: ERROR: missing fields in event %@", event);
    }
}

@end

#endif
