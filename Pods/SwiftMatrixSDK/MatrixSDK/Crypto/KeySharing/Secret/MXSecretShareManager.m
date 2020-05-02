/*
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

#import "MXSecretShareManager_Private.h"

#import "MXCrypto_Private.h"
#import "MXSecretShareRequest.h"
#import "MXPendingSecretShareRequest.h"
#import "MXSecretShareSend.h"
#import "MXTools.h"


#pragma mark - Constants

const struct MXSecretId MXSecretId = {
    .crossSigningMaster = @"m.cross_signing.master",
    .crossSigningSelfSigning = @"m.cross_signing.self_signing",
    .crossSigningUserSigning = @"m.cross_signing.user_signing",
    .keyBackup = @"m.megolm_backup.v1"
};


static NSArray<MXEventTypeString> *kMXSecretShareEventTypes;


@interface MXSecretShareManager ()
{
    NSMutableDictionary<NSString*, MXPendingSecretShareRequest*> *pendingSecretShareRequests;
    NSMutableArray<NSString*> *cancelledRequestIds;
}

@property (nonatomic, readonly, weak) MXCrypto *crypto;

@end


@implementation MXSecretShareManager

- (MXHTTPOperation *)requestSecret:(NSString*)secretId
                       toDeviceIds:(nullable NSArray<NSString*>*)deviceIds
                           success:(void (^)(NSString *requestId))success
                  onSecretReceived:(void (^)(NSString *secret))onSecretReceived
                           failure:(void (^)(NSError *error))failure
{
    NSLog(@"[MXSecretShareManager] requestSecret: %@ to %@", secretId, deviceIds);
    
    // Create an empty operation that will be mutated later
    MXHTTPOperation *operation = [[MXHTTPOperation alloc] init];
    
    MXWeakify(self);
    dispatch_async(_crypto.cryptoQueue, ^{
        MXStrongifyAndReturnIfNil(self);
        
        MXCredentials *myUser = self.crypto.mxSession.matrixRestClient.credentials;
        
        MXSecretShareRequest *request = [MXSecretShareRequest new];
        request.name = secretId;
        request.action = MXSecretShareRequestAction.request;
        request.requestingDeviceId = myUser.deviceId;
        request.requestId = [MXTools generateTransactionId];
        
        MXPendingSecretShareRequest *pendingRequest = [MXPendingSecretShareRequest new];
        pendingRequest.request = request;
        pendingRequest.onSecretReceivedBlock = onSecretReceived;
        pendingRequest.requestedDeviceIds = deviceIds;
        
        self->pendingSecretShareRequests[request.requestId] = pendingRequest;
        
        MXWeakify(self);
        MXHTTPOperation *operation2 = [self sendMessage:request.JSONDictionary toDeviceIds:deviceIds success:^{
            
            dispatch_async(dispatch_get_main_queue(), ^{
                success(request.requestId);
            });
            
        } failure:^(NSError *error) {
            MXStrongifyAndReturnIfNil(self);
            
            [self->pendingSecretShareRequests removeObjectForKey:request.requestId];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(error);
            });
        }];
        
        [operation mutateTo:operation2];
    });
    
    return operation;
}

- (MXHTTPOperation *)cancelRequestWithRequestId:(NSString*)requestId
                                        success:(void (^)(void))success
                                        failure:(void (^)(NSError *error))failure
{
    NSLog(@"[MXSecretShareManager] cancelRequestWithRequestId: %@", requestId);
    
    // Create an empty operation that will be mutated later
    MXHTTPOperation *operation = [[MXHTTPOperation alloc] init];
    
    MXWeakify(self);
    dispatch_async(_crypto.cryptoQueue, ^{
        MXStrongifyAndReturnIfNil(self);
        
        MXPendingSecretShareRequest *pendingRequest = self->pendingSecretShareRequests[requestId];
        if (!pendingRequest)
        {
            NSLog(@"[MXSecretShareManager] cancelRequestWithRequestId: Unknown request: %@", requestId);
            failure(nil);
        }
        
        [self->pendingSecretShareRequests removeObjectForKey:requestId];
        
        MXCredentials *myUser = self.crypto.mxSession.matrixRestClient.credentials;
        
        MXSecretShareRequest *request = [MXSecretShareRequest new];
        request.action = MXSecretShareRequestAction.requestCancellation;
        request.requestingDeviceId = myUser.deviceId;
        request.requestId = requestId;
        
        MXHTTPOperation *operation2 = [self sendMessage:request.JSONDictionary toDeviceIds:pendingRequest.requestedDeviceIds success:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                success();
            });
            
        } failure:^(NSError *error) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(error);
            });
        }];
        
        [operation mutateTo:operation2];
    });
    
    return operation;
}


#pragma mark - SDK-Private methods -

+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kMXSecretShareEventTypes = @[
                                     kMXEventTypeStringSecretRequest,
                                     kMXEventTypeStringSecretSend
                                     ];
    });
}

- (instancetype)initWithCrypto:(MXCrypto *)crypto;
{
    self = [super init];
    if (self)
    {
        _crypto = crypto;
        pendingSecretShareRequests = [NSMutableDictionary dictionary];
        cancelledRequestIds = [NSMutableArray array];
        
        // Observe incoming secret share requests
        [self setupIncomingRequests];
    }
    return self;
}


#pragma mark - Private methods -

- (MXHTTPOperation*)sendMessage:(NSDictionary*)message
                    toDeviceIds:(nullable NSArray<NSString*>*)deviceIds
                        success:(void (^)(void))success
                        failure:(void (^)(NSError *error))failure
{
    MXCredentials *myUser = _crypto.mxSession.matrixRestClient.credentials;
    
    MXUsersDevicesMap<NSDictionary*> *contentMap = [[MXUsersDevicesMap alloc] init];
    if (deviceIds)
    {
        for (NSString *deviceId in deviceIds)
        {
            [contentMap setObject:message forUser:myUser.userId andDevice:deviceId];
        }
    }
    else
    {
        [contentMap setObject:message forUser:myUser.userId andDevice:@"*"];
    }
    
    return [_crypto.matrixRestClient sendToDevice:kMXEventTypeStringSecretRequest contentMap:contentMap txnId:nil success:success failure:failure];
}

- (BOOL)isSecretShareEvent:(MXEventTypeString)type
{
    return [kMXSecretShareEventTypes containsObject:type];
}

- (void)setupIncomingRequests
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onToDeviceEvent:) name:kMXSessionOnToDeviceEventNotification object:_crypto.mxSession];
}

- (void)onToDeviceEvent:(NSNotification *)notification
{
    MXEvent *event = notification.userInfo[kMXSessionNotificationEventKey];

    if ([self isSecretShareEvent:event.type])
    {
        [self handleSecretShareEvent:event];
    }
}

- (void)handleSecretShareEvent:(MXEvent*)event
{
    NSLog(@"[MXSecretShareManager] handleSecretShareEvent: eventType: %@", event.type);
    
    dispatch_async(_crypto.cryptoQueue, ^{
        switch (event.eventType)
        {
            case MXEventTypeSecretRequest:
                [self handleSecretRequestEvent:event];
                break;
                
            case MXEventTypeSecretSend:
                [self handleSecretSendEvent:event];
                break;
                
            default:
                break;
        }
    });
}

- (void)handleSecretRequestEvent:(MXEvent*)event
{
    MXCredentials *myUser = _crypto.mxSession.matrixRestClient.credentials;
    
    if (![event.sender isEqualToString:myUser.userId])
    {
        return;
    }
    
    MXSecretShareRequest *request;
    MXJSONModelSetMXJSONModel(request, MXSecretShareRequest, event.content);
    if (!request)
    {
        NSLog(@"[MXSecretShareManager] handleSecretRequestEvent: Bad content format: %@", event.JSONDictionary);
        return;
    }
    
    if ([request.requestingDeviceId isEqualToString:myUser.deviceId])
    {
        // Ignore own requests
        return;
    }
    
    if ([request.action isEqualToString:MXSecretShareRequestAction.request])
    {
        [self handleSecretRequest:request];
    }
    else if ([request.action isEqualToString:MXSecretShareRequestAction.requestCancellation])
    {
        [self handleSecretRequestCancellation:request];
    }
    else
    {
        NSLog(@"[MXSecretShareManager] handleSecretRequestEvent. Unsupported action: %@. Event: %@", request.action, event.JSONDictionary);
    }
}

- (void)handleSecretRequest:(MXSecretShareRequest*)request
{
    // Handle secret requests only when the sync has been done.
    // This allows to manage cancellations events for that requests
    if (self.crypto.mxSession.state == MXSessionStateSyncInProgress
        || self.crypto.mxSession.state == MXSessionStateBackgroundSyncInProgress)
    {
        // TODO: Be more accurate to detect the first sync is done
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), self.crypto.cryptoQueue, ^{
            [self handleSecretRequest:request];
        });
        return;
    }
    
    [self handleSecretRequest2:request];
}

- (void)handleSecretRequest2:(MXSecretShareRequest*)request
{
    if ([cancelledRequestIds containsObject:request.requestId])
    {
        NSLog(@"[MXSecretShareManager] handleSecretRequestEvent: Ignored cancelled request: %@", request.requestId);
        [cancelledRequestIds removeObject:request.requestId];
        return;
    }
    
    MXCredentials *myUser = _crypto.mxSession.matrixRestClient.credentials;
    
    MXDeviceInfo *otherDevice = [_crypto.store deviceWithDeviceId:request.requestingDeviceId forUser:myUser.userId];
    if (!otherDevice.trustLevel.isVerified)
    {
        NSLog(@"[MXSecretShareManager] handleSecretRequestEvent: Ignore secret share request from untrusted device: %@", otherDevice);
        return;
    }
    
    // TODO: Add a timeout constraint
    // Share the secret only if the verification occurred less than 5min ago
    // https://github.com/vector-im/riot-ios/issues/3023
    
    NSString *secret = [_crypto.store secretWithSecretId:request.name];
    if (!secret)
    {
        NSLog(@"[MXSecretShareManager] handleSecretRequestEvent: Unknown secret id: %@", request.name);
        return;
    }
    
    [self shareSecret:secret toRequest:request];
}

- (void)handleSecretRequestCancellation:(MXSecretShareRequest*)request
{
    NSLog(@"[MXSecretShareManager] handleSecretRequestCancellation: %@ from device %@", request.name, request.requestingDeviceId);
    
    // Store cancelled requests
    // Those requests will be ignored at the end of the sync processing
    if (self.crypto.mxSession.state == MXSessionStateSyncInProgress
        || self.crypto.mxSession.state == MXSessionStateBackgroundSyncInProgress)
    {
        [cancelledRequestIds addObject:request.requestId];
    }
}

- (void)shareSecret:(NSString*)secret toRequest:(MXSecretShareRequest*)request
{
    NSLog(@"[MXSecretShareManager] shareSecret: %@ to device %@", request.name, request.requestingDeviceId);
    
    MXCredentials *myUser = _crypto.mxSession.matrixRestClient.credentials;
    
    MXDeviceInfo *device = [_crypto.store deviceWithDeviceId:request.requestingDeviceId forUser:myUser.userId];
    if (!device)
    {
        NSLog(@"[MXSecretShareManager] shareSecret: ERROR: Unknown device: %@", request.requestingDeviceId);
        return;
    }
    
    NSDictionary *userDevice = @{
                                 myUser.userId: @[device]
                                 };
   
    [_crypto ensureOlmSessionsForDevices:userDevice force:NO success:^(MXUsersDevicesMap<MXOlmSessionResult *> *results) {
        
        // Build the response
        MXSecretShareSend *shareSend = [MXSecretShareSend new];
        shareSend.requestId = request.requestId;
        shareSend.secret = secret;
        
        NSDictionary *message = @{
                                  @"type": kMXEventTypeStringSecretSend,
                                  @"content": shareSend.JSONDictionary
                                  };
        
        // Encrypt it
        NSDictionary *encryptedContent = [self.crypto encryptMessage:message
                                                          forDevices:@[device]];
        
        // Send it encrypted as an m.room.encrypted to-device event.
        MXUsersDevicesMap<NSDictionary*> *contentMap = [MXUsersDevicesMap new];
        [contentMap setObject:encryptedContent forUser:myUser.userId andDevice:device.deviceId];
        
        [self.crypto.matrixRestClient sendToDevice:kMXEventTypeStringRoomEncrypted contentMap:contentMap txnId:nil success:nil failure:^(NSError *error) {
            NSLog(@"[MXSecretShareManager] shareSecret: ERROR for sendToDevice: %@", error);
        }];
        
    } failure:^(NSError *error) {
        NSLog(@"[MXSecretShareManager] shareSecret: ERROR for ensureOlmSessionsForDevices: %@", error);
    }];
}


- (void)handleSecretSendEvent:(MXEvent*)event
{
    MXSecretShareSend *shareSend;
    MXJSONModelSetMXJSONModel(shareSend, MXSecretShareSend, event.content);
    if (!shareSend)
    {
        NSLog(@"[MXSecretShareManager] handleSecretSendEvent: Bad content format: %@", event.JSONDictionary);
        return;
    }
    
    MXPendingSecretShareRequest *pendingRequest = pendingSecretShareRequests[shareSend.requestId];
    if (!pendingRequest)
    {
        NSLog(@"[MXSecretShareManager] handleSecretSendEvent: Unexpected response to request: %@", shareSend.requestId);
        return;
    }
    
    pendingRequest.onSecretReceivedBlock(shareSend.secret);
    
    [self cancelRequestWithRequestId:shareSend.requestId success:^{} failure:^(NSError * _Nonnull error) {}];
}

@end
