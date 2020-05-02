/*
 Copyright 2019 The Matrix.org Foundation C.I.C

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

#import "MXKeyVerificationStatusResolver.h"

#import "MXSession.h"
#import "MXKeyVerificationByDMRequest.h"
#import "MXKeyVerificationRequest_Private.h"
#import "MXKeyVerification.h"
#import "MXKeyVerificationManager_Private.h"

#import "MXKeyVerificationCancel.h"

#import "MXQRCodeTransaction.h"
#import "MXSASTransaction.h"

@interface MXKeyVerificationStatusResolver ()
@property (nonatomic, weak) MXKeyVerificationManager *manager;
@property (nonatomic) MXSession *mxSession;
@end


@implementation MXKeyVerificationStatusResolver

#pragma mark - Setup

- (instancetype)initWithManager:(MXKeyVerificationManager*)manager matrixSession:(MXSession*)matrixSession;

{
    self = [super init];
    if (self)
    {
        self.manager = manager;
        self.mxSession = matrixSession;
    }
    return self;
}

#pragma mark - Public

- (nullable MXHTTPOperation *)keyVerificationWithKeyVerificationId:(NSString*)keyVerificationId
                                                             event:(MXEvent*)event
                                                         transport:(MXKeyVerificationTransport)transport
                                                           success:(void(^)(MXKeyVerification *keyVerification))success
                                                           failure:(void(^)(NSError *error))failure
{
    MXHTTPOperation *operation;
    switch (transport)
    {
        case MXKeyVerificationTransportDirectMessage:
        {
            operation = [self eventsInVerificationByDMThreadFromOriginalEventId:keyVerificationId inRoom:event.roomId success:^(MXEvent *originalEvent, NSArray<MXEvent*> *events) {

                if (!originalEvent)
                {
                    originalEvent = event;
                }

                MXKeyVerification *keyVerification = [self makeKeyVerificationFromOriginalDMEvent:originalEvent events:events];
                if (keyVerification)
                {
                    success(keyVerification);
                }
                else
                {
                    NSError *error = [NSError errorWithDomain:MXKeyVerificationErrorDomain
                                                         code:MXKeyVerificationUnknownIdentifier
                                                     userInfo:@{
                                                                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unknown id"]
                                                                }];
                    failure(error);
                }

            } failure:failure];
            break;
        }

        default:
            // Requests by to_device are not supported
            // TODO: Can we really do something? This is all by DM here
            NSParameterAssert(NO);
            break;
    }

    return operation;
}

- (nullable MXKeyVerification*)keyVerificationFromRequest:(nullable MXKeyVerificationRequest*)request andTransaction:(nullable MXKeyVerificationTransaction*)transaction
{
    if (!request && !transaction)
    {
        return nil;
    }
    
    MXKeyVerification *keyVerification = [MXKeyVerification new];
    
    MXKeyVerificationState state = [self stateFromRequest:request andTransaction:transaction];
    
    if (transaction && state >= MXKeyVerificationStateTransactionStarted)
    {
        keyVerification.transaction = transaction;
    }
    else
    {
        keyVerification.request = request;
    }
    
    keyVerification.state = state;
    
    return keyVerification;
}

#pragma mark - Private

- (nullable MXHTTPOperation *)eventsInVerificationByDMThreadFromOriginalEventId:(NSString*)originalEventId
                                                                         inRoom:(NSString*)roomId
                                                                        success:(void(^)(MXEvent *originalEvent, NSArray<MXEvent*> *events))success
                                                                        failure:(void(^)(NSError *error))failure
{
    // Get all related events
    return [self.mxSession.aggregations referenceEventsForEvent:originalEventId inRoom:roomId from:nil limit:-1 success:^(MXAggregationPaginatedResponse * _Nonnull paginatedResponse) {
        success(paginatedResponse.originalEvent, paginatedResponse.chunk);
    } failure:failure];
}

- (nullable MXKeyVerification *)makeKeyVerificationFromOriginalDMEvent:(nullable MXEvent*)originalEvent events:(NSArray<MXEvent*> *)events
{
    MXKeyVerification *keyVerification;

    MXKeyVerificationRequest *request = [self verificationRequestInDMEvent:originalEvent events:events];

    if (request)
    {
        keyVerification = [MXKeyVerification new];
        keyVerification.request = request;

        keyVerification.state = [self stateFromRequestState:request.state andEvents:events];
    }

    return keyVerification;
}

- (nullable MXKeyVerificationByDMRequest*)verificationRequestInDMEvent:(MXEvent*)event events:(NSArray<MXEvent*> *)events
{
    MXKeyVerificationByDMRequest *request;
    if (![event.content[@"msgtype"] isEqualToString:kMXMessageTypeKeyVerificationRequest])
    {
        return nil;
    }
    
    request = [[MXKeyVerificationByDMRequest alloc] initWithEvent:event andManager:self.manager];
    
    if (!request)
    {
        return nil;
    }
    
    MXKeyVerificationRequestState requestState = MXKeyVerificationRequestStatePending;
    NSString *myUserId = self.mxSession.myUserId;
    
    MXEvent *firstEvent = events.firstObject;
    if (firstEvent.eventType == MXEventTypeKeyVerificationCancel)
    {
        // If the first event is a cancel, the request has been cancelled
        // by me or declined by the other
        if ([firstEvent.sender isEqualToString:myUserId])
        {
            requestState = MXKeyVerificationRequestStateCancelledByMe;
        }
        else
        {
            requestState = MXKeyVerificationRequestStateCancelled;
        }
    }
    else if (events.count)
    {
        // If there are events but no cancel event at first, the transaction
        // has started = the request has been accepted
        for (MXEvent *event in events)
        {
            // In case the other sent a ready event, store its content
            if (event.eventType == MXEventTypeKeyVerificationReady)
            {
                // Avoid to overwrite requestState if value was set to MXKeyVerificationRequestStateAccepted
                if (requestState != MXKeyVerificationRequestStateAccepted)
                {
                    requestState = MXKeyVerificationRequestStateReady;
                }
                
                MXKeyVerificationReady *keyVerificationReady;
                MXJSONModelSetMXJSONModel(keyVerificationReady, MXKeyVerificationReady, event.content);
                request.acceptedData = keyVerificationReady;
            }
            // For SAS or QR code if I sent MXEventTypeKeyVerificationStart I have accepted the request.
            else if (event.eventType == MXEventTypeKeyVerificationStart)
            {
                requestState = MXKeyVerificationRequestStateAccepted;
            }
        }
    }
    // There is only the request event. What is the status of it?
    else if (![self.manager isRequestStillValid:request])
    {
        requestState = MXKeyVerificationRequestStateExpired;
    }
    else
    {
        requestState = MXKeyVerificationRequestStatePending;
    }
    
    [request updateState:requestState notifiy:NO];

    return request;
}


- (MXKeyVerificationState)stateFromRequestState:(MXKeyVerificationRequestState)requestState andEvents:(NSArray<MXEvent*> *)events
{
    MXKeyVerificationState state;
    
    if (requestState == MXKeyVerificationRequestStateAccepted)
    {
        state = [self computeTranscationStateWithEvents:events];
    }
    else
    {
        state = [self stateFromRequestState:requestState];
    }

    return state;
}

- (MXKeyVerificationState)computeTranscationStateWithEvents:(NSArray<MXEvent*> *)events
{
    MXKeyVerificationState state = MXKeyVerificationStateTransactionStarted;
    
    BOOL exitLoop = NO;
    
    for (MXEvent *event in events)
    {
        NSString *myUserId = self.mxSession.myUserId;
        
        switch (event.eventType)
        {
            case MXEventTypeKeyVerificationCancel:
            {
                MXKeyVerificationCancel *cancel;
                MXJSONModelSetMXJSONModel(cancel, MXKeyVerificationCancel.class, event.content);
                
                NSString *cancelCode = cancel.code;
                if ([cancelCode isEqualToString:MXTransactionCancelCode.user.value]
                    || [cancelCode isEqualToString:MXTransactionCancelCode.timeout.value])
                {
                    if ([event.sender isEqualToString:myUserId])
                    {
                        state = MXKeyVerificationStateTransactionCancelledByMe;
                        exitLoop = YES;
                    }
                    else
                    {
                        state = MXKeyVerificationStateTransactionCancelled;
                        exitLoop = YES;
                    }
                }
                else
                {
                    state = MXKeyVerificationStateTransactionFailed;
                    exitLoop = YES;
                }
                break;
            }
            case MXEventTypeKeyVerificationReady:
                state = MXKeyVerificationStateRequestReady;
                break;
            case MXEventTypeKeyVerificationDone:
                if ([event.sender isEqualToString:myUserId])
                {
                    state = MXKeyVerificationStateVerified;
                    exitLoop = YES;
                }
                break;
                
            default:
                break;
        }
        
        if (exitLoop)
        {
            break;
        }
    }
    
    return state;
}

- (MXKeyVerificationState)stateFromRequestState:(MXKeyVerificationRequestState)requestState
{
    MXKeyVerificationState state;
    switch (requestState)
    {
        case MXKeyVerificationRequestStatePending:
            state = MXKeyVerificationStateRequestPending;
            break;
        case MXKeyVerificationRequestStateExpired:
            state = MXKeyVerificationStateRequestExpired;
            break;
        case MXKeyVerificationRequestStateCancelled:
            state = MXKeyVerificationStateRequestCancelled;
            break;
        case MXKeyVerificationRequestStateCancelledByMe:
            state = MXKeyVerificationStateRequestCancelledByMe;
            break;
        case MXKeyVerificationRequestStateReady:
            state = MXKeyVerificationStateRequestReady;
            break;
        case MXKeyVerificationRequestStateAccepted:
            state = MXKeyVerificationStateTransactionStarted;
            break;
    }
    
    return state;
}

- (MXKeyVerificationState)stateFromRequest:(nullable MXKeyVerificationRequest*)request andTransaction:(nullable MXKeyVerificationTransaction*)transaction
{
    MXKeyVerificationState keyVerificationState = MXKeyVerificationStateRequestPending;
    
    if (transaction)
    {
        if ([transaction isKindOfClass:MXQRCodeTransaction.class])
        {
            MXQRCodeTransaction *qrCodeTransaction = (MXQRCodeTransaction*)transaction;
            
            switch (qrCodeTransaction.state) {
                case MXQRCodeTransactionStateUnknown:
                    
                    if (request)
                    {
                        keyVerificationState = [self stateFromRequestState:request.state];
                    }
                    else
                    {
                        keyVerificationState = MXKeyVerificationStateRequestPending;
                    }
                    
                    break;
                case MXQRCodeTransactionStateQRScannedByOther:
                case MXQRCodeTransactionStateScannedOtherQR:
                    keyVerificationState = MXKeyVerificationStateTransactionStarted;
                    break;
                case MXQRCodeTransactionStateVerified:
                    keyVerificationState = MXKeyVerificationStateVerified;
                    break;
                case MXQRCodeTransactionStateCancelled:
                    keyVerificationState = MXKeyVerificationStateTransactionCancelled;
                    break;
                case MXQRCodeTransactionStateCancelledByMe:
                    keyVerificationState = MXKeyVerificationStateTransactionCancelledByMe;
                    break;
                case MXQRCodeTransactionStateError:
                    keyVerificationState = MXKeyVerificationStateTransactionFailed;
                    break;
                default:
                    break;
            }
        }
        else if ([transaction isKindOfClass:MXSASTransaction.class])
        {
            MXSASTransaction *sasTransaction = (MXSASTransaction*)transaction;
            
            switch (sasTransaction.state) {
                case MXSASTransactionStateVerified:
                    keyVerificationState = MXKeyVerificationStateVerified;
                    break;
                case MXSASTransactionStateCancelled:
                    keyVerificationState = MXKeyVerificationStateTransactionCancelled;
                    break;
                case MXSASTransactionStateCancelledByMe:
                    keyVerificationState = MXKeyVerificationStateTransactionCancelledByMe;
                    break;
                case MXSASTransactionStateError:
                    keyVerificationState = MXKeyVerificationStateTransactionFailed;
                    break;
                default:
                    keyVerificationState = MXKeyVerificationStateTransactionStarted;
                    break;
            }
        }
    }
    else if (request)
    {
        keyVerificationState = [self stateFromRequestState:request.state];
    }
    
    return keyVerificationState;
}

@end
