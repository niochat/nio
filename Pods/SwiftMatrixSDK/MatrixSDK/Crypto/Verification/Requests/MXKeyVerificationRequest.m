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

#import "MXKeyVerificationRequest_Private.h"

#import "MXKeyVerificationManager_Private.h"

#import "MXCrypto_Private.h"


#pragma mark - Constants
NSString * const MXKeyVerificationRequestDidChangeNotification = @"MXKeyVerificationRequestDidChangeNotification";

@interface MXKeyVerificationRequest()

@property (nonatomic, readwrite) MXKeyVerificationRequestState state;

@end

@implementation MXKeyVerificationRequest

#pragma mark - SDK-Private methods -

- (instancetype)initWithEvent:(MXEvent*)event andManager:(MXKeyVerificationManager*)manager
{
    self = [super init];
    if (self)
    {
        _event = event;
        _state = MXKeyVerificationRequestStatePending;
        _manager = manager;
    }
    return self;
}

- (void)acceptWithMethods:(NSArray<NSString *> *)methods success:(dispatch_block_t)success failure:(void (^)(NSError * _Nonnull))failure
{
    [self.manager computeReadyMethodsFromVerificationRequestWithId:self.requestId
                                               andSupportedMethods:methods
                                                        completion:^(NSArray<NSString *> * _Nonnull readyMethods, MXQRCodeData * _Nullable qrCodeData)
    {
        if (!readyMethods.count)
        {
            void (^noReadyMethodsFailure)(void) = ^{
                
                NSError *error = [NSError errorWithDomain:MXKeyVerificationErrorDomain
                                                     code:MXKeyVerificationUnsupportedMethodCode
                                                 userInfo:@{
                                                            NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unsupported verification methods: %@", self.methods]
                                                            }];
                
                if (failure)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        failure(error);
                    });
                }
            };
            
            [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage success:^{
                noReadyMethodsFailure();
            } failure:^(NSError * _Nonnull error) {
                noReadyMethodsFailure();
            }];
            
            return;
        }
        
        NSString *myDeviceId = self.manager.crypto.mxSession.matrixRestClient.credentials.deviceId;
        
        MXKeyVerificationReady *ready = [MXKeyVerificationReady new];
        ready.transactionId = self.requestId;
        ready.relatedEventId = self.event.eventId;
        ready.methods = readyMethods;
        ready.fromDevice = myDeviceId;
        
        [self.manager sendToOtherInRequest:self eventType:kMXEventTypeStringKeyVerificationReady content:ready.JSONDictionary success:^{
            
            self.acceptedData = ready;
            
            if (qrCodeData)
            {
                [self.manager createQRCodeTransactionFromRequest:self qrCodeData:qrCodeData success:^(MXQRCodeTransaction * _Nonnull transaction) {
                    [self updateState:MXKeyVerificationRequestStateReady notifiy:YES];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        success();
                    });
                } failure:^(NSError * _Nonnull error) {
                    
                    NSLog(@"[MXKeyVerificationRequest] acceptWithMethods fail to create qrCodeData.");
                    
                    [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage success:^{
                        
                    } failure:^(NSError * _Nonnull error) {
                        NSLog(@"[MXKeyVerificationRequest] acceptWithMethods fail to cancel request");
                    }];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        failure(error);
                    });
                }];
            }
            else
            {
                [self updateState:MXKeyVerificationRequestStateReady notifiy:YES];
                dispatch_async(dispatch_get_main_queue(), ^{
                    success();
                });
            }
                        
        }  failure:^(NSError * _Nonnull error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(error);
            });
        }];
    }];
}

- (void)cancelWithCancelCode:(MXTransactionCancelCode*)code success:(void(^)(void))success failure:(void(^)(NSError *error))failure
{
    [self.manager cancelVerificationRequest:self success:^{
        self.reasonCancelCode = code;
        
        [self updateState:MXKeyVerificationRequestStateCancelledByMe notifiy:YES];
        [self.manager removePendingRequestWithRequestId:self.requestId];
        
        if (success)
        {
            success();
        }
        
    } failure:failure];
}

- (void)updateState:(MXKeyVerificationRequestState)state notifiy:(BOOL)notify
{
    if (state == self.state)
    {
        return;
    }
    
    self.state = state;
    
    if (notify)
    {
        [self didUpdateState];
    }
}

- (void)didUpdateState
{
    dispatch_async(dispatch_get_main_queue(),^{
        [[NSNotificationCenter defaultCenter] postNotificationName:MXKeyVerificationRequestDidChangeNotification object:self userInfo:nil];
    });
}

- (void)handleReady:(MXKeyVerificationReady*)readyContent
{
    MXQRCodeData *qrCodeData;
    
    // Check if other user is able to scan QR code
    if ([readyContent.methods containsObject:MXKeyVerificationMethodQRCodeScan] && [self.methods containsObject:MXKeyVerificationMethodQRCodeShow])
    {
        qrCodeData = [self.manager createQRCodeDataWithTransactionId:self.requestId otherUserId:self.otherUser otherDeviceId:self.otherDevice];
    }
    
    self.acceptedData = readyContent;
    
    if ([readyContent.methods containsObject:MXKeyVerificationMethodReciprocate])
    {
        [self.manager createQRCodeTransactionFromRequest:self qrCodeData:qrCodeData success:^(MXQRCodeTransaction * _Nonnull transaction) {
            
            [self updateState:MXKeyVerificationRequestStateReady notifiy:YES];
            
        } failure:^(NSError * _Nonnull error) {
            [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage success:^{
                
            } failure:^(NSError * _Nonnull error) {
                NSLog(@"[MXKeyVerificationRequest] handleReady fail to cancel request");
            }];
        }];
    }
    else
    {
        [self updateState:MXKeyVerificationRequestStateReady notifiy:YES];
    }
}

- (void)handleCancel:(MXKeyVerificationCancel *)cancelContent
{
    self.reasonCancelCode = [[MXTransactionCancelCode alloc] initWithValue:cancelContent.code
                                                             humanReadable:cancelContent.reason];
    
    [self updateState:MXKeyVerificationRequestStateCancelled notifiy:YES];
    [self.manager removePendingRequestWithRequestId:self.requestId];
}


// Shortcuts to the accepted event
-(NSArray<NSString *> *)acceptedMethods
{
    return _acceptedData.methods;
}


// Shortcuts of methods according to the point of view
- (NSArray<NSString *> *)myMethods
{
    return _isFromMyDevice ? self.methods : self.acceptedMethods;
}

- (NSArray<NSString *> *)otherMethods
{
    return _isFromMyDevice ? self.acceptedMethods : self.methods;
}

@end
