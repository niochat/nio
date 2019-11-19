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

#import "MXSASTransaction.h"
#import "MXSASTransaction_Private.h"

#import "MXCrypto_Private.h"
#import "MXDeviceVerificationManager_Private.h"

#pragma mark - Constants

NSString * const MXKeyVerificationMethodSAS        = @"m.sas.v1";
NSString * const MXKeyVerificationSASModeDecimal   = @"decimal";
NSString * const MXKeyVerificationSASModeEmoji     = @"emoji";

NSString * const MXKeyVerificationSASMacSha256         = @"hkdf-hmac-sha256";
NSString * const MXKeyVerificationSASMacSha256LongKdf  = @"hmac-sha256";

NSArray<NSString*> *kKnownAgreementProtocols;
NSArray<NSString*> *kKnownHashes;
NSArray<NSString*> *kKnownMacs;
NSArray<NSString*> *kKnownShortCodes;

static NSArray<MXEmojiRepresentation*> *kSasEmojis;


@implementation MXSASTransaction

- (NSString *)sasDecimal
{
    NSString *sasDecimal;
    if (_sasBytes && [self.accepted.shortAuthenticationString containsObject:MXKeyVerificationSASModeDecimal])
    {
        sasDecimal = [[MXSASTransaction decimalRepresentationForSas:_sasBytes] componentsJoinedByString:@" "];
    }

    return sasDecimal;
}

- (NSArray<MXEmojiRepresentation *> *)sasEmoji
{
    NSArray *sasEmoji;
    if (_sasBytes && [self.accepted.shortAuthenticationString containsObject:MXKeyVerificationSASModeEmoji])
    {
        sasEmoji = [MXSASTransaction emojiRepresentationForSas:_sasBytes];
    }

    return sasEmoji;
}

- (void)confirmSASMatch
{
    if (self.state != MXSASTransactionStateShowSAS)
    {
        // Ignore and cancel
        NSLog(@"[MXKeyVerification][MXSASTransaction] accept: Accepted short code from invalid state (%@)", @(self.state));
        [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage];

        return;
    }

    MXKeyVerificationMac *macContent = [self macContentWithDevice:self.manager.crypto.myDevice
                                                   andOtherDevice:self.otherDevice];

    if (macContent)
    {
        self.state = MXSASTransactionStateWaitForPartnerToConfirm;
        self.myMac = macContent;

        [self sendToOther:kMXEventTypeStringKeyVerificationMac content:macContent.JSONDictionary success:^{

        } failure:^(NSError * _Nonnull error) {
            NSLog(@"[MXKeyVerification][MXSASTransaction] accept: sendToOther:kMXEventTypeStringKeyVerificationAccept failed. Error: %@", error);
            self.error = error;
            self.state = MXSASTransactionStateError;
        }];

        // If we already have the other mac, compare them
        if (self.theirMac)
        {
            [self verifyMacs];
        }
    }
    else
    {
        NSLog(@"[MXKeyVerification][MXSASTransaction] confirmSASMatch: Failed to send KeyMac, empty key hashes");
        [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage];
    }
}


- (void)cancelWithCancelCodeFromCryptoQueue:(MXTransactionCancelCode *)code
{
    [super cancelWithCancelCodeFromCryptoQueue:code];
    
    self.state = MXSASTransactionStateCancelledByMe;
    self.reasonCancelCode = code;
}

#pragma mark - SDK-Private methods -

+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{

        kKnownAgreementProtocols = @[@"curve25519"];
        kKnownHashes = @[@"sha256"];
        kKnownMacs = @[MXKeyVerificationSASMacSha256, MXKeyVerificationSASMacSha256LongKdf];
        kKnownShortCodes = @[MXKeyVerificationSASModeEmoji, MXKeyVerificationSASModeDecimal];

        [self initializeSasEmojis];
    });
}

- (instancetype)initWithOtherDevice:(MXDeviceInfo*)otherDevice andManager:(MXDeviceVerificationManager*)manager
{
    self = [super initWithOtherDevice:otherDevice andManager:manager];
    if (self)
    {
        _olmSAS = [OLMSAS new];
    }
    return self;
}


- (NSString*)hashUsingAgreedHashMethod:(NSString*)string
{
    NSString *hashUsingAgreedHashMethod;
    if ([_accepted.hashAlgorithm isEqualToString:@"sha256"])
    {
        hashUsingAgreedHashMethod = [[OLMUtility new] sha256:[string dataUsingEncoding:NSUTF8StringEncoding]];
    }
    else
    {
        NSLog(@"[MXKeyVerification][MXSASTransaction] hashUsingAgreedHashMethod: Unsupported hash: %@", _accepted.hashAlgorithm);
    }

    return hashUsingAgreedHashMethod;
}

- (NSData*)generateSasBytesWithTheirPublicKey:(NSString*)theirPublicKey requestingDevice:(MXDeviceInfo*)requestingDevice otherDevice:(MXDeviceInfo*)otherDevice
{
    // Alice’s and Bob’s devices perform an Elliptic-curve Diffie-Hellman
    // (calculate the point (x,y)=dAQB=dBQA and use x as the result of the ECDH),
    // using the result as the shared secret.

    [self.olmSAS setTheirPublicKey:theirPublicKey];

    // (Note: In all of the following HKDF is as defined in RFC 5869, and uses the previously agreed-on hash function as the hash function,
    // the shared secret as the input keying material, no salt, and with the input parameter set to the concatenation of:
    // - the string “MATRIX_KEY_VERIFICATION_SAS”,
    // - the Matrix ID of the user who sent the m.key.verification.start message,
    // - the device ID of the device that sent the m.key.verification.start message,
    // - the Matrix ID of the user who sent the m.key.verification.accept message,
    // - he device ID of the device that sent the m.key.verification.accept message
    // - the transaction ID.
    NSString *sasInfo = [NSString stringWithFormat:@"MATRIX_KEY_VERIFICATION_SAS%@%@%@%@%@",
                         requestingDevice.userId, requestingDevice.deviceId,
                         otherDevice.userId, otherDevice.deviceId,
                         self.transactionId];

    // decimal: generate five bytes by using HKDF
    // emoji: generate six bytes by using HKDF
    return [self.olmSAS generateBytes:sasInfo length:6];
}

- (NSString*)macUsingAgreedMethod:(NSString*)message info:(NSString*)info
{
    NSString *macUsingAgreedMethod;
    NSError *error;

    if ([_accepted.messageAuthenticationCode isEqualToString:MXKeyVerificationSASMacSha256LongKdf])
    {
        macUsingAgreedMethod = [_olmSAS calculateMacLongKdf:message info:info error:&error];
    }
    else if ([_accepted.messageAuthenticationCode isEqualToString:MXKeyVerificationSASMacSha256])
    {
        macUsingAgreedMethod = [_olmSAS calculateMac:message info:info error:&error];
    }
    else
    {
        NSLog(@"[MXKeyVerification][MXSASTransaction] macUsingAgreedMethod: Unsupported MAC format: %@", _accepted.messageAuthenticationCode);
    }

    if (error)
    {
        NSLog(@"[MXKeyVerification][MXSASTransaction] macUsingAgreedMethod: Error with MAC format: %@. Error: %@", _accepted.messageAuthenticationCode, error);
    }

    return macUsingAgreedMethod;
}


#pragma mark - Incoming to_device events

- (void)handleMac:(MXKeyVerificationMac*)macContent
{
    if (self.state != MXSASTransactionStateWaitForPartnerToConfirm
        && self.state != MXSASTransactionStateShowSAS)
    {
        NSLog(@"[MXKeyVerification] handleMac: wrong state: %@", self);
        [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage];
        return;
    }

    self.theirMac = macContent;
    [self verifyMacs];
}

- (void)handleCancel:(MXKeyVerificationCancel *)cancelContent
{
    self.reasonCancelCode = [[MXTransactionCancelCode alloc] initWithValue:cancelContent.code
                                                             humanReadable:cancelContent.reason];

    self.state = MXSASTransactionStateCancelled;
}


#pragma mark - Private methods -

- (void)setState:(MXSASTransactionState)state
{
    NSLog(@"[MXKeyVerification][MXSASTransaction] setState: %@ -> %@", @(_state), @(state));

    _state = state;
    [self didUpdateState];
}

- (MXKeyVerificationMac*)macContentWithDevice:(MXDeviceInfo*)device andOtherDevice:(MXDeviceInfo*)otherDevice
{
    MXKeyVerificationMac *macContent;

    // Alice and Bob’ devices calculate the HMAC of their own device keys and a comma-separated,
    // sorted list of the key IDs that they wish the other user to verify,
    // the shared secret as the input keying material, no salt, and with the input
    // parameter set to the concatenation of:
    //  - the string “MATRIX_KEY_VERIFICATION_MAC”,
    //  - the Matrix ID of the user whose key is being MAC-ed,
    //  - the device ID of the device sending the MAC,
    //  - the Matrix ID of the other user,
    //  - the device ID of the device receiving the MAC,
    //  - the transaction ID, and
    //  - the key ID of the key being MAC-ed, or the string “KEY_IDS” if the item being MAC-ed is the list of key IDs.
    NSString *baseInfo = [NSString stringWithFormat:@"MATRIX_KEY_VERIFICATION_MAC%@%@%@%@%@",
                          device.userId, device.deviceId,
                          otherDevice.userId, otherDevice.deviceId,
                          self.transactionId];

    NSString *keyId = [NSString stringWithFormat:@"ed25519:%@", device.deviceId];

    NSString *macString = [self macUsingAgreedMethod:device.fingerprint
                                                info:[NSString stringWithFormat:@"%@%@", baseInfo, keyId]];
    NSString *keyStrings = [self macUsingAgreedMethod:keyId
                                                 info:[NSString stringWithFormat:@"%@KEY_IDS", baseInfo]];

    if (macString.length && keyStrings.length)
    {
        macContent = [MXKeyVerificationMac new];
        macContent.transactionId = self.transactionId;
        macContent.mac = @{
                           keyId: macString
                           };
        macContent.keys = keyStrings;
    }

    return macContent;
}

- (void)verifyMacs
{
    if (self.myMac && self.theirMac)
    {
        MXKeyVerificationMac *macContent = [self macContentWithDevice:self.otherDevice
                                                       andOtherDevice:self.manager.crypto.myDevice];

        if (!macContent)
        {
            [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage];
            return;
        }

        if (![_theirMac.keys isEqualToString:macContent.keys])
        {
            [self cancelWithCancelCode:MXTransactionCancelCode.mismatchedKeys];
            return;
        }

        if (![_theirMac.mac isEqualToDictionary:macContent.mac])
        {
            [self cancelWithCancelCode:MXTransactionCancelCode.mismatchedKeys];
            return;
        }

        [self.manager removeTransactionWithTransactionId:self.transactionId];
        [self setDeviceAsVerified];
    }
}

- (void)setDeviceAsVerified
{
    [self.manager.crypto setDeviceVerification:MXDeviceVerified forDevice:self.otherDeviceId ofUser:self.otherUserId success:^{
        self.state = MXSASTransactionStateVerified;
    } failure:^(NSError *error) {
        // Should never happen
        [self cancelWithCancelCode:MXTransactionCancelCode.invalidMessage];
    }];
}


#pragma mark - Decimal representation

+ (NSArray<NSNumber*> *)decimalRepresentationForSas:(NSData*)sas
{
    UInt8 *sasBytes = (UInt8 *)sas.bytes;

    /**
     *      +--------+--------+--------+--------+--------+
     *      | Byte 0 | Byte 1 | Byte 2 | Byte 3 | Byte 4 |
     *      +--------+--------+--------+--------+--------+
     * bits: 87654321 87654321 87654321 87654321 87654321
     *       \____________/\_____________/\____________/
     *         1st number    2nd number     3rd number
     */
    return @[
             @((sasBytes[0] << 5 | sasBytes[1] >> 3) + 1000),
             @(((sasBytes[1] & 0x7) << 10 | sasBytes[2] << 2 | sasBytes[3] >> 6) + 1000),
             @(((sasBytes[3] & 0x3f) << 7 | sasBytes[4] >> 1) + 1000),
             ];
}


#pragma mark - Emoji representation
+ (void)initializeSasEmojis
{
    kSasEmojis = @[
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🐶" andName:@"dog"],        //  0
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🐱" andName:@"cat"],        //  1
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🦁" andName:@"lion"],       //  2
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🐎" andName:@"horse"],      //  3
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🦄" andName:@"unicorn"],    //  4
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🐷" andName:@"pig"],        //  5
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🐘" andName:@"elephant"],   //  6
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🐰" andName:@"rabbit"],     //  7
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🐼" andName:@"panda"],      //  8
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🐓" andName:@"rooster"],    //  9
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🐧" andName:@"penguin"],    // 10
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🐢" andName:@"turtle"],     // 11
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🐟" andName:@"fish"],       // 12
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🐙" andName:@"octopus"],    // 13
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🦋" andName:@"butterfly"],  // 14
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🌷" andName:@"flower"],     // 15
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🌳" andName:@"tree"],       // 16
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🌵" andName:@"cactus"],     // 17
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🍄" andName:@"mushroom"],   // 18
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🌏" andName:@"globe"],      // 19
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🌙" andName:@"moon"],       // 20
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"☁️" andName:@"cloud"],      // 21
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🔥" andName:@"fire"],       // 22
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🍌" andName:@"banana"],     // 23
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🍎" andName:@"apple"],      // 24
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🍓" andName:@"strawberry"], // 25
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🌽" andName:@"corn"],       // 26
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🍕" andName:@"pizza"],      // 27
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🎂" andName:@"cake"],       // 28
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"❤️" andName:@"heart"],      // 29
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🙂" andName:@"smiley"],     // 30
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🤖" andName:@"robot"],      // 31
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🎩" andName:@"hat"],        // 32
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"👓" andName:@"glasses"],    // 33
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🔧" andName:@"spanner"],    // 34
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🎅" andName:@"santa"],      // 35
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"👍" andName:@"thumbs up"],  // 36
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"☂️" andName:@"umbrella"],   // 37
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"⌛" andName:@"hourglass"],  // 38
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"⏰" andName:@"clock"],      // 39
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🎁" andName:@"gift"],       // 40
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"💡" andName:@"light bulb"], // 41
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"📕" andName:@"book"],       // 42
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"✏️" andName:@"pencil"],     // 43
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"📎" andName:@"paperclip"],  // 44
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"✂️" andName:@"scissors"],   // 45
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🔒" andName:@"lock"],       // 46
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🔑" andName:@"key"],        // 47
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🔨" andName:@"hammer"],     // 48
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"☎️" andName:@"telephone"],  // 49
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🏁" andName:@"flag"],       // 50
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🚂" andName:@"train"],      // 51
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🚲" andName:@"bicycle"],    // 52
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"✈️" andName:@"aeroplane"],  // 53
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🚀" andName:@"rocket"],     // 54
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🏆" andName:@"trophy"],     // 55
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"⚽" andName:@"ball"],       // 56
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🎸" andName:@"guitar"],     // 57
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🎺" andName:@"trumpet"],    // 58
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🔔" andName:@"bell"],       // 59
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"⚓️" andName:@"anchor"],     // 60
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"🎧" andName:@"headphones"], // 61
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"📁" andName:@"folder"],     // 62
                   [[MXEmojiRepresentation alloc] initWithEmoji:@"📌" andName:@"pin"],        // 63
                   ];
}

+ (NSArray<MXEmojiRepresentation*> *)emojiRepresentationForSas:(NSData*)sas
{
    UInt8 *sasBytes = (UInt8 *)sas.bytes;

    return @[
             kSasEmojis[sasBytes[0] >> 2],
             kSasEmojis[(sasBytes[0] & 0x3) << 4 | sasBytes[1] >> 4],
             kSasEmojis[(sasBytes[1] & 0xf) << 2 | sasBytes[2] >> 6],
             kSasEmojis[sasBytes[2] & 0x3f],
             kSasEmojis[sasBytes[3] >> 2],
             kSasEmojis[(sasBytes[3] & 0x3) << 4 | sasBytes[4] >> 4],
             kSasEmojis[(sasBytes[4] & 0xf) << 2 | sasBytes[5] >> 6]
             ];
}

@end
