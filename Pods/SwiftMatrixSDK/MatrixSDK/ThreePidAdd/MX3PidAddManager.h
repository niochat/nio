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

#import "MX3PidAddSession.h"

@class MXSession;

NS_ASSUME_NONNULL_BEGIN

/**
 MX3PidAddManager error domain
 */
FOUNDATION_EXPORT NSString *const MX3PidAddManagerErrorDomain;

/**
 MXIdentityServerRestClient errors
 */
NS_ERROR_ENUM(MX3PidAddManagerErrorDomain)
{
    MX3PidAddManagerErrorDomainErrorInvalidParameters,
    MX3PidAddManagerErrorDomainIdentityServerRequired
};



/**
  The `MX3PidAddManager` instance allows a user to add a third party identifier
  to their homeserver and, optionally, the identity servers (bind).

  Diagrams of the intended API flows here are available at:

  https://gist.github.com/jryans/839a09bf0c5a70e2f36ed990d50ed928
 */
@interface MX3PidAddManager : NSObject

- (instancetype)initWithMatrixSession:(MXSession*)session NS_REFINED_FOR_SWIFT;


/**
 Cancel a session and its current operation.

 @param threePidAddSession the session to cancel.
 */
- (void)cancel3PidAddSession:(MX3PidAddSession*)threePidAddSession NS_REFINED_FOR_SWIFT;


#pragma mark - Add 3rd-Party Identifier

/**
 Get the authentication flow required to add a 3rd party id to the user homeserver account.

 @param success A block object called when the operation succeeds. If the returned flows is nil, no auth is required.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)authenticationFlowForAdd3PidWithSuccess:(void (^)(NSArray<MXLoginFlow*> * _Nullable flows))success
                                                    failure:(void (^)(NSError * _Nonnull))failure;


#pragma mark - Add Email

/**
 Add an email to the user homeserver account.

 The user will receive a validation email.
 Use then `tryFinaliseAddEmailSession` to complete the session.

 @param email the email.
 @param nextLink an optional URL where the user will be redirected to after they
                 click on the validation link within the validation email.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a 3pid add session.
 */
- (MX3PidAddSession*)startAddEmailSessionWithEmail:(NSString*)email
                                          nextLink:(nullable NSString*)nextLink
                                           success:(void (^)(void))success
                                           failure:(void (^)(NSError * _Nonnull))failure NS_REFINED_FOR_SWIFT;

/**
 Try to finalise the email addition.

 This must be called after the user has clicked the validation link.

 @param threePidAddSession the session to finalise.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (void)tryFinaliseAddEmailSession:(MX3PidAddSession*)threePidAddSession
                           success:(void (^)(void))success
                           failure:(void (^)(NSError * _Nonnull))failure NS_REFINED_FOR_SWIFT;

- (void)tryFinaliseAddEmailSession:(MX3PidAddSession*)threePidAddSession
                      withPassword:(nullable NSString*)password
                           success:(void (^)(void))success
                           failure:(void (^)(NSError * _Nonnull))failure NS_REFINED_FOR_SWIFT;

- (void)tryFinaliseAddEmailSession:(MX3PidAddSession*)threePidAddSession
                        authParams:(nullable NSDictionary*)authParams
                           success:(void (^)(void))success
                           failure:(void (^)(NSError * _Nonnull))failure NS_REFINED_FOR_SWIFT;

#pragma mark - Add MSISDN

/**
 Add a phone number to the user homeserver account.

 The user will receive a code by SMS.
 Use then `finaliseAddPhoneNumberSession` to complete the session.

 @param phoneNumber the phone number.
 @param countryCode the country code. Can be nil if `phoneNumber` is internationalised.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a 3pid add session.
 */
- (MX3PidAddSession*)startAddPhoneNumberSessionWithPhoneNumber:(NSString*)phoneNumber
                                                   countryCode:(nullable NSString*)countryCode
                                                       success:(void (^)(void))success
                                                       failure:(void (^)(NSError * _Nonnull))failure NS_REFINED_FOR_SWIFT;

/**
 Finalise the phone number addition.

 @param threePidAddSession the session to finalise.
 @param token the code received by SMS.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (void)finaliseAddPhoneNumberSession:(MX3PidAddSession*)threePidAddSession
                            withToken:(NSString*)token
                              success:(void (^)(void))success
                              failure:(void (^)(NSError * _Nonnull))failure NS_REFINED_FOR_SWIFT;

- (void)finaliseAddPhoneNumberSession:(MX3PidAddSession*)threePidAddSession
                            withToken:(NSString*)token
                             password:(nullable NSString*)password
                              success:(void (^)(void))success
                              failure:(void (^)(NSError * _Nonnull))failure NS_REFINED_FOR_SWIFT;

- (void)finaliseAddPhoneNumberSession:(MX3PidAddSession*)threePidAddSession
                            withToken:(NSString*)token
                           authParams:(nullable NSDictionary*)authParams
                              success:(void (^)(void))success
                              failure:(void (^)(NSError * _Nonnull))failure NS_REFINED_FOR_SWIFT;


#pragma mark - Bind Email

/**
 Add (bind) or remove (unbind) an email to/from the user identity server.

 If a validation(needValidation) is required, the user will receive a validation email.
 Use then `tryFinaliseBindOrUnBindEmailSession` to complete the session.
 Else, no more action is required.

 @param email the email.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a 3pid add session.
 */
- (MX3PidAddSession*)startIdentityServerEmailSessionWithEmail:(NSString*)email
                                                         bind:(BOOL)bind
                                                      success:(void (^)(BOOL needValidation))success
                                                      failure:(void (^)(NSError * _Nonnull))failure NS_REFINED_FOR_SWIFT;

/**
 Try to finalise the email addition or removal.

 This must be called after the user has clicked the validation link.

 @param threePidAddSession the session to finalise.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (void)tryFinaliseIdentityServerEmailSession:(MX3PidAddSession*)threePidAddSession
                                      success:(void (^)(void))success
                                      failure:(void (^)(NSError * _Nonnull))failure NS_REFINED_FOR_SWIFT;


#pragma mark - Bind Phone Number

/**
  Add (bind) or remove (unbind) a phone number to/from the user identity server.

 If a validation(needValidation) is required, the user will receive a code by SMS.
 Use then `finaliseBindPhoneNumberSession` to complete the session.
 Else, no more action is required.

 @param phoneNumber the phone number.
 @param countryCode the country code. Can be nil if `phoneNumber` is internationalised.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a 3pid add session.
 */
- (MX3PidAddSession*)startIdentityServerPhoneNumberSessionWithPhoneNumber:(NSString*)phoneNumber
                                                              countryCode:(nullable NSString*)countryCode
                                                                     bind:(BOOL)bind
                                                                  success:(void (^)(BOOL needValidation))success
                                                                  failure:(void (^)(NSError * _Nonnull))failure NS_REFINED_FOR_SWIFT;

/**
 Finalise the phone number addition or removal.

 @param threePidAddSession the session to finalise.
 @param token the code received by SMS.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (void)finaliseIdentityServerPhoneNumberSession:(MX3PidAddSession*)threePidAddSession
                                       withToken:(NSString*)token
                                         success:(void (^)(void))success
                                         failure:(void (^)(NSError * _Nonnull))failure NS_REFINED_FOR_SWIFT;

@end

NS_ASSUME_NONNULL_END

