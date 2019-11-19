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

#import "MXError.h"

#pragma mark - Constants definitions

NSString *const kMXNSErrorDomain = @"org.matrix.sdk";

NSString *const kMXErrCodeStringForbidden               = @"M_FORBIDDEN";
NSString *const kMXErrCodeStringUnknown                 = @"M_UNKNOWN";
NSString *const kMXErrCodeStringUnknownToken            = @"M_UNKNOWN_TOKEN";
NSString *const kMXErrCodeStringBadJSON                 = @"M_BAD_JSON";
NSString *const kMXErrCodeStringNotJSON                 = @"M_NOT_JSON";
NSString *const kMXErrCodeStringNotFound                = @"M_NOT_FOUND";
NSString *const kMXErrCodeStringLimitExceeded           = @"M_LIMIT_EXCEEDED";
NSString *const kMXErrCodeStringUserInUse               = @"M_USER_IN_USE";
NSString *const kMXErrCodeStringRoomInUse               = @"M_ROOM_IN_USE";
NSString *const kMXErrCodeStringBadPagination           = @"M_BAD_PAGINATION";
NSString *const kMXErrCodeStringUnauthorized            = @"M_UNAUTHORIZED";
NSString *const kMXErrCodeStringOldVersion              = @"M_OLD_VERSION";
NSString *const kMXErrCodeStringUnrecognized            = @"M_UNRECOGNIZED";
NSString *const kMXErrCodeStringLoginEmailURLNotYet     = @"M_LOGIN_EMAIL_URL_NOT_YET";
NSString *const kMXErrCodeStringThreePIDAuthFailed      = @"M_THREEPID_AUTH_FAILED";
NSString *const kMXErrCodeStringThreePIDInUse           = @"M_THREEPID_IN_USE";
NSString *const kMXErrCodeStringThreePIDNotFound        = @"M_THREEPID_NOT_FOUND";
NSString *const kMXErrCodeStringServerNotTrusted        = @"M_SERVER_NOT_TRUSTED";
NSString *const kMXErrCodeStringGuestAccessForbidden    = @"M_GUEST_ACCESS_FORBIDDEN";
NSString *const kMXErrCodeStringConsentNotGiven         = @"M_CONSENT_NOT_GIVEN";
NSString *const kMXErrCodeStringResourceLimitExceeded   = @"M_RESOURCE_LIMIT_EXCEEDED";
NSString *const kMXErrCodeStringBackupWrongKeysVersion  = @"M_WRONG_ROOM_KEYS_VERSION";
NSString *const kMXErrCodeStringPasswordTooShort        = @"M_PASSWORD_TOO_SHORT";
NSString *const kMXErrCodeStringPasswordNoDigit         = @"M_PASSWORD_NO_DIGIT";
NSString *const kMXErrCodeStringPasswordNoUppercase     = @"M_PASSWORD_NO_UPPERCASE";
NSString *const kMXErrCodeStringPasswordNoLowercase     = @"M_PASSWORD_NO_LOWERCASE";
NSString *const kMXErrCodeStringPasswordNoSymbol        = @"M_PASSWORD_NO_SYMBOL";
NSString *const kMXErrCodeStringPasswordInDictionary    = @"M_PASSWORD_IN_DICTIONARY";
NSString *const kMXErrCodeStringWeakPassword            = @"M_WEAK_PASSWORD";
NSString *const kMXErrCodeStringTermsNotSigned          = @"M_TERMS_NOT_SIGNED";
NSString *const kMXErrCodeStringInvalidPepper           = @"M_INVALID_PEPPER";

NSString *const kMXErrorStringInvalidToken      = @"Invalid token";

NSString *const kMXErrorCodeKey                                             = @"errcode";
NSString *const kMXErrorMessageKey                                          = @"error";
NSString *const kMXErrorConsentNotGivenConsentURIKey                        = @"consent_uri";
NSString *const kMXErrorResourceLimitExceededLimitTypeKey                   = @"limit_type";
NSString *const kMXErrorResourceLimitExceededLimitTypeMonthlyActiveUserValue= @"monthly_active_user";
NSString *const kMXErrorResourceLimitExceededAdminContactKey                = @"admin_contact";
NSString *const kMXErrorSoftLogoutKey                                       = @"soft_logout";


// Random NSError code
// Matrix does not use integer but string for error code
NSInteger const kMXNSErrorCode = 6;

@implementation MXError

-(id)initWithErrorCode:(NSString*)errcode error:(NSString*)error
{
    self = [super init];
    if (self)
    {
        _errcode = errcode;
        _error = error;
    }
    return self;
}

- (id)initWithErrorCode:(NSString*)errcode error:(NSString*)error userInfo:(NSDictionary*)userInfo
{
    self = [super init];
    if (self)
    {
        _errcode = errcode;
        _error = error;
        _userInfo = userInfo;
    }
    return self;
}

-(id)initWithNSError:(NSError*)nsError
{
    if ([MXError isMXError:nsError])
    {
        self = [self initWithErrorCode:nsError.userInfo[@"errcode"]
                                 error:nsError.userInfo[@"error"]];
        if (self)
        {
            _userInfo = nsError.userInfo;
        }
    }
    else
    {
        self = nil;
    }

    return self;
}

- (void)setHttpResponse:(NSHTTPURLResponse *)httpResponse
{
    // Store it to userInfo. This makes it easy to transport through a NSError object
    NSMutableDictionary *userInfo = _userInfo ? [_userInfo mutableCopy] : [NSMutableDictionary dictionary];
    userInfo[@"httpResponse"] = httpResponse;
    _userInfo = userInfo;
}

- (NSHTTPURLResponse *)httpResponse
{
    return _userInfo[@"httpResponse"];
}

- (NSError *)createNSError
{
    NSMutableDictionary *userInfo = _userInfo ? [NSMutableDictionary dictionaryWithDictionary:_userInfo] : [NSMutableDictionary dictionary];
    
    if (self.errcode)
    {
        userInfo[@"errcode"] = self.errcode;
    }

    if (self.error)
    {
        userInfo[@"error"] = self.error;
        userInfo[NSLocalizedDescriptionKey] = self.error;
    }
    
    if ((nil == self.error || 0 == self.error.length) && self.errcode)
    {
        // Fallback: use errcode as description
        userInfo[NSLocalizedDescriptionKey] = self.errcode;
    }
    
    return [NSError errorWithDomain:kMXNSErrorDomain
                               code:kMXNSErrorCode
                           userInfo:userInfo];
}

+ (BOOL)isMXError:(NSError *)nsError
{
    if (nsError && [nsError.domain isEqualToString:kMXNSErrorDomain])
    {
        return YES;
    }
    return NO;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ - %@", self.errcode, self.error];
}

@end
