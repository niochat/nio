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

#import "MXKeyVerificationTransaction.h"

@class MXQRCodeData;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const MXKeyVerificationMethodQRCodeShow;
FOUNDATION_EXPORT NSString * const MXKeyVerificationMethodQRCodeScan;

FOUNDATION_EXPORT NSString * const MXKeyVerificationMethodReciprocate;


typedef NS_ENUM(NSInteger, MXQRCodeTransactionState) {
    MXQRCodeTransactionStateUnknown = 0,
    MXQRCodeTransactionStateScannedOtherQR,         // My user scanned the QR code of the other user
    MXQRCodeTransactionStateWaitingOtherConfirm,    // My user scanned the QR code of the other, and wait for confirmation
    MXQRCodeTransactionStateQRScannedByOther,       // Other user scanned my QR code
    MXQRCodeTransactionStateVerified,
    MXQRCodeTransactionStateCancelled,              // Check self.reasonCancelCode for the reason
    MXQRCodeTransactionStateCancelledByMe,          // Check self.reasonCancelCode for the reason
    MXQRCodeTransactionStateError                   // An error occured. Check self.error. The transaction can be only cancelled
};

/**
 An handler on an interactive device verification based on QR Code.
 */
@interface MXQRCodeTransaction : MXKeyVerificationTransaction

@property (nonatomic) MXQRCodeTransactionState state;

/**
 Start the key verification process.
 */
- (void)userHasScannedOtherQrCodeRawData:(NSData*)otherQRCodeRawData;

/**
 Start the key verification process.
 */
- (void)userHasScannedOtherQrCodeData:(MXQRCodeData*)otherQRCodeData;

/**
 Indicate if QR code verification was intended or not.
 */
- (void)otherUserScannedMyQrCode:(BOOL)otherUserScanned;

@end

NS_ASSUME_NONNULL_END
