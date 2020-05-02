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

#import "MXJSONModel.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Model for m.key.verification.request.
 As described at https://matrix.org/docs/spec/client_server/latest#m-key-verification-request
 */
@interface MXKeyVerificationRequestByToDeviceJSONModel : MXJSONModel

/**
 The device ID which is initiating the request.
 */
@property (nonatomic) NSString *fromDevice;

/**
 The request id.
 */
@property (nonatomic) NSString *transactionId;

/**
 The verification methods supported by the sender.
 */
@property (nonatomic) NSArray<NSString*> *methods;

/**
 The POSIX timestamp in milliseconds for when the request was made.
 */
@property (nonatomic) uint64_t timestamp;

@end

NS_ASSUME_NONNULL_END
