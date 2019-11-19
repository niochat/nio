/*
 Copyright 2018 New Vector Ltd

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

#import "MXSDKOptions.h"

#ifdef MX_CRYPTO

#import <OLMKit/OLMKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 The 'MXOlmSession' class adds additional information to an OLMSession object from OLMKit.
 */
@interface MXOlmSession : NSObject


- (instancetype)initWithOlmSession:(OLMSession*)session;

/**
 The associated olm session.
 */
@property (nonatomic, readonly) OLMSession *session;

/**
 Timestamp at which the session last received a message.
 */
@property (nonatomic) NSTimeInterval lastReceivedMessageTs;


/**
 Notify this model that a message has been received on this olm session
 so that it updates `lastReceivedMessageTs`
 */
- (void)didReceiveMessage;

@end

NS_ASSUME_NONNULL_END

#endif
