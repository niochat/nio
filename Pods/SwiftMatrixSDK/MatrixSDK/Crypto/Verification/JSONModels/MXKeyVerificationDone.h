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

#import "MXKeyVerificationJSONModel.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Model for m.key.verification.done.
 As described at https://github.com/uhoreg/matrix-doc/blob/e2e_verification_in_dms/proposals/2241-e2e-verification-in-dms.md#concluding-a-key-verification
 */
@interface MXKeyVerificationDone : MXKeyVerificationJSONModel

@end

NS_ASSUME_NONNULL_END
