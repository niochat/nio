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

#import "MXCrossSigningTools.h"

#import "MXCryptoTools.h"
#import "MXKey.h"


#pragma mark - Constants

NSString *const MXCrossSigningToolsErrorDomain = @"org.matrix.sdk.crosssigning.tools";


@interface MXCrossSigningTools ()
{
    OLMUtility *olmUtility;
}
@end

@implementation MXCrossSigningTools

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        olmUtility = [OLMUtility new];
    }
    return self;
}

- (NSDictionary*)pkSignObject:(NSDictionary*)object withPkSigning:(OLMPkSigning*)pkSigning userId:(NSString*)userId publicKey:(NSString*)publicKey error:(NSError**)error
{
    // Sign the passed object without its `signatures` and `unsigned` fields
    NSMutableDictionary *signatures = [(object[@"signatures"] ?: @{}) mutableCopy];
    NSDictionary *unsignedData = object[@"unsigned"];

    NSMutableDictionary *signedObject = [object mutableCopy];
    [signedObject removeObjectsForKeys:@[@"signatures", @"unsigned"]];

    NSString *signature = [pkSigning sign:[MXCryptoTools canonicalJSONStringForJSON:signedObject] error:error];

    if (!*error)
    {
        // Reinject data
        if (unsignedData)
        {
            signedObject[@"unsigned"] = unsignedData;
        }

        NSMutableDictionary *userSignatures = [(signatures[userId]?: @{}) mutableCopy];
        NSString *keyId = [NSString stringWithFormat:@"%@:%@", kMXKeyEd25519Type, publicKey];
        userSignatures[keyId] = signature;
        signatures[userId] = userSignatures;

        signedObject[@"signatures"] = signatures;
    }

    return signedObject;
}

- (BOOL)pkVerifyObject:(NSDictionary*)object userId:(NSString*)userId publicKey:(NSString*)publicKey error:(NSError**)error
{
    NSString *keyId = [NSString stringWithFormat:@"%@:%@", kMXKeyEd25519Type, publicKey];
    NSString *signature;
    MXJSONModelSetString(signature, object[@"signatures"][userId][keyId]);

    if (!signature)
    {
        NSLog(@"[MXCrossSigningTools] pkVerifyObject. Error: Missing signature for %@:%@ in %@", userId, keyId, object[@"signatures"]);
        if (error)
        {
            *error = [NSError errorWithDomain:MXCrossSigningToolsErrorDomain
                                         code:MXCrossSigningToolsMissingSignatureErrorCode
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: @"Missing signature",
                                                }];
        }
        return NO;
    }

    NSMutableDictionary *signedObject = [object mutableCopy];
    [signedObject removeObjectsForKeys:@[@"signatures", @"unsigned"]];

    NSData *message = [[MXCryptoTools canonicalJSONStringForJSON:signedObject] dataUsingEncoding:NSUTF8StringEncoding];
    return [olmUtility verifyEd25519Signature:signature key:publicKey message:message error:error];
}

- (void)pkSignKey:(MXCrossSigningKey*)crossSigningKey withPkSigning:(OLMPkSigning*)pkSigning userId:(NSString*)userId publicKey:(NSString*)publicKey
{
    NSError *error;
    NSString *signature = [pkSigning sign:[MXCryptoTools canonicalJSONStringForJSON:crossSigningKey.signalableJSONDictionary] error:&error];
    if (!error)
    {
        [crossSigningKey addSignatureFromUserId:userId publicKey:publicKey signature:signature];
    }
}

- (BOOL)pkVerifyKey:(MXCrossSigningKey*)crossSigningKey userId:(NSString*)userId publicKey:(NSString*)publicKey error:(NSError**)error;
{
    NSString *signature = [crossSigningKey signatureFromUserId:userId withPublicKey:publicKey];

    if (!signature)
    {
        return NO;
    }

    NSData *message = [[MXCryptoTools canonicalJSONStringForJSON:crossSigningKey.signalableJSONDictionary] dataUsingEncoding:NSUTF8StringEncoding];
    return [olmUtility verifyEd25519Signature:signature key:publicKey message:message error:error];
}


@end
