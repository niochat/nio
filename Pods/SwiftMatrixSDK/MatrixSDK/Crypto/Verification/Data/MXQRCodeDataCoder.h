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

#import <Foundation/Foundation.h>

#import "MXQRCodeDataCodable.h"
#import "MXQRCodeData.h"

NS_ASSUME_NONNULL_BEGIN

/**
 MXQRCodeDataCoder is used to parse or encode QR code binary format.
 */
@interface MXQRCodeDataCoder : NSObject

/**
 Parse an MXQRCodeData subclass from raw data.

 @param data QR code binary data.
 @return Approriate MXQRCodeData subclass or nil if binary data are not valid.
 */
- (nullable MXQRCodeData*)decode:(NSData*)data;

/**
 Encode a QR code format class conforming to MXQRCodeDataCodable.

 @param qrCodeDataCodable QR code format class.
 @return QR code binary data.
 */
- (NSData*)encode:(id <MXQRCodeDataCodable>)qrCodeDataCodable;

@end

NS_ASSUME_NONNULL_END
