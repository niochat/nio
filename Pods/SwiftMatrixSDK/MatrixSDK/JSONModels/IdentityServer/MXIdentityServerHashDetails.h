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

#import "MXJSONModel.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Defines & Constants

/**
 Identity server v2 API hash algorithms
 */
typedef NS_ENUM(NSInteger, MXIdentityServerHashAlgorithm) {
    MXIdentityServerHashAlgorithmNone,
    MXIdentityServerHashAlgorithmSHA256,
    MXIdentityServerHashAlgorithmUnknown
};

/**
 JSON model for hashing information from the identity server returns by "/hash_details" endpoint.
 */
@interface MXIdentityServerHashDetails : MXJSONModel

#pragma mark - Properties

@property (nonatomic, readonly) NSString *pepper;
@property (nonatomic, readonly) NSArray<NSString*> *algorithms;

#pragma mark - Methods

- (BOOL)containsAlgorithm:(MXIdentityServerHashAlgorithm)hashAlgorithm;

#pragma mark - Utility methods

+ (NSString*)stringValueForHashAlgorithm:(MXIdentityServerHashAlgorithm)hashAlgorithm;

+ (MXIdentityServerHashAlgorithm)hashAlgorithmFromString:(NSString*)hashAlgorithmStringValue;

@end

NS_ASSUME_NONNULL_END
