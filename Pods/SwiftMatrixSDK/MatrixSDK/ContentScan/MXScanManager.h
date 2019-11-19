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

@import Foundation;

#pragma mark - Constants

/**
 Notification name sent when event scans change. Provides event scans inserted, modified or deleted.
 Give an associated userInfo dictionary of type NSDictionary<NSString*, NSArray<MXEventScan*>*> with following keys: "insertions", "modifications", "deletions". Use constants below for convenience.
 */
FOUNDATION_EXPORT NSString * _Nonnull const MXScanManagerEventScanDidChangeNotification;

/**
 Notification name sent when media scans change. Provides media scans inserted, modified or deleted.
 Give an associated userInfo dictionary of type NSDictionary<NSString*, NSArray<MXMediaScan*>*> with following keys: "insertions", "modifications", "deletions". Use constants below for convenience.
 */
FOUNDATION_EXPORT NSString * _Nonnull const MXScanManagerMediaScanDidChangeNotification;

/**
 userInfo dictionary keys used by `MXScanManagerEventScanDidChangeNotification` and `MXScanManagerMediaScanDidChangeNotification`.
 */
FOUNDATION_EXPORT NSString * _Nonnull const MXScanManagerScanDidChangeNotificationInsertionsUserInfoKey;
FOUNDATION_EXPORT NSString * _Nonnull const MXScanManagerScanDidChangeNotificationModificationsUserInfoKey;
FOUNDATION_EXPORT NSString * _Nonnull const MXScanManagerScanDidChangeNotificationDeletionsUserInfoKey;

FOUNDATION_EXPORT NSString * _Nonnull const MXErrorContentScannerReasonKey;
FOUNDATION_EXPORT NSString * _Nonnull const MXErrorContentScannerReasonValueBadDecryption;

#pragma mark - Types

@class MXRestClient, MXEvent, MXEventScan, MXMediaScan, MXEncryptedContentFile, MXContentScanEncryptedBody;

#pragma mark - Interface

/**
 `MXScanManager` enables to perform an antivirus scan on medias (with mxc URI) and event that contain medias.
 
 It emits an NSNotification with name `MXScanManagerMediaScanDidChangeNotification` when event scans change and `MXScanManagerMediaScanDidChangeNotification` when media scans change.
 */
@interface MXScanManager : NSObject

#pragma mark - Properties

/**
 The queue on which asynchronous response blocks are called.
 Default is dispatch_get_main_queue().
 */
@property (nonatomic, strong, nonnull) dispatch_queue_t completionQueue;

/**
 Tell whether the encryption information must be sent encrypted to the antivirus server.
 Default is YES (the request body of any POST request is then encrypted using the server public key).
 */
@property (nonatomic, getter=isEncryptedBobyEnabled) BOOL enableEncryptedBoby;

/**
 The antivirus server URL.
 */
@property (nonatomic, readonly, nonnull) NSString *antivirusServerURL;

/**
 The Client-Server API prefix to use for the antivirus server.
 */
@property (nonatomic, readonly, nonnull) NSString *antivirusServerPathPrefix;

#pragma mark - Methods

#pragma mark Setup

/**
 Designated initializer.
 
 @param restClient A Matrix rest client using antivirus server.
 @return Returns nil if antivirus server does not exist on rest client.
 */
- (nullable instancetype)initWithRestClient:(nonnull MXRestClient*)restClient NS_DESIGNATED_INITIALIZER;

#pragma mark Media

/**
 Retrieve a media scan from his URL.

 @param mediaURL The media URL.
 @return The media scan associated to the URL.
 */
- (nullable MXMediaScan*)mediaScanWithURL:(nonnull NSString*)mediaURL;

/**
 Scan unencrypted media.

 @param mediaURL The media URL.
 @param completion A block object to be executed when the scan finishes. `mediaScan` provide the scan results. `mediaScanDidSucceed` indicate if an error occur.
 */
- (void)scanUnencryptedMediaWithURL:(nonnull NSString*)mediaURL completion:(void (^ _Nullable)(MXMediaScan* _Nullable mediaScan, BOOL mediaScanDidSucceed))completion;

/**
 Launch a scan for an unencrypted media. This method is designed to be used with media scan notifications changes `MXScanManagerMediaScanDidChangeNotification`.

 @param mediaURL The media URL.
 */
- (void)scanUnencryptedMediaIfNeededWithURL:(nonnull NSString*)mediaURL;

/**
 Scan encrypted media.

 @param encryptedContentFile The encryption data required to decrypt the encrypted media.
 @param completion A block object to be executed when the scan finishes. `mediaScan` provide the scan results. `mediaScanDidSucceed` indicate if an error occur.
 */
- (void)scanEncryptedMediaWithEncryptedFile:(nonnull MXEncryptedContentFile*)encryptedContentFile completion:(void (^ _Nullable)(MXMediaScan* _Nullable mediaScan, BOOL mediaScanDidSucceed))completion;

/**
 Launch a scan for an encrypted media. This method is designed to be used with evvent scan notifications changes `MXScanManagerMediaScanDidChangeNotification`.

 @param encryptedContentFile The encryption data required to decrypt the encrypted media.
 */
- (void)scanEncryptedMediaIfNeededWithEncryptedFile:(nonnull MXEncryptedContentFile*)encryptedContentFile;

#pragma mark Event

/**
 Retrieve an event scan from his eventId.

 @param eventId The event identifier.
 @return The event scan associated to the eventId.
 */
- (nullable MXEventScan*)eventScanWithId:(nonnull NSString*)eventId;

/**
 Scan an event and is associated medias.

 @param event The event to scan.
 @param completion A block object to be executed when the scan finishes. `eventScan` provide the scan results. `eventScanDidSucceed` indicate if an error occur.
 */
- (void)scanEvent:(nonnull MXEvent*)event completion:(void (^ _Nullable)(MXEventScan* _Nullable eventScan, BOOL eventScanDidSucceed))completion;

/**
 Launch an event scan. This method is designed to be used with media scan notifications changes `MXScanManagerEventScanDidChangeNotification`.

 @param event The event to scan.
 */
- (void)scanEventIfNeeded:(nonnull MXEvent*)event;

#pragma mark Encrypted body

/**
 Encrypt the provided dictionary using the server public key.
 Use this method to prepare the POST request body when the encrypted body is enabled.
 
 @param requestBody the data to encrypt.
 @param completion A block object to be executed when the encrypted body is available. The returned instance is
 null if the server doesn't have a public key, or if an error occured during the encryption.
 */
- (void)encryptRequestBody:(nonnull NSDictionary *)requestBody completion:(void (^ _Nonnull)(MXContentScanEncryptedBody* _Nullable encryptedBody))completion;

#pragma mark Server key

/**
 Get the current public curve25519 key of the Antivirus server.
 A server request is triggered only if the key is not already known.
 
 @param completion A block object to be executed when the public key is available. `publicKey` provide the key.
 */
- (void)getAntivirusServerPublicKey:(void (^ _Nonnull)(NSString* _Nullable publicKey))completion;

/**
 In case of a content scanner error, use this method to check the public key validity.
 */
- (void)checkAntivirusServerPublicKeyOnError:(nullable NSError *)error;

/**
 * Reset the current known Antivirus server public key (if any).
 */
- (void)resetAntivirusServerPublicKey;

#pragma mark Other

/**
 Reset all event and media scans in `in progress` status to `unknown` status.
 This method could be called at application startup to reset in progress scans statuses to unknown. Because some scans may get stuck to `in progress status` when killing the app for example.
 */
- (void)resetAllAntivirusScanStatusInProgressToUnknown;

/**
 Delete all antivirus scans (event and media).
 */
- (void)deleteAllAntivirusScans;

#pragma mark - Unavailable Methods

/**
 Unavailable initializer.
 */
+ (nonnull instancetype)new NS_UNAVAILABLE;

/**
 Unavailable initializer.
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

@end
