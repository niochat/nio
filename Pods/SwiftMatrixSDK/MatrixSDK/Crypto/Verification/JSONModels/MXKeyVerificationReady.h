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

#import "MXKeyVerificationJSONModel.h"

NS_ASSUME_NONNULL_BEGIN

/**
 "m.key.verification.ready" model.
 */
@interface MXKeyVerificationReady : MXKeyVerificationJSONModel

/**
 An array of verification methods("m.sas.v1", etc) that the device supports.
 */
@property (nonatomic) NSArray<NSString*> *methods;

/**
 The ID of the device that sent the m.key.verification.ready message
 */
@property (nonatomic) NSString *fromDevice;


/**
 Check content validity.

 @return YES if valid.
 */
- (BOOL)isValid;

@end

NS_ASSUME_NONNULL_END
