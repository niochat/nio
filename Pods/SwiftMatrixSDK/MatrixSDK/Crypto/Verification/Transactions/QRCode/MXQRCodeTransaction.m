/*
 Copyright 2020 The Matrix.org Foundation C.I.C
 
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

#import "MXQRCodeTransaction.h"

#import "MXQRCodeTransaction_Private.h"

#import "MXKeyVerificationManager_Private.h"
#import "MXCrypto_Private.h"

#import "MXCryptoTools.h"
#import "NSArray+MatrixSDK.h"

#import "MXQRCodeDataCoder.h"
#import "MXBase64Tools.h"

#import "MXVerifyingAnotherUserQRCodeData.h"
#import "MXSelfVerifyingMasterKeyTrustedQRCodeData.h"
#import "MXSelfVerifyingMasterKeyNotTrustedQRCodeData.h"

NSString * const MXKeyVerificationMethodQRCodeShow  = @"m.qr_code.show.v1";
NSString * const MXKeyVerificationMethodQRCodeScan  = @"m.qr_code.scan.v1";

NSString * const MXKeyVerificationMethodReciprocate = @"m.reciprocate.v1";

@interface MXQRCodeTransaction()

@property (nonatomic, strong) MXQRCodeDataCoder *qrCodeDataCoder;
@property (nonatomic, strong) MXQRCodeData *scannedOtherQRCodeData;

@end


@implementation MXQRCodeTransaction

#pragma mark - Setup

- (nullable instancetype)initWithOtherDevice:(MXDeviceInfo*)otherDevice
                                  qrCodeData:(nullable MXQRCodeData*)qrCodeData
                                  andManager:(MXKeyVerificationManager *)manager
{
    self = [super initWithOtherDevice:otherDevice andManager:manager];
    if (self)
    {
        _qrCodeData = qrCodeData;
        _qrCodeDataCoder = [MXQRCodeDataCoder new];
    }
    return self;
}

#pragma mark - Properties overrides

- (void)setState:(MXQRCodeTransactionState)state
{
    NSLog(@"[MXKeyVerification][MXQRCodeTransaction] setState: %@ -> %@", @(_state), @(state));
    
    _state = state;
    [self didUpdateState];
}

#pragma mark - Public

- (void)otherUserScannedMyQrCode:(BOOL)otherUserScanned
{
    if (self.state != MXQRCodeTransactionStateQRScannedByOther)
    {
        NSLog(@"[MXQRCodeTransaction]: otherUserScannedMyQrCode: QR code has not been scanned");
        [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage];
        return;
    }
    
    if (!otherUserScanned)
    {
        [self cancelWithCancelCode:MXTransactionCancelCode.mismatchedKeys];
    }
    else
    {
        [self trustOtherWithMyQRCodeData];
    }
}

- (void)userHasScannedOtherQrCodeRawData:(NSData*)otherQRCodeRawData
{
    MXQRCodeData *otherQRCodeData = [self.qrCodeDataCoder decode:otherQRCodeRawData];
    
    if (otherQRCodeData)
    {
        [self userHasScannedOtherQrCodeData:otherQRCodeData];
    }
    else
    {
        NSLog(@"[MXKeyVerification][MXQRCodeTransaction] userHasScannedOtherQrCodeRawData: Invalid QR code data: %@", otherQRCodeRawData);
        [self cancelWithCancelCode:MXTransactionCancelCode.qrCodeInvalid];
    }
}

- (void)userHasScannedOtherQrCodeData:(MXQRCodeData*)otherQRCodeData
{
    BOOL isOtherQRCodeDataKeysValid = [self.manager isOtherQRCodeDataKeysValid:otherQRCodeData otherUserId:self.otherUserId otherDevice:self.otherDevice];
    
    if (!isOtherQRCodeDataKeysValid)
    {
        [self cancelWithCancelCode:MXTransactionCancelCode.mismatchedKeys];
        return;
    }
    
    self.scannedOtherQRCodeData = otherQRCodeData;
    
    // All checks are correct. Send the shared secret so that sender can trust me.
    // otherQRCodeData.sharedSecret will be used to send the start request
    [self startWithOtherQRCodeSharedSecret:otherQRCodeData.sharedSecret success:^{
        self.state = MXQRCodeTransactionStateWaitingOtherConfirm;
    } failure:^(NSError *error) {
        [self cancelWithCancelCode:MXTransactionCancelCode.invalidMessage];
    }];
}

- (void)handleCancel:(MXKeyVerificationCancel *)cancelContent
{
    self.reasonCancelCode = [[MXTransactionCancelCode alloc] initWithValue:cancelContent.code
                                                             humanReadable:cancelContent.reason];
    
    self.state = MXQRCodeTransactionStateCancelled;
}

- (void)cancelWithCancelCode:(MXTransactionCancelCode*)code
{
    [self cancelWithCancelCode:code success:^{
        self.state = MXQRCodeTransactionStateCancelledByMe;
    } failure:^(NSError * _Nonnull error) {
        NSLog(@"[MXKeyVerification][MXSASTransaction] Fail to cancel with error: %@", error);
    }];
}

#pragma mark - SDK-Private methods -

- (void)handleStart:(MXQRCodeKeyVerificationStart *)start
{
    if (self.state != MXQRCodeTransactionStateUnknown)
    {
        NSLog(@"[MXQRCodeTransaction]: ERROR: A start event was already retrieved");
        [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage];
        return;
    }
    
    if (!start || !start.isValid)
    {
        NSLog(@"[MXQRCodeTransaction]: ERROR: Invalid start: %@", start);
        [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage];
        return;
    }
    
    if (!self.qrCodeData)
    {
        NSLog(@"[MXQRCodeTransaction]: ERROR: Invalid start, no QR code to scan: %@", start);
        [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage];
        return;
    }
    
    // Verify shared secret
    NSData *startSharedSecretData = [MXBase64Tools dataFromUnpaddedBase64:start.sharedSecret];
    
    if (![startSharedSecretData isEqualToData:self.qrCodeData.sharedSecret])
    {
        NSLog(@"[MXQRCodeTransaction]: ERROR: Invalid start, mismatch shared secret: %@", start);
        [self cancelWithCancelCode:MXTransactionCancelCode.mismatchedKeys];
        return;
    }
    
    self.startContent = start;
    self.state = MXQRCodeTransactionStateQRScannedByOther;
}

- (void)handleDone:(MXKeyVerificationDone*)doneEvent
{
    switch (self.state) {
        case MXQRCodeTransactionStateWaitingOtherConfirm:
        {
            if (self.scannedOtherQRCodeData)
            {
                [self trustOtherWithOtherQRCodeData:self.scannedOtherQRCodeData];
            }
            else
            {
                [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage];
                NSLog(@"[MXQRCodeTransaction]: ERROR: Done event was already retrieved");
            }
        }
            break;
        case MXQRCodeTransactionStateScannedOtherQR:
            [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage];
            NSLog(@"[MXQRCodeTransaction]: ERROR: Unexpected state for done event");
        default:
            break;
    }
}

#pragma mark - Private

- (void)startWithOtherQRCodeSharedSecret:(NSData*)otherQRCodeSharedSecret success:(dispatch_block_t)success failure:(void (^)(NSError* error))failure;
{
    NSLog(@"[MXKeyVerification][MXQRCodeTransaction] start");
    
    if (self.state != MXQRCodeTransactionStateUnknown)
    {
        NSLog(@"[MXKeyVerification][MXQRCodeTransaction] start: wrong state: %@", self);
        self.state = MXQRCodeTransactionStateCancelled;
        return;
    }
    
    MXQRCodeKeyVerificationStart *startContent = [MXQRCodeKeyVerificationStart new];
    startContent.fromDevice = self.manager.crypto.myDevice.deviceId;
    startContent.method = MXKeyVerificationMethodReciprocate;
    startContent.transactionId = self.transactionId;
    startContent.sharedSecret = [MXBase64Tools unpaddedBase64FromData:otherQRCodeSharedSecret];
    
    if (self.transport == MXKeyVerificationTransportDirectMessage)
    {
        startContent.relatedEventId = self.dmEventId;
    }
    
    if (startContent.isValid)
    {
        self.startContent = startContent;
        self.state = MXQRCodeTransactionStateScannedOtherQR;
        
        [self sendToOther:kMXEventTypeStringKeyVerificationStart content:startContent.JSONDictionary success:^{
            NSLog(@"[MXKeyVerification][MXQRCodeTransaction] start: sendToOther:kMXEventTypeStringKeyVerificationStart succeeds");
            success();
        } failure:^(NSError * _Nonnull error) {
            NSLog(@"[MXKeyVerification][MXQRCodeTransaction] start: sendToOther:kMXEventTypeStringKeyVerificationStart failed. Error: %@", error);
            self.error = error;
            self.state = MXQRCodeTransactionStateError;
            failure(error);
        }];
    }
    else
    {
        NSLog(@"[MXKeyVerification][MXQRCodeTransaction] start: Invalid startContent: %@", startContent);
        self.state = MXQRCodeTransactionStateCancelled;
    }
}

- (void)trustOtherWithOtherQRCodeData:(MXQRCodeData*)otherQRCodeData
{
    if (self.state != MXQRCodeTransactionStateWaitingOtherConfirm)
    {
        NSLog(@"[MXKeyVerification][MXQRCodeTransaction] trustOtherWithOtherQRCodeData: wrong state: %@", self);
        [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage];
        return;
    }
    
    NSString *currentUserId = self.manager.crypto.mxSession.myUserId;
    BOOL isSelfVerification = [currentUserId isEqualToString:self.otherUserId];
    
    // If not me sign his MSK and upload the signature
    if (otherQRCodeData.verificationMode == MXQRCodeVerificationModeVerifyingAnotherUser && !isSelfVerification)
    {
        // we should trust this master key
        [self trustOtherUserWithId:self.otherUserId andDeviceId:self.otherDeviceId];
    }
    else if (otherQRCodeData.verificationMode == MXQRCodeVerificationModeSelfVerifyingMasterKeyNotTrusted && isSelfVerification)
    {
        // My device is already trusted and I want to verify a new device
        [self trustOtherDeviceWithId:self.otherDeviceId];
    }
    else if (otherQRCodeData.verificationMode == MXQRCodeVerificationModeSelfVerifyingMasterKeyTrusted && isSelfVerification)
    {
        // I'm the new device. The other device will sign me. Trust the other device locally.
        [self trustOtherUserWithId:self.otherUserId andDeviceId:self.otherDeviceId];
    }
    else
    {
        NSLog(@"[MXKeyVerification][MXQRCodeTransaction] trustOtherWithOtherQRCodeData: QR code is invalid");
        [self cancelWithCancelCode:MXTransactionCancelCode.qrCodeInvalid];
    }
}

- (void)trustOtherWithMyQRCodeData
{
    if (self.state != MXQRCodeTransactionStateQRScannedByOther)
    {
        NSLog(@"[MXKeyVerification][MXQRCodeTransaction] trustOtherWithMyQRCodeData: wrong state: %@", self);
        [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage];
        return;
    }
    
    if (!self.qrCodeData)
    {
        NSLog(@"[MXKeyVerification][MXQRCodeTransaction] start: wrong state: %@", self);
        [self cancelWithCancelCode:MXTransactionCancelCode.unexpectedMessage];
        return;
    }
    
    MXQRCodeData *qrCodeData = self.qrCodeData;
    
    NSString *currentUserId = self.manager.crypto.mxSession.myUserId;
    BOOL isSelfVerification = [currentUserId isEqualToString:self.otherUserId];
    
    // If not me, sign their MSK and upload the signature
    if (qrCodeData.verificationMode == MXQRCodeVerificationModeVerifyingAnotherUser && !isSelfVerification)
    {
        // we should trust their master key
        [self trustOtherUserWithId:self.otherUserId andDeviceId:self.otherDeviceId];
    }
    else if (qrCodeData.verificationMode == MXQRCodeVerificationModeSelfVerifyingMasterKeyNotTrusted && isSelfVerification)
    {
        // I'm the new device. The other device will sign me. Trust the other device locally.
        [self trustOtherUserWithId:self.otherUserId andDeviceId:self.otherDeviceId];
    }
    else if (qrCodeData.verificationMode == MXQRCodeVerificationModeSelfVerifyingMasterKeyTrusted && isSelfVerification)
    {
        // New device from my user scanned my QR code. Trust it
        [self trustOtherDeviceWithId:self.otherDeviceId];
    }
    else
    {
        NSLog(@"[MXKeyVerification][MXQRCodeTransaction] trustOtherWithMyQRCodeData: My QR code is invalid");
        [self cancelWithCancelCode:MXTransactionCancelCode.invalidMessage];
    }
}

- (void)trustOtherUserWithId:(NSString*)otherUserId andDeviceId:(NSString*)otherDeviceId
{
    NSLog(@"[MXKeyVerification][MXQRCodeTransaction] trustOtherUserWithId: Mark user %@:%@ as verified", otherUserId, otherDeviceId);
    
    // Mark the device as locally verified
    [self.manager.crypto setDeviceVerification:MXDeviceVerified forDevice:otherDeviceId ofUser:otherUserId success:^{
        
        // Mark user as verified
        [self.manager.crypto setUserVerification:YES forUser:otherUserId success:^{
            [self sendVerified];
            
        } failure:^(NSError *error) {
            NSLog(@"[MXKeyVerification][MXQRCodeTransaction] trustOtherWithQRCodeData: Fail to cross sign user %@", otherUserId);
            [self cancelWithCancelCode:MXTransactionCancelCode.mismatchedKeys];
        }];
        
    } failure:^(NSError *error) {
        NSLog(@"[MXKeyVerification][MXQRCodeTransaction] trustOtherWithQRCodeData: Fail to mark device %@:%@ as locally verified", otherUserId, otherDeviceId);
        [self cancelWithCancelCode:MXTransactionCancelCode.mismatchedKeys];
    }];
}

- (void)trustOtherDeviceWithId:(NSString*)otherDeviceId
{
    NSString *currentUserId = self.manager.crypto.mxSession.myUserId;
    
    // setDeviceVerification will automatically cross sign the device
    [self.manager.crypto setDeviceVerification:MXDeviceVerified forDevice:otherDeviceId ofUser:currentUserId success:^{
        [self sendVerified];
    } failure:^(NSError *error) {
        [self cancelWithCancelCode:MXTransactionCancelCode.invalidMessage];
    }];
}

- (void)sendVerified
{
    // Inform the other peer we are done
    MXKeyVerificationDone *doneContent = [MXKeyVerificationDone new];
    doneContent.transactionId = self.transactionId;
    if (self.transport == MXKeyVerificationTransportDirectMessage)
    {
        doneContent.relatedEventId = self.dmEventId;
    }
    [self sendToOther:kMXEventTypeStringKeyVerificationDone content:doneContent.JSONDictionary success:^{} failure:^(NSError * _Nonnull error) {}];
    
    self.state = MXQRCodeTransactionStateVerified;
    
    // Remove transaction
    [self.manager removeTransactionWithTransactionId:self.transactionId];
}

@end
