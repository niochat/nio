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

#import "MXJSONModel.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Base class for key verification events.

 It handles the storage of transactionId that can be in JSONDictionary["m.relates_to"]["event_id"]
 for verification by DM.
 */
@interface MXKeyVerificationJSONModel : MXJSONModel

/**
 The transaction ID from the m.key.verification.start message.
 */
@property (nonatomic) NSString *transactionId;

/**
 In case of direct message transport, the first event that triggered the transaction flow.
 */
 @property (nonatomic) NSString *relatedEventId;;


- (instancetype)initWithJSONDictionary:(NSDictionary *)JSONDictionary;
- (NSMutableDictionary*)JSONDictionaryWithTransactionId;

@end

NS_ASSUME_NONNULL_END
