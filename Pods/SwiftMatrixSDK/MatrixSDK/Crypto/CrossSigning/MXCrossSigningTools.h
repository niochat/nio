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

#import <OLMKit/OLMKit.h>

#import "MXCrossSigningKey.h"

NS_ASSUME_NONNULL_BEGIN


#pragma mark - Constants

FOUNDATION_EXPORT NSString *const MXCrossSigningToolsErrorDomain;

typedef NS_ENUM(NSInteger, MXCrossSigningToolsErrorCode)
{
    MXCrossSigningToolsMissingSignatureErrorCode,
};


@interface MXCrossSigningTools : NSObject

- (NSDictionary*)pkSignObject:(NSDictionary*)object withPkSigning:(OLMPkSigning*)pkSigning userId:(NSString*)userId publicKey:(NSString*)publicKey error:(NSError* _Nullable *)error;

- (BOOL)pkVerifyObject:(NSDictionary*)object userId:(NSString*)userId publicKey:(NSString*)publicKey error:(NSError**)error;


- (void)pkSignKey:(MXCrossSigningKey*)crossSigningKey withPkSigning:(OLMPkSigning*)pkSigning userId:(NSString*)userId publicKey:(NSString*)publicKey;

- (BOOL)pkVerifyKey:(MXCrossSigningKey*)crossSigningKey userId:(NSString*)userId publicKey:(NSString*)publicKey error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
