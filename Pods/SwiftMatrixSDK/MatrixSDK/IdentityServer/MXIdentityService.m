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

#import "MXIdentityService.h"

#import "MXRestClient.h"
#import "MXTools.h"

#pragma mark - Defines & Constants

NSString *const MXIdentityServiceTermsNotSignedNotification = @"MXIdentityServiceTermsNotSignedNotification";

NSString *const MXIdentityServiceDidChangeAccessTokenNotification = @"MXIdentityServiceDidChangeAccessTokenNotification";

NSString *const MXIdentityServiceNotificationUserIdKey = @"userId";
NSString *const MXIdentityServiceNotificationIdentityServerKey = @"identityServer";
NSString *const MXIdentityServiceNotificationAccessTokenKey = @"accessToken";

@interface MXIdentityService ()

// Identity server REST client
@property (nonatomic, strong) MXIdentityServerRestClient *restClient;

@property (nonatomic, strong) MXRestClient *homeserverRestClient;

// Identity server hash details
@property (nonatomic, strong) MXIdentityServerHashDetails *identityServerHashDetails;

// Identity server access token for v2 API
@property (nonatomic, strong) NSString *accessToken;

@end

@implementation MXIdentityService

#pragma mark - Properties override

- (NSString *)identityServer
{
    return self.restClient.identityServer;
}

- (dispatch_queue_t)completionQueue
{
    return self.restClient.completionQueue;
}

- (void)setCompletionQueue:(dispatch_queue_t)completionQueue
{
    self.restClient.completionQueue = completionQueue;
}

- (void)setAccessToken:(NSString *)accessToken
{
    _accessToken = accessToken;
        
    [self postAccessTokenDidChangeNotitificationWithAccessToken:accessToken];
}

#pragma mark - Setup

- (instancetype)initWithIdentityServer:(NSString *)identityServer accessToken:(nullable NSString*)accessToken andHomeserverRestClient:(MXRestClient*)homeserverRestClient
{
    MXIdentityServerRestClient *identityServerRestClient = [[MXIdentityServerRestClient alloc] initWithIdentityServer:identityServer accessToken:accessToken andOnUnrecognizedCertificateBlock:nil];

    self = [self initWithIdentityServerRestClient:identityServerRestClient andHomeserverRestClient:homeserverRestClient];
    if (self)
    {
        _accessToken = accessToken;
    }
    return self;
}

- (instancetype)initWithIdentityServerRestClient:(MXIdentityServerRestClient*)identityServerRestClient andHomeserverRestClient:(MXRestClient*)homeserverRestClient
{
    self = [super init];
    if (self)
    {
        identityServerRestClient.shouldRenewTokenHandler = ^BOOL(NSError *error) {
            
            BOOL shouldRenewAccesToken = NO;
            
            if ([MXError isMXError:error])
            {
                MXError *mxError = [[MXError alloc] initWithNSError:error];
                if ([mxError.errcode isEqualToString:kMXErrCodeStringUnauthorized])
                {
                    shouldRenewAccesToken = YES;
                }
            }
            
            return shouldRenewAccesToken;
        };
        
        MXWeakify(self);
        
        identityServerRestClient.renewTokenHandler = ^MXHTTPOperation* (void (^success)(NSString *), void (^failure)(NSError *)) {
            MXStrongifyAndReturnValueIfNil(self, nil);
            
            return [self renewAccessTokenWithSuccess:^(NSString *accessToken) {
                self.accessToken = accessToken;
                success(accessToken);
            } failure:failure];
        };
        
        self.restClient = identityServerRestClient;
        _accessToken = identityServerRestClient.accessToken;
        self.homeserverRestClient = homeserverRestClient;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleHTTPClientError:) name:kMXHTTPClientMatrixErrorNotification object:nil];
    }
    return self;
}

#pragma mark - Public

#pragma mark Access token
- (nullable MXHTTPOperation *)accessTokenWithSuccess:(void (^)(NSString * _Nullable accessToken))success
                                             failure:(void (^)(NSError *error))failure
{
    if (self.accessToken)
    {
        success(self.accessToken);
        return nil;
    }
    
    return [self.restClient getAccessTokenAndRenewIfNeededWithSuccess:^(NSString * _Nonnull accessToken) {
        // If we get here, we have an access token
        success(self.accessToken);
    } failure:failure];
}

#pragma mark Association lookup

- (MXHTTPOperation*)lookup3pid:(NSString*)address
                     forMedium:(MX3PIDMedium)medium
                       success:(void (^)(NSString *userId))success
                       failure:(void (^)(NSError *error))failure
{
    return [self checkAPIVersionAvailabilityAndPerformOperationOnSuccess:^MXHTTPOperation* {
        return [self.restClient lookup3pid:address forMedium:medium success:success failure:failure];;
    } failure:failure];
}

- (MXHTTPOperation*)lookup3pids:(NSArray*)threepids
                        success:(void (^)(NSArray *discoveredUsers))success
                        failure:(void (^)(NSError *error))failure
{
    __block MXHTTPOperation *operation;
    
    operation = [self checkAPIVersionAvailabilityWithSuccess:^{
        
        MXHTTPOperation *operation2;
        
        if ([self.restClient.preferredAPIPathPrefix isEqualToString:kMXIdentityAPIPrefixPathV1])
        {
            operation2 = [self.restClient lookup3pids:threepids
                                              success:success
                                              failure:failure];
        }
        else
        {
            operation2 = [self v2_lookup3pids:threepids
                                      success:success
                                      failure:failure];
        }
        
        if (operation)
        {
            [operation mutateTo:operation2];
        }
        else
        {
            operation = operation2;
        }
        
        
    } failure:^(NSError *error) {
        failure(error);
    }];
    
    return operation;
}

#pragma mark Establishing associations

- (MXHTTPOperation*)requestEmailValidation:(NSString*)email
                              clientSecret:(NSString*)clientSecret
                               sendAttempt:(NSUInteger)sendAttempt
                                  nextLink:(NSString *)nextLink
                                   success:(void (^)(NSString *sid))success
                                   failure:(void (^)(NSError *error))failure
{
    return [self checkAPIVersionAvailabilityAndPerformOperationOnSuccess:^MXHTTPOperation* {
        return [self.restClient requestEmailValidation:email clientSecret:clientSecret sendAttempt:sendAttempt nextLink:nextLink success:success failure:failure];
    } failure:failure];
}

- (MXHTTPOperation*)requestPhoneNumberValidation:(NSString*)phoneNumber
                                     countryCode:(NSString*)countryCode
                                    clientSecret:(NSString*)clientSecret
                                     sendAttempt:(NSUInteger)sendAttempt
                                        nextLink:(NSString *)nextLink
                                         success:(void (^)(NSString *sid, NSString *msisdn))success
                                         failure:(void (^)(NSError *error))failure
{
    return [self checkAPIVersionAvailabilityAndPerformOperationOnSuccess:^MXHTTPOperation* {
        return [self.restClient requestPhoneNumberValidation:phoneNumber countryCode:countryCode clientSecret:clientSecret sendAttempt:sendAttempt nextLink:nextLink success:success failure:failure];
    } failure:failure];
}

- (MXHTTPOperation *)submit3PIDValidationToken:(NSString *)token
                                        medium:(NSString *)medium
                                  clientSecret:(NSString *)clientSecret
                                           sid:(NSString *)sid
                                       success:(void (^)(void))success
                                       failure:(void (^)(NSError *))failure
{
    return [self checkAPIVersionAvailabilityAndPerformOperationOnSuccess:^MXHTTPOperation* {
        return [self.restClient submit3PIDValidationToken:token medium:medium clientSecret:clientSecret sid:sid success:success failure:failure];
    } failure:failure];
}

#pragma mark Other

- (MXHTTPOperation *)pingIdentityServer:(void (^)(void))success failure:(void (^)(NSError *))failure
{
    return [self checkAPIVersionAvailabilityAndPerformOperationOnSuccess:^MXHTTPOperation* {
        return [self.restClient pingIdentityServer:success failure:failure];
    } failure:failure];
}

- (MXHTTPOperation*)signUrl:(NSString*)signUrl
                    success:(void (^)(NSDictionary *thirdPartySigned))success
                    failure:(void (^)(NSError *error))failure
{    
    return [self.restClient signUrl:signUrl mxid:self.homeserverRestClient.credentials.userId success:success failure:failure];
}

- (MXHTTPOperation*)accountWithSuccess:(void (^)(NSString *userId))success
                               failure:(void (^)(NSError *error))failure
{
    return [self checkAPIVersionAvailabilityAndPerformOperationOnSuccess:^MXHTTPOperation* {
        if (self.restClient.preferredAPIPathPrefix == kMXIdentityAPIPrefixPathV2)
        {
            return [self.restClient accountWithSuccess:success failure:failure];
        }
        else
        {
            // There is no account in v1
            success(nil);
            return nil;
        }

    } failure:failure];
}

#pragma mark - Private

- (MXHTTPOperation*)checkAPIVersionAvailabilityWithSuccess:(void (^)(void))success failure:(void (^)(NSError *))failure
{
    if (self.restClient.preferredAPIPathPrefix)
    {
        success();
        return nil;
    }
    
    return [self.restClient isAPIPathPrefixAvailable:kMXIdentityAPIPrefixPathV2 success:^{
        self.restClient.preferredAPIPathPrefix = kMXIdentityAPIPrefixPathV2;
        
        if (success)
        {
            success();
        }
        
    } failure:^(NSError * _Nonnull error) {
        
        // Call success only if API path prefix v2 is not found call failure for other errors
        if ([error.domain isEqualToString:MXIdentityServerRestClientErrorDomain] && error.code == MXIdentityServerRestClientErrorAPIPrefixNotFound)
        {
            self.restClient.preferredAPIPathPrefix = kMXIdentityAPIPrefixPathV1;
            
            if (success)
            {
                success();
            }
        }
        else
        {
            if (failure)
            {
                failure(error);
            }
        }
    }];
}

- (MXHTTPOperation*)renewAccessTokenWithSuccess:(void (^)(NSString*))success failure:(void (^)(NSError *))failure
{
    if (!self.homeserverRestClient)
    {
        NSError *error = [NSError errorWithDomain:@"MXIdentityService" code:0 userInfo:nil];
        failure(error);
        return nil;
    }
    
    MXHTTPOperation *operation;
    
    MXWeakify(self);
    
    operation = [self.homeserverRestClient openIdToken:^(MXOpenIdToken *tokenObject) {
        
        MXStrongifyAndReturnIfNil(self);
        
        MXHTTPOperation *operation2 = [self.restClient registerWithOpenIdToken:tokenObject success:^(NSString * _Nonnull accessToken) {
            
            success(accessToken);
            
        } failure:^(NSError * _Nonnull error) {
            failure(error);
        }];
        
        // Mutate MXHTTPOperation so that the user can cancel this new operation
        [operation mutateTo:operation2];
        
    } failure:^(NSError *error) {
        failure(error);
    }];
    
    return operation;
}

- (MXHTTPOperation*)checkAPIVersionAvailabilityAndPerformOperationOnSuccess:(MXHTTPOperation* (^)(void))operationOnSuccess
                                                                    failure:(void (^)(NSError *))failure
{
    __block MXHTTPOperation *operation;
    
    operation = [self checkAPIVersionAvailabilityWithSuccess:^{
        
        MXHTTPOperation *operation2 = operationOnSuccess();
        
        if (operation)
        {
            [operation mutateTo:operation2];
        }
        else
        {
            operation = operation2;
        }
        
    } failure:failure];
    
    return operation;
}

- (MXHTTPOperation*)v2_lookupHashDetailsWithSuccess:(void (^)(MXIdentityServerHashDetails *hashDetails))success
                                            failure:(void (^)(NSError *error))failure;
{
    if (self.identityServerHashDetails)
    {
        success(self.identityServerHashDetails);
        return nil;
    }
    
    return [self.restClient hashDetailsWithSuccess:^(MXIdentityServerHashDetails * _Nonnull hashDetails) {
        self.identityServerHashDetails = hashDetails;
        success(hashDetails);
    } failure:^(NSError * _Nonnull error) {
        failure(error);
    }];
}

- (MXHTTPOperation*)v2_lookup3pids:(NSArray*)threepids
                           success:(void (^)(NSArray *discoveredUsers))success
                           failure:(void (^)(NSError *error))failure
{
    
    __block MXHTTPOperation *operation;
    
    operation = [self v2_lookupHashDetailsWithSuccess:^(MXIdentityServerHashDetails *hashDetails) {
        
        MXHTTPOperation *operation2;
        
        MXIdentityServerHashAlgorithm lookupHashAlgorithm = [self preferredLookupAlgorithmForLookupoHashDetails:hashDetails];
        
        operation2 = [self.restClient lookup3pids:threepids
                                        algorithm:lookupHashAlgorithm
                                           pepper:hashDetails.pepper
                                          success:success
                                          failure:^(NSError * _Nonnull error) {
                                              
                                              MXError *mxError = [[MXError alloc] initWithNSError:error];
                                              if ([mxError.errcode isEqualToString:kMXErrCodeStringInvalidPepper])
                                              {
                                                  // Identity server could rotate the pepper and it could become invalid
                                                  // TODO: Retry lookup with new pepper on invalid pepper error
                                                  self.identityServerHashDetails = nil;
                                              }
                                              
                                              failure(error);
                                          }];
        
        
        if (operation)
        {
            [operation mutateTo:operation2];
        }
        else
        {
            operation = operation2;
        }
        
    } failure:failure];
    
    return operation;
}

- (MXIdentityServerHashAlgorithm)preferredLookupAlgorithmForLookupoHashDetails:(MXIdentityServerHashDetails*)lookupHashDetails
{
    MXIdentityServerHashAlgorithm preferredAlgorithm = MXIdentityServerHashAlgorithmUnknown;
    
    if ([lookupHashDetails containsAlgorithm:MXIdentityServerHashAlgorithmSHA256])
    {
        preferredAlgorithm = MXIdentityServerHashAlgorithmSHA256;
    }
    else if ([lookupHashDetails containsAlgorithm:MXIdentityServerHashAlgorithmNone])
    {
        preferredAlgorithm = MXIdentityServerHashAlgorithmNone;
    }
    
    return preferredAlgorithm;
}

- (void)handleHTTPClientError:(NSNotification*)nofitication
{
    MXHTTPClient *httpClient = nofitication.object;
    
    MXError *mxError;
    MXJSONModelSet(mxError, [MXError class], nofitication.userInfo[kMXHTTPClientMatrixErrorNotificationErrorKey]);
    
    NSString *accessToken = self.restClient.accessToken;
    
    if (httpClient
        && [httpClient.baseURL.absoluteString hasPrefix:self.identityServer]
        && [mxError.errcode isEqualToString:kMXErrCodeStringTermsNotSigned] && accessToken)
    {
        NSDictionary *userInfo = [self notificationUserInfoWithAccessToken:accessToken];
        [[NSNotificationCenter defaultCenter] postNotificationName:MXIdentityServiceTermsNotSignedNotification object:nil userInfo:userInfo];
    }
}

- (void)postAccessTokenDidChangeNotitificationWithAccessToken:(NSString*)accessToken
{
    if (accessToken)
    {
        NSDictionary *userInfo = [self notificationUserInfoWithAccessToken:accessToken];
        [[NSNotificationCenter defaultCenter] postNotificationName:MXIdentityServiceDidChangeAccessTokenNotification object:nil userInfo:userInfo];
    }
}

- (NSDictionary*)notificationUserInfoWithAccessToken:(nonnull NSString*)accessToken
{
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] initWithDictionary:@{
                                                                                      MXIdentityServiceNotificationIdentityServerKey : self.identityServer,
                                                                                      MXIdentityServiceNotificationAccessTokenKey : accessToken
                                                                                      }];
    
    NSString *userId = self.homeserverRestClient.credentials.userId;
    
    if (userId)
    {
        userInfo[MXIdentityServiceNotificationUserIdKey] = userId;
    }
    
    return userInfo;
}

@end
