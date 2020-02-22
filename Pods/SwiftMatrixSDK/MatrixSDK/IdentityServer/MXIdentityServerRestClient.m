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

#import "MXIdentityServerRestClient.h"

#import <AFNetworking/AFNetworking.h>
#import <OLMKit/OLMUtility.h>

#import "MXHTTPClient.h"
#import "MXError.h"
#import "MXTools.h"
#import "MXEncryptedAttachments.h"

#pragma mark - Constants definitions

/**
 Prefix used in path of home server API requests.
 */
NSString *const kMXIdentityAPIPrefixPathV1 = @"_matrix/identity/api/v1";
NSString *const kMXIdentityAPIPrefixPathV2 = @"_matrix/identity/v2";

/**
 MXIdentityServerRestClient error domain
 */
NSString *const MXIdentityServerRestClientErrorDomain = @"org.matrix.sdk.MXIdentityServerRestClientErrorDomain";

@interface MXIdentityServerRestClient()

/**
 HTTP client to the identity server.
 */
@property (nonatomic, strong) MXHTTPClient *httpClient;

/**
 The queue to process server response.
 This queue is used to create models from JSON dictionary without blocking the main thread.
 */
@property (nonatomic) dispatch_queue_t processingQueue;

@property (nonatomic, readonly) BOOL isUsingV2API;

@end

@implementation MXIdentityServerRestClient

#pragma mark - Properties override

- (NSString *)accessToken
{
    return self.httpClient.accessToken;
}

- (void)setShouldRenewTokenHandler:(MXHTTPClientShouldRenewTokenHandler)shouldRenewTokenHandler
{
    self.httpClient.shouldRenewTokenHandler = shouldRenewTokenHandler;
}

- (MXHTTPClientShouldRenewTokenHandler)shouldRenewTokenHandler
{
    return self.httpClient.shouldRenewTokenHandler;
}

- (void)setRenewTokenHandler:(MXHTTPClientRenewTokenHandler)renewTokenHandler
{
    self.httpClient.renewTokenHandler = renewTokenHandler;
}

- (MXHTTPClientRenewTokenHandler)renewTokenHandler
{
    return self.httpClient.renewTokenHandler;
}

- (BOOL)isUsingV2API
{
    return [self.preferredAPIPathPrefix isEqualToString:kMXIdentityAPIPrefixPathV2];
}

#pragma mark - Setup

- (instancetype)initWithIdentityServer:(NSString *)identityServer
                           accessToken:(nullable NSString *)accessToken
     andOnUnrecognizedCertificateBlock:(nullable MXHTTPClientOnUnrecognizedCertificate)onUnrecognizedCertBlock
{
    self = [super init];
    if (self)
    {
        MXHTTPClient *httpClient = [[MXHTTPClient alloc] initWithBaseURL:identityServer accessToken:accessToken andOnUnrecognizedCertificateBlock:onUnrecognizedCertBlock];
        // The identity server accepts parameters in form data form for some requests
        httpClient.requestParametersInJSON = NO;

        self.httpClient = httpClient;
        _identityServer = identityServer;

        self.processingQueue = dispatch_queue_create("MXIdentityServerRestClient", DISPATCH_QUEUE_SERIAL);
        self.completionQueue = dispatch_get_main_queue();
    }
    return self;
}

#pragma mark - Public

#pragma mark Authentication

- (MXHTTPOperation*)registerWithOpenIdToken:(MXOpenIdToken*)openIdToken
                                    success:(void (^)(NSString *accessToken))success
                                    failure:(void (^)(NSError *error))failure
{
    NSString *path = [self buildAPIPathWithAPIPathPrefix:kMXIdentityAPIPrefixPathV2 andPath:@"account/register"];
    
    if (!path)
    {
        NSError *error = [NSError errorWithDomain:MXIdentityServerRestClientErrorDomain code:MXIdentityServerRestClientErrorMissingAPIPrefix userInfo:nil];
        failure(error);
        return nil;
    }
    
    NSData *payloadData = [NSJSONSerialization dataWithJSONObject:openIdToken.JSONDictionary options:0 error:nil];
    
    return [self.httpClient requestWithMethod:@"POST"
                                         path:path
                                   parameters:nil
                                         data:payloadData
                                      headers:@{@"Content-Type": @"application/json"}
                                      timeout:-1
                               uploadProgress:nil
                                      success:^(NSDictionary *JSONResponse) {
                                          if (success)
                                          {
                                              __block NSString *token;
                                              [self dispatchProcessing:^{
                                                  NSString *token;
                                                  MXJSONModelSetString(token, JSONResponse[@"token"]);

                                                  // The spec is `token`, but we used `access_token` for a Sydent release :/
                                                  if (!token)
                                                  {
                                                      MXJSONModelSetString(token, JSONResponse[@"access_token"]);
                                                  }
                                              } andCompletion:^{
                                                  success(token);
                                              }];
                                          }
                                      } failure:^(NSError *error) {
                                          [self dispatchFailure:error inBlock:failure];
                                      }];
}


- (MXHTTPOperation*)accountWithSuccess:(void (^)(NSString *userId))success
                               failure:(void (^)(NSError *error))failure
{
    NSString *path = [self buildAPIPathWithAPIPathPrefix:kMXIdentityAPIPrefixPathV2 andPath:@"account"];
    
    if (!path)
    {
        NSError *error = [NSError errorWithDomain:MXIdentityServerRestClientErrorDomain code:MXIdentityServerRestClientErrorMissingAPIPrefix userInfo:nil];
        failure(error);
        return nil;
    }
    
    return [self.httpClient requestWithMethod:@"GET"
                                         path:path
                                   parameters:nil
                           needsAuthorization:YES
                                      success:^(NSDictionary *JSONResponse) {
                                          if (success)
                                          {
                                              __block NSString *userId;
                                              [self dispatchProcessing:^{
                                                  MXJSONModelSetString(userId, JSONResponse[@"user_id"]);
                                              } andCompletion:^{
                                                  success(userId);
                                              }];
                                          }
                                      } failure:^(NSError *error) {
                                          [self dispatchFailure:error inBlock:failure];
                                      }];
}


#pragma mark Association lookup

- (MXHTTPOperation*)lookup3pid:(NSString*)address
                     forMedium:(MX3PIDMedium)medium
                       success:(void (^)(NSString *userId))success
                       failure:(void (^)(NSError *error))failure
{
    NSString *path = [self buildAPIPathWithAPIPathPrefix:kMXIdentityAPIPrefixPathV1 andPath:@"lookup"];
    
    if (!path)
    {
        NSError *error = [NSError errorWithDomain:MXIdentityServerRestClientErrorDomain code:MXIdentityServerRestClientErrorMissingAPIPrefix userInfo:nil];
        failure(error);
        return nil;
    }

    if ([medium isEqualToString:kMX3PIDMediumEmail])
    {
        // Email should be lower case
        address = address.lowercaseString;
    }
    
    return [self.httpClient requestWithMethod:@"GET"
                                         path:path
                                   parameters:@{
                                                @"medium": medium,
                                                @"address": address
                                                }
                                      success:^(NSDictionary *JSONResponse) {
                                          if (success)
                                          {
                                              __block NSString *mxid;
                                              [self dispatchProcessing:^{
                                                  MXJSONModelSetString(mxid, JSONResponse[@"mxid"]);
                                              } andCompletion:^{
                                                  success(mxid);
                                              }];
                                          }
                                      } failure:^(NSError *error) {
                                          [self dispatchFailure:error inBlock:failure];
                                      }];
}

- (MXHTTPOperation*)lookup3pids:(NSArray*)threepids
                        success:(void (^)(NSArray *discoveredUsers))success
                        failure:(void (^)(NSError *error))failure
{
    NSString *path = [self buildAPIPathWithAPIPathPrefix:kMXIdentityAPIPrefixPathV1 andPath:@"bulk_lookup"];
    
    if (!path)
    {
        NSError *error = [NSError errorWithDomain:MXIdentityServerRestClientErrorDomain code:MXIdentityServerRestClientErrorMissingAPIPrefix userInfo:nil];
        failure(error);
        return nil;
    }

    // Emails should be lower case
    NSMutableArray<NSArray<NSString*>*> *lowercaseThreepids = [NSMutableArray new];
    for (NSArray<NSString*> *threepidArray in threepids)
    {
        if (threepidArray.count < 2)
        {
            continue;
        }

        NSString *medium = threepidArray[0];
        NSString *address = threepidArray[1];

        if ([medium isEqualToString:kMX3PIDMediumEmail])
        {
            [lowercaseThreepids addObject:@[
                                            medium,
                                            address.lowercaseString
                                            ]];
        }
        else
        {
            [lowercaseThreepids addObject:threepidArray];
        }
    }

    
    NSData *payloadData = nil;
    if (threepids)
    {
        payloadData = [NSJSONSerialization dataWithJSONObject:@{@"threepids": lowercaseThreepids} options:0 error:nil];
    }
    
    return [self.httpClient requestWithMethod:@"POST"
                                         path:path
                                   parameters:nil
                                         data:payloadData
                                      headers:@{@"Content-Type": @"application/json"}
                                      timeout:-1
                               uploadProgress:nil
                                      success:^(NSDictionary *JSONResponse) {
                                          if (success)
                                          {
                                              __block NSArray *discoveredUsers;
                                              [self dispatchProcessing:^{
                                                  // The identity server returns a dictionary with key 'threepids', which is a list of results
                                                  // where each result is a 3 item list of medium, address, mxid.
                                                  MXJSONModelSetArray(discoveredUsers, JSONResponse[@"threepids"]);
                                              } andCompletion:^{
                                                  success(discoveredUsers);
                                              }];
                                          }
                                      } failure:^(NSError *error) {
                                          [self dispatchFailure:error inBlock:failure];
                                      }];
}

- (MXHTTPOperation*)hashDetailsWithSuccess:(void (^)(MXIdentityServerHashDetails *hashDetails))success failure:(void (^)(NSError *error))failure
{
    NSString *path = [self buildAPIPathWithAPIPathPrefix:kMXIdentityAPIPrefixPathV2 andPath:@"hash_details"];
    
    if (!path)
    {
        NSError *error = [NSError errorWithDomain:MXIdentityServerRestClientErrorDomain code:MXIdentityServerRestClientErrorMissingAPIPrefix userInfo:nil];
        failure(error);
        return nil;
    }
    
    return [self.httpClient requestWithMethod:@"GET"
                                         path:path
                                   parameters:nil
                           needsAuthorization:YES
                                      success:^(NSDictionary *JSONResponse) {
                                          if (success)
                                          {
                                              __block MXIdentityServerHashDetails *hashDetails;
                                              [self dispatchProcessing:^{
                                                  MXJSONModelSetMXJSONModel(hashDetails, [MXIdentityServerHashDetails class], JSONResponse);
                                              } andCompletion:^{
                                                  success(hashDetails);
                                              }];
                                          }
                                      } failure:^(NSError *error) {
                                          [self dispatchFailure:error inBlock:failure];
                                      }];
}

- (MXHTTPOperation*)lookup3pids:(NSArray<NSArray<NSString*>*> *)threepids
                      algorithm:(MXIdentityServerHashAlgorithm)algorithm
                         pepper:(NSString*)pepper
                        success:(void (^)(NSArray *discoveredUsers))success
                        failure:(void (^)(NSError *error))failure
{
    if (algorithm == MXIdentityServerHashAlgorithmUnknown)
    {
        NSError *error = [NSError errorWithDomain:MXIdentityServerRestClientErrorDomain code:MXIdentityServerRestClientErrorUnsupportedHashAlgorithm userInfo:nil];
        failure(error);
        return nil;
    }
    
    NSString *path = [self buildAPIPathWithAPIPathPrefix:kMXIdentityAPIPrefixPathV2 andPath:@"lookup"];
    
    if (!path)
    {
        NSError *error = [NSError errorWithDomain:MXIdentityServerRestClientErrorDomain code:MXIdentityServerRestClientErrorMissingAPIPrefix userInfo:nil];
        failure(error);
        return nil;
    }
    
    NSData *payloadData = nil;
    
    NSMutableDictionary<NSString*, NSArray<NSString*>*> *threePidArrayByThreePidConcatHash = [NSMutableDictionary new];
    
    if (threepids)
    {
        NSMutableArray *hashedThreePids = [NSMutableArray new];
        
        for (NSArray<NSString*> *threepidArray in threepids)
        {
            if (threepidArray.count < 2)
            {
                continue;
            }
            
            NSString *medium = threepidArray[0];
            NSString *threepid = threepidArray[1];

            if ([medium isEqualToString:kMX3PIDMediumEmail])
            {
                // Email should be lower case
                threepid = threepid.lowercaseString;
            }
            
            NSString *hashedTreePid;
            
            switch (algorithm)
            {
                case MXIdentityServerHashAlgorithmNone:
                    hashedTreePid = [NSString stringWithFormat:@"%@ %@", threepid, medium];
                    break;
                case MXIdentityServerHashAlgorithmSHA256:
                {
                    NSString *threePidConcatenation = [NSString stringWithFormat:@"%@ %@ %@", threepid, medium, pepper];
                    
                    OLMUtility *olmUtility = [OLMUtility new];
                    NSString *hashedSha256ThreePid = [olmUtility sha256:[threePidConcatenation dataUsingEncoding:NSUTF8StringEncoding]];
                    hashedTreePid = [MXEncryptedAttachments base64ToBase64Url:hashedSha256ThreePid];
                    
                    threePidArrayByThreePidConcatHash[hashedTreePid] = threepidArray;
                }
                    break;
                default:
                    break;
            }
            
            [hashedThreePids addObject:hashedTreePid];
        }
        
        NSString *algorithmStringValue = [MXIdentityServerHashDetails stringValueForHashAlgorithm:algorithm];
        
        NSDictionary *jsonDictionary = @{
                                         @"addresses": hashedThreePids,
                                         @"algorithm": algorithmStringValue,
                                         @"pepper": pepper,
                                         };
        
        payloadData = [NSJSONSerialization dataWithJSONObject:jsonDictionary options:0 error:nil];
    }
    
    return [self.httpClient requestWithMethod:@"POST"
                                         path:path
                                   parameters:nil
                           needsAuthorization:YES
                                         data:payloadData
                                      headers:@{@"Content-Type": @"application/json"}
                                      timeout:-1
                               uploadProgress:nil
                                      success:^(NSDictionary *JSONResponse) {
                                          if (success)
                                          {
                                              __block NSMutableArray *discoveredUsers;
                                              [self dispatchProcessing:^{
                                                  
                                                  NSDictionary *mappings;
                                                  MXJSONModelSetDictionary(mappings, JSONResponse[@"mappings"]);
                                                  
                                                  if (mappings)
                                                  {
                                                      discoveredUsers = [NSMutableArray new];
                                                      
                                                      switch (algorithm)
                                                      {
                                                          case MXIdentityServerHashAlgorithmNone:
                                                          {
                                                              [mappings enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL* stop) {
                                                                  
                                                                  NSArray *addressPlusMedium = [key componentsSeparatedByString:@" "];
                                                                  
                                                                  if (addressPlusMedium.count == 2)
                                                                  {
                                                                      // Medium, 3 pid, Matrix ID
                                                                      NSArray *userItems = @[ addressPlusMedium[1], addressPlusMedium[0], value];
                                                                      
                                                                      [discoveredUsers addObject:userItems];
                                                                  }
                                                              }];
                                                          }
                                                              break;
                                                          case MXIdentityServerHashAlgorithmSHA256:
                                                          {
                                                              [mappings enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL* stop) {
                                                                  
                                                                  NSArray<NSString*> *threePidArray = threePidArrayByThreePidConcatHash[key];
                                                                  
                                                                  if (threePidArray.count == 2)
                                                                  {
                                                                      // Medium, 3 pid, Matrix ID
                                                                      NSArray *userItems = @[ threePidArray[0], threePidArray[1], value];
                                                                      [discoveredUsers addObject:userItems];
                                                                  }
                                                              }];
                                                          }
                                                              break;
                                                          default:
                                                              break;
                                                      }
                                                  }
                                                  
                                              } andCompletion:^{
                                                  success(discoveredUsers);
                                              }];
                                          }
                                      } failure:^(NSError *error) {
                                          [self dispatchFailure:error inBlock:failure];
                                      }];
    
}

#pragma mark Establishing associations

- (MXHTTPOperation*)requestEmailValidation:(NSString*)email
                              clientSecret:(NSString*)clientSecret
                               sendAttempt:(NSUInteger)sendAttempt
                                  nextLink:(NSString *)nextLink
                                   success:(void (^)(NSString *sid))success
                                   failure:(void (^)(NSError *error))failure
{
    NSString *path = [self buildAPIPathWithPath:@"validate/email/requestToken"];
    
    if (!path)
    {
        NSError *error = [NSError errorWithDomain:MXIdentityServerRestClientErrorDomain code:MXIdentityServerRestClientErrorMissingAPIPrefix userInfo:nil];
        failure(error);
        return nil;
    }
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                      @"email": email,
                                                                                      @"client_secret": clientSecret,
                                                                                      @"send_attempt" : @(sendAttempt)
                                                                                      }];
    
    if (nextLink)
    {
        parameters[@"next_link"] = nextLink;
    }
    
    NSData *payloadData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:nil];

    return [self.httpClient requestWithMethod:@"POST"
                                         path:path
                                   parameters:nil
                           needsAuthorization:self.isUsingV2API
                                         data:payloadData
                                      headers:@{@"Content-Type": @"application/json"}
                                      timeout:-1
                               uploadProgress:nil
                                      success:^(NSDictionary *JSONResponse) {
                                          if (success)
                                          {
                                              __block NSString *sid;
                                              [self dispatchProcessing:^{
                                                  MXJSONModelSetString(sid, JSONResponse[@"sid"]);
                                              } andCompletion:^{
                                                  success(sid);
                                              }];
                                          }
                                      } failure:^(NSError *error) {
                                          [self dispatchFailure:error inBlock:failure];
                                      }];
    
}

- (MXHTTPOperation*)requestPhoneNumberValidation:(NSString*)phoneNumber
                                     countryCode:(NSString*)countryCode
                                    clientSecret:(NSString*)clientSecret
                                     sendAttempt:(NSUInteger)sendAttempt
                                        nextLink:(NSString *)nextLink
                                         success:(void (^)(NSString *sid, NSString *msisdn))success
                                         failure:(void (^)(NSError *error))failure
{
    NSString *path = [self buildAPIPathWithPath:@"validate/msisdn/requestToken"];
    
    if (!path)
    {
        NSError *error = [NSError errorWithDomain:MXIdentityServerRestClientErrorDomain code:MXIdentityServerRestClientErrorMissingAPIPrefix userInfo:nil];
        failure(error);
        return nil;
    }
    
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
    
    NSData *payloadData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:nil];
    
    return [self.httpClient requestWithMethod:@"POST"
                                         path:path
                                   parameters:nil
                           needsAuthorization:self.isUsingV2API
                                         data:payloadData
                                      headers:@{@"Content-Type": @"application/json"}
                                      timeout:-1
                               uploadProgress:nil
                                      success:^(NSDictionary *JSONResponse) {
                                          if (success)
                                          {
                                              __block NSString *sid, *msisdn;
                                              [self dispatchProcessing:^{
                                                  MXJSONModelSetString(sid, JSONResponse[@"sid"]);
                                                  MXJSONModelSetString(msisdn, JSONResponse[@"msisdn"]);
                                              } andCompletion:^{
                                                  success(sid, msisdn);
                                              }];
                                          }
                                      } failure:^(NSError *error) {
                                          [self dispatchFailure:error inBlock:failure];
                                      }];
}

- (MXHTTPOperation *)submit3PIDValidationToken:(NSString *)token
                                        medium:(NSString *)medium
                                  clientSecret:(NSString *)clientSecret
                                           sid:(NSString *)sid
                                       success:(void (^)(void))success
                                       failure:(void (^)(NSError *))failure
{
    // Sanity check
    if (!medium.length)
    {
        NSError *error = [NSError errorWithDomain:MXIdentityServerRestClientErrorDomain code:MXIdentityServerRestClientErrorUnknown userInfo:nil];
        failure(error);
        return nil;
    }
    
    NSString *path = [NSString stringWithFormat:@"validate/%@/submitToken", medium];
    
    NSString *apiPath = [self buildAPIPathWithPath:path];
    
    if (!apiPath)
    {
        NSError *error = [NSError errorWithDomain:MXIdentityServerRestClientErrorDomain code:MXIdentityServerRestClientErrorMissingAPIPrefix userInfo:nil];
        failure(error);
        return nil;
    }
    
    NSDictionary *jsonDictionary = @{
                                     @"token": token,
                                     @"client_secret": clientSecret,
                                     @"sid": sid
                                     };
    
    NSData *payloadData = [NSJSONSerialization dataWithJSONObject:jsonDictionary options:0 error:nil];
    
    return [self.httpClient requestWithMethod:@"POST"
                                         path:apiPath
                                   parameters:nil
                           needsAuthorization:self.isUsingV2API
                                         data:payloadData
                                      headers:@{@"Content-Type": @"application/json"}
                                      timeout:-1
                               uploadProgress:nil
                                      success:^(NSDictionary *JSONResponse) {
                                          __block BOOL successValue = NO;
                                          
                                          [self dispatchProcessing:^{
                                              MXJSONModelSetBoolean(successValue, JSONResponse[@"success"]);
                                          } andCompletion:^{
                                              if (successValue)
                                              {
                                                  if (success)
                                                  {
                                                      success();
                                                  }
                                              }
                                              else if (failure)
                                              {
                                                  MXError *error = [[MXError alloc] initWithErrorCode:kMXErrCodeStringUnknownToken error:kMXErrorStringInvalidToken];
                                                  failure([error createNSError]);
                                              }
                                          }];
                                      } failure:^(NSError *error) {
                                          [self dispatchFailure:error inBlock:failure];
                                      }];
}

#pragma mark Other

- (MXHTTPOperation *)pingIdentityServer:(void (^)(void))success failure:(void (^)(NSError *))failure
{
    NSString *apiPathPrefix = self.preferredAPIPathPrefix;
    
    if (!apiPathPrefix)
    {
        NSError *error = [NSError errorWithDomain:MXIdentityServerRestClientErrorDomain code:MXIdentityServerRestClientErrorMissingAPIPrefix userInfo:nil];
        failure(error);
        return nil;
    }
    
    return [self isAPIPathPrefixAvailable:apiPathPrefix success:^{
        if (success)
        {
            [self dispatchProcessing:nil
                       andCompletion:^{
                           success();
                       }];
        }
    } failure:^(NSError * _Nonnull error) {
        [self dispatchFailure:error inBlock:failure];
    }];
}

- (MXHTTPOperation *)isAPIPathPrefixAvailable:(NSString*)apiPathPrefix
                                      success:(void (^)(void))success
                                      failure:(void (^)(NSError *))failure
{
    return [self.httpClient requestWithMethod:@"GET"
                                         path:apiPathPrefix
                                   parameters:nil
                                      success:^(NSDictionary *JSONResponse) {
                                          if (success)
                                          {
                                              [self dispatchSuccess:success];
                                          }
                                      } failure:^(NSError *error) {
                                          
                                          NSError *finalError = error;
                                          
                                          if ([error.domain isEqualToString:AFURLResponseSerializationErrorDomain])
                                          {
                                              NSHTTPURLResponse *httpURLResponse;
                                              MXJSONModelSet(httpURLResponse, [NSHTTPURLResponse class], error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey])
                                              
                                              if (httpURLResponse.statusCode == 404)
                                              {
                                                  finalError = [NSError errorWithDomain:MXIdentityServerRestClientErrorDomain code:MXIdentityServerRestClientErrorAPIPrefixNotFound userInfo:nil];
                                              }
                                          }
                                          
                                          [self dispatchFailure:finalError inBlock:failure];
                                      }];
}

- (MXHTTPOperation*)signUrl:(NSString*)signUrl
                       mxid:(NSString*)mxid
                    success:(void (^)(NSDictionary *thirdPartySigned))success
                    failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"%@&mxid=%@", signUrl, mxid];
    
    return [self.httpClient requestWithMethod:@"POST"
                                         path:path
                                   parameters:nil
                                      success:^(NSDictionary *JSONResponse) {
                                          if (success)
                                          {
                                              [self dispatchProcessing:nil andCompletion:^{
                                                  success(JSONResponse);
                                              }];
                                          }
                                          
                                      } failure:^(NSError *error) {
                                          [self dispatchFailure:error inBlock:failure];
                                      }];
}

- (MXHTTPOperation *)getAccessTokenAndRenewIfNeededWithSuccess:(void (^)(NSString *accessToken))success
                                                       failure:(void (^)(NSError *error))failure
{
    return [self.httpClient getAccessTokenAndRenewIfNeededWithSuccess:success failure:failure];
}

#pragma mark - Private methods

/**
 Dispatch code blocks to respective GCD queue.
 
 @param processingBlock code block to run on the processing queue.
 @param completionBlock code block to run on the completion queue.
 */
- (void)dispatchProcessing:(dispatch_block_t)processingBlock andCompletion:(dispatch_block_t)completionBlock
{
    if (self.processingQueue)
    {
        MXWeakify(self);
        dispatch_async(self.processingQueue, ^{
            MXStrongifyAndReturnIfNil(self);
            
            if (processingBlock)
            {
                processingBlock();
            }
            
            if (self.completionQueue)
            {
                dispatch_async(self.completionQueue, ^{
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
    if (failureBlock && self.processingQueue)
    {
        MXWeakify(self);
        dispatch_async(self.processingQueue, ^{
            MXStrongifyAndReturnIfNil(self);
            
            if (self.completionQueue)
            {
                dispatch_async(self.completionQueue, ^{
                    failureBlock(error);
                });
            }
        });
    }
}

- (NSString*)buildAPIPathWithPath:(NSString*)path
{
    return [self buildAPIPathWithAPIPathPrefix:self.preferredAPIPathPrefix andPath:path];
}

- (NSString*)buildAPIPathWithAPIPathPrefix:(NSString*)apiPathPrefix andPath:(NSString*)path
{
    NSString *apiPath;
    
    if (apiPathPrefix)
    {
        apiPath = [NSString stringWithFormat:@"%@/%@", apiPathPrefix, path];
    }
    
    return apiPath;
}

@end
