/*
 Copyright 2014 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
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

#import "MXHTTPOperation.h"

/**
 `MXHTTPClientErrorResponseDataKey`
 The corresponding value is an `NSDictionary` containing the response data of the operation associated with an error.
 */
extern NSString * const MXHTTPClientErrorResponseDataKey;

/**
 Posted when the user did not consent to GDPR.
 */
FOUNDATION_EXPORT NSString* const kMXHTTPClientUserConsentNotGivenErrorNotification;
/**
 Consent URI userInfo key for notification kMXHTTPClientUserConsentNotGivenErrorNotification
 */
FOUNDATION_EXPORT NSString* const kMXHTTPClientUserConsentNotGivenErrorNotificationConsentURIKey;
/**
 Posted when a Matrix error is observed.
 The `userInfo` dictionary contains an `MXError` object under the `kMXHTTPClientMatrixErrorNotificationErrorKey` key
 */
FOUNDATION_EXPORT NSString* const kMXHTTPClientMatrixErrorNotification;
FOUNDATION_EXPORT NSString* const kMXHTTPClientMatrixErrorNotificationErrorKey;

/**
 Block called when an authentication challenge from a server failed whereas a certificate is present in certificate chain.
 
 @param certificate the server certificate to evaluate.
 @return YES to accept/trust this certificate, NO to cancel/ignore it.
 */
typedef BOOL (^MXHTTPClientOnUnrecognizedCertificate)(NSData *certificate);

/**
 Block called when a request fails and needs authorization to determine if the access token should be renewed.
 
 @param error A request error.
 
 @return YES if the access token should be renewed for the given error.
 */
typedef BOOL (^MXHTTPClientShouldRenewTokenHandler)(NSError *error);

/**
 Block called when a request needs authorization and access token should be renewed.

 @param success A block object called when the operation succeeds. It provides the access token.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
typedef MXHTTPOperation* (^MXHTTPClientRenewTokenHandler)(void (^success)(NSString *accessToken), void (^failure)(NSError *error));

/**
 SSL Pinning mode
 */
typedef NS_ENUM(NSUInteger, MXHTTPClientSSLPinningMode) {
    /**
     Do not used pinned certificates to validate servers.
     */
    MXHTTPClientSSLPinningModeNone,
    /**
     Validate host certificates against public keys of pinned certificates.
     */
    MXHTTPClientSSLPinningModePublicKey,
    /**
     Validate host certificates against pinned certificates.
     */
    MXHTTPClientSSLPinningModeCertificate,
};

/**
 `MXHTTPClient` is an abstraction layer for making requests to a HTTP server.

*/
@interface MXHTTPClient : NSObject


#pragma mark - Configuration
/**
 `requestParametersInJSON` indicates if parameters passed in [self requestWithMethod:..] methods
 must be serialised in JSON.
 Else, they will be send in form data.
 Default is YES.
 */
@property (nonatomic) BOOL requestParametersInJSON;

/**
 The current trusted certificate (if any).
 */
@property (nonatomic, readonly) NSData* allowedCertificate;

/**
 The acceptable MIME types for responses.
 */
@property (nonatomic, copy) NSSet <NSString *> *acceptableContentTypes;

/**
 The server URL from which requests will be done.
 */
@property (nonatomic, readonly) NSURL *baseURL;

/**
 The access token used for authenticated requests.
 */
@property (nonatomic, readonly) NSString *accessToken;

/**
 Block called when a request needs authorization and access token should be renewed.
 */
@property (nonatomic, copy) MXHTTPClientShouldRenewTokenHandler shouldRenewTokenHandler;

/**
 Block called when a request fails and needs authorization to determine if the access token should be renewed.
 */
@property (nonatomic, copy) MXHTTPClientRenewTokenHandler renewTokenHandler;

#pragma mark - Public methods
/**
 Create an instance to make requests to the server.

 @param baseURL the server URL from which requests will be done.
 @param onUnrecognizedCertBlock the block called to handle unrecognized certificate (nil if unrecognized certificates are ignored).
 @return a MXHTTPClient instance.
 */
- (id)initWithBaseURL:(NSString*)baseURL andOnUnrecognizedCertificateBlock:(MXHTTPClientOnUnrecognizedCertificate)onUnrecognizedCertBlock;

/**
 Create an intance to make access-token-authenticated requests to the server.
 MXHTTPClient will automatically add the access token to requested URLs

 @param baseURL the server URL from which requests will be done.
 @param accessToken the access token to authenticate requests.
 @param onUnrecognizedCertBlock the block called to handle unrecognized certificate (nil if unrecognized certificates are ignored).
 @return a MXHTTPClient instance.
 */
- (id)initWithBaseURL:(NSString*)baseURL accessToken:(NSString*)accessToken andOnUnrecognizedCertificateBlock:(MXHTTPClientOnUnrecognizedCertificate)onUnrecognizedCertBlock;

/**
 Make a HTTP request to the server.

 @param httpMethod the HTTP method (GET, PUT, ...)
 @param path the relative path of the server API to call.
 @param parameters the parameters to be set as a query string for `GET` requests, or the request HTTP body.

 @param success A block object called when the operation succeeds. It provides the JSON response object from the the server.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)requestWithMethod:(NSString *)httpMethod
                   path:(NSString *)path
             parameters:(NSDictionary*)parameters
                success:(void (^)(NSDictionary *JSONResponse))success
                failure:(void (^)(NSError *error))failure;

/**
 Make a HTTP request to the server with a timeout.

 @param httpMethod the HTTP method (GET, PUT, ...)
 @param path the relative path of the server API to call.
 @param parameters the parameters to be set as a query string for `GET` requests, or the request HTTP body.
 @param timeoutInSeconds the timeout allocated for the request.

 @param success A block object called when the operation succeeds. It provides the JSON response object from the the server.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)requestWithMethod:(NSString *)httpMethod
                   path:(NSString *)path
             parameters:(NSDictionary*)parameters
                timeout:(NSTimeInterval)timeoutInSeconds
                success:(void (^)(NSDictionary *JSONResponse))success
                failure:(void (^)(NSError *error))failure;

/**
 Make a HTTP request to the server with all possible options.

 @param path the relative path of the server API to call.
 @param parameters (optional) the parameters to be set as a query string for `GET` requests, or the request HTTP body.
 @param data (optional) the data to post.
 @param headers (optional) the HTTP headers to set.
 @param timeoutInSeconds (optional) the timeout allocated for the request.
 
 @param uploadProgress (optional) A block object called when the upload progresses.

 @param success A block object called when the operation succeeds. It provides the JSON response object from the the server.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)requestWithMethod:(NSString *)httpMethod
                             path:(NSString *)path
                       parameters:(NSDictionary*)parameters
                             data:(NSData *)data
                          headers:(NSDictionary*)headers
                          timeout:(NSTimeInterval)timeoutInSeconds
                   uploadProgress:(void (^)(NSProgress *uploadProgress))uploadProgress
                          success:(void (^)(NSDictionary *JSONResponse))success
                          failure:(void (^)(NSError *error))failure;


/**
 Make a HTTP request to the server.
 
 @param httpMethod the HTTP method (GET, PUT, ...)
 @param path the relative path of the server API to call.
 @param parameters the parameters to be set as a query string for `GET` requests, or the request HTTP body.
 @param needsAuthorization Indicate YES if the request is authenticated.
 
 @param success A block object called when the operation succeeds. It provides the JSON response object from the the server.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)requestWithMethod:(NSString *)httpMethod
                                 path:(NSString *)path
                           parameters:(NSDictionary*)parameters
                   needsAuthorization:(BOOL)needsAuthorization
                              success:(void (^)(NSDictionary *JSONResponse))success
                              failure:(void (^)(NSError *error))failure;

/**
 Make a HTTP request to the server with a timeout.
 
 @param httpMethod the HTTP method (GET, PUT, ...)
 @param path the relative path of the server API to call.
 @param parameters the parameters to be set as a query string for `GET` requests, or the request HTTP body.
 @param needsAuthorization Indicate YES if the request is authenticated.
 @param timeoutInSeconds the timeout allocated for the request.
 
 @param success A block object called when the operation succeeds. It provides the JSON response object from the the server.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)requestWithMethod:(NSString *)httpMethod
                                 path:(NSString *)path
                           parameters:(NSDictionary*)parameters
                   needsAuthorization:(BOOL)needsAuthorization
                              timeout:(NSTimeInterval)timeoutInSeconds
                              success:(void (^)(NSDictionary *JSONResponse))success
                              failure:(void (^)(NSError *error))failure;

/**
 Make a HTTP request to the server with all possible options.
 
 @param path the relative path of the server API to call.
 @param parameters (optional) the parameters to be set as a query string for `GET` requests, or the request HTTP body.
 @param needsAuthorization Indicate YES if the request is authenticated.
 @param data (optional) the data to post.
 @param headers (optional) the HTTP headers to set.
 @param timeoutInSeconds (optional) the timeout allocated for the request.
 
 @param uploadProgress (optional) A block object called when the upload progresses.
 
 @param success A block object called when the operation succeeds. It provides the JSON response object from the the server.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)requestWithMethod:(NSString *)httpMethod
                                 path:(NSString *)path
                           parameters:(NSDictionary*)parameters
                   needsAuthorization:(BOOL)needsAuthorization
                                 data:(NSData *)data
                              headers:(NSDictionary*)headers
                              timeout:(NSTimeInterval)timeoutInSeconds
                       uploadProgress:(void (^)(NSProgress *uploadProgress))uploadProgress
                              success:(void (^)(NSDictionary *JSONResponse))success
                              failure:(void (^)(NSError *error))failure;

/**
 Get current access or get a new one if not exist.
 Note: There is no guarantee that current access token is valid.

 @param success A block object called when the operation succeeds. It provides the access token.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance. Nil if the access token is already known
 and no HTTP request is required.
 */
- (MXHTTPOperation *)getAccessTokenAndRenewIfNeededWithSuccess:(void (^)(NSString *accessToken))success
                                                       failure:(void (^)(NSError *error))failure;

/**
 Return the amount of time to wait before retrying a request.
 
 The time is based on an exponential backoff plus a jitter in order to prevent all Matrix clients 
 from retrying all in the same time if there is server side issue like server restart.
 
 @return a time in milliseconds like [2000, 4000, 8000, 16000, ...] + a jitter of 3000ms.
 */
+ (NSUInteger)timeForRetry:(MXHTTPOperation*)httpOperation;

/**
 The certificates used to evaluate server trust.
 The default SSL pinning mode is MXHTTPClientSSLPinningModeCertificate when the provided set is not empty.
 Set an empty set or null to restore the default security policy.
 */
@property (nonatomic, strong) NSSet<NSData *> *pinnedCertificates;

/**
 Set the certificates used to evaluate server trust and the SSL pinning mode.
 
 @param pinnedCertificates The certificates to pin against.
 @param pinningMode The SSL pinning mode.
 */
- (void)setPinnedCertificates:(NSSet<NSData *> *)pinnedCertificates withPinningMode:(MXHTTPClientSSLPinningMode)pinningMode;

@end
