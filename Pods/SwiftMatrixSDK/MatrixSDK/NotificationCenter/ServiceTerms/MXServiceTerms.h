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

#import "MXHTTPOperation.h"
#import "MXLoginTerms.h"
#import "MXSession.h"

/**
 Services around Matrix.
 */
typedef enum : NSUInteger
{
    // An Identity Service
    MXServiceTypeIdentityService = 0,

    // An Integration Manager
    MXServiceTypeIntegrationManager
} MXServiceType;

/**
 MXServiceTerms error domain
 */
FOUNDATION_EXPORT NSString * _Nonnull const MXServiceTermsErrorDomain;

/**
 MXServiceTerms error codes
 */
NS_ERROR_ENUM(MXServiceTermsErrorDomain)
{
    MXServiceTermsErrorUnknown,
    MXServiceTermsErrorMissingParameters
};

NS_ASSUME_NONNULL_BEGIN

@interface MXServiceTerms : NSObject

- (instancetype)initWithBaseUrl:(NSString*)baseUrl serviceType:(MXServiceType)serviceType matrixSession:(nullable MXSession *)mxSession accessToken:(nullable NSString *)accessToken;

@property (nonatomic, readonly) NSString *baseUrl;
@property (nonatomic, readonly) MXServiceType serviceType;

/**
 Get all terms of the service.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)terms:(void (^)(MXLoginTerms * _Nullable terms, NSArray<NSString*> * _Nullable alreadyAcceptedTermsUrls))success
                  failure:(nullable void (^)(NSError * _Nonnull))failure;

/**
 Check if all terms of the service are aggreed.
 
 @param success A block object called when the operation succeeds with a progress
                object indicating how many terms have been already accepted out of
                all terms to accept.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)areAllTermsAgreed:(void (^)(NSProgress *agreedTermsProgress))success
                              failure:(nullable void (^)(NSError * _Nonnull))failure;

/**
 Accept terms by their urls.

 @param termsUrls urls of the terms documents.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)agreeToTerms:(NSArray<NSString *> *)termsUrls
                         success:(void (^)(void))success
                         failure:(nullable void (^)(NSError * _Nonnull))failure;

@end

NS_ASSUME_NONNULL_END
