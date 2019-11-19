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

#import "MXHTTPClient.h"

#import "MXError.h"
#import "MXSDKOptions.h"
#import "MXBackgroundModeHandler.h"
#import "MXTools.h"
#import "MXHTTPClient_Private.h"

#import <AFNetworking/AFNetworking.h>

#pragma mark - Constants definitions
/**
 The max time in milliseconds a request can be retried in the case of rate limiting errors.
 */
#define MXHTTPCLIENT_RATE_LIMIT_MAX_MS 20000

/**
 The jitter value to apply to compute a random retry time.
 */
#define MXHTTPCLIENT_RETRY_JITTER_MS 3000

NSString* const MXHTTPClientErrorResponseDataKey = @"com.matrixsdk.httpclient.error.response.data";
NSString* const kMXHTTPClientUserConsentNotGivenErrorNotification = @"kMXHTTPClientUserConsentNotGivenErrorNotification";
NSString* const kMXHTTPClientUserConsentNotGivenErrorNotificationConsentURIKey = @"kMXHTTPClientUserConsentNotGivenErrorNotificationConsentURIKey";
NSString* const kMXHTTPClientMatrixErrorNotification = @"kMXHTTPClientMatrixErrorNotification";
NSString* const kMXHTTPClientMatrixErrorNotificationErrorKey = @"kMXHTTPClientMatrixErrorNotificationErrorKey";


static NSUInteger requestCount = 0;


@interface MXHTTPClient ()
{
    /**
     Use AFNetworking as HTTP client.
     */
    AFHTTPSessionManager *httpManager;

    /**
     The main observer to AFNetworking reachability.
     */
    id reachabilityObserver;

    /**
     The list of blocks managing request retries once network is back
     */
    NSMutableArray *reachabilityObservers;

    /**
     Unrecognized Certificate handler
     */
    MXHTTPClientOnUnrecognizedCertificate onUnrecognizedCertificateBlock;

    /**
     Flag to indicate that the underlying NSURLSession has been invalidated.
     In this state, we can not use anymore NSURLSession else it crashes.
     */
    BOOL invalidatedSession;
}

/**
 The access token used for authenticated requests.
 */
@property (nonatomic, strong) NSString *accessToken;

/**
 The current background task id if any.
 */
@property (nonatomic, strong) id<MXBackgroundTask> backgroundTask;

@end

@implementation MXHTTPClient

#pragma mark - Properties override

// TODO: Set Authorization field only for authenticated requests
- (void)setAccessToken:(NSString *)accessToken
{
    _accessToken = accessToken;
    
    [self updateAuthorizationBearHTTPHeaderFieldWithAccessToken:accessToken];
}

- (NSURL *)baseURL
{
    return httpManager.baseURL;
}

#pragma mark - Public methods
-(id)initWithBaseURL:(NSString *)baseURL andOnUnrecognizedCertificateBlock:(MXHTTPClientOnUnrecognizedCertificate)onUnrecognizedCertBlock
{
    return [self initWithBaseURL:baseURL accessToken:nil andOnUnrecognizedCertificateBlock:onUnrecognizedCertBlock];
}

-(id)initWithBaseURL:(NSString *)baseURL accessToken:(NSString *)accessToken andOnUnrecognizedCertificateBlock:(MXHTTPClientOnUnrecognizedCertificate)onUnrecognizedCertBlock
{
    self = [super init];
    if (self)
    {
        httpManager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:baseURL]];

        [self setDefaultSecurityPolicy];

        onUnrecognizedCertificateBlock = onUnrecognizedCertBlock;

        // Send requests parameters in JSON format by default
        self.requestParametersInJSON = YES;

        // No need for caching. The sdk caches the data it needs
        [httpManager.requestSerializer setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];

        // Set authorization HTTP header if access token is present
        if (accessToken)
        {
            _accessToken = accessToken;
            [httpManager.requestSerializer setValue:[NSString stringWithFormat:@"Bearer %@", accessToken] forHTTPHeaderField:@"Authorization"];
        }

        [self setUpNetworkReachibility];
        [self setUpSSLCertificatesHandler];

        // Track potential expected session invalidation (seen on iOS10 beta)
        MXWeakify(self);
        [httpManager setSessionDidBecomeInvalidBlock:^(NSURLSession * _Nonnull session, NSError * _Nonnull error) {
            NSLog(@"[MXHTTPClient] SessionDidBecomeInvalid: %@: %@", session, error);

            MXStrongifyAndReturnIfNil(self);
            self->invalidatedSession = YES;
        }];
    }
    return self;
}

- (void)dealloc
{
    [self cancel];
    [self cleanupBackgroundTask];
    
    [[NSNotificationCenter defaultCenter] removeObserver:reachabilityObserver];
}

- (MXHTTPOperation*)requestWithMethod:(NSString *)httpMethod
                                 path:(NSString *)path
                           parameters:(NSDictionary*)parameters
                              success:(void (^)(NSDictionary *JSONResponse))success
                              failure:(void (^)(NSError *error))failure
{
    return [self requestWithMethod:httpMethod path:path parameters:parameters timeout:-1 success:success failure:failure];
}

- (MXHTTPOperation*)requestWithMethod:(NSString *)httpMethod
                                 path:(NSString *)path
                           parameters:(NSDictionary*)parameters
                              timeout:(NSTimeInterval)timeoutInSeconds
                              success:(void (^)(NSDictionary *JSONResponse))success
                              failure:(void (^)(NSError *error))failure
{
    return [self requestWithMethod:httpMethod path:path parameters:parameters data:nil headers:nil timeout:timeoutInSeconds uploadProgress:nil success:success failure:failure ];
}

- (MXHTTPOperation*)requestWithMethod:(NSString *)httpMethod
                   path:(NSString *)path
             parameters:(NSDictionary*)parameters
                   data:(NSData *)data
                headers:(NSDictionary*)headers
                timeout:(NSTimeInterval)timeoutInSeconds
         uploadProgress:(void (^)(NSProgress *uploadProgress))uploadProgress
                success:(void (^)(NSDictionary *JSONResponse))success
                failure:(void (^)(NSError *error))failure
{
    MXHTTPOperation *mxHTTPOperation = [[MXHTTPOperation alloc] init];

    [self tryRequest:mxHTTPOperation method:httpMethod path:path parameters:parameters data:data headers:headers timeout:timeoutInSeconds uploadProgress:uploadProgress success:success failure:failure];

    return mxHTTPOperation;
}

- (MXHTTPOperation*)requestWithMethod:(NSString *)httpMethod
                                 path:(NSString *)path
                           parameters:(NSDictionary*)parameters
                   needsAuthorization:(BOOL)needsAuthorization
                              success:(void (^)(NSDictionary *JSONResponse))success
                              failure:(void (^)(NSError *error))failure
{
    return [self requestWithMethod:httpMethod path:path parameters:parameters needsAuthorization:needsAuthorization timeout:-1 success:success failure:failure];
}

- (MXHTTPOperation*)requestWithMethod:(NSString *)httpMethod
                                 path:(NSString *)path
                           parameters:(NSDictionary*)parameters
                   needsAuthorization:(BOOL)needsAuthorization
                              timeout:(NSTimeInterval)timeoutInSeconds
                              success:(void (^)(NSDictionary *JSONResponse))success
                              failure:(void (^)(NSError *error))failure
{
    return [self requestWithMethod:httpMethod path:path parameters:parameters needsAuthorization:needsAuthorization data:nil headers:nil timeout:timeoutInSeconds uploadProgress:nil success:success failure:failure];
}


- (MXHTTPOperation*)requestWithMethod:(NSString *)httpMethod
                                 path:(NSString *)path
                           parameters:(NSDictionary*)parameters
                   needsAuthorization:(BOOL)needsAuthorization
                                 data:(NSData *)data
                              headers:(NSDictionary*)headers
                              timeout:(NSTimeInterval)timeoutInSeconds
                       uploadProgress:(void (^)(NSProgress *uploadProgress))uploadProgress
                              success:(void (^)(NSDictionary *JSONResponse))success
                              failure:(void (^)(NSError *error))failure
{
    MXHTTPOperation *mxHTTPOperation = [[MXHTTPOperation alloc] init];
    
    [self tryRequest:mxHTTPOperation
              method:httpMethod
                path:path
          parameters:parameters
                data:data
            headers:headers
             timeout:timeoutInSeconds
      uploadProgress:uploadProgress
             success:success
             failure:^(NSError *error) {
                 
                 if (needsAuthorization
                     && error
                     && self.shouldRenewTokenHandler(error)
                     && self.renewTokenHandler)
                 {
                     dispatch_async(dispatch_get_main_queue(), ^{
                         
                         // Remove current access token
                         self.accessToken = nil;
                         
                         mxHTTPOperation.operation = nil;
                         
                         typeof(self) __weak weakSelf = self;
                         
                         self.renewTokenHandler(^(NSString *accessToken) {
                             
                             typeof(self) strongSelf = weakSelf;
                             
                             if (strongSelf)
                             {
                                 strongSelf.accessToken = accessToken;
                                 
                                 [strongSelf tryRequest:mxHTTPOperation
                                                 method:httpMethod
                                                   path:path
                                             parameters:parameters
                                                   data:data
                                                headers:headers
                                                timeout:timeoutInSeconds
                                         uploadProgress:uploadProgress
                                                success:success
                                                failure:failure];
                             }
                         }, ^(NSError *error) {
                             failure(error);
                         });
                     });
                 }
                 else
                 {
                     failure(error);
                 }
             }];
    
    return mxHTTPOperation;
}

- (MXHTTPOperation *)getAccessTokenAndRenewIfNeededWithSuccess:(void (^)(NSString *accessToken))success
                                                       failure:(void (^)(NSError *error))failure
{
    if (self.accessToken)
    {
        success(self.accessToken);
        return nil;
    }
    
    typeof(self) __weak weakSelf = self;
    
    return self.renewTokenHandler(^(NSString *accessToken) {
        
        typeof(self) strongSelf = weakSelf;
        
        if (strongSelf)
        {
            strongSelf.accessToken = accessToken;
        }
        
        success(accessToken);
        
    }, ^(NSError *error) {
        failure(error);
    });
}

- (void)tryRequest:(MXHTTPOperation*)mxHTTPOperation
            method:(NSString *)httpMethod
              path:(NSString *)path
        parameters:(NSDictionary*)parameters
              data:(NSData *)data
           headers:(NSDictionary*)headers
           timeout:(NSTimeInterval)timeoutInSeconds
    uploadProgress:(void (^)(NSProgress *uploadProgress))uploadProgress
           success:(void (^)(NSDictionary *JSONResponse))success
           failure:(void (^)(NSError *error))failure
{
    // Sanity check
    if (invalidatedSession)
    {
        // This 
    	NSLog(@"[MXHTTPClient] tryRequest: ignore the request as the NSURLSession has been invalidated");
        return;
    }

    NSString *URLString = [[NSURL URLWithString:path relativeToURL:httpManager.baseURL] absoluteString];
    
    NSMutableURLRequest *request;
    request = [httpManager.requestSerializer requestWithMethod:httpMethod URLString:URLString parameters:parameters error:nil];
    if (data)
    {
        NSParameterAssert(![httpMethod isEqualToString:@"GET"] && ![httpMethod isEqualToString:@"HEAD"]);
        request.HTTPBody = data;
        for (NSString *key in headers.allKeys)
        {
            [request setValue:[headers valueForKey:key] forHTTPHeaderField:key];
        }
    }

    // If a timeout is specified, set it
    if (-1 != timeoutInSeconds)
    {
        [request setTimeoutInterval:timeoutInSeconds];
    }

    MXWeakify(self);

    NSDate *startDate = [NSDate date];
    NSUInteger requestNumber = requestCount++;

    NSLog(@"[MXHTTPClient] #%@ - %@", @(requestNumber), path);

    mxHTTPOperation.numberOfTries++;
    mxHTTPOperation.operation = [httpManager dataTaskWithRequest:request uploadProgress:^(NSProgress * _Nonnull theUploadProgress) {
        
        if (uploadProgress)
        {
            // theUploadProgress is called from an AFNetworking thread. So, switch to the UI one
            dispatch_async(dispatch_get_main_queue(), ^{
                uploadProgress(theUploadProgress);
            });
        }
        
    } downloadProgress:nil completionHandler:^(NSURLResponse * _Nonnull theResponse, NSDictionary *JSONResponse, NSError * _Nullable error) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse*)theResponse;

        NSLog(@"[MXHTTPClient] #%@ - %@ completed in %.0fms" ,@(requestNumber), path, [[NSDate date] timeIntervalSinceDate:startDate] * 1000);

        if (!weakself)
        {
            // Log which request failed because of a potentiel unexpected object release
            [MXHTTPClient logRequestFailure:mxHTTPOperation path:path statusCode:response.statusCode error:error];
        }
        MXStrongifyAndReturnIfNil(self);

        mxHTTPOperation.operation = nil;

        if (!error)
        {
            NSUInteger responseDelayMS = [MXHTTPClient delayForRequest:request];
            if (responseDelayMS)
            {
                NSLog(@"[MXHTTPClient] Delay call of success for request %p", mxHTTPOperation);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, responseDelayMS * USEC_PER_SEC), dispatch_get_main_queue(), ^{
                    success(JSONResponse);
                });
            }
            else
            {
                success(JSONResponse);
            }
        }
        else
        {
            [MXHTTPClient logRequestFailure:mxHTTPOperation path:path statusCode:response.statusCode error:error];

            if (response)
            {
                // If the home server (or any other Matrix server) sent data, it may contain 'errcode' and 'error'.
                // In this case, we return an NSError which encapsulates MXError information.
                // When neither 'errcode' nor 'error' are present, the received data are reported in NSError userInfo thanks to 'MXHTTPClientErrorResponseDataKey' key.
                if (JSONResponse)
                {
                    NSLog(@"[MXHTTPClient] Error JSONResponse: %@", JSONResponse);

                    if (JSONResponse[kMXErrorCodeKey] || JSONResponse[kMXErrorMessageKey])
                    {
                        // Extract values from the home server JSON response
                        MXError *mxError = [self mxErrorFromJSON:JSONResponse];
                        mxError.httpResponse = response;

                        // Send a notification
                        [[NSNotificationCenter defaultCenter] postNotificationName:kMXHTTPClientMatrixErrorNotification
                                                                            object:self
                                                                          userInfo:@{ kMXHTTPClientMatrixErrorNotificationErrorKey: mxError }];

                        if ([mxError.errcode isEqualToString:kMXErrCodeStringLimitExceeded])
                        {
                            error = [mxError createNSError];
                            
                            // Wait and retry if we have not retried too much
                            if (mxHTTPOperation.age < MXHTTPCLIENT_RATE_LIMIT_MAX_MS)
                            {
                                NSString *retryAfterMsString = JSONResponse[@"retry_after_ms"];
                                if (retryAfterMsString)
                                {
                                    int delay = [retryAfterMsString intValue];
                                    if (delay < MXHTTPCLIENT_RATE_LIMIT_MAX_MS)
                                    {
                                        error = nil;
                                        
                                        NSLog(@"[MXHTTPClient] Request %p reached rate limiting. Wait for %@ ms", mxHTTPOperation, retryAfterMsString);
                                        
                                        // Wait for the time provided by the server before retrying
                                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * USEC_PER_SEC), dispatch_get_main_queue(), ^{
                                            
                                            NSLog(@"[MXHTTPClient] Retry rate limited request %p", mxHTTPOperation);
                                            
                                            [self tryRequest:mxHTTPOperation method:httpMethod path:path parameters:parameters data:data headers:headers timeout:timeoutInSeconds uploadProgress:uploadProgress success:^(NSDictionary *JSONResponse) {
                                                
                                                NSLog(@"[MXHTTPClient] Success of rate limited request %p after %tu tries", mxHTTPOperation, mxHTTPOperation.numberOfTries);
                                                
                                                success(JSONResponse);
                                                
                                            } failure:^(NSError *error) {
                                                failure(error);
                                            }];
                                        });
                                    }
                                    else
                                    {
                                        NSLog(@"[MXHTTPClient] Giving up rate limited request %p (may retry after %@ ms).", mxHTTPOperation, retryAfterMsString);
                                    }
                                }
                            }
                            else
                            {
                                NSLog(@"[MXHTTPClient] Giving up rate limited request %p: spent too long retrying.", mxHTTPOperation);
                            }
                        }
                        else if ([mxError.errcode isEqualToString:kMXErrCodeStringConsentNotGiven])
                        {
                            NSString* consentURI = mxError.userInfo[kMXErrorConsentNotGivenConsentURIKey];

                            if (consentURI.length > 0)
                            {
                                NSLog(@"[MXHTTPClient] User did not consent to GDPR");

                                // Send a notification if user did not consent to GDPR
                                [[NSNotificationCenter defaultCenter] postNotificationName:kMXHTTPClientUserConsentNotGivenErrorNotification
                                                                                    object:self
                                                                                  userInfo:@{ kMXHTTPClientUserConsentNotGivenErrorNotificationConsentURIKey: consentURI }];
                            }
                            else
                            {
                                NSLog(@"[MXHTTPClient] User did not consent to GDPR but fail to retrieve consent uri");
                            }

                            error = [mxError createNSError];
                        }
                        else
                        {
                            error = [mxError createNSError];
                        }
                    }
                    else
                    {
                        // Report the received data in userInfo dictionary
                        NSMutableDictionary *userInfo;
                        if (error.userInfo)
                        {
                            userInfo = [NSMutableDictionary dictionaryWithDictionary:error.userInfo];
                        }
                        else
                        {
                            userInfo = [NSMutableDictionary dictionary];
                        }

                        [userInfo setObject:JSONResponse forKey:MXHTTPClientErrorResponseDataKey];

                        error = [NSError errorWithDomain:error.domain code:error.code userInfo:userInfo];
                    }
                }
            }
            else if (mxHTTPOperation.numberOfTries < mxHTTPOperation.maxNumberOfTries
                     && mxHTTPOperation.age < mxHTTPOperation.maxRetriesTime
                     && !([error.domain isEqualToString:NSURLErrorDomain]
                          && (error.code == kCFURLErrorCancelled                    // No need to retry a cancelation (which can also happen on SSL error)
                              || error.code == kCFURLErrorCannotFindHost)           // No need to retry on a non existing host
                         )
                     && response.statusCode != 400 && response.statusCode != 401 && response.statusCode != 403     // No amount of retrying will save you now
                     )
            {
                // Check if it is a network connectivity issue
                AFNetworkReachabilityManager *networkReachabilityManager = [AFNetworkReachabilityManager sharedManager];
                NSLog(@"[MXHTTPClient] request %p. Network reachability: %d", mxHTTPOperation, networkReachabilityManager.isReachable);

                if (networkReachabilityManager.isReachable)
                {
                    // The problem is not the network, do simple retry later
                    MXWeakify(self);
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, [MXHTTPClient timeForRetry:mxHTTPOperation] * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                        MXStrongifyAndReturnIfNil(self);

                        NSLog(@"[MXHTTPClient] Retry request %p. Try #%tu/%tu. Age: %tums. Max retries time: %tums", mxHTTPOperation, mxHTTPOperation.numberOfTries + 1, mxHTTPOperation.maxNumberOfTries, mxHTTPOperation.age, mxHTTPOperation.maxRetriesTime);

                        [self tryRequest:mxHTTPOperation method:httpMethod path:path parameters:parameters data:data headers:headers timeout:timeoutInSeconds uploadProgress:uploadProgress success:^(NSDictionary *JSONResponse) {

                            NSLog(@"[MXHTTPClient] Request %p finally succeeded after %tu tries and %tums", mxHTTPOperation, mxHTTPOperation.numberOfTries, mxHTTPOperation.age);

                            success(JSONResponse);

                        } failure:^(NSError *error) {
                            failure(error);
                        }];

                    });
                }
                else
                {
                    __block NSError *lastError = error;

                    // The device is not connected to the internet, wait for the connection to be up again before retrying
                    MXWeakify(self);
                    id networkComeBackObserver = [self addObserverForNetworkComeBack:^{
                        MXStrongifyAndReturnIfNil(self);

                        NSLog(@"[MXHTTPClient] Network is back for request %p", mxHTTPOperation);

                        // Flag this request as retried
                        lastError = nil;

                        // Check whether the pending operation was not cancelled.
                        if (mxHTTPOperation.maxNumberOfTries)
                        {
                            NSLog(@"[MXHTTPClient] Retry request %p. Try #%tu/%tu. Age: %tums. Max retries time: %tums", mxHTTPOperation, mxHTTPOperation.numberOfTries + 1, mxHTTPOperation.maxNumberOfTries, mxHTTPOperation.age, mxHTTPOperation.maxRetriesTime);

                            MXWeakify(self);
                            [self tryRequest:mxHTTPOperation method:httpMethod path:path parameters:parameters data:data headers:headers timeout:timeoutInSeconds uploadProgress:uploadProgress success:^(NSDictionary *JSONResponse) {
                                MXStrongifyAndReturnIfNil(self);

                                NSLog(@"[MXHTTPClient] Request %p finally succeeded after %tu tries and %tums", mxHTTPOperation, mxHTTPOperation.numberOfTries, mxHTTPOperation.age);

                                success(JSONResponse);

                                // The request is complete, managed the next one
                                [self wakeUpNextReachabilityServer];

                            } failure:^(NSError *error) {
                                MXStrongifyAndReturnIfNil(self);
                                
                                failure(error);

                                // The request is complete, managed the next one
                                [self wakeUpNextReachabilityServer];
                            }];
                        }
                        else
                        {
                            NSLog(@"[MXHTTPClient] The request %p has been cancelled", mxHTTPOperation);

                            // The request is complete, managed the next one
                            [self wakeUpNextReachabilityServer];
                        }
                    }];

                    // Wait for a limit of time. After that the request is considered expired
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (mxHTTPOperation.maxRetriesTime - mxHTTPOperation.age) * USEC_PER_SEC), dispatch_get_main_queue(), ^{
                        MXStrongifyAndReturnIfNil(self);

                        // If the request has not been retried yet, consider we are in error
                        if (lastError)
                        {
                            NSLog(@"[MXHTTPClient] Give up retry for request %p. Time expired.", mxHTTPOperation);

                            [self removeObserverForNetworkComeBack:networkComeBackObserver];
                            failure(lastError);
                        }
                    });
                }
                error = nil;
            }
        }

        if (error)
        {
            NSUInteger responseDelayMS = [MXHTTPClient delayForRequest:request];
            if (responseDelayMS)
            {
                NSLog(@"[MXHTTPClient] Delay call of failure for request %p", mxHTTPOperation);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, responseDelayMS * USEC_PER_SEC), dispatch_get_main_queue(), ^{
                    failure(error);
                });
            }
            else
            {
                failure(error);
            }
        }

        // Delay the call of 'cleanupBackgroundTask' in order to let httpManager.tasks.count
        // decrease.
        // Note that if one of the callbacks of 'tryRequest' makes a new request, the bg
        // task will persist until the end of this new request.
        // The basic use case is the sending of a media which consists in two requests:
        //     - the upload of the media
        //     - then, the sending of the message event associated to this media
        // When backgrounding the app while sending the media, the user expects that the two
        // requests complete.

        dispatch_async(dispatch_get_main_queue(), ^{
            [self cleanupBackgroundTask];
        });
    }];

    // Make request continues when app goes in background
    [self startBackgroundTask];

    [mxHTTPOperation.operation resume];
}

+ (NSUInteger)timeForRetry:(MXHTTPOperation *)httpOperation
{
    NSUInteger jitter = arc4random_uniform(MXHTTPCLIENT_RETRY_JITTER_MS);

    NSUInteger retry = (2 << (httpOperation.numberOfTries - 1)) * 1000 + jitter;
    return retry;
}


#pragma mark - Configuration
- (void)setRequestParametersInJSON:(BOOL)requestParametersInJSON
{
    _requestParametersInJSON = requestParametersInJSON;
    if (_requestParametersInJSON)
    {
        httpManager.requestSerializer = [AFJSONRequestSerializer serializer];
    }
    else
    {
        httpManager.requestSerializer = [AFHTTPRequestSerializer serializer];
    }
    
    // Refresh authorization HTTP header field
    [self updateAuthorizationBearHTTPHeaderFieldWithAccessToken:self.accessToken];
}


#pragma - Background task
/**
 Engage a background task.
 
 The bg task will be ended by the call of 'cleanupBackgroundTask' when the request completes.
 The goal of these methods is to mimic the behavior of 'setShouldExecuteAsBackgroundTaskWithExpirationHandler'
 in AFNetworking < 3.0.
 */
- (void)startBackgroundTask
{
    @synchronized(self)
    {
        id<MXBackgroundModeHandler> handler = [MXSDKOptions sharedInstance].backgroundModeHandler;
        if (handler && !self.backgroundTask.isRunning)
        {
            MXWeakify(self);
            self.backgroundTask = [handler startBackgroundTaskWithName:@"[MXHTTPClient] startBackgroundTask" expirationHandler:^{
                
                MXStrongifyAndReturnIfNil(self);
                
                // Cancel all the tasks currently run by the managed session
                NSArray *tasks = self->httpManager.tasks;
                for (NSURLSessionTask *sessionTask in tasks)
                {
                    [sessionTask cancel];
                }
            }];
        }
    }
}


/**
 End the background task.

 The tast will be stopped only if there is no more http request in progress.
 */
- (void)cleanupBackgroundTask
{
    NSLog(@"[MXHTTPClient] cleanupBackgroundTask");
    
    @synchronized(self)
    {
        if (self.backgroundTask.isRunning && httpManager.tasks.count == 0)
        {
            [self.backgroundTask stop];
            self.backgroundTask = nil;
        }
    }
}

- (void)setPinnedCertificates:(NSSet<NSData *> *)pinnedCertificates
{
    // Restore the default security policy when the provided set is empty.
    if (!pinnedCertificates.count)
    {
        _pinnedCertificates = pinnedCertificates;
        [self setDefaultSecurityPolicy];
        
        return;
    }
    
    // Else consider MXHTTPClientSSLPinningModeCertificate SSL pinning mode by default.
    [self setPinnedCertificates:pinnedCertificates withPinningMode:MXHTTPClientSSLPinningModeCertificate];
}

- (void)setPinnedCertificates:(NSSet<NSData *> *)pinnedCertificates withPinningMode:(MXHTTPClientSSLPinningMode)pinningMode
{
    AFSSLPinningMode mode = AFSSLPinningModeNone;
    switch (pinningMode)
    {
        case MXHTTPClientSSLPinningModePublicKey:
            mode = AFSSLPinningModePublicKey;
            break;
        case MXHTTPClientSSLPinningModeCertificate:
            mode = AFSSLPinningModeCertificate;
            break;
            
        default:
            break;
    }
    
    _pinnedCertificates = pinnedCertificates;
    
    httpManager.securityPolicy = [AFSecurityPolicy policyWithPinningMode:mode withPinnedCertificates:pinnedCertificates];
}

- (NSSet<NSString *> *)acceptableContentTypes
{
    return httpManager.responseSerializer.acceptableContentTypes;
}

- (void)setAcceptableContentTypes:(NSSet<NSString *> *)acceptableContentTypes
{
    httpManager.responseSerializer.acceptableContentTypes = acceptableContentTypes;
}

#pragma mark - Private methods
- (void)cancel
{
    NSLog(@"[MXHTTPClient] cancel");
    [httpManager invalidateSessionCancelingTasks:YES];
}

- (void)setUpNetworkReachibility
{
    AFNetworkReachabilityManager *networkReachabilityManager = [AFNetworkReachabilityManager sharedManager];
    
    // Start monitoring reachibility to get its status and change notifications
    [networkReachabilityManager startMonitoring];

    reachabilityObservers = [NSMutableArray array];
    
    MXWeakify(self);
    reachabilityObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AFNetworkingReachabilityDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        MXStrongifyAndReturnIfNil(self);

        if (networkReachabilityManager.isReachable && self->reachabilityObservers.count)
        {
            // Start retrying request one by one to keep messages order
            NSLog(@"[MXHTTPClient] Network is back. Wake up %tu observers.", self->reachabilityObservers.count);
            [self wakeUpNextReachabilityServer];
        }
    }];
}

- (void)wakeUpNextReachabilityServer
{
    AFNetworkReachabilityManager *networkReachabilityManager = [AFNetworkReachabilityManager sharedManager];
    if (networkReachabilityManager.isReachable)
    {
        void(^onNetworkComeBackBlock)(void) = [reachabilityObservers firstObject];
        if (onNetworkComeBackBlock)
        {
            [reachabilityObservers removeObject:onNetworkComeBackBlock];
            onNetworkComeBackBlock();
        }
    }
}

- (id)addObserverForNetworkComeBack:(void (^)(void))onNetworkComeBackBlock
{
    id block = [onNetworkComeBackBlock copy];
    [reachabilityObservers addObject:block];

    return block;
}

- (void)removeObserverForNetworkComeBack:(id)observer
{
    [reachabilityObservers removeObject:observer];
}

- (void)setUpSSLCertificatesHandler
{
    // Handle SSL certificates
    MXWeakify(self);
    [httpManager setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession * _Nonnull session, NSURLAuthenticationChallenge * _Nonnull challenge, NSURLCredential *__autoreleasing  _Nullable * _Nullable credential) {

        MXStrongifyAndReturnValueIfNil(self, NSURLSessionAuthChallengePerformDefaultHandling);

        NSURLProtectionSpace *protectionSpace = [challenge protectionSpace];

        if ([protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
        {
            if ([self->httpManager.securityPolicy evaluateServerTrust:protectionSpace.serverTrust forDomain:protectionSpace.host])
            {
                *credential = [NSURLCredential credentialForTrust:protectionSpace.serverTrust];
                return NSURLSessionAuthChallengeUseCredential;
            }
            else
            {
                NSLog(@"[MXHTTPClient] Shall we trust %@?", protectionSpace.host);

                if (self->onUnrecognizedCertificateBlock)
                {
                    SecTrustRef trust = [protectionSpace serverTrust];

                    if (SecTrustGetCertificateCount(trust) > 0)
                    {
                        // Consider here the leaf certificate (the one at index 0).
                        SecCertificateRef certif = SecTrustGetCertificateAtIndex(trust, 0);

                        NSData *certifData = (__bridge NSData*)SecCertificateCopyData(certif);
                        if (self->onUnrecognizedCertificateBlock(certifData))
                        {
                            NSLog(@"[MXHTTPClient] Yes, the user trusts its certificate");

                            self->_allowedCertificate = certifData;

                            // Update http manager security policy with this trusted certificate.
                            AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate];
                            securityPolicy.pinnedCertificates = [NSSet setWithObjects:certifData, nil];
                            securityPolicy.allowInvalidCertificates = YES;
                            // Disable the domain validation for this certificate trusted by the user.
                            securityPolicy.validatesDomainName = NO;
                            self->httpManager.securityPolicy = securityPolicy;

                            // Evaluate again server security
                            if ([self->httpManager.securityPolicy evaluateServerTrust:protectionSpace.serverTrust forDomain:protectionSpace.host])
                            {
                                *credential = [NSURLCredential credentialForTrust:protectionSpace.serverTrust];
                                return NSURLSessionAuthChallengeUseCredential;
                            }

                            // Here pin certificate failed
                            NSLog(@"[MXHTTPClient] Failed to pin certificate for %@", protectionSpace.host);
                            return NSURLSessionAuthChallengePerformDefaultHandling;
                        }
                    }
                }

                // Here we don't trust the certificate
                NSLog(@"[MXHTTPClient] No, the user doesn't trust it");
                return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
            }
        }

        return NSURLSessionAuthChallengePerformDefaultHandling;
    }];
}

- (void)setDefaultSecurityPolicy
{
    // If some certificates are included in app bundle, we enable the AFNetworking pinning mode based on certificate 'AFSSLPinningModeCertificate'.
    // These certificates will be handled as pinned certificates (only these certificates will be trusted).
    NSSet<NSData *> *certificates = [AFSecurityPolicy certificatesInBundle:[NSBundle mainBundle]];
    if (certificates && certificates.count)
    {
        httpManager.securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate withPinnedCertificates:certificates];
    }
    else
    {
        httpManager.securityPolicy = [AFSecurityPolicy defaultPolicy];
    }
}

- (MXError*)mxErrorFromJSON:(NSDictionary*)json
{
    // Add key/values other than error code and error message in user info
    NSMutableDictionary *userInfo = [json mutableCopy];
    [userInfo removeObjectForKey:kMXErrorCodeKey];
    [userInfo removeObjectForKey:kMXErrorMessageKey];
    
    NSDictionary *mxErrorUserInfo = nil;
    
    if (userInfo.allKeys.count > 0) {
        mxErrorUserInfo = [NSDictionary dictionaryWithDictionary:userInfo];
    }
    
    return [[MXError alloc] initWithErrorCode:json[kMXErrorCodeKey]
                                        error:json[kMXErrorMessageKey]
                                     userInfo:mxErrorUserInfo];
}

- (void)updateAuthorizationBearHTTPHeaderFieldWithAccessToken:(NSString *)accessToken
{
    if (accessToken)
    {
        [httpManager.requestSerializer setValue:[NSString stringWithFormat:@"Bearer %@", accessToken] forHTTPHeaderField:@"Authorization"];
    }
    else
    {
        [httpManager.requestSerializer clearAuthorizationHeader];
    }
}

+ (void)logRequestFailure:(MXHTTPOperation*)mxHTTPOperation
                     path:(NSString*)path
               statusCode:(NSUInteger)statusCode
                    error:(NSError*)error
{
    NSLog(@"[MXHTTPClient] Request %p failed for path: %@ - HTTP code: %@. Error: %@", mxHTTPOperation, path, @(statusCode), error);
}


#pragma mark - MXHTTPClient_Private
// See MXHTTPClient_Private.h for details
+ (NSMutableDictionary<NSString*, NSNumber*> *)delayedRequests
{
    static NSMutableDictionary<NSString*, NSNumber*> *delayedRequests;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        delayedRequests = [NSMutableDictionary dictionary];
    });
    return delayedRequests;
}

+ (void)setDelay:(NSUInteger)delayMs toRequestsContainingString:(NSString *)string
{
    if (string)
    {
        if (delayMs)
        {
            [MXHTTPClient delayedRequests][string] = @(delayMs);
        }
        else
        {
            [[MXHTTPClient delayedRequests] removeObjectForKey:string];
        }
    }
}

+ (void)removeAllDelays
{
    [[MXHTTPClient delayedRequests] removeAllObjects];
}

+ (NSUInteger)delayForRequest:(NSURLRequest*)request
{
    NSUInteger delayMs = 0;

    NSMutableDictionary<NSString*, NSNumber*> *delayedRequests = [MXHTTPClient delayedRequests];
    if (delayedRequests.count)
    {
        NSString *requestString = request.URL.absoluteString;
        for (NSString *string in delayedRequests)
        {
            if ([requestString containsString:string])
            {
                delayMs = [delayedRequests[string] unsignedIntegerValue];
                break;
            }
        }
    }

    return delayMs;
}

@end
