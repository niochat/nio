/*
 Copyright 2019 New Vector Ltd

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

@class MXLoginResponse;

NS_ASSUME_NONNULL_BEGIN

/**
 The `MXCredentials` class contains credentials to communicate with the Matrix
 Client-Server API.
 */
@interface MXCredentials : NSObject

/**
 The homeserver url (ex: "https://matrix.org").
 */
@property (nonatomic, nullable) NSString *homeServer;

/**
 The identity server url (ex: "https://vector.im").
 */
@property (nonatomic, nullable) NSString *identityServer;

/**
 The obtained user id.
 */
@property (nonatomic, nullable) NSString *userId;

/**
 The access token to create a MXRestClient
 */
@property (nonatomic, nullable) NSString *accessToken;

/**
 The access token to create a MXIdentityServerRestClient
 */
@property (nonatomic, nullable) NSString *identityServerAccessToken;

/**
 The device id.
 */
@property (nonatomic, nullable) NSString *deviceId;

/**
 The homeserver name (ex: "matrix.org").
 */
- (nullable NSString *)homeServerName;

/**
 The server certificate trusted by the user (nil when the server is trusted by the device).
 */
@property (nonatomic, nullable) NSData *allowedCertificate;

/**
 The ignored server certificate (set when the user ignores a certificate change).
 */
@property (nonatomic, nullable) NSData *ignoredCertificate;


/**
 Simple MXCredentials construtor

 @param homeServer the homeserver URL.
 @param userId the user id.
 @param accessToken the user access token.
 @return a MXCredentials instance.
 */
- (instancetype)initWithHomeServer:(NSString*)homeServer
                            userId:(nullable NSString*)userId
                       accessToken:(nullable NSString*)accessToken;

/**
 Create credentials from a login or register response.

 @param loginResponse the login or register response.
 @param defaultCredentials credentials to use if loginResponse data cannot be trusted or missing.
 @return a MXCredentials instance.
 */
- (instancetype)initWithLoginResponse:(MXLoginResponse*)loginResponse
                andDefaultCredentials:(nullable MXCredentials*)defaultCredentials;

@end

NS_ASSUME_NONNULL_END
