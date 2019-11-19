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
#import "MXJSONModels.h"
#import "MXHTTPOperation.h"

NS_ASSUME_NONNULL_BEGIN

@interface MX3PidAddSession : NSObject

/**
 Initialise the instance with a 3PID.

 @param medium the medium.
 @param address the id of the contact on this medium.
 @return the new instance.
 */
- (instancetype)initWithMedium:(NSString*)medium andAddress:(NSString*)address;

/**
 The type of the third party media.
 */
@property (nonatomic, readonly) MX3PIDMedium medium;

/**
 The third party media (email address, msisdn,...).
 */
@property (nonatomic, readonly) NSString *address;

/**
 The 3PID country code when applicable.
 */
@property (nonatomic, nullable) NSString *countryCode;

/**
 The client secret key used during third party validation.
 */
@property (nonatomic, readonly) NSString *clientSecret;

/**
 The session identifier during third party validation.
 */
@property (nonatomic) NSString *sid;

/**
 The ongoing HTTP request.
 */
@property (nonatomic, nullable) MXHTTPOperation *httpOperation;

/**
 Number of request send attempts.
 */
@property (nonatomic) NSUInteger sendAttempt;

/**
 Flag indicating if the 3Pid must be add to the identity server.
 */
@property (nonatomic) BOOL bind;

/**
 The url where the validation token should be sent.
 @see [self submitMsisdnTokenOtherUrl:] for more details.
 */
@property (nonatomic, nullable) NSString *submitUrl;

@end

NS_ASSUME_NONNULL_END
