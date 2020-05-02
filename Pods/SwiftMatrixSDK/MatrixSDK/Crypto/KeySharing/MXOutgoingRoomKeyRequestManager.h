/*
 Copyright 2017 OpenMarket Ltd

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

#import "MXRestClient.h"
#import "MXCryptoStore.h"

#ifdef MX_CRYPTO

/**
 Management of outgoing room key requests.

 See https://docs.google.com/document/d/1m4gQkcnJkxNuBmb5NoFCIadIY-DyqqNAS3lloE73BlQ
 for draft documentation on what we're supposed to be implementing here.
 */
@interface MXOutgoingRoomKeyRequestManager : NSObject

/**
 Create a MXSession instance.
 This instance will use the passed MXRestClient to make requests to the home server.

 @param mxRestClient The MXRestClient to the home server.
 @param deviceId The user device id.
 @param cryptoQueue The crypto thread.
 @param cryptoStore The crypto store.

 @return The newly-initialized MXSession.
 */
- (id)initWithMatrixRestClient:(MXRestClient*)mxRestClient
                      deviceId:(NSString*)deviceId
                   cryptoQueue:(dispatch_queue_t)cryptoQueue
                   cryptoStore:(id<MXCryptoStore>)cryptoStore;

/**
 Called when the client is started. Sets background processes running.
 */
- (void)start;

/**
 Enable or disable key share requests.
 Enabled by default
 
 @param enabled the new enable state.
 */
- (void)setEnabled:(BOOL)enabled;
- (BOOL)isEnabled;

/**
 Called when the client is stopped. Stops any running background processes.
 */
- (void)close;

/**
 Send off a room key request, if we haven't already done so.

 The `requestBody` is compared (with a deep-equality check) against
 previous queued or sent requests and if it matches, no change is made.
 Otherwise, a request is added to the pending list, and a job is started
 in the background to send it.
 
 @param requestBody the requestBody.
 @param recipients a {Array<{userId: string, deviceId: string}>}.
 */
- (void)sendRoomKeyRequest:(NSDictionary*)requestBody recipients:(NSArray<NSDictionary<NSString*, NSString*>*>*)recipients;

/**
 Cancel room key requests, if any match the given details.

 @param requestBody parameters to match for cancellation.
 */
- (void)cancelRoomKeyRequest:(NSDictionary*)requestBody;

/**
 Resend a room key request, if any match the given details.

 @param requestBody parameters to match for resend.
 */
- (void)resendRoomKeyRequest:(NSDictionary*)requestBody;

@end

#endif
