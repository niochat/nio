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

#import "MXIncomingSASTransaction.h"
#import "MXSASTransaction_Private.h"
#import "MXIncomingSASTransaction_Private.h"

#import "MXKeyVerificationManager_Private.h"
#import "MXCrypto_Private.h"

#import "MXCryptoTools.h"
#import "NSArray+MatrixSDK.h"
#import "MXTools.h"

@implementation MXIncomingSASTransaction

- (void)accept;
{
    NSLog(@"[MXKeyVerification][MXIncomingSASTransaction] accept");

    if (self.state != MXSASTransactionStateIncomingShowAccept)
    {
        NSLog(@"[MXKeyVerification][MXIncomingSASTransaction] accept: wrong state: %@", self);
        [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage];
        return;
    }

    MXKeyVerificationAccept *acceptContent = [MXKeyVerificationAccept new];
    acceptContent.transactionId = self.transactionId;


    // Select a key agreement protocol, a hash algorithm, a message authentication code,
    // and short authentication string methods out of the lists given in requester's message
    acceptContent.keyAgreementProtocol = [self.startContent.keyAgreementProtocols mx_intersectArray:kKnownAgreementProtocols].firstObject;
    acceptContent.hashAlgorithm = [self.startContent.hashAlgorithms mx_intersectArray:kKnownHashes].firstObject;
    acceptContent.messageAuthenticationCode = [self.startContent.messageAuthenticationCodes mx_intersectArray:kKnownMacs].firstObject;
    acceptContent.shortAuthenticationString = [self.startContent.shortAuthenticationString mx_intersectArray:kKnownShortCodes];

    self.accepted = acceptContent;

    // The hash commitment is the hash (using the selected hash algorithm) of the unpadded base64 representation of QB,
    // concatenated with the canonical JSON representation of the content of the m.key.verification.start message
    acceptContent.commitment = [NSString stringWithFormat:@"%@%@", self.olmSAS.publicKey, [MXCryptoTools canonicalJSONStringForJSON:self.startContent.JSONDictionary]];
    acceptContent.commitment = [self hashUsingAgreedHashMethod:acceptContent.commitment];

    // No common key sharing/hashing/hmac/SAS methods.
    // If a device is unable to complete the verification because the devices are unable to find a common key sharing,
    // hashing, hmac, or SAS method, then it should send a m.key.verification.cancel message
    if (acceptContent.isValid)
    {
        [self sendToOther:kMXEventTypeStringKeyVerificationAccept content:acceptContent.JSONDictionary success:^{

            self.state = MXSASTransactionStateWaitForPartnerKey;
        } failure:^(NSError * _Nonnull error) {

            NSLog(@"[MXKeyVerification][MXIncomingSASTransaction] accept: sendToOther:kMXEventTypeStringKeyVerificationAccept failed. Error: %@", error);
            self.error = error;
            self.state = MXSASTransactionStateError;
        }];
    }
    else
    {
        NSLog(@"[MXKeyVerification][MXIncomingSASTransaction] accept: Failed to find agreement");
        [self cancelWithCancelCode:MXTransactionCancelCode.unknownMethod];
        return;
    }
}


#pragma mark - SDK-Private methods -

- (nullable instancetype)initWithOtherDevice:(MXDeviceInfo *)otherDevice startEvent:(MXEvent *)event andManager:(MXKeyVerificationManager *)manager
{
    MXSASKeyVerificationStart *startContent;
    MXJSONModelSetMXJSONModel(startContent, MXSASKeyVerificationStart, event.content);
    if (!startContent || !startContent.isValid)
    {
        NSLog(@"[MXKeyVerificationTransaction]: ERROR: Invalid start event: %@", event);
        return nil;
    }
    
    self = [super initWithOtherDevice:otherDevice andManager:manager];
    if (self)
    {
        self.startContent = startContent;
        self.transactionId = startContent.transactionId;
        
        // Detect verification by DM
        if (startContent.relatedEventId)
        {
            [self setDirectMessageTransportInRoom:event.roomId originalEvent:startContent.relatedEventId];
        }
        
        // It would have been nice to timeout from the event creation date
        // but we do not receive the information. originServerTs = 0
        // So, use the time when we receive it instead
        //_creationDate = [NSDate dateWithTimeIntervalSince1970: (event.originServerTs / 1000)];
        
        // Check validity
        if (![self.startContent.method isEqualToString:MXKeyVerificationMethodSAS]
            || ![self.startContent.shortAuthenticationString containsObject:MXKeyVerificationSASModeDecimal])
        {
            NSLog(@"[MXKeyVerification][MXIncomingSASTransaction]: ERROR: Invalid start event: %@", event);
            return nil;
        }

        // Bob's case
        self.state = MXSASTransactionStateIncomingShowAccept;
        self.isIncoming = YES;
    }
    return self;
}


#pragma mark - Incoming to_device events

- (void)handleAccept:(MXKeyVerificationAccept*)acceptContent
{
    NSLog(@"[MXKeyVerification][MXIncomingSASTransaction] handleAccept");

    [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage];
}

- (void)handleKey:(MXKeyVerificationKey *)keyContent
{
    NSLog(@"[MXKeyVerification][MXIncomingSASTransaction] handleKey");

    if (self.state != MXSASTransactionStateWaitForPartnerKey)
    {
        NSLog(@"[MXKeyVerification][MXIncomingSASTransaction] handleKey: wrong state: %@. keyContent: %@", self, keyContent);
        [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage];
        return;
    }
    
    if (!keyContent.isValid)
    {
        NSLog(@"[MXKeyVerification][MXIncomingSASTransaction] handleKey: key content is invalid. keyContent: %@", keyContent);
        [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage];
        return;
    }

    // Upon receipt of the m.key.verification.key message from Alice’s device,
    // Bob’s device replies with a to_device message with type set to m.key.verification.key,
    // sending Bob’s public key QB
    NSString *pubKey = self.olmSAS.publicKey;

    MXKeyVerificationKey *bobKeyContent = [MXKeyVerificationKey new];
    bobKeyContent.transactionId = self.transactionId;
    bobKeyContent.key = pubKey;

    MXWeakify(self);
    [self sendToOther:kMXEventTypeStringKeyVerificationKey content:bobKeyContent.JSONDictionary success:^{
        MXStrongifyAndReturnIfNil(self);

        self.sasBytes = [self generateSasBytesWithTheirPublicKey:keyContent.key requestingDevice:self.otherDevice otherDevice:self.manager.crypto.myDevice];

//        NSLog(@"[MXKeyVerification][MXIncomingSASTransaction] handleKey: BOB CODE: %@", self.sasDecimal);
//        NSLog(@"[MXKeyVerification][MXIncomingSASTransaction] handleKey: BOB EMOJI CODE: %@", self.sasEmoji);

        self.state = MXSASTransactionStateShowSAS;

    } failure:^(NSError * _Nonnull error) {

        NSLog(@"[MXKeyVerification][MXIncomingSASTransaction] handleKey: sendToOther:kMXEventTypeStringKeyVerificationKey failed. Error: %@", error);
        self.error = error;
        self.state = MXSASTransactionStateError;
    }];
}


#pragma mark - Private methods

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MXIncomingSASTransaction: %p> id:%@ from %@:%@. State %@",
            self,
            self.transactionId,
            self.otherUserId, self.otherDeviceId,
            @(self.state)];
}

@end
