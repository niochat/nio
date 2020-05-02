/*
 Copyright 2017 OpenMarket Ltd

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

#import "MXOutgoingRoomKeyRequestManager.h"

#import "MXTools.h"
#import "MXOutgoingRoomKeyRequest.h"

#ifdef MX_CRYPTO

// delay between deciding we want some keys, and sending out the request, to
// allow for (a) it turning up anyway, (b) grouping requests together
NSUInteger const SEND_KEY_REQUESTS_DELAY_MS = 500;


@interface MXOutgoingRoomKeyRequestManager ()
{
    MXRestClient *matrixRestClient;
    NSString *deviceId;
    dispatch_queue_t cryptoQueue;
    id<MXCryptoStore> cryptoStore;

    // handle for the delayed call to sendOutgoingRoomKeyRequests. Non-null
    // if the callback has been set, or if it is still running.
    NSTimer *sendOutgoingRoomKeyRequestsTimer;
}

@property (nonatomic, assign, getter = isEnabled) BOOL enabled;

@end

@implementation MXOutgoingRoomKeyRequestManager

- (id)initWithMatrixRestClient:(MXRestClient*)mxRestClient
                      deviceId:(NSString*)theDeviceId
                   cryptoQueue:(dispatch_queue_t)theCryptoQueue
                   cryptoStore:(id<MXCryptoStore>)theCryptoStore
{
    self = [super init];
    if (self)
    {
        matrixRestClient = mxRestClient;
        deviceId = theDeviceId;
        cryptoQueue = theCryptoQueue;
        cryptoStore = theCryptoStore;
        _enabled = YES;
    }
    return self;
}

- (void)start
{
    // set the timer going, to handle any requests which didn't get sent
    // on the previous run of the client.
    [self startTimer];
}

- (void)close
{
    // Close is planned to be called from the main thread
    NSParameterAssert([NSThread isMainThread]);

    [sendOutgoingRoomKeyRequestsTimer invalidate];
    sendOutgoingRoomKeyRequestsTimer = nil;
}

- (void)setEnabled:(BOOL)enabled
{
    NSLog(@"[MXOutgoingRoomKeyRequestManager] setEnabled: %@ (old: %@)", @(enabled), @(_enabled));
    if (enabled == _enabled)
    {
        return;
    }
    
    if (enabled)
    {
        // Check keys we got while this manager was disabled
        [self checkAllPendingOutgoingRoomKeyRequests];
    }
    
    _enabled = enabled;
    [self startTimer];
}


- (void)sendRoomKeyRequest:(NSDictionary *)requestBody recipients:(NSArray<NSDictionary<NSString *,NSString *> *> *)recipients
{
    MXOutgoingRoomKeyRequest *request = [self getOrAddOutgoingRoomKeyRequest:requestBody recipients:recipients];

    if (request.state == MXRoomKeyRequestStateUnsent)
    {
        [self startTimer];
    }
}

- (void)cancelRoomKeyRequest:(NSDictionary *)requestBody
{
    [self cancelRoomKeyRequest:requestBody andResend:NO];
}

- (void)resendRoomKeyRequest:(NSDictionary *)requestBody
{
    [self cancelRoomKeyRequest:requestBody andResend:YES];
}

- (void)cancelRoomKeyRequest:(NSDictionary *)requestBody andResend:(BOOL)resend
{
    MXOutgoingRoomKeyRequest *request = [cryptoStore outgoingRoomKeyRequestWithRequestBody:requestBody];

    if (!request)
    {
        // no request was made for this key
        return;
    }

    NSLog(@"[MXOutgoingRoomKeyRequestManager] cancelRoomKeyRequest:andResend:%@: request.requestId: %@. state: %@", @(resend), request.requestId,  @(request.state));

    switch (request.state)
    {
        case MXRoomKeyRequestStateCancellationPending:
        case MXRoomKeyRequestStateCancellationPendingAndWillResend:
            // nothing to do here
            break;

        case MXRoomKeyRequestStateUnsent:
            // just delete it

            // FIXME: ghahah we may have attempted to send it, and
            // not yet got a successful response. So the server
            // may have seen it, so we still need to send a cancellation
            // in that case :/

            NSLog(@"[MXOutgoingRoomKeyRequestManager] cancelRoomKeyRequest: deleting unnecessary room key request %@", request.requestId);

            [cryptoStore deleteOutgoingRoomKeyRequestWithRequestId:request.requestId];
            break;

        case MXRoomKeyRequestStateSent:
            // send a cancellation.
            request.state = resend ? MXRoomKeyRequestStateCancellationPendingAndWillResend : MXRoomKeyRequestStateCancellationPending;

            request.cancellationTxnId = [MXTools generateTransactionId];

            [cryptoStore updateOutgoingRoomKeyRequest:request];

            // We don't want to wait for the timer, so we send it
            // immediately. (We might actually end up racing with the timer,
            // but that's ok: even if we make the request twice, we'll do it
            // with the same transaction_id, so only one message will get
            // sent).
            //
            // (We also don't want to wait for the response from the server
            // here, as it will slow down processing of received keys if we
            // do.)
            MXWeakify(self);
            [self sendOutgoingRoomKeyRequestCancellation:request andResend:resend success:nil failure:^(NSError *error) {
                MXStrongifyAndReturnIfNil(self);

                NSLog(@"[MXOutgoingRoomKeyRequestManager] cancelRoomKeyRequest: Error sending room key request cancellation; will retry later.");

                [self startTimer];
            }];
    }
}

#pragma mark - Private methods

- (void)startTimer
{
    // Must be called on the crypto thread
    // So, move on the main thread to create NSTimer
    MXWeakify(self);
    dispatch_async(dispatch_get_main_queue(), ^{
        MXStrongifyAndReturnIfNil(self);
        
        if (self->sendOutgoingRoomKeyRequestsTimer)
        {
            return;
        }

        // Start timer
        self->sendOutgoingRoomKeyRequestsTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:SEND_KEY_REQUESTS_DELAY_MS / 1000.0]
                                                                          interval:0
                                                                            target:self
                                                                          selector:@selector(sendOutgoingRoomKeyRequests)
                                                                          userInfo:nil
                                                                           repeats:NO];
        [[NSRunLoop mainRunLoop] addTimer:self->sendOutgoingRoomKeyRequestsTimer forMode:NSDefaultRunLoopMode];
    });
}

- (void)checkAllPendingOutgoingRoomKeyRequests
{
    NSArray<MXOutgoingRoomKeyRequest*> *requests = [self->cryptoStore allOutgoingRoomKeyRequestsWithState:MXRoomKeyRequestStateUnsent];
        
    NSUInteger deleted = 0;
    for (MXOutgoingRoomKeyRequest *request in requests)
    {
        // Check if we have now a valid key
        MXOlmInboundGroupSession *inboundGroupSession = [cryptoStore inboundGroupSessionWithId:request.sessionId andSenderKey:request.senderKey];
        if ([inboundGroupSession.roomId isEqualToString:request.roomId])
        {
            [cryptoStore deleteOutgoingRoomKeyRequestWithRequestId:request.requestId];
            deleted++;
        }
    }
    
    NSLog(@"[MXOutgoingRoomKeyRequestManager] checkAllPendingOutgoingRoomKeyRequests: Cleared %@ requests out of %@", @(deleted), @(requests.count));
}

- (void)sendOutgoingRoomKeyRequests
{
    [sendOutgoingRoomKeyRequestsTimer invalidate];
    sendOutgoingRoomKeyRequestsTimer = nil;
    
    // Do not start
    if (!self.isEnabled)
    {
        NSLog(@"[MXOutgoingRoomKeyRequestManager] startSendingOutgoingRoomKeyRequests: Disabled.");
        return;
    }
    
    NSLog(@"[MXOutgoingRoomKeyRequestManager] startSendingOutgoingRoomKeyRequests: Looking for queued outgoing room key requests.");

    // This method is called on the [NSRunLoop mainRunLoop]. Go to the crypto thread
    MXWeakify(self);
    dispatch_async(cryptoQueue, ^{
        MXStrongifyAndReturnIfNil(self);

        MXOutgoingRoomKeyRequest* request = [self->cryptoStore outgoingRoomKeyRequestWithState:MXRoomKeyRequestStateCancellationPending];
        if (!request)
        {
            request = [self->cryptoStore outgoingRoomKeyRequestWithState:MXRoomKeyRequestStateUnsent];
        }

        if (!request)
        {
            NSLog(@"[MXOutgoingRoomKeyRequestManager] startSendingOutgoingRoomKeyRequests: No more outgoing room key requests");
            return;
        }

        MXWeakify(self);
        void(^onSuccess)(void) = ^(void) {
            MXStrongifyAndReturnIfNil(self);

            // go around the loop again
            [self sendOutgoingRoomKeyRequests];
        };

        void(^onFailure)(NSError *) = ^(NSError *error) {
            MXStrongifyAndReturnIfNil(self);

            [self startTimer];
        };

        switch (request.state)
        {
            case MXRoomKeyRequestStateUnsent:
                [self sendOutgoingRoomKeyRequest:request success:onSuccess failure:onFailure];
                break;

            case MXRoomKeyRequestStateCancellationPending:
                [self sendOutgoingRoomKeyRequestCancellation:request andResend:NO success:onSuccess failure:onFailure];
                break;

            case MXRoomKeyRequestStateCancellationPendingAndWillResend:
                [self sendOutgoingRoomKeyRequestCancellation:request andResend:YES success:onSuccess failure:onFailure];
                break;

            default:
                break;
        }
    });
}

// given a RoomKeyRequest, send it and update the request record
- (void)sendOutgoingRoomKeyRequest:(MXOutgoingRoomKeyRequest*)request
                           success:(void (^)(void))success
                           failure:(void (^)(NSError *error))failure
{
    NSLog(@"[MXOutgoingRoomKeyRequestManager] sendOutgoingRoomKeyRequest: Requesting key %@ using request id %@ to %@: %@", request.sessionId, request.requestId, request.recipients, request.requestBody);

    NSDictionary *requestMessage = @{
                                     @"action": @"request",
                                     @"requesting_device_id": deviceId,
                                     @"request_id": request.requestId,
                                     @"body": request.requestBody
                                     };

    MXWeakify(self);
    [self sendMessageToDevices:requestMessage recipients:request.recipients txnId:request.requestId success:^{
        MXStrongifyAndReturnIfNil(self);

        request.state = MXRoomKeyRequestStateSent;
        [self->cryptoStore updateOutgoingRoomKeyRequest:request];

        success();

    } failure:failure];
}

// Given a RoomKeyRequest, cancel it and delete the request record.
// If resend is set, send a new request.
- (void)sendOutgoingRoomKeyRequestCancellation:(MXOutgoingRoomKeyRequest*)request
                                     andResend:(BOOL)resend
                                       success:(void (^)(void))success
                                       failure:(void (^)(NSError *error))failure
{
    NSLog(@"[MXOutgoingRoomKeyRequestManager] sendOutgoingRoomKeyRequestCancellation: Sending cancellation for key request (request id %@) for key %@ (cancellation id %@)", request.requestId, request.sessionId, request.cancellationTxnId);

    NSDictionary *requestMessage = @{
                                     @"action": @"request_cancellation",
                                     @"requesting_device_id": deviceId,
                                     @"request_id": request.requestId
                                     };

    MXWeakify(self);
    [self sendMessageToDevices:requestMessage recipients:request.recipients txnId:request.cancellationTxnId success:^{
        MXStrongifyAndReturnIfNil(self);

        [self->cryptoStore deleteOutgoingRoomKeyRequestWithRequestId:request.requestId];

        if (resend)
        {
            // Resend by creating a request (with new requestId)
            [self sendRoomKeyRequest:request.requestBody recipients:request.recipients];
        }

        if (success)
        {
            success();
        }

    } failure:failure];
}

- (void)sendMessageToDevices:(NSDictionary*)message
                  recipients:(NSArray<NSDictionary<NSString *,NSString *> *> *)recipients
                       txnId:(NSString*)txnId
                     success:(void (^)(void))success
                     failure:(void (^)(NSError *error))failure
{
    MXUsersDevicesMap<NSDictionary*> *contentMap = [[MXUsersDevicesMap alloc] init];
    for (NSDictionary<NSString *,NSString *> *recipient in recipients)
    {
        [contentMap setObject:message forUser:recipient[@"userId"] andDevice:recipient[@"deviceId"]];
    }

    [matrixRestClient sendToDevice:kMXEventTypeStringRoomKeyRequest contentMap:contentMap txnId:txnId success:success failure:failure];
}

/**
 Look for an existing outgoing room key request, and if none is found,
 add a new one

 @param requestBody the body of the request.
 @param recipients the recipients.
 @returns the existing outgoing room key request or a new one.
 */
- (MXOutgoingRoomKeyRequest*)getOrAddOutgoingRoomKeyRequest:(NSDictionary *)requestBody
                                                 recipients:(NSArray<NSDictionary<NSString *,NSString *> *> *)recipients
{
    // first see if we already have an entry for this request.
    MXOutgoingRoomKeyRequest *outgoingRoomKeyRequest = [cryptoStore outgoingRoomKeyRequestWithRequestBody:requestBody];
    if (outgoingRoomKeyRequest)
    {
        // this entry matches the request - return it.
        NSLog(@"[MXOutgoingRoomKeyRequestManager] getOrAddOutgoingRoomKeyRequest: already have key request outstanding for %@ / %@: not sending another", requestBody[@"room_id"], requestBody[@"session_id"]);
        return outgoingRoomKeyRequest;
    }

    // we got to the end of the list without finding a match
    // - add the new request.
    NSLog(@"[MXOutgoingRoomKeyRequestManager] getOrAddOutgoingRoomKeyRequest: enqueueing key request for %@ / %@", requestBody[@"room_id"], requestBody[@"session_id"]);

    outgoingRoomKeyRequest = [[MXOutgoingRoomKeyRequest alloc] init];
    outgoingRoomKeyRequest.requestBody = requestBody;
    outgoingRoomKeyRequest.recipients = recipients;
    outgoingRoomKeyRequest.requestId = [MXTools generateTransactionId];
    outgoingRoomKeyRequest.state = MXRoomKeyRequestStateUnsent;

    [cryptoStore storeOutgoingRoomKeyRequest:outgoingRoomKeyRequest];

    return outgoingRoomKeyRequest;
}

@end

#endif
