/*
 Copyright 2014 OpenMarket Ltd
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

FOUNDATION_EXPORT NSString *const kMXNSErrorDomain;

/**
 Matrix error codes
 The error as described by the Matrix standard (http://matrix.org/docs/spec/#api-standards).
 */
typedef NSString* MXErrCodeString;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringForbidden;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringUnknown;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringUnknownToken;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringBadJSON;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringNotJSON;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringNotFound;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringLimitExceeded;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringUserInUse;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringRoomInUse;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringBadPagination;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringUnauthorized;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringOldVersion;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringUnrecognized;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringLoginEmailURLNotYet;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringThreePIDAuthFailed;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringThreePIDInUse;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringThreePIDNotFound;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringServerNotTrusted;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringGuestAccessForbidden;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringConsentNotGiven;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringResourceLimitExceeded;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringBackupWrongKeysVersion;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringPasswordTooShort;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringPasswordNoDigit;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringPasswordNoUppercase;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringPasswordNoLowercase;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringPasswordNoSymbol;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringPasswordInDictionary;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringWeakPassword;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringTermsNotSigned;
FOUNDATION_EXPORT NSString *const kMXErrCodeStringInvalidPepper;

FOUNDATION_EXPORT NSString *const kMXErrorStringInvalidToken;


/**
 Keys and values that can be found in a Matrix error JSON dictionary.
 */
FOUNDATION_EXPORT NSString *const kMXErrorCodeKey;
FOUNDATION_EXPORT NSString *const kMXErrorMessageKey;
FOUNDATION_EXPORT NSString *const kMXErrorConsentNotGivenConsentURIKey;
FOUNDATION_EXPORT NSString *const kMXErrorResourceLimitExceededLimitTypeKey;
FOUNDATION_EXPORT NSString *const kMXErrorResourceLimitExceededAdminContactKey;
FOUNDATION_EXPORT NSString *const kMXErrorResourceLimitExceededLimitTypeMonthlyActiveUserValue;
FOUNDATION_EXPORT NSString *const kMXErrorSoftLogoutKey;

/**
 `MXError` represents an error sent by the home server.
 MXErrors are encapsulated in NSError. This class is an helper to create NSError or extract MXError from NSError.
 */
@interface MXError : NSObject

/**
 The error code. This is a string like "M_FORBIDDEN"
 */
@property (nonatomic, readonly) MXErrCodeString errcode;

/**
 The error description
 */
@property (nonatomic, readonly) NSString *error;

/**
 Additional error info
 */
@property (nonatomic, readonly, copy) NSDictionary *userInfo;

/**
 The HTTP response
 */
@property (nonatomic) NSHTTPURLResponse *httpResponse;

/**
 Construtors.
 */
- (id)initWithErrorCode:(NSString*)errcode error:(NSString*)error;
- (id)initWithErrorCode:(NSString*)errcode error:(NSString*)error userInfo:(NSDictionary*)userInfo;

/**
 Create a MXError from a NSError.
 
 @param nsError The NSError object that is supposed to contain MXError data in its userInfo.
 
 @return The newly-initialized MXError. nil if nsError does not contain MXError information.
 */
- (id)initWithNSError:(NSError*)nsError;

/**
 Generate an NSError for this MXError instance
 
  @return The newly-initialized NSError.
 */
- (NSError*)createNSError;

/**
 Check if an NSError is in the Matrix error domain
 
 @return A boolean that will be YES if the NSError contains MXError data.
 */
+ (BOOL)isMXError:(NSError*)nsError;

@end
