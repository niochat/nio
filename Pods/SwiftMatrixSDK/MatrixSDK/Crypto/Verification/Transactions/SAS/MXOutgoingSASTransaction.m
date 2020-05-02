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

#import "MXOutgoingSASTransaction.h"
#import "MXSASTransaction_Private.h"

#import "MXKeyVerificationManager_Private.h"
#import "MXCrypto_Private.h"

#import "MXCryptoTools.h"
#import "NSArray+MatrixSDK.h"

@interface MXOutgoingSASTransaction ()

@end

@implementation MXOutgoingSASTransaction

- (void)start;
{
    NSLog(@"[MXKeyVerification][MXOutgoingSASTransaction] start");

    if (self.state != MXSASTransactionStateUnknown)
    {
        NSLog(@"[MXKeyVerification][MXOutgoingSASTransaction] start: wrong state: %@", self);
        self.state = MXSASTransactionStateCancelled;
        return;
    }

    MXSASKeyVerificationStart *startContent = [MXSASKeyVerificationStart new];
    startContent.fromDevice = self.manager.crypto.myDevice.deviceId;
    startContent.method = MXKeyVerificationMethodSAS;
    startContent.transactionId = self.transactionId;
    startContent.keyAgreementProtocols = kKnownAgreementProtocols;
    startContent.hashAlgorithms = kKnownHashes;
    startContent.messageAuthenticationCodes = kKnownMacs;
    startContent.shortAuthenticationString = kKnownShortCodes;

    if (self.transport == MXKeyVerificationTransportDirectMessage)
    {
        startContent.relatedEventId = self.dmEventId;
    }

    if (startContent.isValid)
    {
        self.startContent = startContent;
        self.state = MXSASTransactionStateOutgoingWaitForPartnerToAccept;

        [self sendToOther:kMXEventTypeStringKeyVerificationStart content:startContent.JSONDictionary success:^{
            NSLog(@"[MXKeyVerification][MXOutgoingSASTransaction] start: sendToOther:kMXEventTypeStringKeyVerificationStart succeeds");
        } failure:^(NSError * _Nonnull error) {
            NSLog(@"[MXKeyVerification][MXOutgoingSASTransaction] start: sendToOther:kMXEventTypeStringKeyVerificationStart failed. Error: %@", error);
            self.error = error;
            self.state = MXSASTransactionStateError;
        }];
    }
    else
    {
        NSLog(@"[MXKeyVerification][MXOutgoingSASTransaction] start: Invalid startContent: %@", startContent);
        self.state = MXSASTransactionStateCancelled;
    }
}


#pragma mark - SDK-Private methods -

- (instancetype)initWithOtherDevice:(MXDeviceInfo *)otherDevice andManager:(MXKeyVerificationManager *)manager
{
    self = [super initWithOtherDevice:otherDevice andManager:manager];
    if (self)
    {
        // Alice's case
        self.state = MXSASTransactionStateUnknown;
        self.isIncoming = NO;
    }
    return self;
}


#pragma mark - Incoming to_device events

- (void)handleAccept:(MXKeyVerificationAccept*)acceptContent
{
    // Alice's POV
    NSLog(@"[MXKeyVerification][MXOutgoingSASTransaction] handleAccept");

    if (self.state != MXSASTransactionStateOutgoingWaitForPartnerToAccept)
    {
        NSLog(@"[MXKeyVerification][MXOutgoingSASTransaction] handleAccept: wrong state: %@. acceptContent: %@", self, acceptContent);
        [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage];
        return;
    }

    // Check that the agreement is correct
    if (![kKnownAgreementProtocols containsObject:acceptContent.keyAgreementProtocol]
        || ![kKnownHashes containsObject:acceptContent.hashAlgorithm]
        || ![kKnownMacs containsObject:acceptContent.messageAuthenticationCode]
        || ![acceptContent.shortAuthenticationString mx_intersectArray:kKnownShortCodes].count)
    {
        NSLog(@"[MXKeyVerification][MXOutgoingSASTransaction] handleAccept: wrong method: %@. acceptContent: %@", self, acceptContent);
        [self cancelWithCancelCode:MXTransactionCancelCode.unknownMethod];
        return;
    }

    // Upon receipt of the m.key.verification.accept message from Bob’s device,
    // Alice’s device stores the commitment value for later use.
    self.accepted = acceptContent;

    // Alice’s device creates an ephemeral Curve25519 key pair (dA,QA),
    // and replies with a to_device message with type set to “m.key.verification.key”, sending Alice’s public key QA
    NSString *pubKey = self.olmSAS.publicKey;

    MXKeyVerificationKey *keyContent = [MXKeyVerificationKey new];
    keyContent.transactionId = self.transactionId;
    keyContent.key = pubKey;

    [self sendToOther:kMXEventTypeStringKeyVerificationKey content:keyContent.JSONDictionary success:^{

        self.state = MXSASTransactionStateWaitForPartnerKey;

    } failure:^(NSError * _Nonnull error) {
        NSLog(@"[MXKeyVerification][MXOutgoingSASTransaction] handleAccept: sendToOther:kMXEventTypeStringKeyVerificationKey failed. Error: %@", error);
        self.error = error;
        self.state = MXSASTransactionStateError;
    }];
}

- (void)handleKey:(MXKeyVerificationKey *)keyContent
{
    NSLog(@"[MXKeyVerification][MXOutgoingSASTransaction] handleKey");

    if (self.state != MXSASTransactionStateWaitForPartnerKey)
    {
        NSLog(@"[MXKeyVerification][MXOutgoingSASTransaction] handleKey: wrong state: %@. keyContent: %@", self, keyContent);
        [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage];
        return;
    }
    
    if (!keyContent.isValid)
    {
        NSLog(@"[MXKeyVerification][MXOutgoingSASTransaction] handleKey: key content is invalid. keyContent: %@", keyContent);
        [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage];
        return;
    }

    // Upon receipt of the m.key.verification.key message from Bob’s device,
    // Alice’s device checks that the commitment property from the Bob’s m.key.verification.accept
    // message is the same as the expected value based on the value of the key property received
    // in Bob’s m.key.verification.key and the content of Alice’s m.key.verification.start message.

    // Check commitment
    NSString *otherCommitment = [NSString stringWithFormat:@"%@%@",
                                 keyContent.key,
                                 [MXCryptoTools canonicalJSONStringForJSON:self.startContent.JSONDictionary]];
    otherCommitment = [self hashUsingAgreedHashMethod:otherCommitment];

    if ([self.accepted.commitment isEqualToString:otherCommitment])
    {
        self.sasBytes = [self generateSasBytesWithTheirPublicKey:keyContent.key requestingDevice:self.manager.crypto.myDevice otherDevice:self.otherDevice];

//        NSLog(@"[MXKeyVerification][MXOutgoingSASTransaction] handleKey: ALICE CODE: %@", self.sasDecimal);
//        NSLog(@"[MXKeyVerification][MXOutgoingSASTransaction] handleKey: ALICE EMOJI CODE: %@", self.sasEmoji);

        self.state = MXSASTransactionStateShowSAS;
    }
    else
    {
        NSLog(@"[MXKeyVerification][MXOutgoingSASTransaction] handleKey: Bad commitment:\n%@\n%@", self.accepted.commitment, otherCommitment);

        [self cancelWithCancelCode:MXTransactionCancelCode.mismatchedCommitment];
    }
}


#pragma mark - Private methods

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MXOutgoingSASTransaction: %p> id:%@ from %@:%@. State %@",
            self,
            self.transactionId,
            self.otherUserId, self.otherDeviceId,
            @(self.state)];
}

@end
