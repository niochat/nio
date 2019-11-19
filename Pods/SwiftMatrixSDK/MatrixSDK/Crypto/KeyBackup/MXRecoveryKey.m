/*
 Copyright 2018 New Vector Ltd

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

#import "MXRecoveryKey.h"

#import "MXTools.h"

#import <OLMKit/OLMKit.h>

#import <libbase58/libbase58.h>


NSString *const MXRecoveryKeyErrorDomain = @"org.matrix.sdk.recoverykey";

// Picked arbitrarily bits to try & avoid clashing with any bitcoin ones
// (also base58 encoded, albeit with a lot of hashing)
const UInt8 kOlmRecoveryKeyPrefix[] = {0x8B, 0x01};

@implementation MXRecoveryKey

+ (NSString *)encode:(NSData *)key
{
    // Prepend the recovery key 2-bytes header
    NSMutableData *buffer = [NSMutableData dataWithBytes:kOlmRecoveryKeyPrefix length:sizeof(kOlmRecoveryKeyPrefix)];
    [buffer appendData:key];

    // Add a parity checksum
    UInt8 parity = 0;
    UInt8 *bytes = (UInt8 *)buffer.bytes;
    for (NSUInteger i = 0; i < buffer.length; i++)
    {
        parity ^= bytes[i];
    }
    [buffer appendBytes:&parity length:sizeof(parity)];

    // Encode it in Base58
    NSString *recoveryKey = [self encodeBase58:buffer];

    // Add white spaces
    return [MXTools addWhiteSpacesToString:recoveryKey every:4];
}

+ (NSData *)decode:(NSString *)recoveryKey error:(NSError **)error
{
    NSString *recoveryKeyWithNoSpaces = [recoveryKey stringByReplacingOccurrencesOfString:@"\\s"
                                                                               withString:@""
                                                                                  options:NSRegularExpressionSearch
                                                                                    range:NSMakeRange(0, recoveryKey.length)];

    NSMutableData *result = [[self decodeBase58:recoveryKeyWithNoSpaces] mutableCopy];

    if (!result)
    {
        *error = [NSError errorWithDomain:MXRecoveryKeyErrorDomain
                                     code:MXRecoveryKeyErrorBase58Code
                                 userInfo:@{
                                            NSLocalizedDescriptionKey: @"Cannot decode Base58 string",
                                            }];
        return nil;
    }

    // Check length
    if (result.length !=
        sizeof(kOlmRecoveryKeyPrefix) + [OLMPkDecryption privateKeyLength] + 1)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:MXRecoveryKeyErrorDomain
                                         code:MXRecoveryKeyErrorLengthCode
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: @"Incorrect length",
                                                }];
        }
        return nil;
    }

    // Check the checksum
    UInt8 parity = 0;
    UInt8 *bytes = (UInt8 *)result.bytes;
    for (NSUInteger i = 0; i < result.length; i++)
    {
        parity ^= bytes[i];
    }
    if (parity != 0)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:MXRecoveryKeyErrorDomain
                                         code:MXRecoveryKeyErrorParityCode
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: @"Incorrect parity",
                                                }];
        }
        return nil;
    }

    // Check recovery key header
    for (NSUInteger i = 0; i < sizeof(kOlmRecoveryKeyPrefix); i++)
    {
        if (bytes[i] != kOlmRecoveryKeyPrefix[i])
        {
            if (error)
            {
                *error = [NSError errorWithDomain:MXRecoveryKeyErrorDomain
                                             code:MXRecoveryKeyErrorHeaderCode
                                         userInfo:@{
                                                    NSLocalizedDescriptionKey: @"Invalid header",
                                                    }];
            }
            return nil;
        }
    }

    // Remove header and checksum bytes
    [result replaceBytesInRange:NSMakeRange(0, sizeof(kOlmRecoveryKeyPrefix)) withBytes:NULL length:0];
    result.length -= 1;

    return result;
}


#pragma mark - Private methods

+ (NSString *)encodeBase58:(NSData *)data
{
    NSString *base58;

    // Get the required buffer size
    size_t base58Length = 0;
    b58enc(nil, &base58Length, data.bytes, data.length);

    // Encode
    NSMutableData *base58Data = [NSMutableData dataWithLength:base58Length];
    BOOL result = b58enc(base58Data.mutableBytes, &base58Length, data.bytes, data.length);

    if (result)
    {
        base58 = [[NSString alloc] initWithData:base58Data encoding:NSUTF8StringEncoding];
        base58 = [base58 substringToIndex:base58Length - 1];
    }

    return base58;
}

+ (NSData *)decodeBase58:(NSString *)base58
{
    NSMutableData *data;

    NSData *base58Data = [base58 dataUsingEncoding:NSUTF8StringEncoding];

    // Get the required buffer size
    // We need to pass a non null buffer, so allocate one using the base64 string length
    // The decoded buffer can only be smaller
    size_t dataLength = base58.length;
    data = [NSMutableData dataWithLength:dataLength];
    b58tobin(data.mutableBytes, &dataLength, base58Data.bytes, base58Data.length);

    // Decode with the actual result size
    data = [NSMutableData dataWithLength:dataLength];
    BOOL result = b58tobin(data.mutableBytes, &dataLength, base58Data.bytes, base58Data.length);
    if (!result)
    {
        data = nil;
    }

    return data;
}

@end
