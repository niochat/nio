/*
 Copyright 2014 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
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

#import <Foundation/Foundation.h>

/**
 The Matrix iOS SDK version.
 */
FOUNDATION_EXPORT NSString *MatrixSDKVersion;

#import "MXRestClient.h"
#import "MXSession.h"
#import "MXError.h"

#import "MXStore.h"
#import "MXNoStore.h"
#import "MXMemoryStore.h"
#import "MXFileStore.h"

#import "MXAllowedCertificates.h"

#import "MXRoomSummaryUpdater.h"

#import "MXEventsEnumeratorOnArray.h"
#import "MXEventsByTypesEnumeratorOnArray.h"

#import "MXLogger.h"

#import "MXTools.h"
#import "MXThrottler.h"
#import "NSData+MatrixSDK.h"

#import "MXSDKOptions.h"

#import "MXMediaManager.h"

#import "MXLRUCache.h"

#import "MXCallStack.h"

#import "MXCrypto.h"
#import "MXMegolmExportEncryption.h"
#import "MXEncryptedContentFile.h"
#import "MXEncryptedContentKey.h"
#import "MXKeyVerificationStart.h"
#import "MXKeyVerificationAccept.h"
#import "MXKeyVerificationCancel.h"
#import "MXKeyVerificationDone.h"
#import "MXKeyVerificationKey.h"
#import "MXKeyVerificationMac.h"
#import "MXKeyVerificationRequestByDMJSONModel.h"
#import "MXSASKeyVerificationStart.h"
#import "MXQRCodeKeyVerificationStart.h"

#import "MXQRCodeDataCodable.h"
#import "MXQRCodeDataBuilder.h"
#import "MXQRCodeDataCoder.h"
#import "MXQRCodeData.h"
#import "MXVerifyingAnotherUserQRCodeData.h"
#import "MXSelfVerifyingMasterKeyTrustedQRCodeData.h"
#import "MXSelfVerifyingMasterKeyNotTrustedQRCodeData.h"

#import "MXBugReportRestClient.h"

#import "MXCallKitAdapter.h"
#import "MXCallKitConfiguration.h"

#import "MXGroup.h"

#import "MXServerNotices.h"

#import "MXAutoDiscovery.h"
#import "MXServiceTerms.h"

#import "MXEventUnsignedData.h"
#import "MXEventRelations.h"
#import "MXEventAnnotationChunk.h"
#import "MXEventAnnotation.h"
#import "MXEventReferenceChunk.h"


#import "MXReplyEventParser.h"

#import "MXEventScan.h"
#import "MXMediaScan.h"
