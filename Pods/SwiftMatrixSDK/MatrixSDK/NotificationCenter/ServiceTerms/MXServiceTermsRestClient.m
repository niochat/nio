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

#import "MXServiceTermsRestClient.h"

#import "MXHTTPClient.h"

@interface MXServiceTermsRestClient()

@property (nonatomic, strong) MXHTTPClient *httpClient;

@end

@implementation MXServiceTermsRestClient

- (instancetype)initWithBaseUrl:(NSString*)baseUrl accessToken:(nullable NSString *)accessToken
{
    self = [super init];
    if (self)
    {
        _httpClient = [[MXHTTPClient alloc] initWithBaseURL:baseUrl accessToken:accessToken andOnUnrecognizedCertificateBlock:nil];
    }
    return self;
}

- (MXHTTPOperation*)terms:(void (^)(MXLoginTerms * _Nullable terms))success
                  failure:(nullable void (^)(NSError * _Nonnull))failure
{
    return [_httpClient requestWithMethod:@"GET"
                                    path:@"terms"
                              parameters:nil
                                 success:^(NSDictionary *JSONResponse) {

                                     MXLoginTerms *terms;
                                     MXJSONModelSetMXJSONModel(terms, MXLoginTerms.class, JSONResponse);

                                     success(terms);
                                 }
                                 failure:^(NSError *error) {
                                     if (failure)
                                     {
                                         failure(error);
                                     }
                                 }];
}

- (MXHTTPOperation*)agreeToTerms:(NSArray<NSString *> *)termsUrls
                         success:(void (^)(void))success
                         failure:(nullable void (^)(NSError * _Nonnull))failure
{
    return [_httpClient requestWithMethod:@"POST"
                                     path:@"terms"
                               parameters:@{
                                            @"user_accepts": termsUrls
                                            }
                                  success:^(NSDictionary *JSONResponse) {
                                      success();
                                  }
                                  failure:^(NSError *error) {
                                      if (failure)
                                      {
                                          failure(error);
                                      }
                                  }];
}


@end
