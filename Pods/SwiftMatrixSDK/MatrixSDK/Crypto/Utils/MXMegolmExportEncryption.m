/*
 Copyright 2017 OpenMarket Ltd

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

#import "MXMegolmExportEncryption.h"

#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonKeyDerivation.h>

NSString *const MXMegolmExportEncryptionErrorDomain = @"org.matrix.sdk.megolm.export";

NSString *const MXMegolmExportEncryptionHeaderLine = @"-----BEGIN MEGOLM SESSION DATA-----";
NSString *const MXMegolmExportEncryptionTrailerLine = @"-----END MEGOLM SESSION DATA-----";


@implementation MXMegolmExportEncryption

+ (NSData*)decryptMegolmKeyFile:(NSData*)data withPassword:(NSString*)password error:(NSError *__autoreleasing *)error
{
    NSDate *startDate = [NSDate date];

    NSData *result;

    NSData *body = [MXMegolmExportEncryption unpackMegolmKeyFile:data error:error];
    uint8_t *bodyBytes = (uint8_t*)body.bytes;

    if (!*error)
    {
        // Check we have a version byte
        if (body.length < 1)
        {
            *error = [NSError errorWithDomain:MXMegolmExportEncryptionErrorDomain
                                         code:MXMegolmExportErrorInvalidKeyFileTooShortCode
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: @"Invalid file: too short",
                                                }];
            return nil;
        }

        uint8_t version = bodyBytes[0];
        if (version != 1)
        {
            *error = [NSError errorWithDomain:MXMegolmExportEncryptionErrorDomain
                                         code:MXMegolmExportErrorInvalidKeyFileUnsupportedVersionCode
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: @"Unsupported version",
                                                }];
            return nil;
        }

        NSInteger ciphertextLength = body.length-(1+16+16+4+32);
        if (ciphertextLength < 0)
        {
            *error = [NSError errorWithDomain:MXMegolmExportEncryptionErrorDomain
                                         code:MXMegolmExportErrorInvalidKeyFileTooShortCode
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: @"Invalid file: too short",
                                                }];
            return nil;
        }

        NSData *salt = [body subdataWithRange:NSMakeRange(1, 16)];
        NSData *iv = [body subdataWithRange:NSMakeRange(17, 16)];
        NSUInteger iterations = bodyBytes[33] << 24 | bodyBytes[34] << 16 | bodyBytes[35] << 8 | bodyBytes[36];
        NSData *ciphertext = [body subdataWithRange:NSMakeRange(37, ciphertextLength)];
        NSData *hmac = [body subdataWithRange:NSMakeRange(body.length-32, 32)];

        NSData *aesKey, *hmacKey;
        if (kCCSuccess == [MXMegolmExportEncryption deriveKeys:salt iterations:iterations password:password aesKey:&aesKey hmacKey:&hmacKey])
        {
            // Check HMAC
            NSData *toVerify = [body subdataWithRange:NSMakeRange(0, body.length - 32)];

            NSMutableData* hash = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH ];
            CCHmac(kCCHmacAlgSHA256, hmacKey.bytes, hmacKey.length, toVerify.bytes, toVerify.length, hash.mutableBytes);

            if (![hash isEqualToData:hmac])
            {
                *error = [NSError errorWithDomain:MXMegolmExportEncryptionErrorDomain
                                             code:MXMegolmExportErrorAuthenticationFailedCode
                                         userInfo:@{
                                                    NSLocalizedDescriptionKey: @"Authentication check failed: incorrect password?",
                                                    }];
                return nil;
            }

            // Decrypt the cypher text
            CCCryptorRef cryptor;
            CCCryptorStatus status;

            status = CCCryptorCreateWithMode(kCCDecrypt, kCCModeCTR, kCCAlgorithmAES,
                                             ccNoPadding, iv.bytes, aesKey.bytes, kCCKeySizeAES256,
                                             NULL, 0, 0, kCCModeOptionCTR_BE, &cryptor);
            if (status != kCCSuccess)
            {
                *error = [NSError errorWithDomain:MXMegolmExportEncryptionErrorDomain
                                             code:MXMegolmExportErrorCannotInitialiseCryptorCode
                                         userInfo:@{
                                                    NSLocalizedDescriptionKey: @"Cannot initialise decryptor",
                                                    }];
                return nil;
            }

            size_t bufferLength = CCCryptorGetOutputLength(cryptor, ciphertext.length, false);
            NSMutableData *buffer = [NSMutableData dataWithLength:bufferLength];

            size_t outLength;
            status |= CCCryptorUpdate(cryptor,
                                      ciphertext.bytes,
                                      ciphertext.length,
                                      [buffer mutableBytes],
                                      [buffer length],
                                      &outLength);

            status |= CCCryptorRelease(cryptor);

            if (status == kCCSuccess)
            {
                result = buffer;
            }
            else
            {
                *error = [NSError errorWithDomain:MXMegolmExportEncryptionErrorDomain
                                             code:MXMegolmExportErrorCannotDecryptCode
                                         userInfo:@{
                                                    NSLocalizedDescriptionKey: @"Cannot decrypt",
                                                    }];
                return nil;
            }
        }
        else
        {
            *error = [NSError errorWithDomain:MXMegolmExportEncryptionErrorDomain
                                         code:MXMegolmExportErrorCannotDeriveKeysCode
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: @"Cannot derive keys",
                                                }];
            return nil;
        }
    }

    NSLog(@"[MXMegolmExportEncryption] decryptMegolmKeyFile: decrypted %tu bytes in %.0fms", data.length, [[NSDate date] timeIntervalSinceDate:startDate] * 1000);

    return result;
}

+ (NSData*)encryptMegolmKeyFile:(NSData*)data withPassword:(NSString*)password kdfRounds:(NSUInteger)kdfRounds error:(NSError *__autoreleasing *)error
{
    NSDate *startDate = [NSDate date];

    if (!password)
    {
        *error = [NSError errorWithDomain:MXMegolmExportEncryptionErrorDomain
                                     code:MXMegolmExportErrorAuthenticationFailedCode
                                 userInfo:@{
                                            NSLocalizedDescriptionKey: @"Authentication check failed: password is mandatory",
                                            }];
        return nil;
    }

    if (!kdfRounds)
    {
        kdfRounds = 500000;
    }

    NSMutableData *salt = [NSMutableData dataWithLength:16];
    int r = SecRandomCopyBytes(kSecRandomDefault, 16, salt.mutableBytes);

    NSMutableData *iv = [NSMutableData dataWithLength:16];
    r += SecRandomCopyBytes(kSecRandomDefault, 16, iv.mutableBytes);

    if (r != 0)
    {
        *error = [NSError errorWithDomain:MXMegolmExportEncryptionErrorDomain
                                     code:MXMegolmExportErrorCannotInitialiseCryptorCode
                                 userInfo:@{
                                            NSLocalizedDescriptionKey: @"Cannot compute salt or iv",
                                            }];
        return nil;
    }

    // Clear bit 63 of the IV to stop us hitting the 64-bit counter boundary
    // (which would mean we wouldn't be able to decrypt on Android). The loss
    // of a single bit of iv is a price we have to pay.
    uint8_t *ivBytes = (uint8_t*)iv.mutableBytes;
    ivBytes[9] &= 0x7f;

    NSData *aesKey, *hmacKey;
    if (kCCSuccess == [MXMegolmExportEncryption deriveKeys:salt iterations:kdfRounds password:password aesKey:&aesKey hmacKey:&hmacKey])
    {
        // Encrypt
        CCCryptorRef cryptor;
        CCCryptorStatus status;

        status = CCCryptorCreateWithMode(kCCEncrypt, kCCModeCTR, kCCAlgorithmAES,
                                         ccNoPadding, iv.bytes, aesKey.bytes, kCCKeySizeAES256,
                                         NULL, 0, 0, kCCModeOptionCTR_BE, &cryptor);
        if (status != kCCSuccess)
        {
            *error = [NSError errorWithDomain:MXMegolmExportEncryptionErrorDomain
                                         code:MXMegolmExportErrorCannotInitialiseCryptorCode
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: @"Cannot initialise encryptor",
                                                }];
            return nil;
        }

        size_t bufferLength = CCCryptorGetOutputLength(cryptor, data.length, false);
        NSMutableData *cipher = [NSMutableData dataWithLength:bufferLength];

        size_t outLength;
        status |= CCCryptorUpdate(cryptor,
                                  data.bytes,
                                  data.length,
                                  [cipher mutableBytes],
                                  [cipher length],
                                  &outLength);

        status |= CCCryptorRelease(cryptor);

        if (status == kCCSuccess)
        {
            // Packetise
            NSUInteger bodyLength = (1+salt.length+iv.length+4+cipher.length);

            NSMutableData *result = [NSMutableData dataWithLength:bodyLength];
            uint8_t *resultBuffer = (uint8_t*)result.mutableBytes;

            NSUInteger idx = 0;
            resultBuffer[idx++] = 1; // version
            [result replaceBytesInRange:NSMakeRange(idx, salt.length) withBytes:salt.bytes]; idx += salt.length;
            [result replaceBytesInRange:NSMakeRange(idx, iv.length) withBytes:iv.bytes]; idx += iv.length;
            resultBuffer[idx++] = kdfRounds >> 24;
            resultBuffer[idx++] = (kdfRounds >> 16) & 0xff;
            resultBuffer[idx++] = (kdfRounds >> 8) & 0xff;
            resultBuffer[idx++] = kdfRounds & 0xff;
            [result replaceBytesInRange:NSMakeRange(idx, cipher.length) withBytes:cipher.bytes]; idx += cipher.length;

            // Sign
            NSData *toSign = result;

            NSMutableData* hmac = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH ];
            CCHmac(kCCHmacAlgSHA256, hmacKey.bytes, hmacKey.length, toSign.bytes, toSign.length, hmac.mutableBytes);

            [result appendData:hmac];

            NSData *keyFile = [MXMegolmExportEncryption packMegolmKeyFile:result];

            NSLog(@"[MXMegolmExportEncryption] encryptMegolmKeyFile: encrypted %tu bytes in %.0fms", data.length, [[NSDate date] timeIntervalSinceDate:startDate] * 1000);

            return keyFile;
        }
        else
        {
            *error = [NSError errorWithDomain:MXMegolmExportEncryptionErrorDomain
                                         code:MXMegolmExportErrorCannotEncryptCode
                                     userInfo:@{
                                                NSLocalizedDescriptionKey: @"Cannot encrypt",
                                                }];
            return nil;
        }

    }
    else
    {
        *error = [NSError errorWithDomain:MXMegolmExportEncryptionErrorDomain
                                     code:MXMegolmExportErrorCannotDeriveKeysCode
                                 userInfo:@{
                                            NSLocalizedDescriptionKey: @"Cannot derive keys",
                                            }];
        return nil;
    }

    return nil;
}

+ (BOOL)isMegolmKeyFile:(NSURL *)fileURL
{
    BOOL isMegolmKeyFile = NO;

    NSError *error;
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingFromURL:fileURL error:&error];
    if (fileHandle)
    {
        NSData *fileHeaderData = [fileHandle readDataOfLength:MXMegolmExportEncryptionHeaderLine.length];
        NSString *fileHeader = [[NSString alloc] initWithData:fileHeaderData encoding:NSUTF8StringEncoding];

        if ([fileHeader isEqualToString:MXMegolmExportEncryptionHeaderLine])
        {
            isMegolmKeyFile = YES;
        }

        [fileHandle closeFile];
    }

    return isMegolmKeyFile;
}


#pragma mark - Private methods

/**
 Derive the AES and HMAC-SHA-256 keys for the file.

 @param salt for pbkdf.
 @param iterations the number of pbkdf iterations.
 @param password the password.
 @param aesKey the aes key
 @param hmacKey the hmac key
 @return the derivation result. Should be kCCSuccess.
 */
+ (int)deriveKeys:(NSData*)salt iterations:(NSUInteger)iterations password:(NSString*)password aesKey:(NSData**)aesKey hmacKey:(NSData**)hmacKey
{
    int result = kCCSuccess;

    NSDate *startDate = [NSDate date];

    NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];

    NSMutableData *derivedKey = [NSMutableData dataWithLength:64];

    result =  CCKeyDerivationPBKDF(kCCPBKDF2,
                                   passwordData.bytes,
                                   passwordData.length,
                                   salt.bytes,
                                   salt.length,
                                   kCCPRFHmacAlgSHA512,
                                   (uint)iterations,
                                   derivedKey.mutableBytes,
                                   derivedKey.length);

    *aesKey = [derivedKey subdataWithRange:NSMakeRange(0, 32)];
    *hmacKey = [derivedKey subdataWithRange:NSMakeRange(32, derivedKey.length - 32)];

    NSLog(@"[MXMegolmExportEncryption] deriveKeys: %tu iterations took %.0fms", iterations, [[NSDate date] timeIntervalSinceDate:startDate] * 1000);

    return result;
}

/**
 ascii-armour a megolm key file.

 base64s the content, and adds header and trailer lines.

 @param data raw data.
 @return formatted data.
 */
+ (NSData*)packMegolmKeyFile:(NSData*)data
{
    NSMutableArray<NSString*> *lines = [NSMutableArray array];
    [lines addObject:MXMegolmExportEncryptionHeaderLine];

    // We split into lines before base64ing, because encodeBase64 doesn't deal
    // terribly well with large arrays.
    NSUInteger LINE_LENGTH = (72 * 4 / 3);
    NSUInteger nLines = ceil((double)data.length / LINE_LENGTH);
    NSUInteger o = 0;

    for (NSUInteger i = 0; i < nLines; i++)
    {
        NSUInteger len = MIN(LINE_LENGTH, data.length - o);

        NSData *lineData = [data subdataWithRange:NSMakeRange(o, len)];
        [lines addObject:[lineData base64EncodedStringWithOptions:0]];

        o += LINE_LENGTH;
    }

    [lines addObject:MXMegolmExportEncryptionTrailerLine];
    [lines addObject:@""];

    return [[lines componentsJoinedByString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
}

/*
 Unbase64 an ascii-armoured megolm key file.

 Strips the header and trailer lines, and unbase64s the content.

 @param data the input file.
 @param error the output error.
 @return unbase64ed content.
 */
+ (NSData *)unpackMegolmKeyFile:(NSData*)data error:(NSError *__autoreleasing *)error
{
    // Parse the file as a great big String. This should be safe, because there
    // should be no non-ASCII characters, and it means that we can do string
    // comparisons to find the header and footer, and feed it into window.atob.
    NSString *fileStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    NSArray* lines = [fileStr componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];

    // Look for the start line
    NSUInteger lineStart = 0;
    for (lineStart = 0; lineStart < lines.count; lineStart++)
    {
        NSString *line = lines[lineStart];

        if ([line isEqualToString:MXMegolmExportEncryptionHeaderLine])
        {
            break;
        }
    }

    if (lineStart == lines.count)
    {
        *error = [NSError errorWithDomain:MXMegolmExportEncryptionErrorDomain
                                     code:MXMegolmExportErrorInvalidKeyFileHeaderNotFoundCode
                                 userInfo:@{
                                            NSLocalizedDescriptionKey: @"Header line not found",
                                            }];
        return nil;
    }

    // Look for the end line
    NSUInteger lineEnd = 0;
    for (lineEnd = lineStart + 1; lineEnd < lines.count; lineEnd++)
    {
        NSString *line = lines[lineEnd];

        if ([line isEqualToString:MXMegolmExportEncryptionTrailerLine])
        {
            break;
        }
    }

    if (lineEnd == lines.count)
    {
        *error = [NSError errorWithDomain:MXMegolmExportEncryptionErrorDomain
                                     code:MXMegolmExportErrorInvalidKeyFileTrailerNotFoundCode
                                 userInfo:@{
                                            NSLocalizedDescriptionKey: @"Trailer line not found",
                                            }];

        return nil;
    }

    NSArray *contentLines = [lines subarrayWithRange:NSMakeRange(lineStart + 1, lineEnd - lineStart - 1)];
    NSString *content = [contentLines componentsJoinedByString:@""];

    NSData *contentData = [[NSData alloc] initWithBase64EncodedString:content options:0];

    return contentData;
}

// @TODO: For dev. To remove
+ (void)logBytesDec:(NSData*)data
{
    uint8_t *bytes = (uint8_t*)data.bytes;

    NSMutableString *s = [NSMutableString string];
    for (NSUInteger i = 0; i < data.length; i++)
    {
        [s appendFormat:@"%hhu, ", bytes[i]];
    }

    NSLog(@"%tu bytes:\n%@", data.length, s);
}

@end
