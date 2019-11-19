/*
 Copyright 2016 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
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

#import <AVFoundation/AVFoundation.h>
#import "MXMediaLoader.h"
#import "MXEnumConstants.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#elif TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#endif

@class MXEncryptedContentFile;
@class MXScanManager;

/**
 The predefined folder for avatar thumbnail.
 */
extern NSString *const kMXMediaManagerAvatarThumbnailFolder;
extern NSString *const kMXMediaManagerDefaultCacheFolder;

/**
 `MXMediaManager` class provide multiple services related to media handling: cache storage, downloading, uploading.
 
 Cache is handled by folders. A specific folder is defined to store avatar thumbnails `kMXMediaManagerAvatarThumbnailFolder`.
 Other folders creation is free.
 
 Media upload is based on matrix content repository. It requires a matrix session.
 */
@interface MXMediaManager : NSObject

/**
 Create an instance based on a homeserver url. This homeserver URL is required to resolve
 the Matrix Content URI (in the form of "mxc://...").
 
 @param homeserverURL the homeserver URL.
 @return a MXMediaManager instance.
 */
- (id)initWithHomeServer:(NSString *)homeserverURL;

/**
 The homeserver URL.
 */
@property (nonatomic, readonly) NSString *homeserverURL;

/**
 Antivirus scanner used to scan medias.
 Set a non-null instance to enable the antivirus server use.
 */
@property (nonatomic) MXScanManager *scanManager;


#pragma mark - File handling

/**
 Write data into the provided file path.
 
 @param mediaData the data to write.
 @param filePath the file to write data to.
 @return YES on sucess.
 */
+ (BOOL)writeMediaData:(NSData *)mediaData toFilePath:(NSString*)filePath;

/**
 Load an image in memory cache. If the image is not in the cache,
 load it from the given path, insert it into the cache and return it.
 The images are cached in a LRU cache if they are not yet loaded.
 So, it should be faster than calling loadPictureFromFilePath;
 
 @param filePath picture file path.
 @return Image (if any).
 */
#if TARGET_OS_IPHONE
+ (UIImage*)loadThroughCacheWithFilePath:(NSString*)filePath;
#elif TARGET_OS_OSX
+ (NSImage*)loadThroughCacheWithFilePath:(NSString*)filePath;
#endif

/**
 Load an image from the in memory cache, or return nil if the image
 is not in the cache
 
 @param filePath picture file path.
 @return Image (if any).
 */
#if TARGET_OS_IPHONE
+ (UIImage*)getFromMemoryCacheWithFilePath:(NSString*)filePath;
#elif TARGET_OS_OSX
+ (NSImage*)getFromMemoryCacheWithFilePath:(NSString*)filePath;
#endif

/**
 * Save an image to in-memory cache, evicting other images
 * if necessary
 */

#if TARGET_OS_IPHONE
+ (void)cacheImage:(UIImage *)image withCachePath:(NSString *)cachePath;
#elif TARGET_OS_OSX
+ (void)cacheImage:(NSImage *)image withCachePath:(NSString *)cachePath;
#endif

/**
 Load a picture from the local storage
 
 @param filePath picture file path.
 @return Image (if any).
 */
#if TARGET_OS_IPHONE
+ (UIImage*)loadPictureFromFilePath:(NSString*)filePath; 
#elif TARGET_OS_OSX
+ (NSImage*)loadPictureFromFilePath:(NSString*)filePath;
#endif

/**
 Save an image to user's photos library
 
 @param image
 @param success A block object called when the operation succeeds. The returned url
 references the image in the file system or in the AssetsLibrary framework.
 @param failure A block object called when the operation fails.
 */
#if TARGET_OS_IPHONE
+ (void)saveImageToPhotosLibrary:(UIImage*)image success:(void (^)(NSURL *imageURL))success failure:(void (^)(NSError *error))failure;
#endif
/**
 Save a media to user's photos library
 
 @param fileURL URL based on local media file path.
 @param isImage YES for images, NO for video files.
 @param success A block object called when the operation succeeds.The returned url
 references the media in the file system or in the AssetsLibrary framework.
 @param failure A block object called when the operation fails.
 */
#if TARGET_OS_IPHONE
+ (void)saveMediaToPhotosLibrary:(NSURL*)fileURL isImage:(BOOL)isImage success:(void (^)(NSURL *imageURL))success failure:(void (^)(NSError *error))failure;
#endif


#pragma mark - Media Repository API

/**
 Resolve a Matrix media content URI (in the form of "mxc://...") into an HTTP URL.
 
 @param mxcContentURI the Matrix content URI to resolve.
 @return the Matrix content HTTP URL. nil if the Matrix content URI is invalid.
 */
- (NSString*)urlOfContent:(NSString*)mxcContentURI;

/**
 Get the suitable HTTP URL of a thumbnail image from a Matrix media content according to the destined view size.

 @param mxcContentURI the Matrix content URI to resolve.
 @param viewSize in points, it will be converted in pixels by considering screen scale.
 @param thumbnailingMethod the method the Matrix content repository must use to generate the thumbnail.
 @return the thumbnail HTTP URL. The provided URI is returned if it is not a valid Matrix content URI.
 */
- (NSString*)urlOfContentThumbnail:(NSString*)mxcContentURI toFitViewSize:(CGSize)viewSize withMethod:(MXThumbnailingMethod)thumbnailingMethod;

/**
 Get the HTTP URL of an identicon served by the media repository.
 
 @param identiconString the string to build an identicon from.
 @return the identicon HTTP URL.
 */
- (NSString*)urlOfIdenticon:(NSString*)identiconString;


#pragma mark - Download

/**
 Get the unique download identifier for a Matrix Content URI, consider a potential cache folder to handle
 several downloads in different cache areas.
 
 @param mxContentURI the Matrix Content URI (mxc://...).
 @param folder cache folder to use (may be nil). kMXMediaManagerDefaultCacheFolder is used by default.
 @return the download identifier. nil if the Matrix Content URI is invalid.
 */
+ (NSString*)downloadIdForMatrixContentURI:(NSString*)mxContentURI
                                  inFolder:(NSString*)folder;

/**
 Get the unique download identifier for a thumbnail downloaded from on the Matrix Content URI,
 consider a potential cache folder to handle several downloads in different cache areas.
 
 @param mxContentURI the Matrix Content URI (mxc://...).
 @param folder cache folder to use (may be nil). kMXMediaManagerDefaultCacheFolder is used by default.
 @param viewSize the size in points of the view in which the thumbnail is supposed to be displayed.
 @param thumbnailingMethod the method the Matrix content repository must use to generate the thumbnail.
 @return the download identifier. nil if the Matrix Content URI is invalid.
 */
+ (NSString*)thumbnailDownloadIdForMatrixContentURI:(NSString*)mxContentURI
                                           inFolder:(NSString*)folder
                                      toFitViewSize:(CGSize)viewSize
                                         withMethod:(MXThumbnailingMethod)thumbnailingMethod;

/**
 Download data from the provided Matrix Content (MXC) URI (in the form of "mxc://...").
 
 @param mxContentURI the Matrix Content URI.
 @param mimeType the media mime type (may be nil).
 @param folder the cache folder to use (may be nil). kMXMediaManagerDefaultCacheFolder is used by default.
 @param success a block called when the download succeeds. This block gets the path of the resulting file.
 @param failure a block called when the download fails
 @return a media loader in order to let the user cancel this action.
 */
- (MXMediaLoader*)downloadMediaFromMatrixContentURI:(NSString *)mxContentURI
                                           withType:(NSString *)mimeType
                                           inFolder:(NSString *)folder
                                            success:(void (^)(NSString *outputFilePath))success
                                            failure:(void (^)(NSError *error))failure;

/**
 Download data from the provided Matrix Content (MXC) URI (in the form of "mxc://...").
 
 @param mxContentURI the Matrix Content URI.
 @param mimeType the media mime type (may be nil).
 @param folder the cache folder to use (may be nil). kMXMediaManagerDefaultCacheFolder is used by default.
 @return a media loader in order to let the user cancel this action.
 */
- (MXMediaLoader*)downloadMediaFromMatrixContentURI:(NSString *)mxContentURI
                                           withType:(NSString *)mimeType
                                           inFolder:(NSString *)folder;

/**
 Download thumbnail data from the provided Matrix Content (MXC) URI (in the form of "mxc://...")
 to fit a specific view size.
 
 @param mxContentURI the Matrix Content URI.
 @param mimeType the media mime type (may be nil).
 @param folder the cache folder to use (may be nil). kMXMediaManagerDefaultCacheFolder is used by default.
 @param viewSize the size in points of the view in which the thumbnail will be displayed, it will be converted
 in pixels by considering screen scale.
 @param thumbnailingMethod the method the Matrix content repository must use to generate the thumbnail.
 @param success a block called when the download succeeds. This block gets the path of the resulting file.
 @param failure a block called when the download fails
 @return a media loader in order to let the user cancel this action.
 */
- (MXMediaLoader*)downloadThumbnailFromMatrixContentURI:(NSString *)mxContentURI
                                               withType:(NSString *)mimeType
                                               inFolder:(NSString *)folder
                                          toFitViewSize:(CGSize)viewSize
                                             withMethod:(MXThumbnailingMethod)thumbnailingMethod
                                                success:(void (^)(NSString *outputFilePath))success
                                                failure:(void (^)(NSError *error))failure;

/**
 Download encrypted data from the Matrix Content repository.
 
 @param encryptedContentFile the encrypted Matrix Content details.
 @param folder the cache folder to use (may be nil). kMXMediaManagerDefaultCacheFolder is used by default.
 @param success a block called when the download succeeds. This block gets the path of the resulting file.
 @param failure a block called when the download fails
 @return a media loader in order to let the user cancel this action.
 */
- (MXMediaLoader*)downloadEncryptedMediaFromMatrixContentFile:(MXEncryptedContentFile *)encryptedContentFile
                                                     inFolder:(NSString *)folder
                                                      success:(void (^)(NSString *outputFilePath))success
                                                      failure:(void (^)(NSError *error))failure;

/**
 Download encrypted data from the Matrix Content repository.
 
 @param encryptedContentFile the encrypted Matrix Content details.
 @param folder the cache folder to use (may be nil). kMXMediaManagerDefaultCacheFolder is used by default.
 @return a media loader in order to let the user cancel this action.
 */
- (MXMediaLoader*)downloadEncryptedMediaFromMatrixContentFile:(MXEncryptedContentFile *)encryptedContentFile
                                                     inFolder:(NSString *)folder;

/**
 Check whether a download is already running with a specific download identifier.
 
 @param downloadId the identifier.
 @return mediaLoader (if any)
 */
+ (MXMediaLoader*)existingDownloaderWithIdentifier:(NSString *)downloadId;

/**
 Cancel any pending download within a cache folder
 */
+ (void)cancelDownloadsInCacheFolder:(NSString*)folder;

/**
 Cancel all pending downloads
 */
+ (void)cancelDownloads;


#pragma mark - Upload

/**
 Prepares a media loader to upload data to a matrix content repository.
 
 Note: An upload could be a subpart of a global upload. For example, upload a video can be split in two parts :
 1 - upload the thumbnail -> initialRange = 0, range = 0.1 : assume that the thumbnail upload is 10% of the upload process
 2 - upload the media -> initialRange = 0.1, range = 0.9 : the media upload is 90% of the global upload
 
 @param mxSession the matrix session used to upload media.
 @param initialRange the global upload progress already did done before this current upload.
 @param range the range value of this upload in the global scope.
 @return a media loader.
 */
+ (MXMediaLoader*)prepareUploaderWithMatrixSession:(MXSession*)mxSession
                                       initialRange:(CGFloat)initialRange
                                           andRange:(CGFloat)range;

/**
 Check whether an upload is already running with this id.
 
 @param uploadId the id of the upload to fectch.
 @return mediaLoader (if any).
 */
+ (MXMediaLoader*)existingUploaderWithId:(NSString*)uploadId;

/**
 Cancel any pending upload
 */
+ (void)cancelUploads;


#pragma mark - Cache handling

/**
 Build a cache file path based on the Matrix Content URI of the media and an optional cache folder.
 
 The file extension is extracted from the provided mime type (if any).
 By default 'image/jpeg' is considered for thumbnail folder (kMXMediaManagerAvatarThumbnailFolder). No default mime type
 is defined for other folders.
 
 @param mxContentURI the Matrix Content URI (mxc://...).
 @param mimeType the media mime type (may be nil).
 @param folder cache folder to use (may be nil). kMXMediaManagerDefaultCacheFolder is used by default.
 @return cache file path. nil if the Matrix Content URI is invalid.
 */
+ (NSString*)cachePathForMatrixContentURI:(NSString*)mxContentURI
                                  andType:(NSString *)mimeType
                                 inFolder:(NSString*)folder;

/**
 Build a cache file path for a thumbnail downloaded from on the Matrix Content URI.
 
 The file extension is extracted from the provided mime type (if any).
 By default 'image/jpeg' is considered for thumbnail folder (kMXMediaManagerAvatarThumbnailFolder). No default mime type
 is defined for other folders.
 
 @param mxContentURI the Matrix Content URI (mxc://...).
 @param mimeType the media mime type (may be nil).
 @param folder cache folder to use (may be nil). kMXMediaManagerDefaultCacheFolder is used by default.
 @param viewSize the size in points of the view in which the thumbnail is supposed to be displayed.
 @param thumbnailingMethod the method the Matrix content repository must use to generate the thumbnail.
 @return cache file path. nil if the Matrix Content URI is invalid.
 */
+ (NSString*)thumbnailCachePathForMatrixContentURI:(NSString*)mxContentURI
                                           andType:(NSString *)mimeType
                                          inFolder:(NSString*)folder
                                     toFitViewSize:(CGSize)viewSize
                                        withMethod:(MXThumbnailingMethod)thumbnailingMethod;

/**
 Build a unique cache file path for a temporary file.
 
 The file extension is extracted from the provided mime type (if any).
 
 @param folder cache folder to use (may be nil). kMXMediaManagerDefaultCacheFolder is used by default.
 @param mimeType the media mime type (may be nil).
 @return cache file path.
 */
+ (NSString*)temporaryCachePathInFolder:(NSString*)folder
                               withType:(NSString *)mimeType;

/**
 Check if the media cache size must be reduced to fit the user expected cache size
 
 @param sizeInBytes expected cache size in bytes.
 */
+ (void)reduceCacheSizeToInsert:(NSUInteger)sizeInBytes;

/**
 Clear cache
 */
+ (void)clearCache;

/**
 Return cache root path
 */
+ (NSString*)getCachePath;

/**
 Return the current media cache version.
 This value depends on the version defined at the application level (see [MXSDKOptions mediaCacheAppVersion]),
 and the one defined at SDK level.
 */
+ (NSString*)getCacheVersionString;

/**
 Cache size management (values are in bytes)
 */
+ (NSUInteger)cacheSize;
+ (NSUInteger)minCacheSize;

/**
 The current maximum size of the media cache (in bytes).
 */
+ (NSInteger)currentMaxCacheSize;
+ (void)setCurrentMaxCacheSize:(NSInteger)maxCacheSize;

/**
 The maximum allowed size of the media cache (in bytes).
 
 Return the value for the key `maxAllowedMediaCacheSize` in the shared defaults object (1 GB if no default value is defined).
 */
+ (NSInteger)maxAllowedCacheSize;

@end
