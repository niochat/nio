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

#import <Foundation/Foundation.h>

#import "MXKeyVerification.h"

@class MXKeyVerificationManager, MXSession, MXHTTPOperation, MXEvent;

NS_ASSUME_NONNULL_BEGIN

/**
 `MXKeyVerificationStatusResolver` computes MXKeyVerification status from an event
 of the verification process.
 */
@interface MXKeyVerificationStatusResolver : NSObject

- (instancetype)initWithManager:(MXKeyVerificationManager*)manager matrixSession:(MXSession*)matrixSession;

- (nullable MXHTTPOperation *)keyVerificationWithKeyVerificationId:(NSString*)keyVerificationId
                                                             event:(MXEvent*)event
                                                         transport:(MXKeyVerificationTransport)transport
                                                           success:(void(^)(MXKeyVerification *keyVerification))success
                                                           failure:(void(^)(NSError *error))failure;

- (nullable MXKeyVerification*)keyVerificationFromRequest:(nullable MXKeyVerificationRequest*)request andTransaction:(nullable MXKeyVerificationTransaction*)transaction;

@end

NS_ASSUME_NONNULL_END
