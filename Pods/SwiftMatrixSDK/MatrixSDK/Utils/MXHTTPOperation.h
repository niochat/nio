/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd

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



/**
 The `MXHTTPOperation` objects manage pending HTTP requests.

 They hold statitics on the requests so that the `MXHTTPClient` instance can apply
 retries policies.
 */
@interface MXHTTPOperation : NSObject

/**
 The underlying HTTP request.
 The reference changes in case of retries.
 */
@property (nonatomic) NSURLSessionDataTask *operation;

/**
 The age in milliseconds of the instance.
 */
@property (nonatomic, readonly) NSUInteger age;

/**
 Number of times the request has been issued.
 */
@property (nonatomic) NSUInteger numberOfTries;

/**
 Max number of times the request can be retried.
 Default is 4.
 */
@property (nonatomic) NSUInteger maxNumberOfTries;

/**
 Time is milliseconds while a request can be retried.
 Default is 3 minutes.
 */
@property (nonatomic) NSUInteger maxRetriesTime;

/**
 Cancel status.
 */
@property (nonatomic, readonly, getter=isCancelled) BOOL canceled;

/**
 Cancel the HTTP request.
 */
- (void)cancel;

/**
 Mutate the MXHTTPOperation instance into another operation.
 
 @discussion
 This allows to chain HTTP requests and let the user keep the control on consecutive
 requests, ie he will able to cancel subsequent http requests.
 
 @param operation the other operation to copy data from. If the other operation is nil do nothing.
 */
- (void)mutateTo:(MXHTTPOperation*)operation;

/**
 Extract the NSHTTPURLResponse from an error.

 @param error the request error.
 @return the HTTP response.
 */
+ (NSHTTPURLResponse *)urlResponseFromError:(NSError*)error;

@end
