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

#import "MXHTTPClient.h"
#import "MXInvite3PID.h"
#import "MXJSONModels.h"
#import "MXCredentials.h"
#import "MXIdentityServerHashDetails.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Prefix used in path of identity server for v1 API requests.
 */
FOUNDATION_EXPORT NSString *const kMXIdentityAPIPrefixPathV1;

/**
 Prefix used in path of identity server for v2 API requests.
 */
FOUNDATION_EXPORT NSString *const kMXIdentityAPIPrefixPathV2;


/**
 MXIdentityServerRestClient error domain
 */
FOUNDATION_EXPORT NSString *const MXIdentityServerRestClientErrorDomain;

/**
 MXIdentityServerRestClient errors
 */
NS_ERROR_ENUM(MXIdentityServerRestClientErrorDomain)
{
    MXIdentityServerRestClientErrorUnknown,
    MXIdentityServerRestClientErrorMissingAPIPrefix,
    MXIdentityServerRestClientErrorAPIPrefixNotFound,
    MXIdentityServerRestClientErrorUnsupportedHashAlgorithm
};

/**
 `MXIdentityServerRestClient` makes requests to Matrix identity servers.
 */
@interface MXIdentityServerRestClient : NSObject

#pragma mark - Properties

/**
 The identity server URL.
 */
@property (nonatomic, readonly) NSString *identityServer;

/**
 The access token used for authenticated requests.
 */
@property (nonatomic, readonly, nullable) NSString *accessToken;

/**
 The queue on which asynchronous response blocks are called.
 Default is dispatch_get_main_queue().
*/
@property (nonatomic, strong) dispatch_queue_t completionQueue;

/**
 The preferred API path prefix to use for requests (i.e. "_matrix/identity/v2").
 */
@property (nonatomic, strong, nullable) NSString *preferredAPIPathPrefix;

/**
 Block called when a request needs authorization and access token should be renewed.
 */
@property (nonatomic, copy) MXHTTPClientShouldRenewTokenHandler shouldRenewTokenHandler;

/**
 Block called when a request fails and needs authorization to determine if the access token should be renewed.
 */
@property (nonatomic, copy) MXHTTPClientRenewTokenHandler renewTokenHandler;

#pragma mark - Setup

/**
 Create an instance based on identity server URL.

 @param identityServer the identity server URL.
 @param accessToken the identity server access token. Nil if not known yet.
 @param onUnrecognizedCertBlock the block called to handle unrecognized certificate (nil if unrecognized certificates are ignored).
 @return a MXIdentityServerRestClient instance.
*/
- (instancetype)initWithIdentityServer:(NSString *)identityServer accessToken:(nullable NSString*)accessToken andOnUnrecognizedCertificateBlock:(nullable MXHTTPClientOnUnrecognizedCertificate)onUnrecognizedCertBlock NS_REFINED_FOR_SWIFT;


#pragma mark -

#pragma mark Authentication

/**
 Register with an identity server using the OpenID token from the user's homeserver (v2 API).

 @param openIdToken The OpenID token from an homeserver.
 @param success A block object called when the operation succeeds. It provides the user access token for the identity server.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)registerWithOpenIdToken:(MXOpenIdToken*)openIdToken
                                    success:(void (^)(NSString *accessToken))success
                                    failure:(void (^)(NSError *error))failure;


/**
 Gets information about the token's owner, such as the user ID for which it belongs.

 @param success A block object called when the operation succeeds. It provides the user ID which was represented in the OpenID object provided to /register.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)accountWithSuccess:(void (^)(NSString *userId))success
                               failure:(void (^)(NSError *error))failure;

#pragma mark Association lookup

/**
 Retrieve a user matrix id from a 3rd party id (v1 API).
 
 @param address the id of the user in the 3rd party system.
 @param medium the 3rd party system (ex: "email").
 
 @param success A block object called when the operation succeeds. It provides the Matrix user id.
 It is nil if the user is not found.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)lookup3pid:(NSString*)address
                     forMedium:(MX3PIDMedium)medium
                       success:(nullable void (^)(NSString *userId))success
                       failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Retrieve user matrix ids from a list of 3rd party ids (v1 API).
 
 @param threepids the list of 3rd party ids: [[<(MX3PIDMedium)media1>, <(NSString*)address1>], [<(MX3PIDMedium)media2>, <(NSString*)address2>], ...].
 @param success A block object called when the operation succeeds. It provides the array of the discovered users returned by the identity server.
 [[<(MX3PIDMedium)media>, <(NSString*)address>, <(NSString*)userId>], ...].
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)lookup3pids:(NSArray*)threepids
                        success:(void (^)(NSArray *discoveredUsers))success
                        failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;


/**
 Gets the V2 hashing information from the identity server. Primarily useful for lookups (v2 API).

 @param success A block object called when the operation succeeds. It provides hash alogritms and pepper informations through the MXIdentityServerHashDetails object.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)hashDetailsWithSuccess:(void (^)(MXIdentityServerHashDetails *hashDetails))success
                                   failure:(void (^)(NSError *error))failure;

/**
 Retrieve user matrix ids from a list of 3rd party ids (v2 API). Require informations from `hashDetailsWithSuccess:failure` request.

 @param threepids The list of 3rd party ids: [[<(MX3PIDMedium)media1>, <(NSString*)address1>], [<(MX3PIDMedium)media2>, <(NSString*)address2>], ...].
 @param algorithm Three pids hash algorithm retrieved from "/hash_details" endpoint.
 @param pepper Three pids hash pepper retrieved from "/hash_details" endpoint.
 @param success A block object called when the operation succeeds. It provides the array of the discovered users returned by the identity server.
 [[<(MX3PIDMedium)media>, <(NSString*)address>, <(NSString*)userId>], ...].
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)lookup3pids:(NSArray<NSArray<NSString*>*> *)threepids
                      algorithm:(MXIdentityServerHashAlgorithm)algorithm
                         pepper:(NSString*)pepper
                        success:(void (^)(NSArray *discoveredUsers))success
                        failure:(void (^)(NSError *error))failure;

#pragma mark Establishing associations

/**
 Request the validation of an email address.
 
 The identity server will send an email to this address. The end user
 will have to click on the link it contains to validate the address.
 
 Use the returned sid to complete operations that require authenticated email
 like [MXRestClient add3PID:].
 
 @param email the email address to validate.
 @param clientSecret a secret key generated by the client. ([MXTools generateSecret] creates such key)
 @param sendAttempt the number of the attempt for the validation request. Increment this value to make the
 identity server resend the email. Keep it to retry the request in case the previous request
 failed.
 @param nextLink the link the validation page will automatically open. Can be nil
 
 @param success A block object called when the operation succeeds. It provides the id of the
 email validation session.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)requestEmailValidation:(NSString*)email
                              clientSecret:(NSString*)clientSecret
                               sendAttempt:(NSUInteger)sendAttempt
                                  nextLink:(nullable NSString*)nextLink
                                   success:(void (^)(NSString *sid))success
                                   failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Request the validation of a phone number.
 
 The identity server will send a validation token by sms. The end user
 will have to send this token by using [MXRestClient submit3PIDValidationToken].
 
 Use the returned sid to complete operations that require authenticated phone number
 like [MXRestClient add3PID:].
 
 @param phoneNumber the phone number (in international or national format).
 @param countryCode the ISO 3166-1 country code representation (required when the phone number is in national format).
 @param clientSecret a secret key generated by the client. ([MXTools generateSecret] creates such key)
 @param sendAttempt the number of the attempt for the validation request. Increment this value to make the
 identity server resend the sms token. Keep it to retry the request in case the previous request
 failed.
 @param nextLink the link the validation page will automatically open. Can be nil
 
 @param success A block object called when the operation succeeds. It provides the id of the validation session and the msisdn.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)requestPhoneNumberValidation:(NSString*)phoneNumber
                                     countryCode:(NSString*)countryCode
                                    clientSecret:(NSString*)clientSecret
                                     sendAttempt:(NSUInteger)sendAttempt
                                        nextLink:(nullable NSString *)nextLink
                                         success:(void (^)(NSString *sid, NSString *msisdn))success
                                         failure:(void (^)(NSError *error))failure;

/**
 Submit the validation token received by an email or a sms.
 
 In case of success, the related third-party id has been validated.
 
 @param token the validation token.
 @param medium the type of the third-party id (see kMX3PIDMediumEmail, kMX3PIDMediumMSISDN).
 @param clientSecret the clientSecret used during the validation request.
 @param sid the validation session id returned by the server.
 
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)submit3PIDValidationToken:(NSString *)token
                                       medium:(NSString *)medium
                                 clientSecret:(NSString *)clientSecret
                                          sid:(NSString *)sid
                                      success:(void (^)(void))success
                                      failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

#pragma mark Other

/**
 Check if there is an identity server endpoint running at the provided
 identity server address.
 
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)pingIdentityServer:(void (^)(void))success
                               failure:(void (^)(NSError *error))failure;


/**
 Check if API path prefix is reachable on identity server (i.e. "_matrix/identity/v2").

 @param apiPathPrefix API path prefix to check.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation *)isAPIPathPrefixAvailable:(NSString*)apiPathPrefix
                                      success:(void (^)(void))success
                                      failure:(void (^)(NSError *))failure;

/**
 Sign a 3PID URL.
 
 @param signUrl the URL that will be called for signing.
 @param mxid the user matrix id.
 @param success A block object called when the operation succeeds. It provides the signed data.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)signUrl:(NSString*)signUrl
                       mxid:(NSString*)mxid
                    success:(void (^)(NSDictionary *thirdPartySigned))success
                    failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

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


@end

NS_ASSUME_NONNULL_END
