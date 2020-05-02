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

#import <Foundation/Foundation.h>
#import "MXQRCodeDataCodable.h"

NS_ASSUME_NONNULL_BEGIN

@interface MXQRCodeData : NSObject <MXQRCodeDataCodable>

// the event ID or transaction id of the associated verification request event
@property (nonatomic, strong, readwrite) NSString *transactionId;

// the first key, as 32 bytes. The key to use depends on the verification mode
@property (nonatomic, strong, readwrite) NSString *firstKey;

// the second key, as 32 bytes. The key to use depends on the verification mode
@property (nonatomic, strong, readwrite) NSString *secondKey;

// random shared secret
@property (nonatomic, strong, readwrite) NSData *sharedSecret;

@end

NS_ASSUME_NONNULL_END
