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

#import "MXKeyVerificationJSONModel.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Sent by either party to cancel a key verification.
 Upon receiving an m.key.verification.cancel message, if the transaction ID refers to a current verification,
 then the device must cancel the verification and should inform the user of the reason.
 */
@interface MXKeyVerificationCancel : MXKeyVerificationJSONModel

/**
 Machine-readable reason for cancelling (MXKeyVerificationCancelCodeXxx).
 */
@property (nonatomic) NSString *code;

/**
 Human-readable reason for cancelling.
 This should only be used if the receiving client does not understand the code given.
 */
@property (nonatomic, nullable) NSString *reason;

@end

NS_ASSUME_NONNULL_END
