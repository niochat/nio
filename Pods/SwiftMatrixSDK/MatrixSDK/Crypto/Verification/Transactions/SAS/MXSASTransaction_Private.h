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
#import "MXKeyVerificationTransaction_Private.h"
#import "MXSASKeyVerificationStart.h"

#import <OLMKit/OLMKit.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Constants

FOUNDATION_EXPORT NSArray<NSString*> *kKnownAgreementProtocols;
FOUNDATION_EXPORT NSArray<NSString*> *kKnownHashes;
FOUNDATION_EXPORT NSArray<NSString*> *kKnownMacs;
FOUNDATION_EXPORT NSArray<NSString*> *kKnownShortCodes;

/**
 The `MXKeyVerificationTransaction` extension exposes internal operations.
 */
@interface MXSASTransaction ()

@property (nonatomic) OLMSAS *olmSAS;
@property (nonatomic, nullable) MXSASKeyVerificationStart *startContent;
@property (nonatomic) MXKeyVerificationAccept *accepted;

@property (nonatomic, nullable) MXKeyVerificationMac *myMac;
@property (nonatomic, nullable) MXKeyVerificationMac *theirMac;

- (void)handleAccept:(MXKeyVerificationAccept*)acceptContent;
- (void)handleKey:(MXKeyVerificationKey*)keyContent;
- (void)handleMac:(MXKeyVerificationMac*)macContent;

- (NSString*)hashUsingAgreedHashMethod:(NSString*)string;
- (NSData*)generateSasBytesWithTheirPublicKey:(NSString*)theirPublicKey requestingDevice:(MXDeviceInfo*)requestingDevice otherDevice:(MXDeviceInfo*)otherDevice;

@end

NS_ASSUME_NONNULL_END
