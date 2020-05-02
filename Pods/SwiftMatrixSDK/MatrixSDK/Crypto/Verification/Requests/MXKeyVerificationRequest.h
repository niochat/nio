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

#import "MXEvent.h"
#import "MXKeyVerificationTransaction.h"
#import "MXKeyVerificationReady.h"

#pragma mark - Constants

/**
 Notification sent when the request has been updated.
 */
FOUNDATION_EXPORT NSString * _Nonnull const MXKeyVerificationRequestDidChangeNotification;

typedef enum : NSUInteger
{
    MXKeyVerificationRequestStatePending = 0,
    MXKeyVerificationRequestStateExpired,
    MXKeyVerificationRequestStateCancelled,
    MXKeyVerificationRequestStateCancelledByMe,
    MXKeyVerificationRequestStateReady,
    MXKeyVerificationRequestStateAccepted
} MXKeyVerificationRequestState;


NS_ASSUME_NONNULL_BEGIN

/**
 An handler on an interactive verification request.
 */
@interface MXKeyVerificationRequest : NSObject

/**
Accept an incoming key verification request.

@param methods possible methods.
@param success a block called when the operation succeeds.
@param failure a block called when the operation fails.
*/
- (void)acceptWithMethods:(NSArray<NSString*>*)methods
                  success:(dispatch_block_t)success
                  failure:(void(^)(NSError *error))failure;

/**
 Cancel this request.

 @param code the cancellation reason
 @param success a block called when the operation succeeds.
 @param failure a block called when the operation fails.
 */
- (void)cancelWithCancelCode:(MXTransactionCancelCode*)code
                     success:(void(^ _Nullable)(void))success
                     failure:(void(^ _Nullable)(NSError *error))failure;

/**
 The cancellation reason, if any.
 */
@property (nonatomic, nullable) MXTransactionCancelCode *reasonCancelCode;

// Current state
@property (nonatomic, readonly) MXKeyVerificationRequestState state;

// Original data for this request
@property (nonatomic, readonly) MXEvent *event;

// Is it a request made by our user?
@property (nonatomic, readonly) BOOL isFromMyUser;
@property (nonatomic, readonly) BOOL isFromMyDevice;


// Shortcuts to the original request
@property (nonatomic, readonly) NSString *requestId;
@property (nonatomic, readonly) MXKeyVerificationTransport transport;
@property (nonatomic, readonly) NSString *fromDevice;
@property (nonatomic, readonly) uint64_t timestamp;
@property (nonatomic, readonly) NSArray<NSString*> *methods;

// The other party
@property (nonatomic, readonly) NSString *otherUser;
@property (nonatomic, readonly, nullable) NSString *otherDevice;  // This is unknown and nil while the request has not been accepted


// Original data from the accepted (aka m.verification.ready) event
@property (nonatomic, readonly, nullable) MXKeyVerificationReady *acceptedData;

// Shortcuts to the accepted event
@property (nonatomic, readonly, nullable) NSArray<NSString*> *acceptedMethods;

// Shortcuts of methods according to the point of view
@property (nonatomic, readonly, nullable) NSArray<NSString*> *myMethods;
@property (nonatomic, readonly, nullable) NSArray<NSString*> *otherMethods;

@end

NS_ASSUME_NONNULL_END
