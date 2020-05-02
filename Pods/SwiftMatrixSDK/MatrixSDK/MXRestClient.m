/*
 Copyright 2014 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2018 New Vector Ltd
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

#import "MXRestClient.h"

#import "MXJSONModel.h"
#import "MXTools.h"
#import "MXError.h"

#import "MXAllowedCertificates.h"

#pragma mark - Constants definitions
/**
 Prefix used in path of home server API requests.
 */
NSString *const kMXAPIPrefixPathR0 = @"_matrix/client/r0";
NSString *const kMXAPIPrefixPathUnstable = @"_matrix/client/unstable";

/**
 Account data types
 */
NSString *const kMXAccountDataTypeIgnoredUserList = @"m.ignored_user_list";
NSString *const kMXAccountDataTypePushRules = @"m.push_rules";
NSString *const kMXAccountDataTypeDirect = @"m.direct";
NSString *const kMXAccountDataTypeUserWidgets = @"m.widgets";
NSString *const kMXAccountDataTypeIdentityServer = @"m.identity_server";
NSString *const kMXAccountDataTypeAcceptedTerms = @"m.accepted_terms";

/**
 Account data keys
 */
NSString *const kMXAccountDataKeyIgnoredUser = @"ignored_users";
NSString *const kMXAccountDataKeyIdentityServer = @"base_url";
NSString *const kMXAccountDataTypeAcceptedTermsKey = @"accepted";

/**
 Types of third party media.
 The list is not exhautive and depends on the Identity server capabilities.
 */
NSString *const kMX3PIDMediumEmail  = @"email";
NSString *const kMX3PIDMediumMSISDN = @"msisdn";

/**
 MXRestClient error domain
 */
NSString *const kMXRestClientErrorDomain = @"kMXRestClientErrorDomain";

/**
 Parameters that can be used in [MXRestClient membersOfRoom:withParameters:...].
 */
NSString *const kMXMembersOfRoomParametersAt            = @"at";
NSString *const kMXMembersOfRoomParametersMembership    = @"membership";
NSString *const kMXMembersOfRoomParametersNotMembership = @"not_membership";

/**
 Authentication flow: register or login
 */
typedef enum
{
    MXAuthActionRegister,
    MXAuthActionLogin
}
MXAuthAction;


#pragma mark - MXRestClient
@interface MXRestClient ()
{
    /**
     HTTP client to the home server.
     */
    MXHTTPClient *httpClient;
    
    /**
     HTTP client to the antivirus server.
     */
    MXHTTPClient *antivirusHttpClient;
    
    /**
     The queue to process server response.
     This queue is used to create models from JSON dictionary without blocking the main thread.
     */
    dispatch_queue_t processingQueue;
}
@end

@implementation MXRestClient
@synthesize credentials, apiPathPrefix, contentPathPrefix, completionQueue, antivirusServerPathPrefix;

-(id)initWithHomeServer:(NSString *)homeserver andOnUnrecognizedCertificateBlock:(MXHTTPClientOnUnrecognizedCertificate)onUnrecognizedCertBlock
{
    MXCredentials *credentials = [MXCredentials new];
    credentials.homeServer = homeserver;

    return [self initWithCredentials:credentials andOnUnrecognizedCertificateBlock:onUnrecognizedCertBlock];
}

-(id)initWithCredentials:(MXCredentials*)inCredentials andOnUnrecognizedCertificateBlock:(MXHTTPClientOnUnrecognizedCertificate)onUnrecognizedCertBlock
{
    self = [super init];
    if (self)
    {
        apiPathPrefix = kMXAPIPrefixPathR0;
        antivirusServerPathPrefix = kMXAntivirusAPIPrefixPathUnstable;
        contentPathPrefix = kMXContentPrefixPath;
        
        credentials = inCredentials;
        _identityServer = credentials.identityServer;

        if (credentials.homeServer)
        {
            httpClient = [[MXHTTPClient alloc] initWithBaseURL:credentials.homeServer
                                                   accessToken:credentials.accessToken
                             andOnUnrecognizedCertificateBlock:^BOOL(NSData *certificate)
                          {

                              // Check whether the provided certificate has been already trusted
                              if ([[MXAllowedCertificates sharedInstance] isCertificateAllowed:certificate])
                              {
                                  return YES;
                              }

                              // Check whether the provided certificate is the already trusted by the user.
                              if (inCredentials.allowedCertificate && [inCredentials.allowedCertificate isEqualToData:certificate])
                              {
                                  // Store the allowed certificate for further requests (from MXMediaManager)
                                  [[MXAllowedCertificates sharedInstance] addCertificate:certificate];
                                  return YES;
                              }

                              // Check whether the user has already ignored this certificate change.
                              if (inCredentials.ignoredCertificate && [inCredentials.ignoredCertificate isEqualToData:certificate])
                              {
                                  return NO;
                              }

                              // Let the app ask the end user to verify it
                              if (onUnrecognizedCertBlock)
                              {
                                  BOOL allowed = onUnrecognizedCertBlock(certificate);

                                  if (allowed)
                                  {
                                      // Store the allowed certificate for further requests
                                      [[MXAllowedCertificates sharedInstance] addCertificate:certificate];
                                  }

                                  return allowed;
                              }
                              else
                              {
                                  return NO;
                              }
                          }];
        }

        completionQueue = dispatch_get_main_queue();

        processingQueue = dispatch_queue_create("MXRestClient", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)close
{
    credentials = nil;
    httpClient = nil;
    antivirusHttpClient = nil;
    
    processingQueue = nil;
    completionQueue = nil;
}

- (NSString *)homeserver
{
    return self.credentials.homeServer;
}

- (NSString *)homeserverSuffix
{
    NSString *homeserverSuffix;

    // Extract homeserver suffix from userId
    NSArray *components = [credentials.userId componentsSeparatedByString:@":"];
    if (components.count > 1)
    {
        // Remove first component
        NSString *matrixId = components.firstObject;
        NSRange range = NSMakeRange(0, matrixId.length);
        homeserverSuffix = [credentials.userId stringByReplacingCharactersInRange:range withString:@""];
    }
    else
    {
        NSLog(@"[MXRestClient] Warning: the userId is not correctly formatted: %@", credentials.userId);
    }

    return homeserverSuffix;
}

- (NSData*)allowedCertificate
{
    return httpClient.allowedCertificate;
}

- (NSSet<NSString *> *)acceptableContentTypes
{
    return httpClient.acceptableContentTypes;
}

- (void)setAcceptableContentTypes:(NSSet<NSString *> *)acceptableContentTypes
{
    httpClient.acceptableContentTypes = acceptableContentTypes;
}


#pragma mark - Server administration

- (MXHTTPOperation*)supportedMatrixVersions:(void (^)(MXMatrixVersions *matrixVersions))success
                        failure:(void (^)(NSError *error))failure
{
    // There is no versioning in the path of this API
    NSString *path = @"_matrix/client/versions";

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXMatrixVersions *matrixVersions;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(matrixVersions, MXMatrixVersions, JSONResponse);
                                         } andCompletion:^{
                                             success(matrixVersions);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}


- (MXHTTPOperation*)wellKnow:(void (^)(MXWellKnown *wellKnown))success
                     failure:(void (^)(NSError *error))failure
{
    NSString *path = @".well-known/matrix/client";

    MXWeakify(self);
    MXHTTPOperation *operation = [httpClient requestWithMethod:@"GET"
                                                          path:path
                                                    parameters:nil
                                                       success:^(NSDictionary *JSONResponse) {
                                                           MXStrongifyAndReturnIfNil(self);

                                                           if (success)
                                                           {
                                                               __block MXWellKnown *wellKnown;
                                                               [self dispatchProcessing:^{
                                                                   MXJSONModelSetMXJSONModel(wellKnown, MXWellKnown, JSONResponse);
                                                               } andCompletion:^{
                                                                   success(wellKnown);
                                                               }];
                                                           }
                                                       }
                                                       failure:^(NSError *error) {
                                                           MXStrongifyAndReturnIfNil(self);
                                                           [self dispatchFailure:error inBlock:failure];
                                                       }];
    return operation;
}

#pragma mark - Registration operations
- (MXHTTPOperation *)testUserRegistration:(NSString *)username callback:(void (^)(MXError *mxError))callback
{
    // Trigger a fake registration to know whether the user name can be registered
    return [self registerWithParameters:@{@"username": username}
                                success:nil
                                failure:^(NSError *error)
            {
                // Retrieve the matrix error back
                MXError *mxError = [[MXError alloc] initWithNSError:error];
                callback(mxError);
            }];
}

- (MXHTTPOperation*)isUserNameInUse:(NSString*)username
                           callback:(void (^)(BOOL isUserNameInUse))callback
{
    return [self testUserRegistration:username callback:^(MXError *mxError) {

        BOOL isUserNameInUse = ([mxError.errcode isEqualToString:kMXErrCodeStringUserInUse]);
        callback(isUserNameInUse);
    }];
}

- (MXHTTPOperation*)getRegisterSession:(void (^)(MXAuthenticationSession *authSession))success
                               failure:(void (^)(NSError *error))failure
{
    // For registration, use POST with no params to get the login mechanism to use
    // The request will fail with Unauthorized status code, but the login mechanism will be available in response data.
    NSDictionary* parameters = nil;
    
    // Patch: Add the temporary `x_show_msisdn` flag to not filter the msisdn login type in the supported authentication flows.
    parameters = @{@"x_show_msisdn":@(YES)};

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:[self authActionPath:MXAuthActionRegister]
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXAuthenticationSession *authSession;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(authSession, MXAuthenticationSession, JSONResponse);
                                         } andCompletion:^{
                                             success(authSession);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);

                                     __block MXAuthenticationSession *authSession;
                                     [self dispatchProcessing:^{
                                         if (error.userInfo[MXHTTPClientErrorResponseDataKey])
                                         {
                                             // The auth session should be available in response data in case of unauthorized request.
                                             NSDictionary *JSONResponse = error.userInfo[MXHTTPClientErrorResponseDataKey];
                                             if (JSONResponse)
                                             {
                                                 MXJSONModelSetMXJSONModel(authSession, MXAuthenticationSession, JSONResponse);
                                             }
                                         }
                                     } andCompletion:^{
                                         if (authSession)
                                         {
                                             if (success)
                                             {
                                                 success(authSession);
                                             }
                                         }
                                         else if (failure)
                                         {
                                             failure(error);
                                         }
                                     }];
                                 }];
}

- (MXHTTPOperation*)registerWithParameters:(NSDictionary*)parameters
                                   success:(void (^)(NSDictionary *JSONResponse))success
                                   failure:(void (^)(NSError *error))failure
{
    return [self registerOrLogin:MXAuthActionRegister parameters:parameters success:success failure:failure];
}

- (MXHTTPOperation *)registerWithLoginType:(NSString *)loginType username:(NSString *)username password:(NSString *)password
                                   success:(void (^)(MXCredentials *))success
                                   failure:(void (^)(NSError *))failure
{
    if (![loginType isEqualToString:kMXLoginFlowTypePassword] && ![loginType isEqualToString:kMXLoginFlowTypeDummy])
    {
        [self dispatchFailure:nil inBlock:failure];
        return nil;
    }

    MXHTTPOperation *operation;
    MXWeakify(self);
    operation = [self getRegisterSession:^(MXAuthenticationSession *authSession) {
        MXStrongifyAndReturnIfNil(self);

        NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithDictionary:
                                           @{
                                             @"auth": @{
                                                     @"type": loginType,
                                                     @"session": authSession.session
                                                     },
                                             @"password": password
                                             }];
        if (username)
        {
            parameters[@"username"] = username;
        }

        MXWeakify(self);
        MXHTTPOperation *operation2 = [self registerWithParameters: parameters success:^(NSDictionary *JSONResponse) {
            MXStrongifyAndReturnIfNil(self);

            [self dispatchProcessing:nil andCompletion:^{

                MXLoginResponse *loginResponse;
                MXJSONModelSetMXJSONModel(loginResponse, MXLoginResponse, JSONResponse);

                // Update our credentials
                self->credentials = [[MXCredentials alloc] initWithLoginResponse:loginResponse
                                                           andDefaultCredentials:self.credentials];

                // Report the certificate trusted by user (if any)
                self->credentials.allowedCertificate = self->httpClient.allowedCertificate;

                // sanity check
                if (success)
                {
                    success(self->credentials);
                }
            }];
        } failure:^(NSError *error) {
            MXStrongifyAndReturnIfNil(self);
            [self dispatchFailure:error inBlock:failure];
        }];

        // Mutate MXHTTPOperation so that the user can cancel this new operation
        [operation mutateTo:operation2];

    } failure:^(NSError *error) {
        MXStrongifyAndReturnIfNil(self);
        [self dispatchFailure:error inBlock:failure];
    }];

    return operation;
}

- (NSString*)registerFallback;
{
    NSString *registerFallback;

    if (self.credentials.homeServer)
    {
        registerFallback = [[NSURL URLWithString:@"_matrix/static/client/register/" relativeToURL:[NSURL URLWithString:self.credentials.homeServer]] absoluteString];
    }
    return registerFallback;
}

- (MXHTTPOperation *)forgetPasswordForEmail:(NSString *)email
                               clientSecret:(NSString *)clientSecret
                                sendAttempt:(NSUInteger)sendAttempt
                                    success:(void (^)(NSString *sid))success
                                    failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/account/password/email/requestToken", apiPathPrefix];

    NSDictionary *parameters = @{
                                 @"email" : email,
                                 @"client_secret" : clientSecret,
                                 @"send_attempt" : @(sendAttempt),
                                 };

    MXWeakify(self);
    return [self requestTokenFromEndpoint:path parameters:parameters success:^(NSDictionary *JSONResponse) {
        MXStrongifyAndReturnIfNil(self);

        if (success)
        {
            __block NSString *sid;
            [self dispatchProcessing:^{
                MXJSONModelSetString(sid, JSONResponse[@"sid"]);
            } andCompletion:^{
                success(sid);
            }];
        }
    } failure:failure];
}

#pragma mark - Login operations
- (MXHTTPOperation*)getLoginSession:(void (^)(MXAuthenticationSession *authSession))success
                            failure:(void (^)(NSError *error))failure
{
    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:[self authActionPath:MXAuthActionLogin]
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXAuthenticationSession *authSession;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(authSession, MXAuthenticationSession, JSONResponse);
                                         } andCompletion:^{
                                             success(authSession);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)login:(NSDictionary*)parameters
                  success:(void (^)(NSDictionary *JSONResponse))success
                  failure:(void (^)(NSError *error))failure
{
    return [self registerOrLogin:MXAuthActionLogin parameters:parameters success:success failure:failure];
}

- (MXHTTPOperation *)loginWithLoginType:(NSString *)loginType username:(NSString *)username password:(NSString *)password
                                   success:(void (^)(MXCredentials *))success
                                   failure:(void (^)(NSError *))failure
{
    if (![loginType isEqualToString:kMXLoginFlowTypePassword])
    {
        [self dispatchFailure:nil inBlock:failure];
        return nil;
    }

    NSDictionary *parameters = @{
                                 @"type": loginType,
                                 @"identifier": @{
                                         @"type": kMXLoginIdentifierTypeUser,
                                         @"user": username
                                         },
                                 @"password": password,

                                 // Patch: add the old login api parameters to make dummy login
                                 // still working
                                 @"user": username
                                 };

    MXWeakify(self);
    return [self login:parameters
               success:^(NSDictionary *JSONResponse) {
                   [self dispatchProcessing:nil andCompletion:^{
                       MXStrongifyAndReturnIfNil(self);

                       MXLoginResponse *loginResponse;
                       MXJSONModelSetMXJSONModel(loginResponse, MXLoginResponse, JSONResponse);

                       // Update our credentials
                       self->credentials = [[MXCredentials alloc] initWithLoginResponse:loginResponse
                                                                  andDefaultCredentials:self.credentials];

                       // Report the certificate trusted by user (if any)
                       self->credentials.allowedCertificate = self->httpClient.allowedCertificate;

                       // sanity check
                       if (success)
                       {
                           success(self->credentials);
                       }
                   }];
               } failure:^(NSError *error) {
                   [self dispatchFailure:error inBlock:failure];
               }];
}

- (NSString*)loginFallback;
{
    NSString *loginFallback;

    if (self.credentials.homeServer)
    {
        loginFallback = [[NSURL URLWithString:@"/_matrix/static/client/login/" relativeToURL:[NSURL URLWithString:self.credentials.homeServer]] absoluteString];
    }
    return loginFallback;
}


#pragma mark - password update operation

- (MXHTTPOperation*)resetPasswordWithParameters:(NSDictionary*)parameters
                           success:(void (^)(void))success
                           failure:(void (^)(NSError *error))failure
{
    // sanity check
    if (!parameters)
    {
        NSError *error = [NSError errorWithDomain:kMXRestClientErrorDomain code:MXRestClientErrorInvalidParameters userInfo:nil];

        [self dispatchFailure:error inBlock:failure];
        return nil;
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:[NSString stringWithFormat:@"%@/account/password", apiPathPrefix]
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)changePassword:(NSString*)oldPassword with:(NSString*)newPassword
                           success:(void (^)(void))success
                           failure:(void (^)(NSError *error))failure
{
    // sanity check
    if (!oldPassword || !newPassword)
    {
        NSError *error = [NSError errorWithDomain:kMXRestClientErrorDomain code:MXRestClientErrorInvalidParameters userInfo:nil];

        [self dispatchFailure:error inBlock:failure];
        return nil;
    }

    NSDictionary *parameters = @{
                                 @"auth": @{
                                             @"type": kMXLoginFlowTypePassword,
                                             @"user": self.credentials.userId,
                                             @"password": oldPassword,
                                           },
                                 @"new_password": newPassword
                                 };

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:[NSString stringWithFormat:@"%@/account/password", apiPathPrefix]
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}


#pragma mark - Common operations for register and login
/*
 The only difference between register and login request are the path of the requests.
 The parameters and the responses are of the same types.
 So, use common functions to implement their functions.
 */

/**
 Return the home server path to use for register or for login actions.
 */
- (NSString*)authActionPath:(MXAuthAction)authAction
{
    NSString *authActionPath = @"login";
    if (MXAuthActionRegister == authAction)
    {
        authActionPath = @"register";
    }
    return [NSString stringWithFormat:@"%@/%@", apiPathPrefix, authActionPath];
}

- (MXHTTPOperation*)registerOrLogin:(MXAuthAction)authAction parameters:(NSDictionary *)parameters success:(void (^)(NSDictionary *JSONResponse))success failure:(void (^)(NSError *))failure
{
    // If the caller does not provide it, fill the device display name field with the device name
    // Do it only if parameters contains the password field, do make homeserver happy.
    if (parameters[@"password"])
    {
        NSMutableDictionary *newParameters;
        
        if (!parameters[@"initial_device_display_name"])
        {
            newParameters = [NSMutableDictionary dictionaryWithDictionary:parameters];
            
#if TARGET_OS_IPHONE
            NSString *deviceName = [UIDevice currentDevice].name;
#elif TARGET_OS_OSX
            NSString *deviceName = [NSHost currentHost].localizedName;
#endif
            newParameters[@"initial_device_display_name"] = deviceName;
        }
        
        if (MXAuthActionRegister == authAction)
        {
            // Patch: Add the temporary `x_show_msisdn` flag to not filter the msisdn login type in the supported authentication flows.
            if (!newParameters)
            {
                newParameters = [NSMutableDictionary dictionaryWithDictionary:parameters];
            }
            newParameters[@"x_show_msisdn"] = @(YES);
        }
        
        if (newParameters)
        {
            parameters = newParameters;
        }
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:[self authActionPath:authAction]
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         [self dispatchProcessing:nil andCompletion:^{
                                             success(JSONResponse);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)logout:(void (^)(void))success
                   failure:(void (^)(NSError *error))failure
{
    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:[NSString stringWithFormat:@"%@/logout", apiPathPrefix]
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)deactivateAccountWithAuthParameters:(NSDictionary*)authParameters
                                           eraseAccount:(BOOL)eraseAccount
                                                success:(void (^)(void))success
                                                failure:(void (^)(NSError *error))failure

{
    // authParameters are required
    if (!authParameters)
    {
        NSError *error = [NSError errorWithDomain:kMXRestClientErrorDomain code:MXRestClientErrorInvalidParameters userInfo:nil];
        
        [self dispatchFailure:error inBlock:failure];
        return nil;
    }
    
    NSDictionary *jsonBodyParameters = @{
                                         @"auth": authParameters,
                                         @"erase": @(eraseAccount)                                         
                                         };
    
    NSData *payloadData = [NSJSONSerialization dataWithJSONObject:jsonBodyParameters options:0 error:nil];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:[NSString stringWithFormat:@"%@/account/deactivate", apiPathPrefix]
                              parameters:nil
                                    data:payloadData
                                 headers:@{@"Content-Type": @"application/json"}
                                 timeout:-1
                          uploadProgress:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

#pragma mark - Account data
- (MXHTTPOperation*)setAccountData:(NSDictionary*)data
                           forType:(NSString*)type
                           success:(void (^)(void))success
                           failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/user/%@/account_data/%@", apiPathPrefix, credentials.userId, type];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"PUT"
                                    path:path
                              parameters:data
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}


#pragma mark - Filtering

- (MXHTTPOperation*)setFilter:(MXFilterJSONModel*)filter
                      success:(void (^)(NSString *filterId))success
                      failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/user/%@/filter", apiPathPrefix, credentials.userId];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:path
                              parameters:filter.JSONDictionary
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block NSString *filterId;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetString(filterId, JSONResponse[@"filter_id"]);
                                         }  andCompletion:^{
                                             success(filterId);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)getFilterWithFilterId:(NSString*)filterId
                                  success:(void (^)(MXFilterJSONModel *filter))success
                                  failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/user/%@/filter/%@", apiPathPrefix, credentials.userId, filterId];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXFilterJSONModel *filter;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(filter, MXFilterJSONModel, JSONResponse);
                                         }  andCompletion:^{
                                             success(filter);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation *)openIdToken:(void (^)(MXOpenIdToken *))success failure:(void (^)(NSError *))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/user/%@/openid/request_token", kMXAPIPrefixPathUnstable, credentials.userId];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:path
                              parameters:@{}
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXOpenIdToken *openIdToken;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(openIdToken, MXOpenIdToken, JSONResponse);
                                         } andCompletion:^{
                                             success(openIdToken);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}


#pragma mark - 3pid token request

- (MXHTTPOperation*)requestTokenForEmail:(NSString*)email
                    isDuringRegistration:(BOOL)isDuringRegistration
                            clientSecret:(NSString*)clientSecret
                             sendAttempt:(NSUInteger)sendAttempt
                                nextLink:(NSString*)nextLink
                                 success:(void (^)(NSString *sid))success
                                 failure:(void (^)(NSError *error))failure
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                      @"email": email,
                                                                                      @"client_secret": clientSecret,
                                                                                      @"send_attempt" : @(sendAttempt)
                                                                                      }];
    
    if (nextLink)
    {
        parameters[@"next_link"] = nextLink;
    }
    
    NSString *path;
    if (isDuringRegistration)
    {
        path = [NSString stringWithFormat:@"%@/register/email/requestToken", apiPathPrefix];
    }
    else
    {
        path = [NSString stringWithFormat:@"%@/account/3pid/email/requestToken", apiPathPrefix];
    }

    MXWeakify(self);
    return [self requestTokenFromEndpoint:path parameters:parameters success:^(NSDictionary *JSONResponse) {
        MXStrongifyAndReturnIfNil(self);

        if (success)
        {
            __block NSString *sid;
            [self dispatchProcessing:^{
                MXJSONModelSetString(sid, JSONResponse[@"sid"]);
            } andCompletion:^{
                success(sid);
            }];
        }
    } failure:failure];
}

- (MXHTTPOperation*)requestTokenForPhoneNumber:(NSString*)phoneNumber
                          isDuringRegistration:(BOOL)isDuringRegistration
                                   countryCode:(NSString*)countryCode
                                  clientSecret:(NSString*)clientSecret
                                   sendAttempt:(NSUInteger)sendAttempt
                                      nextLink:(NSString *)nextLink
                                       success:(void (^)(NSString *sid, NSString *msisdn, NSString *submitUrl))success
                                       failure:(void (^)(NSError *error))failure
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                      @"phone_number": phoneNumber,
                                                                                      @"country": (countryCode ? countryCode : @""),
                                                                                      @"client_secret": clientSecret,
                                                                                      @"send_attempt" : @(sendAttempt)
                                                                                      }];
    if (nextLink)
    {
        parameters[@"next_link"] = nextLink;
    }
    
    NSString *path;
    if (isDuringRegistration)
    {
        path = [NSString stringWithFormat:@"%@/register/msisdn/requestToken", apiPathPrefix];
    }
    else
    {
        path = [NSString stringWithFormat:@"%@/account/3pid/msisdn/requestToken", apiPathPrefix];
    }

    MXWeakify(self);
    return [self requestTokenFromEndpoint:path parameters:parameters success:^(NSDictionary *JSONResponse) {
        MXStrongifyAndReturnIfNil(self);

        if (success)
        {
            __block NSString *sid, *msisdn, *submitUrl;
            [self dispatchProcessing:^{
                MXJSONModelSetString(sid, JSONResponse[@"sid"]);
                MXJSONModelSetString(msisdn, JSONResponse[@"msisdn"]);
                MXJSONModelSetString(submitUrl, JSONResponse[@"submit_url"]);
            } andCompletion:^{
                success(sid, msisdn, submitUrl);
            }];
        }
    } failure:failure];
}


- (MXHTTPOperation*)requestTokenFromEndpoint:(NSString *)path
                                  parameters:(NSDictionary*)parameters
                                     success:(void (^)(NSDictionary *JSONResponse))success
                                     failure:(void (^)(NSError *error))failure
{
    MXHTTPOperation *operation;

    // If the HS supports separate add and bind, then requestToken endpoints
    // don't need an IS as they are all validated by the HS directly.
    MXWeakify(self);
    operation = [self supportedMatrixVersions:^(MXMatrixVersions *matrixVersions) {
        MXStrongifyAndReturnIfNil(self);

        if (!matrixVersions.doesServerSupportSeparateAddAndBind && self.identityServer)
        {
            NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];

            NSURL *identityServerURL = [NSURL URLWithString:self.identityServer];
            params[@"id_server"] = identityServerURL.host;

            MXWeakify(self);
            MXHTTPOperation *operation2 = [self addIdentityAccessTokenToParameters:params success:^(NSDictionary *updatedParameters) {
                MXStrongifyAndReturnIfNil(self);

                MXHTTPOperation *operation3 = [self requestTokenFromEndpoint2:path parameters:updatedParameters success:success failure:failure];
                
                [operation mutateTo:operation3];
                
            } failure:failure];
            
            [operation mutateTo:operation2];
        }
        else
        {
            MXHTTPOperation *operation2 = [self requestTokenFromEndpoint2:path parameters:parameters success:success failure:failure];
            
            [operation mutateTo:operation2];
        }
    } failure:failure];

    return operation;
}

- (MXHTTPOperation*)requestTokenFromEndpoint2:(NSString *)path
                                   parameters:(NSDictionary*)parameters
                                      success:(void (^)(NSDictionary *JSONResponse))success
                                      failure:(void (^)(NSError *error))failure
{
    return [httpClient requestWithMethod:@"POST"
                                    path:path
                              parameters:parameters
                                 success:success
                                 failure:^(NSError *error) {
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}


#pragma mark - Identity Server Parameters

// Add the "id_access_token" parameter if the HS requires it
- (MXHTTPOperation*)addIdentityAccessTokenToParameters:(NSDictionary *)parameters
                                               success:(void (^)(NSDictionary *updatedParameters))success
                                               failure:(void (^)(NSError *error))failure
{
    MXHTTPOperation *operation;

    operation = [self supportedMatrixVersions:^(MXMatrixVersions *matrixVersions) {

        MXHTTPOperation *operation2;
        if (matrixVersions.doesServerAcceptIdentityAccessToken)
        {
            if (self.identityServerAccessTokenHandler)
            {
                MXWeakify(self);
                operation2 = self.identityServerAccessTokenHandler(^(NSString *accessToken) {
                    MXStrongifyAndReturnIfNil(self);

                    if (accessToken)
                    {
                        NSMutableDictionary *updatedParameters = [NSMutableDictionary dictionaryWithDictionary:parameters];
                        updatedParameters[@"id_access_token"] = accessToken;

                        success(updatedParameters);
                    }
                    else
                    {
                        NSLog(@"[MXRestClient] addIdentityAccessTokenToParameters: Error: identityServerAccessTokenHandler returned no token");
                        NSError *error = [NSError errorWithDomain:kMXRestClientErrorDomain code:MXRestClientErrorMissingIdentityServerAccessToken userInfo:nil];
                        [self dispatchFailure:error inBlock:failure];
                    }

                }, ^(NSError *error) {
                    failure(error);
                });
            }
            else
            {
                NSLog(@"[MXRestClient] addIdentityAccessTokenToParameters: Error: No identityServerAccessTokenHandler");
                NSError *error = [NSError errorWithDomain:kMXRestClientErrorDomain code:MXRestClientErrorMissingIdentityServerAccessToken userInfo:nil];
                [self dispatchFailure:error inBlock:failure];
            }
        }
        else
        {
            success(parameters);
        }
        
        [operation mutateTo:operation2];

    } failure:failure];

    return operation;
}


#pragma mark - Push Notifications
- (MXHTTPOperation*)setPusherWithPushkey:(NSString *)pushkey
                                    kind:(NSObject *)kind
                                   appId:(NSString *)appId
                          appDisplayName:(NSString *)appDisplayName
                       deviceDisplayName:(NSString *)deviceDisplayName
                              profileTag:(NSString *)profileTag
                                    lang:(NSString *)lang
                                    data:(NSDictionary *)data
                                  append:(BOOL)append
                                 success:(void (^)(void))success
                                 failure:(void (^)(NSError *))failure
{
    // sanity check
    if (!pushkey || !kind || !appDisplayName || !deviceDisplayName || !profileTag || !lang || !data)
    {
        NSError *error = [NSError errorWithDomain:kMXRestClientErrorDomain code:MXRestClientErrorInvalidParameters userInfo:nil];

        NSLog(@"[MXRestClient] setPusherWithPushkey: Error: Invalid params: ");

        [self dispatchFailure:error inBlock:failure];
        return nil;
    }

    // Fill the request parameters on demand
    // Caution: parameters are JSON serialized in http body, we must use a NSNumber created with a boolean for append value.
    NSDictionary *parameters = @{
                                 @"pushkey": pushkey,
                                 @"kind": kind,
                                 @"app_id": appId,
                                 @"app_display_name": appDisplayName,
                                 @"device_display_name": deviceDisplayName,
                                 @"profile_tag": profileTag,
                                 @"lang": lang,
                                 @"data": data,
                                 @"append":[NSNumber numberWithBool:append]
                                 };

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:[NSString stringWithFormat:@"%@/pushers/set", apiPathPrefix]
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)pushers:(void (^)(NSArray<MXPusher *> *pushers))success
                    failure:(void (^)(NSError *))failure
{
    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:[NSString stringWithFormat:@"%@/pushers", apiPathPrefix]
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block NSArray<MXPusher *> *pushers;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModelArray(pushers, MXPusher, JSONResponse[@"pushers"]);
                                         } andCompletion:^{
                                             success(pushers);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation *)pushRules:(void (^)(MXPushRulesResponse *pushRules))success failure:(void (^)(NSError *))failure
{
    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:[NSString stringWithFormat:@"%@/pushrules/", apiPathPrefix]
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXPushRulesResponse *pushRules;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(pushRules, MXPushRulesResponse, JSONResponse);
                                         } andCompletion:^{
                                             success(pushRules);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation *)enablePushRule:(NSString*)ruleId
                              scope:(NSString*)scope
                               kind:(MXPushRuleKind)kind
                             enable:(BOOL)enable
                            success:(void (^)(void))success
                            failure:(void (^)(NSError *error))failure
{
    NSString *kindString;
    switch (kind)
    {
        case MXPushRuleKindOverride:
            kindString = @"override";
            break;
        case MXPushRuleKindContent:
            kindString = @"content";
            break;
        case MXPushRuleKindRoom:
            kindString = @"room";
            break;
        case MXPushRuleKindSender:
            kindString = @"sender";
            break;
        case MXPushRuleKindUnderride:
            kindString = @"underride";
            break;
    }
    
    NSDictionary *headers = @{@"Content-Type": @"application/json"};
    
    NSString *enabled = enable ? @"true": @"false";

    MXWeakify(self);
    return [httpClient requestWithMethod:@"PUT"
                                    path:[NSString stringWithFormat:@"%@/pushrules/%@/%@/%@/enabled", apiPathPrefix, scope, kindString, ruleId]
                              parameters:nil
                                    data:[enabled dataUsingEncoding:NSUTF8StringEncoding]
                                 headers:headers
                                 timeout:-1
                          uploadProgress:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation *)removePushRule:(NSString*)ruleId
                              scope:(NSString*)scope
                               kind:(MXPushRuleKind)kind
                            success:(void (^)(void))success
                            failure:(void (^)(NSError *error))failure
{
    NSString *kindString;
    switch (kind)
    {
        case MXPushRuleKindOverride:
            kindString = @"override";
            break;
        case MXPushRuleKindContent:
            kindString = @"content";
            break;
        case MXPushRuleKindRoom:
            kindString = @"room";
            break;
        case MXPushRuleKindSender:
            kindString = @"sender";
            break;
        case MXPushRuleKindUnderride:
            kindString = @"underride";
            break;
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"DELETE"
                                    path:[NSString stringWithFormat:@"%@/pushrules/%@/%@/%@", apiPathPrefix, scope, kindString, ruleId]
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation *)addPushRule:(NSString*)ruleId
                           scope:(NSString*)scope
                            kind:(MXPushRuleKind)kind
                         actions:(NSArray*)actions
                         pattern:(NSString*)pattern
                      conditions:(NSArray<NSDictionary *> *)conditions
                         success:(void (^)(void))success
                         failure:(void (^)(NSError *error))failure
{
    NSString *kindString;
    NSDictionary *content = nil;
    
    switch (kind)
    {
        case MXPushRuleKindOverride:
            kindString = @"override";
            if (conditions.count && actions.count)
            {
                content = @{@"conditions": conditions, @"actions": actions};
            }
            else if (actions.count)
            {
                content = @{@"actions": actions};
            }
            break;
        case MXPushRuleKindContent:
            kindString = @"content";
            if (pattern.length && actions.count)
            {
                content = @{@"pattern": pattern, @"actions": actions};
            }
            break;
        case MXPushRuleKindRoom:
            kindString = @"room";
            if (actions.count)
            {
                content = @{@"actions": actions};
            }
            break;
        case MXPushRuleKindSender:
            kindString = @"sender";
            if (actions.count)
            {
                content = @{@"actions": actions};
            }
            break;
        case MXPushRuleKindUnderride:
            kindString = @"underride";
            if (conditions.count && actions.count)
            {
                content = @{@"conditions": conditions, @"actions": actions};
            }
            else if (actions.count)
            {
                content = @{@"actions": actions};
            }
            break;
        default:
            break;
    }

    // Sanity check
    if (content)
    {
        MXWeakify(self);
        return [httpClient requestWithMethod:@"PUT"
                                        path:[NSString stringWithFormat:@"%@/pushrules/%@/%@/%@", apiPathPrefix, scope, kindString, ruleId]
                                  parameters:content
                                     success:^(NSDictionary *JSONResponse) {
                                         MXStrongifyAndReturnIfNil(self);
                                         [self dispatchSuccess:success];
                                     }
                                     failure:^(NSError *error) {
                                         MXStrongifyAndReturnIfNil(self);
                                         [self dispatchFailure:error inBlock:failure];
                                     }];
    }
    else
    {
        NSError *error = [NSError errorWithDomain:kMXRestClientErrorDomain code:MXRestClientErrorInvalidParameters userInfo:nil];
        [self dispatchFailure:error inBlock:failure];
        return nil;
    }
}

#pragma mark - Room operations
- (MXHTTPOperation *)sendEventToRoom:(NSString *)roomId
                           eventType:(MXEventTypeString)eventTypeString
                             content:(NSDictionary *)content
                               txnId:(NSString *)txnId
                             success:(void (^)(NSString *))success
                             failure:(void (^)(NSError *))failure
{
    if (!txnId.length)
    {
        // Create a random transaction id to prevent duplicated events
        txnId = [MXTools generateTransactionId];
    }

    // Prepare the path
    NSString *path = [NSString stringWithFormat:@"%@/rooms/%@/send/%@/%@",
                      apiPathPrefix,
                      roomId,
                      eventTypeString,
                      [MXTools encodeURIComponent:txnId]];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"PUT"
                                    path:path
                              parameters:content
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block NSString *eventId;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetString(eventId, JSONResponse[@"event_id"]);
                                         } andCompletion:^{
                                             success(eventId);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)sendStateEventToRoom:(NSString*)roomId
                               eventType:(MXEventTypeString)eventTypeString
                                 content:(NSDictionary*)content
                                stateKey:(NSString*)stateKey
                                 success:(void (^)(NSString *eventId))success
                                 failure:(void (^)(NSError *error))failure
{
    NSString *path;
    if (stateKey)
    {
        path = [NSString stringWithFormat:@"%@/rooms/%@/state/%@/%@",
                apiPathPrefix,
                roomId,
                eventTypeString,
                [MXTools encodeURIComponent:stateKey]];
    }
    else
    {
        path = [NSString stringWithFormat:@"%@/rooms/%@/state/%@", apiPathPrefix, roomId, eventTypeString];
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"PUT"
                                    path:path
                              parameters:content
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block NSString *eventId;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetString(eventId, JSONResponse[@"event_id"]);
                                         } andCompletion:^{
                                             success(eventId);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)sendMessageToRoom:(NSString*)roomId
                              msgType:(MXMessageType)msgType
                              content:(NSDictionary*)content
                              success:(void (^)(NSString *eventId))success
                              failure:(void (^)(NSError *error))failure
{
    // Add the messsage type to the data to send
    NSMutableDictionary *eventContent = [NSMutableDictionary dictionaryWithDictionary:content];
    eventContent[@"msgtype"] = msgType;
    
    return [self sendEventToRoom:roomId eventType:kMXEventTypeStringRoomMessage content:eventContent txnId:nil success:success failure:failure];
}

- (MXHTTPOperation*)sendTextMessageToRoom:(NSString*)roomId
                                     text:(NSString*)text
                                  success:(void (^)(NSString *eventId))success
                                  failure:(void (^)(NSError *error))failure
{
    return [self sendMessageToRoom:roomId msgType:kMXMessageTypeText
                           content:@{
                                     @"body": text
                                     }
                           success:success failure:failure];
}


// Generic methods to change membership
- (MXHTTPOperation*)doMembershipRequest:(NSString*)roomId
                             membership:(NSString*)membership
                             parameters:(NSDictionary*)parameters
                                success:(void (^)(void))success
                                failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/rooms/%@/%@", apiPathPrefix, roomId, membership];
    
    // A body is required even if empty
    if (nil == parameters)
    {
        parameters = @{};
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

/**
 Generic method to set the value of a state event of a room.

 @param eventType the type of the state event.
 @param value the value to set.
 @param roomId the id of the room.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)updateStateEvent:(MXEventTypeString)eventType
                        withValue:(NSDictionary*)value
                           inRoom:(NSString*)roomId
                          success:(void (^)(void))success
                          failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/rooms/%@/state/%@", apiPathPrefix, roomId, eventType];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"PUT"
                                    path:path
                              parameters:value
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

/**
 Generic method to get the value of a state event of a room.
 
 @param eventType the type of the state event.
 @param roomId the id of the room.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)valueOfStateEvent:(MXEventTypeString)eventType
                              inRoom:(NSString*)roomId
                             success:(void (^)(NSDictionary *JSONResponse))success
                             failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/rooms/%@/state/%@", apiPathPrefix, roomId, eventType];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         [self dispatchProcessing:nil andCompletion:^{
                                             success(JSONResponse);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)setRoomTopic:(NSString*)roomId
                           topic:(NSString*)topic
                         success:(void (^)(void))success
                         failure:(void (^)(NSError *error))failure
{
    return [self updateStateEvent:kMXEventTypeStringRoomTopic
                        withValue:@{
                                    @"topic": topic
                                    }
                           inRoom:roomId
                          success:success failure:failure];
}

- (MXHTTPOperation*)topicOfRoom:(NSString*)roomId
                        success:(void (^)(NSString *topic))success
                        failure:(void (^)(NSError *error))failure
{
    return [self valueOfStateEvent:kMXEventTypeStringRoomTopic
                            inRoom:roomId
                           success:^(NSDictionary *JSONResponse) {
                               if (success)
                               {
                                   __block NSString *topic;
                                   [self dispatchProcessing:^{
                                       MXJSONModelSetString(topic, JSONResponse[@"topic"]);
                                   } andCompletion:^{
                                       success(topic);
                                   }];
                               }
                           } failure:failure];
}


- (MXHTTPOperation *)setRoomAvatar:(NSString *)roomId
                            avatar:(NSString *)avatar
                           success:(void (^)(void))success
                           failure:(void (^)(NSError *))failure
{
    return [self updateStateEvent:kMXEventTypeStringRoomAvatar
                        withValue:@{
                                    @"url": avatar
                                    }
                           inRoom:roomId
                          success:success failure:failure];
}

- (MXHTTPOperation *)avatarOfRoom:(NSString *)roomId
                          success:(void (^)(NSString *))success
                          failure:(void (^)(NSError *))failure
{
    return [self valueOfStateEvent:kMXEventTypeStringRoomAvatar
                            inRoom:roomId
                           success:^(NSDictionary *JSONResponse) {
                               if (success)
                               {
                                   __block NSString *url;
                                   [self dispatchProcessing:^{
                                       MXJSONModelSetString(url, JSONResponse[@"url"]);
                                   } andCompletion:^{
                                       success(url);
                                   }];
                               }
                           } failure:failure];
}

- (MXHTTPOperation*)setRoomName:(NSString*)roomId
                           name:(NSString*)name
                        success:(void (^)(void))success
                        failure:(void (^)(NSError *error))failure
{
    return [self updateStateEvent:kMXEventTypeStringRoomName
                        withValue:@{
                                    @"name": name
                                    }
                           inRoom:roomId
                          success:success failure:failure];
}

- (MXHTTPOperation*)nameOfRoom:(NSString*)roomId
                       success:(void (^)(NSString *name))success
                       failure:(void (^)(NSError *error))failure
{
    return [self valueOfStateEvent:kMXEventTypeStringRoomName
                            inRoom:roomId
                           success:^(NSDictionary *JSONResponse) {
                               if (success)
                               {
                                   __block NSString *name;
                                   [self dispatchProcessing:^{
                                       MXJSONModelSetString(name, JSONResponse[@"name"]);
                                   } andCompletion:^{
                                       success(name);
                                   }];
                               }
                           } failure:failure];
}

- (MXHTTPOperation *)setRoomHistoryVisibility:(NSString *)roomId
                            historyVisibility:(MXRoomHistoryVisibility)historyVisibility
                                      success:(void (^)(void))success
                                      failure:(void (^)(NSError *))failure
{
    return [self updateStateEvent:kMXEventTypeStringRoomHistoryVisibility
                        withValue:@{
                                    @"history_visibility": historyVisibility
                                    }
                           inRoom:roomId
                          success:success failure:failure];
}

- (MXHTTPOperation *)historyVisibilityOfRoom:(NSString *)roomId
                                     success:(void (^)(MXRoomHistoryVisibility historyVisibility))success
                                     failure:(void (^)(NSError *))failure
{
    return [self valueOfStateEvent:kMXEventTypeStringRoomHistoryVisibility
                            inRoom:roomId
                           success:^(NSDictionary *JSONResponse) {
                               if (success)
                               {
                                   __block NSString *historyVisibility;
                                   [self dispatchProcessing:^{
                                       MXJSONModelSetString(historyVisibility, JSONResponse[@"history_visibility"]);
                                   } andCompletion:^{
                                       success(historyVisibility);
                                   }];
                               }
                           } failure:failure];
}

- (MXHTTPOperation*)setRoomJoinRule:(NSString*)roomId
                           joinRule:(MXRoomJoinRule)joinRule
                            success:(void (^)(void))success
                            failure:(void (^)(NSError *error))failure
{
    return [self updateStateEvent:kMXEventTypeStringRoomJoinRules
                        withValue:@{
                                    @"join_rule": joinRule
                                    }
                           inRoom:roomId
                          success:success failure:failure];
}

- (MXHTTPOperation*)joinRuleOfRoom:(NSString*)roomId
                           success:(void (^)(MXRoomJoinRule joinRule))success
                           failure:(void (^)(NSError *error))failure
{
    return [self valueOfStateEvent:kMXEventTypeStringRoomJoinRules
                            inRoom:roomId
                           success:^(NSDictionary *JSONResponse) {
                               if (success)
                               {
                                   __block MXRoomJoinRule joinRule;
                                   [self dispatchProcessing:^{
                                       MXJSONModelSetString(joinRule, JSONResponse[@"join_rule"]);
                                   } andCompletion:^{
                                       success(joinRule);
                                   }];
                               }
                           } failure:failure];
}

- (MXHTTPOperation*)setRoomGuestAccess:(NSString*)roomId
                           guestAccess:(MXRoomGuestAccess)guestAccess
                               success:(void (^)(void))success
                               failure:(void (^)(NSError *error))failure
{
    return [self updateStateEvent:kMXEventTypeStringRoomGuestAccess
                        withValue:@{
                                    @"guest_access": guestAccess
                                    }
                           inRoom:roomId
                          success:success failure:failure];
}

- (MXHTTPOperation*)guestAccessOfRoom:(NSString*)roomId
                              success:(void (^)(MXRoomGuestAccess guestAccess))success
                              failure:(void (^)(NSError *error))failure
{
    return [self valueOfStateEvent:kMXEventTypeStringRoomGuestAccess
                            inRoom:roomId
                           success:^(NSDictionary *JSONResponse) {
                               if (success)
                               {
                                   __block MXRoomGuestAccess guestAccess;
                                   [self dispatchProcessing:^{
                                       MXJSONModelSetString(guestAccess, JSONResponse[@"guest_access"]);
                                   } andCompletion:^{
                                       success(guestAccess);
                                   }];
                               }
                           } failure:failure];
}

- (MXHTTPOperation*)setRoomDirectoryVisibility:(NSString*)roomId
                           directoryVisibility:(MXRoomDirectoryVisibility)directoryVisibility
                                       success:(void (^)(void))success
                                       failure:(void (^)(NSError *error))failure
{
    
    NSString *path = [NSString stringWithFormat:@"%@/directory/list/room/%@", apiPathPrefix, roomId];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"PUT"
                                    path:path
                              parameters:@{
                                           @"visibility": directoryVisibility
                                           }
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)directoryVisibilityOfRoom:(NSString*)roomId
                                      success:(void (^)(MXRoomDirectoryVisibility directoryVisibility))success
                                      failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/directory/list/room/%@", apiPathPrefix, roomId];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXRoomDirectoryVisibility directoryVisibility;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetString(directoryVisibility, JSONResponse[@"visibility"]);
                                         } andCompletion:^{
                                             success(directoryVisibility);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)addRoomAlias:(NSString*)roomId
                           alias:(NSString*)roomAlias
                         success:(void (^)(void))success
                         failure:(void (^)(NSError *error))failure
{
    // Note: characters in a room alias need to be escaped in the URL
    NSString *path = [NSString stringWithFormat:@"%@/directory/room/%@",
                      apiPathPrefix,
                      [MXTools encodeURIComponent:roomAlias]];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"PUT"
                                    path:path
                              parameters:@{
                                           @"room_id": roomId
                                           }
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)removeRoomAlias:(NSString*)roomAlias
                            success:(void (^)(void))success
                            failure:(void (^)(NSError *error))failure
{
    // Note: characters in a room alias need to be escaped in the URL
    NSString *path = [NSString stringWithFormat:@"%@/directory/room/%@",
                      apiPathPrefix,
                      [MXTools encodeURIComponent:roomAlias]];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"DELETE"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)setRoomCanonicalAlias:(NSString*)roomId
                           canonicalAlias:(NSString *)canonicalAlias
                                  success:(void (^)(void))success
                                  failure:(void (^)(NSError *error))failure
{
    return [self updateStateEvent:kMXEventTypeStringRoomCanonicalAlias
                        withValue:@{
                                    @"alias": canonicalAlias
                                    }
                           inRoom:roomId
                          success:success failure:failure];
}

- (MXHTTPOperation*)canonicalAliasOfRoom:(NSString*)roomId
                                 success:(void (^)(NSString *canonicalAlias))success
                                 failure:(void (^)(NSError *error))failure
{
    return [self valueOfStateEvent:kMXEventTypeStringRoomCanonicalAlias
                            inRoom:roomId
                           success:^(NSDictionary *JSONResponse) {
                               if (success)
                               {
                                   __block NSString *alias;
                                   [self dispatchProcessing:^{
                                       MXJSONModelSetString(alias, JSONResponse[@"alias"]);
                                   } andCompletion:^{
                                       success(alias);
                                   }];
                               }
                           } failure:failure];
}


- (MXHTTPOperation*)joinRoom:(NSString*)roomIdOrAlias
                     success:(void (^)(NSString *theRoomId))success
                     failure:(void (^)(NSError *error))failure
{
    return [self joinRoom:roomIdOrAlias viaServers:nil withThirdPartySigned:nil success:success failure:failure];
}

- (MXHTTPOperation*)joinRoom:(NSString*)roomIdOrAlias
                  viaServers:(NSArray<NSString*>*)viaServers
        withThirdPartySigned:(NSDictionary*)thirdPartySigned
                     success:(void (^)(NSString *theRoomId))success
                     failure:(void (^)(NSError *error))failure
{
    NSDictionary *parameters;
    if (thirdPartySigned)
    {
        parameters = @{
                       @"third_party_signed":thirdPartySigned
                       };
    }

    // Characters in a room alias need to be escaped in the URL
    NSString *path = [NSString stringWithFormat:@"%@/join/%@",
                      apiPathPrefix,
                      [MXTools encodeURIComponent:roomIdOrAlias]];

    // Add all servers as query parameters
    if (viaServers.count)
    {
        NSMutableString *queryParameters;
        for (NSString *viaServer in viaServers)
        {
            NSString *value = [MXTools encodeURIComponent:viaServer];

            if (!queryParameters)
            {
                queryParameters = [NSMutableString stringWithFormat:@"?server_name=%@", value];
            }
            else
            {
                [queryParameters appendFormat:@"&server_name=%@", value];
            }
        }

        path = [path stringByAppendingString:queryParameters];
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block NSString *roomId;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetString(roomId, JSONResponse[@"room_id"]);
                                             if (!roomId.length)
                                             {
                                                 roomId = roomIdOrAlias;
                                             }
                                         } andCompletion:^{
                                             success(roomId);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)leaveRoom:(NSString*)roomId
                      success:(void (^)(void))success
                      failure:(void (^)(NSError *error))failure
{
    return [self doMembershipRequest:roomId
                          membership:@"leave"
                          parameters:nil
                             success:success failure:failure];
}

- (MXHTTPOperation*)inviteUser:(NSString*)userId
                        toRoom:(NSString*)roomId
                       success:(void (^)(void))success
                       failure:(void (^)(NSError *error))failure
{
    return [self doMembershipRequest:roomId
                          membership:@"invite"
                          parameters:@{
                                       @"user_id": userId
                                       }
                             success:success failure:failure];
}

- (MXHTTPOperation*)inviteUserByEmail:(NSString*)email
                               toRoom:(NSString*)roomId
                              success:(void (^)(void))success
                              failure:(void (^)(NSError *error))failure
{
    return [self inviteByThreePid:kMX3PIDMediumEmail
                          address:email
                           toRoom:roomId
                          success:success failure:failure];
}

- (MXHTTPOperation*)inviteByThreePid:(NSString*)medium
                             address:(NSString*)address
                              toRoom:(NSString*)roomId
                             success:(void (^)(void))success
                             failure:(void (^)(NSError *error))failure
{
    // The identity server must be defined
    if (!self.identityServer)
    {
        NSError *error = [NSError errorWithDomain:kMXRestClientErrorDomain code:MXRestClientErrorMissingIdentityServer userInfo:nil];
        [self dispatchFailure:error inBlock:failure];
        return nil;
    }

    // This request must not have the protocol part
    NSString *identityServer = self.identityServer;
    if ([identityServer hasPrefix:@"http://"] || [identityServer hasPrefix:@"https://"])
    {
        identityServer = [identityServer substringFromIndex:[identityServer rangeOfString:@"://"].location + 3];
    }

    NSDictionary *parameters = @{
                                 @"id_server": identityServer,
                                 @"medium": medium,
                                 @"address": address
                                 };

    MXHTTPOperation *operation;

    MXWeakify(self);
    operation = [self addIdentityAccessTokenToParameters:parameters success:^(NSDictionary *updatedParameters) {
        MXStrongifyAndReturnIfNil(self);

        MXHTTPOperation *operation2 = [self inviteByThreePidToRoom:roomId parameters:parameters success:success failure:failure];
        
        [operation mutateTo:operation2];

    } failure:failure];

    return operation;
}

- (MXHTTPOperation*)inviteByThreePidToRoom:(NSString*)roomId
                                parameters:(NSDictionary*)parameters
                                   success:(void (^)(void))success
                                   failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/rooms/%@/invite", apiPathPrefix, roomId];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)kickUser:(NSString*)userId
                    fromRoom:(NSString*)roomId
                      reason:(NSString*)reason
                     success:(void (^)(void))success
                     failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/rooms/%@/state/m.room.member/%@",
                      apiPathPrefix,
                      roomId,
                      [MXTools encodeURIComponent:userId]];
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"membership"] = @"kick";
    
    if (reason)
    {
        parameters[@"reason"] = reason;
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"PUT"
                                    path:path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)banUser:(NSString*)userId
                     inRoom:(NSString*)roomId
                     reason:(NSString*)reason
                    success:(void (^)(void))success
                    failure:(void (^)(NSError *error))failure
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"user_id"] = userId;
    
    if (reason)
    {
        parameters[@"reason"] = reason;
    }
    
    return [self doMembershipRequest:roomId
                          membership:@"ban"
                          parameters:parameters
                             success:success failure:failure];
}

- (MXHTTPOperation*)unbanUser:(NSString*)userId
                       inRoom:(NSString*)roomId
                      success:(void (^)(void))success
                      failure:(void (^)(NSError *error))failure
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"user_id"] = userId;

    return [self doMembershipRequest:roomId
                          membership:@"unban"
                          parameters:parameters
                             success:success
                             failure:failure];
}

- (MXHTTPOperation*)createRoom:(NSString*)name
                    visibility:(MXRoomDirectoryVisibility)visibility
                     roomAlias:(NSString*)roomAlias
                         topic:(NSString*)topic
                       success:(void (^)(MXCreateRoomResponse *response))success
                       failure:(void (^)(NSError *error))failure
{
    // All parameters are optional. Fill the request parameters on demand
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
    if (name)
    {
        parameters[@"name"] = name;
    }
    if (visibility)
    {
        parameters[@"visibility"] = visibility;
    }
    if (roomAlias)
    {
        parameters[@"room_alias_name"] = roomAlias;
    }
    if (topic)
    {
        parameters[@"topic"] = topic;
    }
    
    return [self createRoom:parameters success:success failure:failure];
}

- (MXHTTPOperation*)createRoomWithParameters:(MXRoomCreationParameters*)parameters
                                     success:(void (^)(MXCreateRoomResponse *response))success
                                     failure:(void (^)(NSError *error))failure
{
    return [self createRoom:parameters.JSONDictionary success:success failure:failure];
}

- (MXHTTPOperation*)createRoom:(NSDictionary*)parameters
                       success:(void (^)(MXCreateRoomResponse *response))success
                       failure:(void (^)(NSError *error))failure;
{
    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:[NSString stringWithFormat:@"%@/createRoom", apiPathPrefix]
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXCreateRoomResponse *response;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(response, MXCreateRoomResponse, JSONResponse);
                                         } andCompletion:^{
                                             success(response);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)messagesForRoom:(NSString*)roomId
                               from:(NSString*)from
                          direction:(MXTimelineDirection)direction
                              limit:(NSUInteger)limit
                             filter:(MXRoomEventFilter*)roomEventFilter
                            success:(void (^)(MXPaginationResponse *paginatedResponse))success
                            failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/rooms/%@/messages", apiPathPrefix, roomId];
    
    // All query parameters are optional. Fill the request parameters on demand
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    parameters[@"from"] = from;

    if (direction == MXTimelineDirectionForwards)
    {
        parameters[@"dir"] = @"f";
    }
    else
    {
        parameters[@"dir"] = @"b";
    }
    if (-1 != limit)
    {
        parameters[@"limit"] = [NSNumber numberWithUnsignedInteger:limit];
    }
    
    if (roomEventFilter.dictionary.count)
    {
        parameters[@"filter"] = roomEventFilter.jsonString;
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXPaginationResponse *paginatedResponse;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(paginatedResponse, MXPaginationResponse, JSONResponse);
                                         } andCompletion:^{
                                             success(paginatedResponse);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)membersOfRoom:(NSString*)roomId
                          success:(void (^)(NSArray *roomMemberEvents))success
                          failure:(void (^)(NSError *error))failure
{
    return [self membersOfRoom:roomId withParameters:nil success:success failure:failure];
}

- (MXHTTPOperation*)membersOfRoom:(NSString*)roomId
                   withParameters:(NSDictionary*)parameters
                          success:(void (^)(NSArray *roomMemberEvents))success
                          failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/rooms/%@/members", apiPathPrefix, roomId];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block NSArray *roomMemberEvents;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModelArray(roomMemberEvents, MXEvent, JSONResponse[@"chunk"]);
                                         } andCompletion:^{
                                             success(roomMemberEvents);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)stateOfRoom:(NSString*)roomId
                        success:(void (^)(NSDictionary *JSONData))success
                        failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/rooms/%@/state", apiPathPrefix, roomId];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         [self dispatchProcessing:nil andCompletion:^{
                                             success(JSONResponse);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)sendTypingNotificationInRoom:(NSString*)roomId
                                          typing:(BOOL)typing
                                         timeout:(NSUInteger)timeout
                                         success:(void (^)(void))success
                                         failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/rooms/%@/typing/%@",
                      apiPathPrefix,
                      roomId,
                      [MXTools encodeURIComponent:self.credentials.userId]];
    
    // Fill the request parameters on demand
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    // Caution: parameters are JSON serialized in http body, we must use a NSNumber created with a boolean for typing value.
    parameters[@"typing"] = [NSNumber numberWithBool:typing];
    if (-1 != timeout)
    {
        parameters[@"timeout"] = [NSNumber numberWithUnsignedInteger:timeout];
    }

    MXWeakify(self);
    MXHTTPOperation *operation = [httpClient requestWithMethod:@"PUT"
                                                          path:path
                                                    parameters:parameters
                                                       success:^(NSDictionary *JSONResponse) {
                                                           MXStrongifyAndReturnIfNil(self);
                                                           [self dispatchSuccess:success];
                                                       }
                                                       failure:^(NSError *error) {
                                                           MXStrongifyAndReturnIfNil(self);
                                                           [self dispatchFailure:error inBlock:failure];
                                                       }];
    
    // Disable retry for typing notification as it is a very ephemeral piece of information
    operation.maxNumberOfTries = 1;
    
    return operation;
}

- (MXHTTPOperation*)redactEvent:(NSString*)eventId
                         inRoom:(NSString*)roomId
                         reason:(NSString*)reason
                        success:(void (^)(void))success
                        failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/rooms/%@/redact/%@",
                      apiPathPrefix,
                      roomId,
                      [MXTools encodeURIComponent:eventId]];
    
    // All query parameters are optional. Fill the request parameters on demand
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    if (reason)
    {
        parameters[@"reason"] = reason;
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

-(MXHTTPOperation *)reportEvent:(NSString *)eventId
                         inRoom:(NSString *)roomId
                          score:(NSInteger)score
                         reason:(NSString *)reason
                        success:(void (^)(void))success
                        failure:(void (^)(NSError *))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/rooms/%@/report/%@",
                      apiPathPrefix,
                      roomId,
                      [MXTools encodeURIComponent:eventId]];

    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                      @"score": @(score)
                                                                                      }];
    // Reason is optional
    if (reason)
    {
        parameters[@"reason"] = reason;
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)initialSyncOfRoom:(NSString*)roomId
                            withLimit:(NSInteger)limit
                              success:(void (^)(MXRoomInitialSync *roomInitialSync))success
                              failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/rooms/%@/initialSync", apiPathPrefix, roomId];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:@{
                                           @"limit": [NSNumber numberWithInteger:limit]
                                           }
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXRoomInitialSync *roomInitialSync;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(roomInitialSync, MXRoomInitialSync, JSONResponse);
                                         } andCompletion:^{
                                             success(roomInitialSync);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)eventWithEventId:(NSString*)eventId
                             success:(void (^)(MXEvent *event))success
                             failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/events/%@",
                      apiPathPrefix,
                      [MXTools encodeURIComponent:eventId]];

    MXHTTPOperation *operation;
    MXWeakify(self);
    operation = [httpClient requestWithMethod:@"GET"
                                         path:path
                                   parameters:nil
                                      success:^(NSDictionary *JSONResponse) {
                                          MXStrongifyAndReturnIfNil(self);

                                          if (success)
                                          {
                                              __block MXEvent *event;
                                              [self dispatchProcessing:^{
                                                  MXJSONModelSetMXJSONModel(event, MXEvent, JSONResponse);
                                              } andCompletion:^{
                                                  success(event);
                                              }];
                                          }
                                      }
                                      failure:^(NSError *error) {
                                          MXStrongifyAndReturnIfNil(self);
                                          [self dispatchFailure:error inBlock:failure];
                                      }];
    return operation;
}

- (MXHTTPOperation*)eventWithEventId:(NSString*)eventId
                              inRoom:(NSString*)roomId
                             success:(void (^)(MXEvent *event))success
                             failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/rooms/%@/event/%@",
                      apiPathPrefix,
                      roomId,
                      [MXTools encodeURIComponent:eventId]];

    MXHTTPOperation *operation;
    MXWeakify(self);
    operation = [httpClient requestWithMethod:@"GET"
                                         path:path
                                   parameters:nil
                                      success:^(NSDictionary *JSONResponse) {
                                          MXStrongifyAndReturnIfNil(self);

                                          if (success)
                                          {
                                              __block MXEvent *event;
                                              [self dispatchProcessing:^{
                                                  MXJSONModelSetMXJSONModel(event, MXEvent, JSONResponse);
                                              } andCompletion:^{
                                                  success(event);
                                              }];
                                          }
                                      }
                                      failure:^(NSError *error) {
                                          MXStrongifyAndReturnIfNil(self);

                                          // The HS may not support the `/rooms/{roomId}/event/{eventId}` API yet.
                                          // Try to use the older `/context` API as fallback
                                          MXError *mxError = [[MXError alloc] initWithNSError:error];
                                          if (mxError && [mxError.errcode isEqualToString:kMXErrCodeStringUnrecognized])
                                          {
                                              NSLog(@"[MXRestClient] eventWithEventId: The homeserver does not support `/rooms/{roomId}/event/{eventId}` API. Try with `/context`");

                                              MXHTTPOperation *operation2 = [self contextOfEvent:eventId inRoom:roomId limit:1 filter:nil success:^(MXEventContext *eventContext) {

                                                  if (success)
                                                  {
                                                      success(eventContext.event);
                                                  }

                                              } failure:failure];

                                              [operation mutateTo:operation2];
                                              return;
                                          }

                                          [self dispatchFailure:error inBlock:failure];
                                      }];
    return operation;
}

- (MXHTTPOperation*)contextOfEvent:(NSString*)eventId
                            inRoom:(NSString*)roomId
                             limit:(NSUInteger)limit
                            filter:(MXRoomEventFilter*)filter
                           success:(void (^)(MXEventContext *eventContext))success
                           failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/rooms/%@/context/%@",
                      apiPathPrefix,
                      roomId,
                      [MXTools encodeURIComponent:eventId]];

    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"limit"] = @(limit);

    if (filter)
    {
        parameters[@"filter"] = filter.jsonString;
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXEventContext *eventContext;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(eventContext, MXEventContext, JSONResponse);
                                         } andCompletion:^{
                                             success(eventContext);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)setRoomRelatedGroups:(NSString *)roomId
                           relatedGroups:(NSArray<NSString *> *)relatedGroups
                                 success:(void (^)(void))success
                                 failure:(void (^)(NSError *))failure
{
    return [self updateStateEvent:kMXEventTypeStringRoomRelatedGroups
                        withValue:@{
                                    @"groups": relatedGroups
                                    }
                           inRoom:roomId
                          success:success failure:failure];
}

- (MXHTTPOperation*)relatedGroupsOfRoom:(NSString *)roomId
                                success:(void (^)(NSArray<NSString *> *))success
                                failure:(void (^)(NSError *))failure
{
    return [self valueOfStateEvent:kMXEventTypeStringRoomRelatedGroups
                            inRoom:roomId
                           success:^(NSDictionary *JSONResponse) {
                               if (success)
                               {
                                   __block NSArray<NSString *> *relatedGroups;
                                   [self dispatchProcessing:^{
                                       MXJSONModelSetArray(relatedGroups, JSONResponse[@"groups"]);
                                   } andCompletion:^{
                                       success(relatedGroups);
                                   }];
                               }
                           } failure:failure];
}

#pragma mark - Room tags operations
- (MXHTTPOperation*)tagsOfRoom:(NSString*)roomId
                       success:(void (^)(NSArray<MXRoomTag*> *tags))success
                       failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/user/%@/rooms/%@/tags", apiPathPrefix, credentials.userId, roomId];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     NSMutableArray *tags = [NSMutableArray array];
                                     [self dispatchProcessing:^{
                                         // Sort the response into an array of MXRoomTags
                                         for (NSString *tagName in JSONResponse[@"tags"])
                                         {
                                             MXRoomTag *tag = [[MXRoomTag alloc] initWithName:tagName andOrder:JSONResponse[@"tags"][tagName][@"order"]];
                                             [tags addObject:tag];
                                         }
                                     } andCompletion:^{
                                         success(tags);
                                     }];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)addTag:(NSString*)tag
                 withOrder:(NSString*)order
                    toRoom:(NSString*)roomId
                   success:(void (^)(void))success
                   failure:(void (^)(NSError *error))failure
{
   NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    if (order)
    {
        parameters[@"order"] = order;
    }

    NSString *path = [NSString stringWithFormat:@"%@/user/%@/rooms/%@/tags/%@", apiPathPrefix, credentials.userId, roomId, tag];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"PUT"
                                    path:path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)removeTag:(NSString*)tag
                     fromRoom:(NSString*)roomId
                      success:(void (^)(void))success
                      failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/user/%@/rooms/%@/tags/%@", apiPathPrefix, credentials.userId, roomId, tag];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"DELETE"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}


#pragma mark - Profile operations
- (MXHTTPOperation*)setDisplayName:(NSString*)displayname
                           success:(void (^)(void))success
                           failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/profile/%@/displayname", apiPathPrefix, credentials.userId];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"PUT"
                                    path:path
                              parameters:@{
                                           @"displayname": displayname
                                           }
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)displayNameForUser:(NSString*)userId
                               success:(void (^)(NSString *displayname))success
                               failure:(void (^)(NSError *error))failure
{
    if (!userId)
    {
        userId = credentials.userId;
    }
    
    NSString *path = [NSString stringWithFormat:@"%@/profile/%@/displayname",
                      apiPathPrefix,
                      [MXTools encodeURIComponent:userId]];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block NSString *displayname;
                                         [self dispatchProcessing:^{
                                             NSDictionary *cleanedJSONResponse = [MXJSONModel removeNullValuesInJSON:JSONResponse];
                                             MXJSONModelSetString(displayname, cleanedJSONResponse[@"displayname"]);
                                         } andCompletion:^{
                                             success(displayname);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)setAvatarUrl:(NSString*)avatarUrl
                         success:(void (^)(void))success
                         failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/profile/%@/avatar_url", apiPathPrefix, credentials.userId];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"PUT"
                                    path:path
                              parameters:@{
                                           @"avatar_url": avatarUrl
                                           }
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)avatarUrlForUser:(NSString*)userId
                             success:(void (^)(NSString *avatarUrl))success
                             failure:(void (^)(NSError *error))failure
{
    if (!userId)
    {
        userId = credentials.userId;
    }
    
    NSString *path = [NSString stringWithFormat:@"%@/profile/%@/avatar_url",
                      apiPathPrefix,
                      [MXTools encodeURIComponent:userId]];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block NSString *avatarUrl;
                                         [self dispatchProcessing:^{
                                             NSDictionary *cleanedJSONResponse = [MXJSONModel removeNullValuesInJSON:JSONResponse];
                                             MXJSONModelSetString(avatarUrl, cleanedJSONResponse[@"avatar_url"]);
                                         } andCompletion:^{
                                             success(avatarUrl);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)profileForUser:(NSString*)userId
                           success:(void (^)(NSString *displayName, NSString *avatarUrl))success
                           failure:(void (^)(NSError *error))failure
{
    if (!userId)
    {
        userId = credentials.userId;
    }
    
    NSString *path = [NSString stringWithFormat:@"%@/profile/%@",
                      apiPathPrefix,
                      [MXTools encodeURIComponent:userId]];
    
    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     
                                     if (success)
                                     {
                                         __block NSString *displayName;
                                         __block NSString *avatarUrl;
                                         [self dispatchProcessing:^{
                                             NSDictionary *cleanedJSONResponse = [MXJSONModel removeNullValuesInJSON:JSONResponse];
                                             MXJSONModelSetString(displayName, cleanedJSONResponse[@"displayname"]);
                                             MXJSONModelSetString(avatarUrl, cleanedJSONResponse[@"avatar_url"]);
                                         } andCompletion:^{
                                             success(displayName, avatarUrl);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)add3PID:(NSString*)sid
               clientSecret:(NSString*)clientSecret
                       bind:(BOOL)bind
                    success:(void (^)(void))success
                    failure:(void (^)(NSError *error))failure
{
    if (!self.identityServer)
    {
        NSLog(@"[MXRestClient] add3PID: Error: Missing identityServer");
        NSError *error = [NSError errorWithDomain:kMXRestClientErrorDomain code:MXRestClientErrorMissingIdentityServer userInfo:nil];
        [self dispatchFailure:error inBlock:failure];
        return nil;
    }

    NSURL *identityServerURL = [NSURL URLWithString:self.credentials.identityServer];
    NSDictionary *parameters = @{
                                 @"three_pid_creds": @{
                                         @"id_server": identityServerURL.host,
                                         @"sid": sid,
                                         @"client_secret": clientSecret
                                         },
                                 @"bind": @(bind)
                                 };

    NSString *path = [NSString stringWithFormat:@"%@/account/3pid", apiPathPrefix];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)add3PIDOnlyWithSessionId:(NSString*)sid
                                clientSecret:(NSString*)clientSecret
                                  authParams:(NSDictionary*)authParameters
                                     success:(void (^)(void))success
                                     failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/account/3pid/add", kMXAPIPrefixPathUnstable];

    NSMutableDictionary *parameters = [@{
                                 @"sid": sid,
                                 @"client_secret": clientSecret
                                 } mutableCopy];

    if (authParameters)
    {
        parameters[@"auth"] = authParameters;
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)remove3PID:(NSString*)address
                        medium:(NSString*)medium
                       success:(void (^)(void))success
                       failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/account/3pid/delete", kMXAPIPrefixPathUnstable];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:path
                              parameters:@{
                                           @"medium": medium,
                                           @"address": address
                                           }
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)threePIDs:(void (^)(NSArray<MXThirdPartyIdentifier*> *threePIDs))success
                      failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/account/3pid", apiPathPrefix];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block NSArray<MXThirdPartyIdentifier*> *threePIDs;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModelArray(threePIDs, MXThirdPartyIdentifier, JSONResponse[@"threepids"]);
                                         } andCompletion:^{
                                             success(threePIDs);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)bind3PidWithSessionId:(NSString*)sid
                             clientSecret:(NSString*)clientSecret
                                  success:(void (^)(void))success
                                  failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/account/3pid/bind", kMXAPIPrefixPathUnstable];

    if (!self.identityServer)
    {
        NSLog(@"[MXRestClient] bind3PidWithSessionId: Error: Missing identityServer");
        NSError *error = [NSError errorWithDomain:kMXRestClientErrorDomain code:MXRestClientErrorMissingIdentityServer userInfo:nil];
        [self dispatchFailure:error inBlock:failure];
        return nil;
    }

    NSURL *identityServerURL = [NSURL URLWithString:self.credentials.identityServer];
    NSDictionary *parameters = @{
                                 @"id_server": identityServerURL.host,
                                 @"sid": sid,
                                 @"client_secret": clientSecret
                                 };

    MXWeakify(self);
    __block MXHTTPOperation *operation;
    operation = [self addIdentityAccessTokenToParameters:parameters success:^(NSDictionary *updatedParameters) {
        MXStrongifyAndReturnIfNil(self);

        MXHTTPOperation *operation2 = [self->httpClient requestWithMethod:@"POST"
                                                               path:path
                                                         parameters:updatedParameters
                                                            success:^(NSDictionary *JSONResponse) {
                                                                MXStrongifyAndReturnIfNil(self);

                                                                if (success)
                                                                {
                                                                    [self dispatchProcessing:nil
                                                                               andCompletion:success];
                                                                }
                                                            }
                                                            failure:^(NSError *error) {
                                                                MXStrongifyAndReturnIfNil(self);
                                                                [self dispatchFailure:error inBlock:failure];
                                                            }];
        
        [operation mutateTo:operation2];

    } failure:^(NSError *error) {
        MXStrongifyAndReturnIfNil(self);
        [self dispatchFailure:error inBlock:failure];
    }];

    return operation;
}

- (MXHTTPOperation*)unbind3PidWithAddress:(NSString*)address
                                   medium:(NSString*)medium
                                  success:(void (^)(void))success
                                  failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/account/3pid/unbind", kMXAPIPrefixPathUnstable];

    if (!self.identityServer)
    {
        NSLog(@"[MXRestClient] add3PID: Error: Missing identityServer");
        NSError *error = [NSError errorWithDomain:kMXRestClientErrorDomain code:MXRestClientErrorMissingIdentityServer userInfo:nil];
        [self dispatchFailure:error inBlock:failure];
        return nil;
    }

    NSURL *identityServerURL = [NSURL URLWithString:self.credentials.identityServer];
    NSDictionary *parameters = @{
                                 @"id_server": identityServerURL.host,
                                 @"medium": medium,
                                 @"address": address
                                 };

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         [self dispatchProcessing:nil
                                                    andCompletion:success];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}


#pragma mark - Presence operations
- (MXHTTPOperation*)setPresence:(MXPresence)presence andStatusMessage:(NSString*)statusMessage
                        success:(void (^)(void))success
                        failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/presence/%@/status", apiPathPrefix, credentials.userId];
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"presence"] = [MXTools presenceString:presence];
    if (statusMessage)
    {
        parameters[@"status_msg"] = statusMessage;
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"PUT"
                                    path:path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)presence:(NSString*)userId
                     success:(void (^)(MXPresenceResponse *presence))success
                     failure:(void (^)(NSError *error))failure
{
    if (!userId)
    {
        userId = credentials.userId;
    }
    
    NSString *path = [NSString stringWithFormat:@"%@/presence/%@/status", apiPathPrefix,
                      [MXTools encodeURIComponent:userId]];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXPresenceResponse *presence;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(presence, MXPresenceResponse, JSONResponse);
                                         } andCompletion:^{
                                             success(presence);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)presenceList:(void (^)(MXPresenceResponse *presence))success
                         failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/presence/list/%@", apiPathPrefix, credentials.userId];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXPresenceResponse *presence;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(presence, MXPresenceResponse, JSONResponse);
                                         } andCompletion:^{
                                             success(presence);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)presenceListAddUsers:(NSArray*)users
                                 success:(void (^)(void))success
                                 failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/presence/list/%@", apiPathPrefix, credentials.userId];
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"invite"] = users;

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}


#pragma mark - Sync
- (MXHTTPOperation *)syncFromToken:(NSString*)token
                     serverTimeout:(NSUInteger)serverTimeout
                     clientTimeout:(NSUInteger)clientTimeout
                       setPresence:(NSString*)setPresence
                            filter:(NSString*)filterId
                           success:(void (^)(MXSyncResponse *syncResponse))success
                           failure:(void (^)(NSError *error))failure
{
    // Fill the url parameters (CAUTION: boolean value must be true or false string)
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
    if (token)
    {
        parameters[@"since"] = token;
    }
    if (-1 != serverTimeout)
    {
        parameters[@"timeout"] = [NSNumber numberWithInteger:serverTimeout];
    }
    if (setPresence)
    {
        parameters[@"set_presence"] = setPresence;
    }
    if (filterId)
    {
        parameters[@"filter"] = filterId;
    }
    
    NSTimeInterval clientTimeoutInSeconds = clientTimeout;
    if (-1 != clientTimeoutInSeconds)
    {
        // If the Internet connection is lost, this timeout is used to be able to
        // cancel the current request and notify the client so that it can retry with a new request.
        clientTimeoutInSeconds = clientTimeoutInSeconds / 1000;
    }

    MXWeakify(self);
    MXHTTPOperation *operation = [httpClient requestWithMethod:@"GET"
                                                          path:[NSString stringWithFormat:@"%@/sync", apiPathPrefix]
                                                    parameters:parameters timeout:clientTimeoutInSeconds
                                                       success:^(NSDictionary *JSONResponse) {
                                                           MXStrongifyAndReturnIfNil(self);

                                                           if (success)
                                                           {
                                                               __block MXSyncResponse *syncResponse;
                                                               [self dispatchProcessing:^{
                                                                   MXJSONModelSetMXJSONModel(syncResponse, MXSyncResponse, JSONResponse);
                                                               } andCompletion:^{
                                                                   success(syncResponse);
                                                               }];
                                                           }
                                                       }
                                                       failure:^(NSError *error) {
                                                           MXStrongifyAndReturnIfNil(self);
                                                           [self dispatchFailure:error inBlock:failure];
                                                       }];
    
    // Disable retry because it interferes with clientTimeout
    // Let the client manage retries on events streams
    operation.maxNumberOfTries = 1;
    
    return operation;
}


#pragma mark - read receipt
- (MXHTTPOperation*)sendReadReceipt:(NSString*)roomId
                            eventId:(NSString*)eventId
                            success:(void (^)(void))success
                            failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/rooms/%@/receipt/m.read/%@",
                      apiPathPrefix,
                      roomId,
                      [MXTools encodeURIComponent:eventId]];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:path
                              parameters:[[NSDictionary alloc] init]
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
    
}

#pragma mark - read marker
- (MXHTTPOperation*)sendReadMarker:(NSString*)roomId
                 readMarkerEventId:(NSString*)readMarkerEventId
                readReceiptEventId:(NSString*)readReceiptEventId
                           success:(void (^)(void))success
                           failure:(void (^)(NSError *error))failure
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    if (readMarkerEventId)
    {
        parameters[@"m.fully_read"] = readMarkerEventId;
    }
    if (readReceiptEventId)
    {
        parameters[@"m.read"] = readReceiptEventId;
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:[NSString stringWithFormat:@"%@/rooms/%@/read_markers", apiPathPrefix, roomId]
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

#pragma mark - Directory operations
- (MXHTTPOperation *)publicRoomsOnServer:(NSString *)server
                                   limit:(NSInteger)limit
                                   since:(NSString *)since
                                  filter:(NSString *)filter
                    thirdPartyInstanceId:(NSString *)thirdPartyInstanceId
                      includeAllNetworks:(BOOL)includeAllNetworks
                                 success:(void (^)(MXPublicRoomsResponse *))success
                                 failure:(void (^)(NSError *))failure
{
    NSString* path = [NSString stringWithFormat:@"%@/publicRooms", apiPathPrefix];
    if (server)
    {
        path = [NSString stringWithFormat:@"%@?server=%@", path, server];
    }

    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    if (-1 != limit)
    {
        parameters[@"limit"] = @(limit);
    }
    if (since)
    {
        parameters[@"since"] = since;
    }
    if (filter)
    {
        parameters[@"filter"] = @{
                                  @"generic_search_term": filter
                                  };
    }
    if (thirdPartyInstanceId)
    {
        parameters[@"third_party_instance_id"] = thirdPartyInstanceId;
    }
    if (includeAllNetworks)
    {
        parameters[@"include_all_networks"] = @(YES);
    }

    NSString *method = @"POST";
    if (parameters.count == 0)
    {
        // If there is no parameter, use the legacy API. It does not required an access token.
        method = @"GET";
        parameters = nil;
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:method
                                    path:path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXPublicRoomsResponse *publicRoomsResponse;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(publicRoomsResponse, MXPublicRoomsResponse, JSONResponse);
                                         } andCompletion:^{
                                             success(publicRoomsResponse);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)roomIDForRoomAlias:(NSString*)roomAlias
                               success:(void (^)(NSString *roomId))success
                               failure:(void (^)(NSError *error))failure
{
    // Note: characters in a room alias need to be escaped in the URL
    NSString *path = [NSString stringWithFormat:@"%@/directory/room/%@",
                      apiPathPrefix,
                      [MXTools encodeURIComponent:roomAlias]];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block NSString *roomId;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetString(roomId, JSONResponse[@"room_id"]);
                                         } andCompletion:^{
                                             success(roomId);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}


#pragma mark - Third party Lookup API
- (MXHTTPOperation*)thirdpartyProtocols:(void (^)(MXThirdpartyProtocolsResponse *thirdpartyProtocolsResponse))success
                                failure:(void (^)(NSError *error))failure;
{
    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:[NSString stringWithFormat:@"%@/thirdparty/protocols", kMXAPIPrefixPathUnstable]
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXThirdpartyProtocolsResponse *thirdpartyProtocolsResponse;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(thirdpartyProtocolsResponse, MXThirdpartyProtocolsResponse, JSONResponse);
                                         } andCompletion:^{
                                             success(thirdpartyProtocolsResponse);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}


#pragma mark - Media Repository API
- (MXHTTPOperation*) uploadContent:(NSData *)data
                          filename:(NSString*)filename
                          mimeType:(NSString *)mimeType
                           timeout:(NSTimeInterval)timeoutInSeconds
                           success:(void (^)(NSString *url))success
                           failure:(void (^)(NSError *error))failure
                    uploadProgress:(void (^)(NSProgress *uploadProgress))uploadProgress
{
    // Define an absolute path based on Matrix content respository path instead of the base url
    NSString* path = [NSString stringWithFormat:@"%@/upload", contentPathPrefix];
    NSDictionary *headers = @{@"Content-Type": mimeType};

    if (filename.length)
    {
        path = [path stringByAppendingString:[NSString stringWithFormat:@"?filename=%@", [MXTools encodeURIComponent:filename]]];
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:path
                              parameters:nil
                                    data:data
                                 headers:headers
                                 timeout:timeoutInSeconds
                          uploadProgress:uploadProgress
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block NSString *contentURL;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetString(contentURL, JSONResponse[@"content_uri"]);
                                         } andCompletion:^{
                                             success(contentURL);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

#pragma mark - Antivirus server API
- (void)setAntivirusServer:(NSString *)antivirusServer
{
    if (antivirusServer.length)
    {
        _antivirusServer = [antivirusServer copy];
        antivirusHttpClient = [[MXHTTPClient alloc] initWithBaseURL:[NSString stringWithFormat:@"%@/%@", antivirusServer, antivirusServerPathPrefix]
                                  andOnUnrecognizedCertificateBlock:nil];
    }
    else
    {
        // Disable antivirus requests
        _antivirusServer = nil;
        antivirusHttpClient = nil;
    }
}

- (MXHTTPOperation*)getAntivirusServerPublicKey:(void (^)(NSString *publicKey))success
                                        failure:(void (^)(NSError *error))failure
{
    MXWeakify(self);
    return [antivirusHttpClient requestWithMethod:@"GET"
                                             path:@"public_key"
                                       parameters:nil
                                          success:^(NSDictionary *JSONResponse) {
                                              MXStrongifyAndReturnIfNil(self);
                                              if (success)
                                              {
                                                  __block NSString *publicKey;
                                                  [self dispatchProcessing:^{
                                                      MXJSONModelSetString(publicKey, JSONResponse[@"public_key"]);
                                                  } andCompletion:^{
                                                      success(publicKey);
                                                  }];
                                              }
                                          }
                                          failure:^(NSError *error) {
                                              MXStrongifyAndReturnIfNil(self);
                                              [self dispatchFailure:error inBlock:failure];
                                          }];
}

- (MXHTTPOperation*)scanUnencryptedContent:(NSString*)mxcContentURI
                       success:(void (^)(MXContentScanResult *scanResult))success
                       failure:(void (^)(NSError *error))failure
{
    // Sanity check
    if (![mxcContentURI hasPrefix:kMXContentUriScheme])
    {
        // do not scan non-mxc content URLs
        NSError *error = [NSError errorWithDomain:kMXRestClientErrorDomain code:MXRestClientErrorInvalidContentURI userInfo:nil];
        [self dispatchFailure:error inBlock:failure];
        return nil;
    }
    
    // Build request path by replacing the "mxc://" scheme
    NSString *path = [mxcContentURI stringByReplacingOccurrencesOfString:kMXContentUriScheme withString:@"scan/"];
    MXWeakify(self);
    return [antivirusHttpClient requestWithMethod:@"GET"
                                            path:path
                                      parameters:nil
                                         success:^(NSDictionary *JSONResponse) {
                                             MXStrongifyAndReturnIfNil(self);
                                             if (success)
                                             {
                                                 __block MXContentScanResult *scanResult;
                                                 [self dispatchProcessing:^{
                                                     MXJSONModelSetMXJSONModel(scanResult, MXContentScanResult, JSONResponse);
                                                 } andCompletion:^{
                                                     success(scanResult);
                                                 }];
                                             }
                                         }
                                         failure:^(NSError *error) {
                                             MXStrongifyAndReturnIfNil(self);
                                             [self dispatchFailure:error inBlock:failure];
                                         }];
}

- (MXHTTPOperation*)scanEncryptedContent:(MXEncryptedContentFile*)encryptedContentFile
                                 success:(void (^)(MXContentScanResult *scanResult))success
                                 failure:(void (^)(NSError *error))failure
{
    NSData *payloadData = nil;
    if (encryptedContentFile)
    {
        payloadData = [NSJSONSerialization dataWithJSONObject:@{@"file": encryptedContentFile.JSONDictionary} options:0 error:nil];
    }
    
    MXWeakify(self);
    return [antivirusHttpClient requestWithMethod:@"POST"
                                             path:@"scan_encrypted"
                                       parameters:nil
                                             data:payloadData
                                          headers:@{@"Content-Type": @"application/json"}
                                          timeout:-1
                                   uploadProgress:nil
                                          success:^(NSDictionary *JSONResponse) {
                                              MXStrongifyAndReturnIfNil(self);
                                              if (success)
                                              {
                                                  __block MXContentScanResult *scanResult;
                                                  [self dispatchProcessing:^{
                                                      MXJSONModelSetMXJSONModel(scanResult, MXContentScanResult, JSONResponse);
                                                  } andCompletion:^{
                                                      success(scanResult);
                                                  }];
                                              }
                                          }
                                          failure:^(NSError *error) {
                                              MXStrongifyAndReturnIfNil(self);
                                              [self dispatchFailure:error inBlock:failure];
                                          }];
}

- (MXHTTPOperation*)scanEncryptedContentWithSecureExchange:(MXContentScanEncryptedBody *)encryptedbody
                                                   success:(void (^)(MXContentScanResult *scanResult))success
                                                   failure:(void (^)(NSError *error))failure
{
    NSData *payloadData = nil;
    if (encryptedbody)
    {
        payloadData = [NSJSONSerialization dataWithJSONObject:@{@"encrypted_body": encryptedbody.JSONDictionary} options:0 error:nil];
    }
    
    MXWeakify(self);
    return [antivirusHttpClient requestWithMethod:@"POST"
                                             path:@"scan_encrypted"
                                       parameters:nil
                                             data:payloadData
                                          headers:@{@"Content-Type": @"application/json"}
                                          timeout:-1
                                   uploadProgress:nil
                                          success:^(NSDictionary *JSONResponse) {
                                              MXStrongifyAndReturnIfNil(self);
                                              if (success)
                                              {
                                                  __block MXContentScanResult *scanResult;
                                                  [self dispatchProcessing:^{
                                                      MXJSONModelSetMXJSONModel(scanResult, MXContentScanResult, JSONResponse);
                                                  } andCompletion:^{
                                                      success(scanResult);
                                                  }];
                                              }
                                          }
                                          failure:^(NSError *error) {
                                              MXStrongifyAndReturnIfNil(self);
                                              [self dispatchFailure:error inBlock:failure];
                                          }];
}

#pragma mark - Certificates

-(void)setPinnedCertificates:(NSSet <NSData *> *)pinnedCertificates
{
    httpClient.pinnedCertificates = pinnedCertificates;
}

- (void)setPinnedCertificates:(NSSet<NSData *> *)pinnedCertificates withPinningMode:(MXHTTPClientSSLPinningMode)pinningMode
{
    [httpClient setPinnedCertificates:pinnedCertificates withPinningMode:pinningMode];
}

#pragma mark - VoIP API
- (MXHTTPOperation *)turnServer:(void (^)(MXTurnServerResponse *))success
                        failure:(void (^)(NSError *))failure
{
    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:[NSString stringWithFormat:@"%@/voip/turnServer", apiPathPrefix]
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXTurnServerResponse *turnServerResponse;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(turnServerResponse, MXTurnServerResponse, JSONResponse);
                                         } andCompletion:^{
                                             success(turnServerResponse);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

#pragma mark - Search
- (MXHTTPOperation*)searchMessagesWithText:(NSString*)textPattern
                           roomEventFilter:(MXRoomEventFilter*)roomEventFilter
                               beforeLimit:(NSUInteger)beforeLimit
                                afterLimit:(NSUInteger)afterLimit
                                 nextBatch:(NSString*)nextBatch
                                   success:(void (^)(MXSearchRoomEventResults *roomEventResults))success
                                   failure:(void (^)(NSError *error))failure
{
    NSMutableDictionary *roomEventsParameters = [NSMutableDictionary dictionaryWithDictionary:
                                                 @{
                                                   @"search_term": textPattern,
                                                   @"order_by": @"recent",
                                                   @"event_context": @{
                                                           @"before_limit": @(beforeLimit),
                                                           @"after_limit": @(afterLimit),
                                                           @"include_profile": @(YES)
                                                           }
                                                   }];
    
    if (roomEventFilter.dictionary.count)
    {
        roomEventsParameters[@"filter"] = roomEventFilter.dictionary;
    }

    return [self searchRoomEvents:roomEventsParameters nextBatch:nextBatch success:success failure:failure];
}

- (MXHTTPOperation*)search:(NSDictionary*)parameters
                 nextBatch:(NSString*)nextBatch
                   success:(void (^)(MXSearchRoomEventResults *roomEventResults))success
                   failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/search", apiPathPrefix];
    if (nextBatch)
    {
        path = [NSString stringWithFormat:@"%@?next_batch=%@", path, nextBatch];
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path: path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXSearchResponse *searchResponse;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(searchResponse, MXSearchResponse, JSONResponse);
                                         } andCompletion:^{
                                             success(searchResponse.searchCategories.roomEvents);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

// Shorcut for calling [self search] without needing to manage top hierarchy parameters
- (MXHTTPOperation*)searchRoomEvents:(NSDictionary*)roomEventsParameters
                           nextBatch:(NSString*)nextBatch
                   success:(void (^)(MXSearchRoomEventResults *roomEventResults))success
                   failure:(void (^)(NSError *error))failure
{
    NSDictionary *parameters = @{
                                 @"search_categories": @{
                                         @"room_events": roomEventsParameters
                                         }
                                 };

    return [self search:parameters nextBatch:nextBatch success:success failure:failure];
}

- (MXHTTPOperation*)searchUsers:(NSString*)pattern
                          limit:(NSUInteger)limit
                        success:(void (^)(MXUserSearchResponse *userSearchResponse))success
                        failure:(void (^)(NSError *error))failure
{
    NSDictionary *parameters = @{
                                 @"search_term": pattern,
                                 @"limit": @(limit)
                                 };

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:[NSString stringWithFormat:@"%@/user_directory/search", apiPathPrefix]
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXUserSearchResponse *userSearchResponse;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(userSearchResponse, MXUserSearchResponse, JSONResponse);
                                         } andCompletion:^{
                                             success(userSearchResponse);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}


#pragma mark - Crypto
- (MXHTTPOperation*)uploadKeys:(NSDictionary*)deviceKeys oneTimeKeys:(NSDictionary*)oneTimeKeys
                     forDevice:(NSString*)deviceId
                       success:(void (^)(MXKeysUploadResponse *keysUploadResponse))success
                       failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/keys/upload", kMXAPIPrefixPathR0];
    if (deviceId)
    {
        path = [NSString stringWithFormat:@"%@/%@",
                path,
                [MXTools encodeURIComponent:deviceId]];
    }

    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    if (deviceKeys)
    {
        parameters[@"device_keys"] = deviceKeys;
    }
    if (oneTimeKeys)
    {
        parameters[@"one_time_keys"] = oneTimeKeys;
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path: path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXKeysUploadResponse *keysUploadResponse;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(keysUploadResponse, MXKeysUploadResponse, JSONResponse);
                                         } andCompletion:^{
                                             success(keysUploadResponse);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)uploadKeySignatures:(NSDictionary*)signatures
                                success:(void (^)(void))success
                                failure:(void (^)(NSError *error))failure
{
    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:[NSString stringWithFormat:@"%@/keys/signatures/upload", kMXAPIPrefixPathR0]
                              parameters:signatures
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         [self dispatchProcessing:nil
                                                    andCompletion:^{
                                                        success();
                                                    }];
                                     }
                                 } failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)downloadKeysForUsers:(NSArray<NSString*>*)userIds
                                   token:(NSString *)token
                                 success:(void (^)(MXKeysQueryResponse *keysQueryResponse))success
                                 failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/keys/query", kMXAPIPrefixPathR0];

    NSMutableDictionary *downloadQuery = [NSMutableDictionary dictionary];
    for (NSString *userID in userIds)
    {
        downloadQuery[userID] = @{};
    }

    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                      @"device_keys": downloadQuery
                                                                                      }];

    if (token)
    {
        parameters[@"token"] = token;
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path: path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXKeysQueryResponse *keysQueryResponse;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(keysQueryResponse, MXKeysQueryResponse, JSONResponse);
                                         } andCompletion:^{
                                             success(keysQueryResponse);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation *)claimOneTimeKeysForUsersDevices:(MXUsersDevicesMap<NSString *> *)usersDevicesKeyTypesMap success:(void (^)(MXKeysClaimResponse *))success failure:(void (^)(NSError *))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/keys/claim", kMXAPIPrefixPathR0];

    NSDictionary *parameters = @{
                                 @"one_time_keys": usersDevicesKeyTypesMap.map
                                 };


    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path: path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXKeysClaimResponse *keysClaimResponse;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(keysClaimResponse, MXKeysClaimResponse, JSONResponse);
                                         } andCompletion:^{
                                             success(keysClaimResponse);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation *)keyChangesFrom:(NSString *)fromToken to:(NSString *)toToken
                            success:(void (^)(MXDeviceListResponse *deviceLists))success
                            failure:(void (^)(NSError *))failure
{
    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:[NSString stringWithFormat:@"%@/keys/changes", kMXAPIPrefixPathR0]
                              parameters:@{
                                           @"from": fromToken,
                                           @"to": toToken
                                           }
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXDeviceListResponse *deviceLists;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(deviceLists, MXDeviceListResponse, JSONResponse);
                                         } andCompletion:^{
                                             success(deviceLists);
                                         }];
                                     }
                                 } failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}


#pragma mark - Crypto: e2e keys backup
- (MXHTTPOperation*)createKeyBackupVersion:(MXKeyBackupVersion*)keyBackupVersion
                                   success:(void (^)(NSString *version))success
                                   failure:(void (^)(NSError *error))failure
{
    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:[NSString stringWithFormat:@"%@/room_keys/version", kMXAPIPrefixPathR0]
                              parameters:keyBackupVersion.JSONDictionary
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block NSString *version;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetString(version, JSONResponse[@"version"]);
                                         } andCompletion:^{
                                             success(version);
                                         }];
                                     }
                                 } failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)updateKeyBackupVersion:(MXKeyBackupVersion*)keyBackupVersion
                                   success:(void (^)(void))success
                                   failure:(void (^)(NSError *error))failure
{
    MXWeakify(self);
    return [httpClient requestWithMethod:@"PUT"
                                    path:[NSString stringWithFormat:@"%@/room_keys/version/%@", kMXAPIPrefixPathR0, keyBackupVersion.version]
                              parameters:keyBackupVersion.JSONDictionary
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         [self dispatchProcessing:nil
                                                    andCompletion:^{
                                                        success();
                                                    }];
                                     }
                                 } failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)deleteKeyBackupVersion:(NSString*)version
                                   success:(void (^)(void))success
                                   failure:(void (^)(NSError *error))failure
{
    NSMutableString *path = [NSMutableString stringWithFormat:@"%@/room_keys/version", kMXAPIPrefixPathR0];
    if (version)
    {
        [path appendFormat:@"/%@", version];
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"DELETE"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         [self dispatchProcessing:nil
                                                    andCompletion:^{
                                                        success();
                                                    }];
                                     }
                                 } failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)keyBackupVersion:(NSString*)version
                             success:(void (^)(MXKeyBackupVersion *keyBackupVersion))success
                             failure:(void (^)(NSError *error))failure;
{
    NSMutableString *path = [NSMutableString stringWithFormat:@"%@/room_keys/version", kMXAPIPrefixPathR0];
    if (version)
    {
        [path appendFormat:@"/%@", version];
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXKeyBackupVersion *keyBackupVersion;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(keyBackupVersion, MXKeyBackupVersion, JSONResponse);
                                         } andCompletion:^{
                                             success(keyBackupVersion);
                                         }];
                                     }
                                 } failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)sendKeyBackup:(MXKeyBackupData*)keyBackupData
                             room:(NSString*)roomId
                          session:(NSString*)sessionId
                          version:(NSString*)version
                          success:(void (^)(void))success
                          failure:(void (^)(NSError *error))failure
{
    NSString *path = [self keyBackupPath:roomId session:sessionId version:version];
    if (!path || !keyBackupData || !roomId || !sessionId)
    {
        NSLog(@"[MXRestClient] sendKeyBackup: ERROR: Bad parameters");
        [self dispatchFailure:nil inBlock:failure];
        return nil;
    }

    return [self sendBackup:keyBackupData.JSONDictionary path:path success:success failure:failure];
}

- (MXHTTPOperation*)sendRoomKeysBackup:(MXRoomKeysBackupData*)roomKeysBackupData
                                  room:(NSString*)roomId
                               version:(NSString*)version
                               success:(void (^)(void))success
                               failure:(void (^)(NSError *error))failure
{
    NSString *path = [self keyBackupPath:roomId session:nil version:version];
    if (!path || !roomKeysBackupData || !roomId)
    {
        NSLog(@"[MXRestClient] sendRoomKeysBackup: ERROR: Bad parameters");
        [self dispatchFailure:nil inBlock:failure];
        return nil;
    }

    return [self sendBackup:roomKeysBackupData.JSONDictionary path:path success:success failure:failure];
}

- (MXHTTPOperation*)sendKeysBackup:(MXKeysBackupData*)keysBackupData
                           version:(NSString*)version
                           success:(void (^)(void))success
                           failure:(void (^)(NSError *error))failure
{
    NSString *path = [self keyBackupPath:nil session:nil version:version];
    if (!path || !keysBackupData)
    {
        NSLog(@"[MXRestClient] sendKeysBackup: ERROR: Bad parameters");
        [self dispatchFailure:nil inBlock:failure];
        return nil;
    }

    return [self sendBackup:keysBackupData.JSONDictionary path:path success:success failure:failure];
}

- (MXHTTPOperation*)sendBackup:(NSDictionary*)backupData
                          path:(NSString*)path
                       success:(void (^)(void))success
                       failure:(void (^)(NSError *error))failure
{
    MXWeakify(self);
    return [httpClient requestWithMethod:@"PUT"
                                    path:path
                              parameters:backupData
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         [self dispatchProcessing:nil
                                                    andCompletion:^{
                                                        success();
                                                    }];
                                     }
                                 } failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)keyBackupForSession:(NSString*)sessionId
                                 inRoom:(NSString*)roomId
                                version:(NSString*)version
                                success:(void (^)(MXKeyBackupData *keyBackupData))success
                                failure:(void (^)(NSError *error))failure
{
    NSString *path = [self keyBackupPath:roomId session:sessionId version:version];
    if (!path || !roomId || !sessionId)
    {
        NSLog(@"[MXRestClient] keyBackup: ERROR: Bad parameters");
        [self dispatchFailure:nil inBlock:failure];
        return nil;
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXKeyBackupData *keyBackupData;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(keyBackupData, MXKeyBackupData, JSONResponse);
                                         } andCompletion:^{
                                             success(keyBackupData);
                                         }];
                                     }
                                 } failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)keysBackupInRoom:(NSString*)roomId
                             version:(NSString*)version
                             success:(void (^)(MXRoomKeysBackupData *roomKeysBackupData))success
                             failure:(void (^)(NSError *error))failure
{
    NSString *path = [self keyBackupPath:roomId session:nil version:version];
    if (!path || !roomId)
    {
        NSLog(@"[MXRestClient] roomKeysBackup: ERROR: Bad parameters");
        [self dispatchFailure:nil inBlock:failure];
        return nil;
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXRoomKeysBackupData *roomKeysBackupData;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(roomKeysBackupData, MXRoomKeysBackupData, JSONResponse);
                                         } andCompletion:^{
                                             success(roomKeysBackupData);
                                         }];
                                     }
                                 } failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)keysBackup:(NSString*)version
                       success:(void (^)(MXKeysBackupData *keysBackupData))success
                       failure:(void (^)(NSError *error))failure;
{
    NSString *path = [self keyBackupPath:nil session:nil version:version];
    if (!path)
    {
        NSLog(@"[MXRestClient] keysBackup: ERROR: Bad parameters");
        [self dispatchFailure:nil inBlock:failure];
        return nil;
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXKeysBackupData *keysBackupData;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(keysBackupData, MXKeysBackupData, JSONResponse);
                                         } andCompletion:^{
                                             success(keysBackupData);
                                         }];
                                     }
                                 } failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)deleteKeyFromBackup:(NSString*)roomId
                                session:(NSString*)sessionId
                                version:(NSString*)version
                                success:(void (^)(void))success
                                failure:(void (^)(NSError *error))failure
{
    NSString *path = [self keyBackupPath:roomId session:sessionId version:version];
    if (!path || !roomId || !sessionId)
    {
        NSLog(@"[MXRestClient] deleteKeyFromBackup: ERROR: Bad parameters");
        [self dispatchFailure:nil inBlock:failure];
        return nil;
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"DELETE"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         [self dispatchProcessing:nil
                                                    andCompletion:^{
                                                        success();
                                                    }];
                                     }
                                 } failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)deleteKeysInRoomFromBackup:(NSString*)roomId
                                       version:(NSString*)version
                                       success:(void (^)(void))success
                                       failure:(void (^)(NSError *error))failure
{
    NSString *path = [self keyBackupPath:roomId session:nil version:version];
    if (!path || !roomId)
    {
        NSLog(@"[MXRestClient] deleteKeysInRoomFromBackup: ERROR: Bad parameters");
        [self dispatchFailure:nil inBlock:failure];
        return nil;
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"DELETE"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         [self dispatchProcessing:nil
                                                    andCompletion:^{
                                                        success();
                                                    }];
                                     }
                                 } failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)deleteKeysFromBackup:(NSString*)version
                                 success:(void (^)(void))success
                                 failure:(void (^)(NSError *error))failure
{
    NSString *path = [self keyBackupPath:nil session:nil version:version];
    if (!path)
    {
        NSLog(@"[MXRestClient] keysBackup: ERROR: Bad parameters");
        [self dispatchFailure:nil inBlock:failure];
        return nil;
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"DELETE"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         [self dispatchProcessing:nil
                                                    andCompletion:^{
                                                        success();
                                                    }];
                                     }
                                 } failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (NSString*)keyBackupPath:(NSString*)roomId session:(NSString*)sessionId version:(NSString*)version
{
    if (!version)
    {
        return nil;
    }

    NSMutableString *path = [NSMutableString stringWithFormat:@"%@/room_keys/keys", kMXAPIPrefixPathR0];

    if (sessionId)
    {
        if (!roomId)
        {
            NSLog(@"[MXRestClient] keyBackupPath: ERROR: Null version");
            return nil;
        }
        [path appendString:@"/"];
        [path appendString:[MXTools encodeURIComponent:roomId]];
        [path appendString:@"/"];
        [path appendString:[MXTools encodeURIComponent:sessionId]];
    }
    else if (roomId)
    {
        [path appendString:@"/"];
        [path appendString:[MXTools encodeURIComponent:roomId]];
    }

    [path appendString:@"?version="];
    [path appendString:version];

    return path;
}


#pragma mark - Direct-to-device messaging
- (MXHTTPOperation*)sendToDevice:(NSString*)eventType contentMap:(MXUsersDevicesMap<NSDictionary*>*)contentMap
                           txnId:(NSString*)txnId
                         success:(void (^)(void))success
                         failure:(void (^)(NSError *error))failure
{
    if (!txnId)
    {
        txnId = [MXTools generateTransactionId];
    }
    
    // Prepare the path by adding a random transaction id (This id is used to prevent duplicated event).
    NSString *path = [NSString stringWithFormat:@"%@/sendToDevice/%@/%@", kMXAPIPrefixPathR0, eventType, txnId];

    NSDictionary *content = @{
                              @"messages": contentMap.map
                              };

    MXWeakify(self);
    return [httpClient requestWithMethod:@"PUT"
                                    path:path
                              parameters:content
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

#pragma mark - Device Information
- (MXHTTPOperation*)devices:(void (^)(NSArray<MXDevice *> *))success
                    failure:(void (^)(NSError *error))failure
{
    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:[NSString stringWithFormat:@"%@/devices", kMXAPIPrefixPathR0]
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block NSArray<MXDevice *> *devices;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModelArray(devices, MXDevice, JSONResponse[@"devices"]);
                                         } andCompletion:^{
                                             success(devices);
                                         }];
                                     }
                                 } failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)deviceByDeviceId:(NSString *)deviceId
                             success:(void (^)(MXDevice *))success
                             failure:(void (^)(NSError *error))failure
{
    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:[NSString stringWithFormat:@"%@/devices/%@", kMXAPIPrefixPathR0, deviceId]
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXDevice *device;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(device, MXDevice, JSONResponse);
                                         } andCompletion:^{
                                             success(device);
                                         }];
                                     }
                                 } failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)setDeviceName:(NSString *)deviceName
                      forDeviceId:(NSString *)deviceId
                          success:(void (^)(void))success
                          failure:(void (^)(NSError *error))failure
{
    NSDictionary *parameters;
    if (deviceName.length)
    {
        parameters = @{@"display_name": deviceName};
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"PUT"
                                    path:[NSString stringWithFormat:@"%@/devices/%@", kMXAPIPrefixPathR0, deviceId]
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 } failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)getSessionToDeleteDeviceByDeviceId:(NSString *)deviceId
                                               success:(void (^)(MXAuthenticationSession *authSession))success
                                               failure:(void (^)(NSError *error))failure
{
    // Use DELETE with no params to get the supported authentication flows to delete device.
    // The request will fail with Unauthorized status code, but the auth session will be available in response data.
    MXWeakify(self);
    return [httpClient requestWithMethod:@"DELETE"
                                    path:[NSString stringWithFormat:@"%@/devices/%@", kMXAPIPrefixPathR0, [MXTools encodeURIComponent:deviceId]]
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     
                                     NSLog(@"[MXRestClient] Warning: get an authentication session to delete a device failed");
                                     if (success)
                                     {
                                         [self dispatchProcessing:nil
                                                    andCompletion:^{
                                                        success(nil);
                                                    }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);

                                     __block MXAuthenticationSession *authSession;
                                     [self dispatchProcessing:^{
                                         if (error.userInfo[MXHTTPClientErrorResponseDataKey])
                                         {
                                             // The auth session should be available in response data in case of unauthorized request.
                                             NSDictionary *JSONResponse = error.userInfo[MXHTTPClientErrorResponseDataKey];
                                             if (JSONResponse)
                                             {
                                                 MXJSONModelSetMXJSONModel(authSession, MXAuthenticationSession, JSONResponse);
                                             }
                                         }
                                     } andCompletion:^{
                                         if (authSession)
                                         {
                                             if (success)
                                             {
                                                 success(authSession);
                                             }
                                         }
                                         else if (failure)
                                         {
                                             failure(error);
                                         }
                                     }];
                                 }];
}

- (MXHTTPOperation*)deleteDeviceByDeviceId:(NSString *)deviceId
                                authParams:(NSDictionary*)authParameters
                                   success:(void (^)(void))success
                                   failure:(void (^)(NSError *error))failure
{
    NSData *payloadData = nil;
    if (authParameters)
    {
        payloadData = [NSJSONSerialization dataWithJSONObject:@{@"auth": authParameters} options:0 error:nil];
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"DELETE"
                                    path:[NSString stringWithFormat:@"%@/devices/%@", kMXAPIPrefixPathR0, [MXTools encodeURIComponent:deviceId]]
                              parameters:nil
                                    data:payloadData
                                 headers:@{@"Content-Type": @"application/json"}
                                 timeout:-1
                          uploadProgress:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 } failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}


#pragma mark - Cross-Signing

- (MXHTTPOperation*)authSessionToUploadDeviceSigningKeys:(void (^)(MXAuthenticationSession *authSession))success
                                                 failure:(void (^)(NSError *error))failure
{
    return [self authSessionForRequestWithMethod:@"POST"
                                            path:[NSString stringWithFormat:@"%@/keys/device_signing/upload", kMXAPIPrefixPathUnstable]
                                      parameters:@{}
                                         success:success
                                         failure:failure];
}

- (MXHTTPOperation*)uploadDeviceSigningKeys:(NSDictionary *)keys
                                 authParams:(NSDictionary*)authParameters
                                    success:(void (^)(void))success
                                    failure:(void (^)(NSError *error))failure
{
    NSMutableDictionary *parameters = [keys mutableCopy];
    parameters[@"auth"] = authParameters;

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:[NSString stringWithFormat:@"%@/keys/device_signing/upload", kMXAPIPrefixPathUnstable]
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         [self dispatchProcessing:nil
                                                    andCompletion:^{
                                                        success();
                                                    }];
                                     }
                                 } failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}


#pragma mark - Groups
- (MXHTTPOperation*)acceptGroupInvite:(NSString*)groupId
                              success:(void (^)(void))success
                              failure:(void (^)(NSError *error))failure
{
    return [self doGroupMembershipRequest:groupId
                               membership:@"accept_invite"
                               parameters:nil
                                  success:success failure:failure];
}
    
- (MXHTTPOperation*)leaveGroup:(NSString*)groupId
                      success:(void (^)(void))success
                      failure:(void (^)(NSError *error))failure
{
    return [self doGroupMembershipRequest:groupId
                               membership:@"leave"
                               parameters:nil
                                  success:success failure:failure];
}

- (MXHTTPOperation*)updateGroupPublicity:(NSString*)groupId
                            isPublicised:(BOOL)isPublicised
                                 success:(void (^)(void))success
                                 failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/groups/%@/self/update_publicity",
                      apiPathPrefix,
                      [MXTools encodeURIComponent:groupId]];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"PUT"
                                    path:path
                              parameters:@{@"publicise": @(isPublicised)}
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)getGroupProfile:(NSString*)groupId
                            success:(void (^)(MXGroupProfile *groupProfile))success
                            failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/groups/%@/profile",
                      apiPathPrefix,
                      [MXTools encodeURIComponent:groupId]];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXGroupProfile *groupProfile;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(groupProfile, MXGroupProfile, JSONResponse);
                                         } andCompletion:^{
                                             success(groupProfile);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)getGroupSummary:(NSString*)groupId
                            success:(void (^)(MXGroupSummary *groupSummary))success
                            failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/groups/%@/summary",
                      apiPathPrefix,
                      [MXTools encodeURIComponent:groupId]];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXGroupSummary *groupSummary;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(groupSummary, MXGroupSummary, JSONResponse);
                                         } andCompletion:^{
                                             success(groupSummary);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)getGroupUsers:(NSString*)groupId
                          success:(void (^)(MXGroupUsers *groupUsers))success
                          failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/groups/%@/users",
                      apiPathPrefix,
                      [MXTools encodeURIComponent:groupId]];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXGroupUsers *groupUsers;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(groupUsers, MXGroupUsers, JSONResponse);
                                         } andCompletion:^{
                                             success(groupUsers);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)getGroupInvitedUsers:(NSString*)groupId
                                 success:(void (^)(MXGroupUsers *invitedUsers))success
                                 failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/groups/%@/invited_users",
                      apiPathPrefix,
                      [MXTools encodeURIComponent:groupId]];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXGroupUsers *groupUsers;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(groupUsers, MXGroupUsers, JSONResponse);
                                         } andCompletion:^{
                                             success(groupUsers);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)getGroupRooms:(NSString*)groupId
                          success:(void (^)(MXGroupRooms *groupRooms))success
                          failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/groups/%@/rooms",
                      apiPathPrefix,
                      [MXTools encodeURIComponent:groupId]];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXGroupRooms *groupRooms;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(groupRooms, MXGroupRooms, JSONResponse);
                                         } andCompletion:^{
                                             success(groupRooms);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}
    
// Generic methods to change group membership
- (MXHTTPOperation*)doGroupMembershipRequest:(NSString*)groupId
                                  membership:(NSString*)membership
                                  parameters:(NSDictionary*)parameters
                                     success:(void (^)(void))success
                                     failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@/groups/%@/self/%@",
                      apiPathPrefix,
                      [MXTools encodeURIComponent:groupId],
                      membership];
    
    // A body is required even if empty
    if (nil == parameters)
    {
        parameters = @{};
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"PUT"
                                    path:path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchSuccess:success];
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)getPublicisedGroupsForUsers:(NSArray<NSString*>*)userIds
                                        success:(void (^)(NSDictionary<NSString*, NSArray<NSString*>*> *publicisedGroupsByUserId))success
                                        failure:(void (^)(NSError *error))failure
{
    
    // sanity check
    if (!userIds || !userIds.count)
    {
        NSError *error = [NSError errorWithDomain:kMXRestClientErrorDomain code:MXRestClientErrorInvalidParameters userInfo:nil];
        [self dispatchFailure:error inBlock:failure];
        return nil;
    }
    
    NSString *path = [NSString stringWithFormat:@"%@/publicised_groups", apiPathPrefix];

    MXWeakify(self);
    return [httpClient requestWithMethod:@"POST"
                                    path:path
                              parameters:@{@"user_ids": userIds}
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block NSDictionary *publicisedGroupsByUserId;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetDictionary(publicisedGroupsByUserId, JSONResponse[@"users"]);
                                         } andCompletion:^{
                                             success(publicisedGroupsByUserId);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}


#pragma mark - Private methods

/**
 Dispatch code blocks to respective GCD queue.

 @param processingBlock code block to run on the processing queue.
 @param completionBlock code block to run on the completion queue.
 */
- (void)dispatchProcessing:(dispatch_block_t)processingBlock andCompletion:(dispatch_block_t)completionBlock
{
    if (processingQueue)
    {
        MXWeakify(self);
        dispatch_async(processingQueue, ^{
            MXStrongifyAndReturnIfNil(self);

            if (processingBlock)
            {
                processingBlock();
            }

            if (self->completionQueue)
            {
                dispatch_async(self->completionQueue, ^{
                    completionBlock();
                });
            }
        });
    }
}

/**
 Dispatch the execution of the success block on the completion queue.

 with a go through the processing queue in order to keep the server
 response order.

 @param successBlock code block to run on the completion queue.
 */
- (void)dispatchSuccess:(dispatch_block_t)successBlock
{
    if (successBlock)
    {
        [self dispatchProcessing:nil andCompletion:successBlock];
    }
}

/**
 Dispatch the execution of the failure block on the completion queue.

 with a go through the processing queue in order to keep the server
 response order.

 @param failureBlock code block to run on the completion queue.
 */
- (void)dispatchFailure:(NSError*)error inBlock:(void (^)(NSError *error))failureBlock
{
    if (failureBlock && processingQueue)
    {
        MXWeakify(self);
        dispatch_async(processingQueue, ^{
            MXStrongifyAndReturnIfNil(self);

            if (self->completionQueue)
            {
                dispatch_async(self->completionQueue, ^{
                    failureBlock(error);
                });
            }
        });
    }
}

- (MXHTTPOperation*)authSessionForRequestWithMethod:(NSString *)httpMethod
                                               path:(NSString *)path
                                         parameters:(NSDictionary*)parameters
                                            success:(void (^)(MXAuthenticationSession *authSession))success
                                            failure:(void (^)(NSError *error))failure
{
    return [httpClient requestWithMethod:httpMethod
                                    path:path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {

                                     NSLog(@"[MXRestClient] authSessionForRequestWithMethod: Warning: get an authentication session failed");
                                     if (success)
                                     {
                                         [self dispatchProcessing:nil
                                                    andCompletion:^{
                                                        success(nil);
                                                    }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     __block MXAuthenticationSession *authSession;
                                     [self dispatchProcessing:^{
                                         if (error.userInfo[MXHTTPClientErrorResponseDataKey])
                                         {
                                             // The auth session should be available in response data in case of unauthorized request.
                                             NSDictionary *JSONResponse = error.userInfo[MXHTTPClientErrorResponseDataKey];
                                             if (JSONResponse)
                                             {
                                                 MXJSONModelSetMXJSONModel(authSession, MXAuthenticationSession, JSONResponse);
                                             }
                                         }
                                     } andCompletion:^{
                                         if (authSession)
                                         {
                                             if (success)
                                             {
                                                 success(authSession);
                                             }
                                         }
                                         else if (failure)
                                         {
                                             failure(error);
                                         }
                                     }];
                                 }];
}



#pragma mark - Aggregations

- (MXHTTPOperation*)sendRelationToEvent:(NSString*)eventId
                                 inRoom:(NSString*)roomId
                           relationType:(NSString*)relationType
                              eventType:(NSString*)eventType
                             parameters:(NSDictionary*)parameters
                                content:(NSDictionary*)content
                                success:(void (^)(NSString *eventId))success
                                failure:(void (^)(NSError *error))failure
{
    // Create a random transaction id to prevent duplicated events
    NSString *txnId = [MXTools generateTransactionId];

    // Prepare the path
    NSMutableString *path = [NSMutableString stringWithFormat:@"%@/rooms/%@/send_relation/%@/%@/%@/%@",
                             kMXAPIPrefixPathUnstable,    // TODO: use apiPathPrefix
                             roomId,
                             [MXTools encodeURIComponent:eventId],
                             relationType,
                             eventType,
                             [MXTools encodeURIComponent:txnId]];

    // Serialise query parameters
    if (parameters)
    {
        NSMutableString *queryParameters;
        for (NSString *key in parameters)
        {
            NSString *value = [MXTools encodeURIComponent:parameters[key]];

            if (!queryParameters)
            {
                queryParameters = [NSMutableString stringWithFormat:@"?%@=%@", key, value];
            }
            else
            {
                [queryParameters appendFormat:@"&%@=%@", key, value];
            }
        }

        if (queryParameters)
        {
            [path appendString:queryParameters];
        }
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"PUT"
                                    path:path
                              parameters:content
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block NSString *eventId;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetString(eventId, JSONResponse[@"event_id"]);
                                         } andCompletion:^{
                                             success(eventId);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

- (MXHTTPOperation*)relationsForEvent:(NSString*)eventId
                               inRoom:(NSString*)roomId
                         relationType:(NSString*)relationType
                            eventType:(NSString*)eventType
                                 from:(NSString*)from
                                limit:(NSUInteger)limit
                              success:(void (^)(MXAggregationPaginatedResponse *paginatedResponse))success
                              failure:(void (^)(NSError *error))failure
{
    NSMutableString *path = [NSMutableString stringWithFormat:@"%@/rooms/%@/relations/%@",
                             kMXAPIPrefixPathUnstable,    // TODO: use apiPathPrefix
                             roomId,
                             [MXTools encodeURIComponent:eventId]];

    if (relationType)
    {
        [path appendFormat:@"/%@", relationType];
    }
    if (eventType)
    {
        [path appendFormat:@"/%@", eventType];
    }

    // All query parameters are optional. Fill the request parameters on demand
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    if (from)
    {
        parameters[@"from"] = from;
    }

    if (-1 != limit)
    {
        parameters[@"limit"] = @(limit);
    }

    MXWeakify(self);
    return [httpClient requestWithMethod:@"GET"
                                    path:path
                              parameters:parameters
                                 success:^(NSDictionary *JSONResponse) {
                                     MXStrongifyAndReturnIfNil(self);

                                     if (success)
                                     {
                                         __block MXAggregationPaginatedResponse *paginatedResponse;
                                         [self dispatchProcessing:^{
                                             MXJSONModelSetMXJSONModel(paginatedResponse, MXAggregationPaginatedResponse, JSONResponse);
                                         } andCompletion:^{
                                             success(paginatedResponse);
                                         }];
                                     }
                                 }
                                 failure:^(NSError *error) {
                                     MXStrongifyAndReturnIfNil(self);
                                     [self dispatchFailure:error inBlock:failure];
                                 }];
}

@end
