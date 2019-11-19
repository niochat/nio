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
#import "MXIdentityServerRestClient.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Defines & Constants

/**
 Notification name sent when "M_TERMS_NOT_SIGNED" error occured. Provides identity server and identity server access token.
 Give an associated userInfo dictionary of type NSDictionary<NSString*, NSString*> with following keys: "userId", "identityServer", "accessToken". Use constants below for convenience.
 */
extern NSString *const MXIdentityServiceTermsNotSignedNotification;

/**
 Notification name sent when access token change. Provides user id, identity server and access token.
 Give an associated userInfo dictionary of type NSDictionary<NSString*, NSString*> with following keys: "userId", "identityServer", "accessToken". Use constants below for convenience.
 */
extern NSString *const MXIdentityServiceDidChangeAccessTokenNotification;

/**
 userInfo dictionary keys used by `MXIdentityServiceTermsNotSignedNotification` and `MXIdentityServiceDidChangeAccessTokenNotification`.
 */
extern NSString *const MXIdentityServiceNotificationUserIdKey;
extern NSString *const MXIdentityServiceNotificationIdentityServerKey;
extern NSString *const MXIdentityServiceNotificationAccessTokenKey;

@class MXRestClient;

/**
 `MXIdentityService` manages requests to Matrix identity servers and abstract identity server REST client token and version management.
 */
@interface MXIdentityService : NSObject

#pragma mark - Properties

/**
 The identity server URL.
 */
@property (nonatomic, readonly) NSString *identityServer;

/**
 The queue on which asynchronous response blocks are called.
 Default is dispatch_get_main_queue().
 */
@property (nonatomic, strong) dispatch_queue_t completionQueue;

#pragma mark - Setup

/**
 Create an instance based on identity server URL.
 
 @param identityServer The identity server URL.
 @param accessToken the identity server access token. Nil if not known yet.
 @param homeserverRestClient The homeserver REST client.
 
 @return a MXIdentityService instance.
 */
- (instancetype)initWithIdentityServer:(NSString *)identityServer accessToken:(nullable NSString*)accessToken andHomeserverRestClient:(MXRestClient*)homeserverRestClient NS_REFINED_FOR_SWIFT;

/**
 Create an instance based on identity server URL.
 
 @param identityServerRestClient The identity server REST client.
 @param homeserverRestClient The homeserver REST client.
 
 @return a MXIdentityService instance.
 */
- (instancetype)initWithIdentityServerRestClient:(MXIdentityServerRestClient*)identityServerRestClient andHomeserverRestClient:(MXRestClient*)homeserverRestClient;


#pragma mark - Access token

/**
 Get the access token to use on the identity server.

 The method triggers an /account request in order to force the setup of the
 access token, which can lead to a "M_TERMS_NOT_SIGNED" error.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance. Nil if the access token is already known
         and no HTTP request is required.
 */
- (nullable MXHTTPOperation *)accessTokenWithSuccess:(void (^)(NSString * _Nullable accessToken))success
                                             failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

#pragma mark -

#pragma mark Association lookup

/**
 Retrieve user matrix ids from a list of 3rd party ids.
 
 @param threepids the list of 3rd party ids: [[<(MX3PIDMedium)media1>, <(NSString*)address1>], [<(MX3PIDMedium)media2>, <(NSString*)address2>], ...].
 @param success A block object called when the operation succeeds. It provides the array of the discovered users returned by the identity server.
 [[<(MX3PIDMedium)media>, <(NSString*)address>, <(NSString*)userId>], ...].
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)lookup3pids:(NSArray*)threepids
                        success:(void (^)(NSArray *discoveredUsers))success
                        failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

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
                                         failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

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
                               failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Sign a 3PID URL.
 
 @param signUrl the URL that will be called for signing.
 @param success A block object called when the operation succeeds. It provides the signed data.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)signUrl:(NSString*)signUrl
                    success:(void (^)(NSDictionary *thirdPartySigned))success
                    failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;

/**
 Gets information about the token's owner, such as the user ID for which it belongs.
 
 @param success A block object called when the operation succeeds. It provides the user ID.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)accountWithSuccess:(void (^)(NSString *userId))success
                               failure:(void (^)(NSError *error))failure NS_REFINED_FOR_SWIFT;


@end

NS_ASSUME_NONNULL_END
