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

#import "MXIdentityServerHashDetails.h"

#pragma mark - Defines & Constants

static NSString* const kHashDetailsPepperJSONKey = @"lookup_pepper";
static NSString* const kHashDetailsAlgorithmsJSONKey = @"algorithms";

#pragma mark - Private Interface

@interface MXIdentityServerHashDetails()

@property (nonatomic, readwrite) NSString *pepper;
@property (nonatomic, readwrite) NSArray<NSString*> *algorithms;

@end

@implementation MXIdentityServerHashDetails

+ (id)modelFromJSON:(NSDictionary *)jsonDictionary
{
    MXIdentityServerHashDetails *hashDetails;
    
    NSString *pepper;
    NSArray<NSString*> *algorithms;
    
    MXJSONModelSetString(pepper, jsonDictionary[kHashDetailsPepperJSONKey]);
    MXJSONModelSetArray(algorithms, jsonDictionary[kHashDetailsAlgorithmsJSONKey]);
    
    if (pepper && algorithms.count)
    {
        hashDetails = [MXIdentityServerHashDetails new];
        hashDetails.pepper = pepper;
        hashDetails.algorithms = algorithms;
    }
    
    return hashDetails;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *jsonDictionary = [NSMutableDictionary dictionary];
    
    jsonDictionary[kHashDetailsPepperJSONKey] = self.pepper;
    jsonDictionary[kHashDetailsAlgorithmsJSONKey] = self.algorithms;
    
    return jsonDictionary;
}

#pragma mark - Public

- (BOOL)containsAlgorithm:(MXIdentityServerHashAlgorithm)hashAlgorithm
{
    BOOL containsAlgorithm = NO;
    
    NSString *algorithmStringValue = [[self class] stringValueForHashAlgorithm:hashAlgorithm];
    
    if (algorithmStringValue.length)
    {
        containsAlgorithm = [self.algorithms containsObject:algorithmStringValue];
    }
    
    return containsAlgorithm;
}

#pragma mark - Utility methods

+ (NSString*)stringValueForHashAlgorithm:(MXIdentityServerHashAlgorithm)hashAlgorithm
{
    NSString *stringValue;
    
    switch (hashAlgorithm)
    {
        case MXIdentityServerHashAlgorithmNone:
            stringValue = @"none";
            break;
        case MXIdentityServerHashAlgorithmSHA256:
            stringValue = @"sha256";
            break;
        default:
            stringValue = @"";
            break;
    }
    
    return stringValue;
}

+ (MXIdentityServerHashAlgorithm)hashAlgorithmFromString:(NSString*)hashAlgorithmStringValue
{
    MXIdentityServerHashAlgorithm hashAlgorithm;
    
    if ([hashAlgorithmStringValue isEqualToString:@"none"])
    {
        hashAlgorithm = MXIdentityServerHashAlgorithmNone;
    }
    else if ([hashAlgorithmStringValue isEqualToString:@"sha256"])
    {
        hashAlgorithm = MXIdentityServerHashAlgorithmSHA256;
    }
    else
    {
        hashAlgorithm = MXIdentityServerHashAlgorithmUnknown;
    }
    
    return hashAlgorithm;
}

@end
