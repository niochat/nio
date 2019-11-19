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

#import "TargetConditionals.h"

#import <Photos/Photos.h>

#import "MXMediaManager.h"
#import "MXScanManager.h"

#import "MXEncryptedContentFile.h"
#import "MXContentScanEncryptedBody.h"

#import "MXSDKOptions.h"

#import "MXLRUCache.h"
#import "MXTools.h"

NSUInteger const kMXMediaCacheSDKVersion = 3;

NSString *const kMXMediaManagerAvatarThumbnailFolder = @"kMXMediaManagerAvatarThumbnailFolder";
NSString *const kMXMediaManagerDefaultCacheFolder = @"kMXMediaManagerDefaultCacheFolder";

NSString *const kMXMediaManagerTmpCachePathPrefix = @"tmpCache-";

static NSString* mediaCachePath  = nil;
static NSString *mediaDir        = @"mediacache";

static MXMediaManager *sharedMediaManager = nil;

// store the current cache size
// avoid listing files because it is useless
static NSUInteger storageCacheSize = 0;

@implementation MXMediaManager

- (id)initWithHomeServer:(NSString *)homeserverURL
{
    self = [super init];
    if (self)
    {
        _homeserverURL = homeserverURL;
        _scanManager = nil;
    }
    return self;
}

/**
 Table of downloads in progress
 */
static NSMutableDictionary* downloadTable = nil;

/**
 Table of uploads in progress
 */
static NSMutableDictionary* uploadTableById = nil;

+ (MXMediaManager *)sharedManager
{
    @synchronized(self)
    {
        if(sharedMediaManager == nil)
        {
            sharedMediaManager = [[super allocWithZone:NULL] init];
        }
    }
    return sharedMediaManager;
}

#pragma mark - File handling

+ (BOOL)writeMediaData:(NSData *)mediaData toFilePath:(NSString*)filePath
{
    BOOL isCacheFile = [filePath hasPrefix:[MXMediaManager getCachePath]];
    if (isCacheFile)
    {
        [MXMediaManager reduceCacheSizeToInsert:mediaData.length];
    }
    
    if ([mediaData writeToFile:filePath atomically:YES])
    {
        if (isCacheFile)
        {
            storageCacheSize += mediaData.length;
        }
        
        return YES;
    }
    return NO;
}

static MXLRUCache* imagesCacheLruCache = nil;

#if TARGET_OS_IPHONE
+ (UIImage*)loadThroughCacheWithFilePath:(NSString*)filePath
#elif TARGET_OS_OSX
+ (NSImage*)loadThroughCacheWithFilePath:(NSString*)filePath
#endif
{
#if TARGET_OS_IPHONE
    UIImage *image = [MXMediaManager getFromMemoryCacheWithFilePath:filePath];
#elif TARGET_OS_OSX
    NSImage *image = [MXMediaManager getFromMemoryCacheWithFilePath:filePath];
#endif
    
    if (image) return image;
    
    image = [MXMediaManager loadPictureFromFilePath:filePath];
    
    if (image)
    {
        [MXMediaManager cacheImage:image withCachePath:filePath];
    }
    
    return image;
}


#if TARGET_OS_IPHONE
+ (UIImage*)getFromMemoryCacheWithFilePath:(NSString*)filePath
#elif TARGET_OS_OSX
+ (NSImage*)getFromMemoryCacheWithFilePath:(NSString*)filePath
#endif
{
    if (!imagesCacheLruCache)
    {
        imagesCacheLruCache = [[MXLRUCache alloc] initWithCapacity:20];
    }
    
#if TARGET_OS_IPHONE
    return (UIImage*)[imagesCacheLruCache get:filePath];
#elif TARGET_OS_OSX
    return (NSImage*)[imagesCacheLruCache get:filePath];
#endif
}

#if TARGET_OS_IPHONE
+ (void)cacheImage:(UIImage *)image withCachePath:(NSString *)filePath
#elif TARGET_OS_OSX
+ (void)cacheImage:(NSImage *)image withCachePath:(NSString *)filePath
#endif
{
    [imagesCacheLruCache put:filePath object:image];
}


#if TARGET_OS_IPHONE
+ (UIImage*)loadPictureFromFilePath:(NSString*)filePath
#elif TARGET_OS_OSX
+ (NSImage*)loadPictureFromFilePath:(NSString*)filePath
#endif
{
#if TARGET_OS_IPHONE
    UIImage* res = nil;
#elif TARGET_OS_OSX
    NSImage* res = nil;
#endif
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath])
    {
        NSData* imageContent = [NSData dataWithContentsOfFile:filePath options:(NSDataReadingMappedAlways | NSDataReadingUncached) error:nil];
        if (imageContent)
        {
#if TARGET_OS_IPHONE
            res = [[UIImage alloc] initWithData:imageContent];
#elif TARGET_OS_OSX
            res = [[NSImage alloc] initWithData:imageContent];
#endif
        }
    }
    
    return res;
}

#if TARGET_OS_IPHONE
+ (void)saveImageToPhotosLibrary:(UIImage*)image success:(void (^)(NSURL *imageURL))success failure:(void (^)(NSError *error))failure
{
    if (image)
    {
        __block NSString* localId;
        
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            
            // Request creating an asset from the image.
            PHAssetChangeRequest *assetRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
            
            localId = [[assetRequest placeholderForCreatedAsset] localIdentifier];
            
        } completionHandler:^(BOOL successFlag, NSError *error) {
            
            NSLog(@"Finished adding asset. %@", (successFlag ? @"Success" : error));
            
            if (successFlag)
            {
                if (success)
                {
                    // Retrieve the created asset thanks to the local id of the change request
                    PHFetchResult* assetResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[localId] options:nil];
                    // Sanity check
                    if (assetResult.count)
                    {
                        PHAsset *asset = [assetResult firstObject];
                        PHContentEditingInputRequestOptions *editOptions = [[PHContentEditingInputRequestOptions alloc] init];
                        
                        [asset requestContentEditingInputWithOptions:editOptions
                                                   completionHandler:^(PHContentEditingInput *contentEditingInput, NSDictionary *info) {
                                                       
                                                       // Here the fullSizeImageURL is related to a local file path
                                                       
                                                       // Return on main thread
                                                       dispatch_async(dispatch_get_main_queue(), ^{
                                                           success(contentEditingInput.fullSizeImageURL);
                                                       });
                                                   }];
                    }
                    else
                    {
                        // Return on main thread
                        dispatch_async(dispatch_get_main_queue(), ^{
                            success(nil);
                        });
                    }
                }
            }
            else if (failure)
            {
                // Return on main thread
                dispatch_async(dispatch_get_main_queue(), ^{
                    failure(error);
                });
            }
            
        }];
    }
}
#endif

#if TARGET_OS_IPHONE
+ (void)saveMediaToPhotosLibrary:(NSURL*)fileURL isImage:(BOOL)isImage success:(void (^)(NSURL *imageURL))success failure:(void (^)(NSError *error))failure
{
    if (fileURL)
    {
        __block NSString* localId;
        
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            
            PHAssetChangeRequest *assetRequest;
            
            if (isImage)
            {
                // Request creating an asset from the image.
                assetRequest = [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:fileURL];
            }
            else
            {
                // Request creating an asset from the image.
                assetRequest = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:fileURL];
            }
            
            localId = [[assetRequest placeholderForCreatedAsset] localIdentifier];
            
        } completionHandler:^(BOOL successFlag, NSError *error) {
            NSLog(@"Finished adding asset. %@", (successFlag ? @"Success" : error));
            
            if (successFlag)
            {
                if (success)
                {
                    // Retrieve the created asset thanks to the local id of the change request
                    PHFetchResult* assetResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[localId] options:nil];
                    // Sanity check
                    if (assetResult.count)
                    {
                        PHAsset *asset = [assetResult firstObject];
                        PHContentEditingInputRequestOptions *editOptions = [[PHContentEditingInputRequestOptions alloc] init];
                        
                        [asset requestContentEditingInputWithOptions:editOptions
                                                   completionHandler:^(PHContentEditingInput *contentEditingInput, NSDictionary *info) {
                                                       
                                                       if (contentEditingInput.mediaType == PHAssetMediaTypeImage)
                                                       {
                                                           // Here the fullSizeImageURL is related to a local file path
                                                           
                                                           // Return on main thread
                                                           dispatch_async(dispatch_get_main_queue(), ^{
                                                               success(contentEditingInput.fullSizeImageURL);
                                                           });
                                                       }
                                                       else if (contentEditingInput.mediaType == PHAssetMediaTypeVideo)
                                                       {
                                                           if ([contentEditingInput.avAsset isKindOfClass:[AVURLAsset class]])
                                                           {
                                                               AVURLAsset *avURLAsset = (AVURLAsset*)contentEditingInput.avAsset;
                                                               
                                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                                   success ([avURLAsset URL]);
                                                               });
                                                           }
                                                           else
                                                           {
                                                               NSLog(@"[MXMediaManager] Failed to retrieve the asset URL of the saved video!");
                                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                                   success (nil);
                                                               });
                                                           }
                                                       }
                                                       else
                                                       {
                                                           NSLog(@"[MXMediaManager] Failed to retrieve editing input from asset");
                                                           
                                                           // Return on main thread
                                                           dispatch_async(dispatch_get_main_queue(), ^{
                                                               success (nil);
                                                           });
                                                       }
                                                       
                                                   }];
                    }
                    else
                    {
                        // Return on main thread
                        dispatch_async(dispatch_get_main_queue(), ^{
                            success (nil);
                        });
                    }
                }
            }
            else if (failure)
            {
                // Return on main thread
                dispatch_async(dispatch_get_main_queue(), ^{
                    failure (error);
                });
            }
        }];
    }
}
#endif


#pragma mark - Media Repository URL

- (NSString*)urlOfContent:(NSString*)mxContentURI
{
    NSString *contentURL;
    
    // Replace the "mxc://" scheme by the absolute http location of the content
    if ([mxContentURI hasPrefix:kMXContentUriScheme])
    {
        NSString *mxMediaPrefix;
        
        // Check whether an antivirus server is present
        if (_scanManager)
        {
            mxMediaPrefix = [NSString stringWithFormat:@"%@/%@/download/", _scanManager.antivirusServerURL, _scanManager.antivirusServerPathPrefix];
        }
        else
        {
            mxMediaPrefix = [NSString stringWithFormat:@"%@/%@/download/", _homeserverURL, kMXContentPrefixPath];
        }
        
        contentURL = [mxContentURI stringByReplacingOccurrencesOfString:kMXContentUriScheme withString:mxMediaPrefix];
        
        // Remove the auto generated image tag from the URL
        contentURL = [contentURL stringByReplacingOccurrencesOfString:@"#auto" withString:@""];
        return contentURL;
    }
    
    // do not allow non-mxc content URLs: we should not be making requests out to whatever http urls people send us
    return nil;
}

- (NSString*)urlOfContentThumbnail:(NSString*)mxContentURI
                     toFitViewSize:(CGSize)viewSize
                        withMethod:(MXThumbnailingMethod)thumbnailingMethod
{
    // Replace the "mxc://" scheme by the absolute http location for the content thumbnail
    if ([mxContentURI hasPrefix:kMXContentUriScheme])
    {
        // Convert first the provided size in pixels
#if TARGET_OS_IPHONE
        CGFloat scale = [[UIScreen mainScreen] scale];
#elif TARGET_OS_OSX
        CGFloat scale = [[NSScreen mainScreen] backingScaleFactor];
#endif
        
        CGSize sizeInPixels = CGSizeMake(viewSize.width * scale, viewSize.height * scale);
        
        NSString *mxThumbnailPrefix;
        
        // Check whether an antivirus server is present
        if (_scanManager)
        {
            mxThumbnailPrefix = [NSString stringWithFormat:@"%@/%@/thumbnail/", _scanManager.antivirusServerURL, _scanManager.antivirusServerPathPrefix];
        }
        else
        {
            mxThumbnailPrefix = [NSString stringWithFormat:@"%@/%@/thumbnail/", _homeserverURL, kMXContentPrefixPath];
        }
        NSString *thumbnailURL = [mxContentURI stringByReplacingOccurrencesOfString:kMXContentUriScheme withString:mxThumbnailPrefix];
        
        // Convert MXThumbnailingMethod to parameter string
        NSString *thumbnailingMethodString;
        switch (thumbnailingMethod)
        {
            case MXThumbnailingMethodScale:
                thumbnailingMethodString = @"scale";
                break;
                
            case MXThumbnailingMethodCrop:
                thumbnailingMethodString = @"crop";
                break;
        }
        
        // Remove the auto generated image tag from the URL
        thumbnailURL = [thumbnailURL stringByReplacingOccurrencesOfString:@"#auto" withString:@""];
        
        // Add thumbnailing parameters to the URL
        thumbnailURL = [NSString stringWithFormat:@"%@?width=%tu&height=%tu&method=%@", thumbnailURL, (NSUInteger)sizeInPixels.width, (NSUInteger)sizeInPixels.height, thumbnailingMethodString];
        
        return thumbnailURL;
    }
    
    // do not allow non-mxc content URLs: we should not be making requests out to whatever http urls people send us
    return nil;
}

- (NSString *)urlOfIdenticon:(NSString *)identiconString
{
    return [NSString stringWithFormat:@"%@/%@/identicon/%@", _homeserverURL, kMXContentPrefixPath, [identiconString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]]];
}


#pragma mark - Media Download

+ (NSString*)downloadIdForMatrixContentURI:(NSString*)mxContentURI
                                  inFolder:(NSString*)folder
{
    // Return the unique output file path built from the mxc uri and the potential folder (no type is required here)
    return [MXMediaManager cachePathForMatrixContentURI:mxContentURI andType:nil inFolder:folder];
}

+ (NSString*)thumbnailDownloadIdForMatrixContentURI:(NSString*)mxContentURI
                                           inFolder:(NSString*)folder
                                      toFitViewSize:(CGSize)viewSize
                                         withMethod:(MXThumbnailingMethod)thumbnailingMethod
{
    // Return the unique output file path built from the mxc uri and the potential folder (no type is required here)
    return [MXMediaManager thumbnailCachePathForMatrixContentURI:mxContentURI andType:nil inFolder:folder toFitViewSize:viewSize withMethod:thumbnailingMethod];
}

- (MXMediaLoader*)downloadMediaFromMatrixContentURI:(NSString *)mxContentURI
                                           withType:(NSString *)mimeType
                                           inFolder:(NSString *)folder
                                            success:(void (^)(NSString *outputFilePath))success
                                            failure:(void (^)(NSError *error))failure
{
    // Check the provided mxc URI by resolving it into an HTTP URL.
    NSString *mediaURL = [self urlOfContent:mxContentURI];
    if (!mediaURL)
    {
        NSLog(@"[MXMediaManager] downloadMediaFromMatrixContentURI: invalid media content URI");
        if (failure) failure(nil);
        return nil;
    }
    
    // Build the outpout file path from mxContentURI, and other inputs.
    NSString *filePath = [MXMediaManager cachePathForMatrixContentURI:mxContentURI andType:mimeType inFolder:folder];
    
    // Build the download id from mxContentURI.
    NSString *downloadId = [MXMediaManager downloadIdForMatrixContentURI:mxContentURI inFolder:folder];
    
    // Create a media loader to download data
    return [MXMediaManager downloadMedia:mediaURL
                                withData:nil
                           andIdentifier:downloadId
                          saveAtFilePath:filePath
                             scanManager:_scanManager
                                 success:success
                                 failure:failure];
}

- (MXMediaLoader*)downloadMediaFromMatrixContentURI:(NSString *)mxContentURI
                                           withType:(NSString *)mimeType
                                           inFolder:(NSString *)folder
{
    return [self downloadMediaFromMatrixContentURI:mxContentURI withType:mimeType inFolder:folder success:nil failure:nil];
}

- (MXMediaLoader*)downloadThumbnailFromMatrixContentURI:(NSString *)mxContentURI
                                               withType:(NSString *)mimeType
                                               inFolder:(NSString *)folder
                                          toFitViewSize:(CGSize)viewSize
                                             withMethod:(MXThumbnailingMethod)thumbnailingMethod
                                                success:(void (^)(NSString *outputFilePath))success
                                                failure:(void (^)(NSError *error))failure
{
    // Check the provided mxc URI by resolving it into an HTTP URL.
    NSString *mediaURL = [self urlOfContentThumbnail:mxContentURI toFitViewSize:viewSize withMethod:thumbnailingMethod];
    if (!mediaURL)
    {
        NSLog(@"[MXMediaManager] downloadThumbnailFromMatrixContentURI: invalid media content URI");
        if (failure) failure(nil);
        return nil;
    }
    
    // Build the outpout file path from mxContentURI, and other inputs.
    NSString *filePath = [MXMediaManager thumbnailCachePathForMatrixContentURI:mxContentURI andType:mimeType inFolder:folder toFitViewSize:viewSize withMethod:thumbnailingMethod];
    
    // Build the download id from mxContentURI.
    NSString *downloadId = [MXMediaManager thumbnailDownloadIdForMatrixContentURI:mxContentURI inFolder:folder toFitViewSize:viewSize withMethod:thumbnailingMethod];
    
    // Create a media loader to download data
    return [MXMediaManager downloadMedia:mediaURL
                                withData:nil
                           andIdentifier:downloadId
                          saveAtFilePath:filePath
                             scanManager:_scanManager
                                 success:success
                                 failure:failure];
}

// Private
+ (MXMediaLoader*)downloadMedia:(NSString *)mediaURL
                       withData:(NSDictionary *)data
                  andIdentifier:(NSString *)downloadId
                 saveAtFilePath:(NSString *)filePath
                    scanManager:(MXScanManager *)scanManager
                        success:(void (^)(NSString *outputFilePath))success
                        failure:(void (^)(NSError *error))failure
{
    MXMediaLoader *mediaLoader;
    
    // Check whether there is a loader for this download id in downloadTable.
    mediaLoader = [MXMediaManager existingDownloaderWithIdentifier:downloadId];
    if (mediaLoader)
    {
        // This mediaLoader has been created for the same matrix content uri, and cache folder.
        if (success || failure)
        {
            __weak NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
            id token;
            
            token = [center addObserverForName:kMXMediaLoaderStateDidChangeNotification
                                        object:mediaLoader
                                         queue:nil
                                    usingBlock:^(NSNotification * _Nonnull note) {
                                        
                                        MXMediaLoader *loader = (MXMediaLoader *)note.object;
                                        switch (loader.state) {
                                            case MXMediaLoaderStateDownloadCompleted:
                                                if (success)
                                                {
                                                    success(loader.downloadOutputFilePath);
                                                }
                                                [center removeObserver:token];
                                                break;
                                            case MXMediaLoaderStateDownloadFailed:
                                            case MXMediaLoaderStateCancelled:
                                                if (failure)
                                                {
                                                    failure(loader.error);
                                                }
                                                [center removeObserver:token];
                                                break;
                                            default:
                                                break;
                                        }
                                    }];
        }
    }
    else
    {
        // Create a media loader to download data
        mediaLoader = [[MXMediaLoader alloc] init];
        // Report this loader
        if (!downloadTable)
        {
            downloadTable = [[NSMutableDictionary alloc] init];
        }
        [downloadTable setValue:mediaLoader forKey:downloadId];
        
        if (data && scanManager.isEncryptedBobyEnabled)
        {
            [scanManager encryptRequestBody:data completion:^(MXContentScanEncryptedBody * _Nullable encryptedBody) {
                if (encryptedBody)
                {
                    // Launch the download
                    [mediaLoader downloadMediaFromURL:mediaURL
                                             withData:@{@"encrypted_body": encryptedBody.JSONDictionary}
                                           identifier:downloadId
                                    andSaveAtFilePath:filePath
                                              success:^(NSString *outputFilePath) {
                                                  
                                                  [downloadTable removeObjectForKey:downloadId];
                                                  if (success) success(outputFilePath);
                                                  
                                              }
                                              failure:^(NSError *error) {
                                                  
                                                  // Check whether the public key must be updated
                                                  [scanManager checkAntivirusServerPublicKeyOnError:error];
                                                  
                                                  if (failure) failure(error);
                                                  [downloadTable removeObjectForKey:downloadId];
                                                  
                                              }];
                }
                else
                {
                    NSLog(@"[MXMediaManager] download encrypted content failed");
                    if (failure) failure(nil);
                    [mediaLoader cancel];
                    [downloadTable removeObjectForKey:downloadId];
                }
            }];
        }
        else
        {
            // Launch the download without encrypted the request body (if any).
            [mediaLoader downloadMediaFromURL:mediaURL
                                     withData:data
                                   identifier:downloadId
                            andSaveAtFilePath:filePath
                                      success:^(NSString *outputFilePath) {
                                          
                                          [downloadTable removeObjectForKey:downloadId];
                                          if (success) success(outputFilePath);
                                          
                                      }
                                      failure:^(NSError *error) {
                                          
                                          if (failure) failure(error);
                                          [downloadTable removeObjectForKey:downloadId];
                                          
                                      }];
        }
    }
    
    return mediaLoader;
}

- (MXMediaLoader*)downloadEncryptedMediaFromMatrixContentFile:(MXEncryptedContentFile *)encryptedContentFile
                                                     inFolder:(NSString *)folder
                                                      success:(void (^)(NSString *outputFilePath))success
                                                      failure:(void (^)(NSError *error))failure
{
    // Check the provided mxc URI by resolving it into a download URL.
    NSString *mxContentURI = encryptedContentFile.url;
    NSString *downloadMediaURL;
    NSDictionary *dataToPost;
    
    // Check whether an antivirus server is present.
    if (_scanManager && [mxContentURI hasPrefix:kMXContentUriScheme])
    {
        // In this case, the same URL is used to download all the encrypted content.
        // The encrypted content file is sent in the request body.
        downloadMediaURL = [NSString stringWithFormat:@"%@/%@/download_encrypted", _scanManager.antivirusServerURL, _scanManager.antivirusServerPathPrefix];
        dataToPost = @{@"file": encryptedContentFile.JSONDictionary};
    }
    else
    {
        downloadMediaURL = [self urlOfContent:mxContentURI];
    }
    
    if (!downloadMediaURL)
    {
        NSLog(@"[MXMediaManager] downloadEncryptedMediaFromMatrixContentFile: invalid media content URI");
        if (failure) failure(nil);
        return nil;
    }
    
    // Build the outpout file path from mxContentURI, and other inputs.
    NSString *filePath = [MXMediaManager cachePathForMatrixContentURI:mxContentURI
                                                              andType:encryptedContentFile.mimetype
                                                             inFolder:folder];
    
    // Build the download id from mxContentURI.
    NSString *downloadId = [MXMediaManager downloadIdForMatrixContentURI:mxContentURI
                                                                inFolder:folder];
    
    // Create a media loader to download data
    return [MXMediaManager downloadMedia:downloadMediaURL
                                withData:dataToPost
                           andIdentifier:downloadId
                          saveAtFilePath:filePath
                             scanManager:_scanManager
                                 success:success
                                 failure:failure];
}

- (MXMediaLoader*)downloadEncryptedMediaFromMatrixContentFile:(MXEncryptedContentFile *)encryptedContentFile
                                                     inFolder:(NSString *)folder
{
    return [self downloadEncryptedMediaFromMatrixContentFile:encryptedContentFile inFolder:folder success:nil failure:nil];
}

+ (MXMediaLoader*)existingDownloaderWithIdentifier:(NSString *)downloadId
{
    if (downloadTable && downloadId)
    {
        return [downloadTable valueForKey:downloadId];
    }
    return nil;
}

+ (void)cancelDownloadsInCacheFolder:(NSString*)folder
{
    NSMutableArray *pendingLoaders =[[NSMutableArray alloc] init];
    NSArray *allKeys = [downloadTable allKeys];
    
    if (folder.length > 0)
    {
        NSString *folderPath = [MXMediaManager cacheFolderPath:folder];
        for (NSString* key in allKeys)
        {
            if ([key hasPrefix:folderPath])
            {
                [pendingLoaders addObject:[downloadTable valueForKey:key]];
                [downloadTable removeObjectForKey:key];
            }
        }
    }
    
    if (pendingLoaders.count)
    {
        for (MXMediaLoader* loader in pendingLoaders)
        {
            [loader cancel];
        }
    }
}

+ (void)cancelDownloads
{
    NSArray* allKeys = [downloadTable allKeys];
    
    for (NSString* key in allKeys)
    {
        [[downloadTable valueForKey:key] cancel];
        [downloadTable removeObjectForKey:key];
    }
}

#pragma mark - Media Uploader

+ (MXMediaLoader*)prepareUploaderWithMatrixSession:(MXSession*)mxSession
                                       initialRange:(CGFloat)initialRange
                                           andRange:(CGFloat)range
{
    if (mxSession)
    {
        // Create a media loader to upload data
        MXMediaLoader *mediaLoader = [[MXMediaLoader alloc] initForUploadWithMatrixSession:mxSession initialRange:initialRange andRange:range];
        // Report this loader
        if (!uploadTableById)
        {
            uploadTableById =  [[NSMutableDictionary alloc] init];
            
            // Need to listen to kMXMediaUploadDid* notifications to automatically release allocated upload ids
            if (0 == uploadTableById.count)
            {
                
                MXMediaManager *sharedManager = [MXMediaManager sharedManager];
                [[NSNotificationCenter defaultCenter] addObserver:sharedManager
                                                         selector:@selector(onMediaLoaderStateDidChange:)
                                                             name:kMXMediaLoaderStateDidChangeNotification
                                                           object:nil];
            }
        }
        [uploadTableById setValue:mediaLoader forKey:mediaLoader.uploadId];
        return mediaLoader;
    }
    return nil;
}

+ (MXMediaLoader*)existingUploaderWithId:(NSString*)uploadId
{
    if (uploadTableById && uploadId)
    {
        return [uploadTableById valueForKey:uploadId];
    }
    return nil;
}

- (void)onMediaLoaderStateDidChange:(NSNotification *)notif
{
    MXMediaLoader *loader = (MXMediaLoader*)notif.object;
    
    // Consider only the end of uploading.
    switch (loader.state) {
        case MXMediaLoaderStateUploadCompleted:
        case MXMediaLoaderStateUploadFailed:
        case MXMediaLoaderStateCancelled:
            [MXMediaManager removeUploaderWithId:loader.uploadId];
            // If there is no more upload in progress, stop observing upload notifications
            if (0 == uploadTableById.count)
            {
                [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXMediaLoaderStateDidChangeNotification object:nil];
            }
            break;
        default:
            break;
    }
}

+ (void)removeUploaderWithId:(NSString*)uploadId
{
    if (uploadTableById && uploadId)
    {
        [uploadTableById removeObjectForKey:uploadId];
    }
}

+ (void)cancelUploads
{
    NSArray* allKeys = [uploadTableById allKeys];
    
    for(NSString* key in allKeys)
    {
        [[uploadTableById valueForKey:key] cancel];
        [uploadTableById removeObjectForKey:key];
    }
}

#pragma mark - Cache Handling

+ (NSString*)cacheFolderPath:(NSString*)folder
{
    NSString* path = [MXMediaManager getCachePath];
    
    // update the path if the folder is provided
    if (folder.length > 0)
    {
        path = [[MXMediaManager getCachePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%lu", (unsigned long)folder.hash]];
    }
    
    // create the folder it does not exist
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
    }
    
    return path;
}

static NSMutableDictionary* fileBaseFromMimeType = nil;

+ (NSString*)filebase:(NSString*)mimeType
{
    // sanity checks
    if (!mimeType || !mimeType.length)
    {
        return @"";
    }
    
    NSString* fileBase;

    if (!fileBaseFromMimeType)
    {
        fileBaseFromMimeType = [[NSMutableDictionary alloc] init];
    }
    
    fileBase = fileBaseFromMimeType[mimeType];
    
    if (!fileBase)
    {
        fileBase = @"";
        
        if ([mimeType rangeOfString:@"/"].location != NSNotFound)
        {
            NSArray *components = [mimeType componentsSeparatedByString:@"/"];
            fileBase = [components objectAtIndex:0];
            if (fileBase.length > 3)
            {
                fileBase = [fileBase substringToIndex:3];
            }
        }
        
        [fileBaseFromMimeType setObject:fileBase forKey:mimeType];
    }
    
    return fileBase;
}

+ (NSString*)cachePathForMatrixContentURI:(NSString*)mxContentURI andType:(NSString *)mimeType inFolder:(NSString*)folder
{
    // Check whether the provided uri is valid.
    // Note: When an uploading is in progress, the upload id is used temporarily as the content url (nasty trick).
    // That is why we allow here to retrieve a cache file path from an upload identifier.
    if (![mxContentURI hasPrefix:kMXContentUriScheme] && ![mxContentURI hasPrefix:kMXMediaUploadIdPrefix])
    {
        NSLog(@"[MXMediaManager] cachePathForMatrixContentURI: invalid media content URI");
        return nil;
    }
    
    NSString* fileBase = @"";
    NSString *extension = @"";
    
    if (!folder.length)
    {
        folder = kMXMediaManagerDefaultCacheFolder;
    }
    
    if (mimeType.length)
    {
        extension = [MXTools fileExtensionFromContentType:mimeType];
        
        // use the mime type to extract a base filename
        fileBase = [MXMediaManager filebase:mimeType];
    }
    
    if (!extension.length && [folder isEqualToString:kMXMediaManagerAvatarThumbnailFolder])
    {
        // Consider the default image type for thumbnail folder
        extension = [MXTools fileExtensionFromContentType:@"image/jpeg"];
    }
    
    return [[MXMediaManager cacheFolderPath:folder] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%lu%@", fileBase, (unsigned long)mxContentURI.hash, extension]];
}

+ (NSString*)thumbnailCachePathForMatrixContentURI:(NSString*)mxContentURI
                                           andType:(NSString *)mimeType
                                          inFolder:(NSString*)folder
                                     toFitViewSize:(CGSize)viewSize
                                        withMethod:(MXThumbnailingMethod)thumbnailingMethod
{
    // Check whether the provided uri is valid.
    if (![mxContentURI hasPrefix:kMXContentUriScheme])
    {
        NSLog(@"[MXMediaManager] thumbnailCachePathForMatrixContentURI: invalid media content URI");
        return nil;
    }
    
    NSString* fileBase = @"";
    NSString *extension = @"";
    
    if (!folder.length)
    {
        folder = kMXMediaManagerDefaultCacheFolder;
    }
    
    if (mimeType.length)
    {
        extension = [MXTools fileExtensionFromContentType:mimeType];
        
        // use the mime type to extract a base filename
        fileBase = [MXMediaManager filebase:mimeType];
    }
    
    if (!extension.length && [folder isEqualToString:kMXMediaManagerAvatarThumbnailFolder])
    {
        // Consider the default image type for thumbnail folder
        extension = [MXTools fileExtensionFromContentType:@"image/jpeg"];
    }
    
    NSString *suffix = [NSString stringWithFormat:@"_w%tuh%tum%tu", (NSUInteger)viewSize.width, (NSUInteger)viewSize.height, thumbnailingMethod];
    
    return [[MXMediaManager cacheFolderPath:folder] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%lu%@%@", fileBase, (unsigned long)mxContentURI.hash, suffix, extension]];
}

+ (NSString*)temporaryCachePathInFolder:(NSString*)folder
                               withType:(NSString *)mimeType
{
    NSString* fileBase = @"";
    NSString *extension = @"";
    
    if (!folder.length)
    {
        folder = kMXMediaManagerDefaultCacheFolder;
    }
    
    if (mimeType.length)
    {
        extension = [MXTools fileExtensionFromContentType:mimeType];
        
        // use the mime type to extract a base filename
        fileBase = [MXMediaManager filebase:mimeType];
    }
    
    return [[MXMediaManager cacheFolderPath:folder] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@%@%@", kMXMediaManagerTmpCachePathPrefix, fileBase, [[NSProcessInfo processInfo] globallyUniqueString], extension]];
}

+ (void)reduceCacheSizeToInsert:(NSUInteger)sizeInBytes
{
    if (([MXMediaManager cacheSize] + sizeInBytes) > [MXMediaManager maxAllowedCacheSize])
    {
        
        NSString* thumbnailPath = [MXMediaManager cacheFolderPath:kMXMediaManagerAvatarThumbnailFolder];
        
        // add a 50 MB margin to reduce this method call
        NSUInteger maxSize = 0;
        
        // check if the cache cannot content the file
        if ([MXMediaManager maxAllowedCacheSize] < (sizeInBytes - 50 * 1024 * 1024))
        {
            // delete item as much as possible
            maxSize = 0;
        }
        else
        {
            maxSize = [MXMediaManager maxAllowedCacheSize] - sizeInBytes - 50 * 1024 * 1024;
        }
        
        NSArray* filesList = [MXTools listFiles:mediaCachePath timeSorted:YES largeFilesFirst:YES];
        
        // list the files sorted by timestamp
        for(NSString* filepath in filesList)
        {
            // do not release the contact thumbnails : they must be released when the contacts are deleted
            if (![filepath hasPrefix:thumbnailPath])
            {
                NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filepath error:nil];
                
                // sanity check
                if (fileAttributes)
                {
                    // delete the files
                    if ([[NSFileManager defaultManager] removeItemAtPath:filepath error:nil])
                    {
                        storageCacheSize -= fileAttributes.fileSize;
                        if (storageCacheSize < maxSize)
                        {
                            return;
                        }
                    }
                }
            }
        }
    }
}

+ (NSUInteger)cacheSize
{
    if (!mediaCachePath)
    {
        // compute the path
        mediaCachePath = [MXMediaManager getCachePath];
    }
    
    // assume that 0 means uninitialized
    if (storageCacheSize == 0)
    {
        storageCacheSize = (NSUInteger)[MXTools folderSize:mediaCachePath];
    }
    
    return storageCacheSize;
}

+ (NSUInteger)minCacheSize
{
    NSUInteger minSize = [MXMediaManager cacheSize];
    NSArray* filenamesList = [MXTools listFiles:mediaCachePath timeSorted:NO largeFilesFirst:YES];
    
    NSFileManager* defaultManager = [NSFileManager defaultManager];
    
    for(NSString* filename in filenamesList)
    {
        NSDictionary* attsDict = [defaultManager attributesOfItemAtPath:filename error:nil];
        
        if (attsDict)
        {
            if (attsDict.fileSize > 100 * 1024)
            {
                minSize -= attsDict.fileSize;
            }
        }
    }
    return minSize;
}

+ (NSInteger)currentMaxCacheSize
{
    NSInteger res = [[NSUserDefaults standardUserDefaults] integerForKey:@"maxMediaCacheSize"];
    if (res == 0)
    {
        // no default value, use the max allowed value
        res = [MXMediaManager maxAllowedCacheSize];
    }
    
    return res;
}

+ (void)setCurrentMaxCacheSize:(NSInteger)maxCacheSize
{
    if ((maxCacheSize == 0) || (maxCacheSize > [MXMediaManager maxAllowedCacheSize]))
    {
        maxCacheSize = [MXMediaManager maxAllowedCacheSize];
    }
    
    [[NSUserDefaults standardUserDefaults] setInteger:maxCacheSize forKey:@"maxMediaCacheSize"];
}

+ (NSInteger)maxAllowedCacheSize
{
    NSInteger res = [[NSUserDefaults standardUserDefaults] integerForKey:@"maxAllowedMediaCacheSize"];
    if (res == 0)
    {
        // no default value, assume that 1 GB is enough
        res = 1024 * 1024 * 1024;
    }
    
    return res;
}

+ (void)clearCache
{
    NSError *error = nil;
    
    if (!mediaCachePath)
    {
        // compute the path
        mediaCachePath = [MXMediaManager getCachePath];
    }
    
    [MXMediaManager cancelDownloads];
    [MXMediaManager cancelUploads];
    
    if (mediaCachePath)
    {
        NSLog(@"[MXMediaManager] Delete media cache directory");
        
        if (![[NSFileManager defaultManager] removeItemAtPath:mediaCachePath error:&error])
        {
            NSLog(@"[MXMediaManager] Failed to delete media cache dir: %@", error);
        }
    }
    else
    {
        NSLog(@"[MXMediaManager] Media cache does not exist");
    }
    
    mediaCachePath = nil;
    
    // force to recompute the cache size at next cacheSize call
    storageCacheSize = 0;
}

+ (NSString*)getCachePath
{
    NSString *cachePath = nil;
    
    if (!mediaCachePath)
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cacheRoot = [paths objectAtIndex:0];
        NSString *mediaCacheVersionString = [MXMediaManager getCacheVersionString];
        
        mediaCachePath = [cacheRoot stringByAppendingPathComponent:mediaDir];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:mediaCachePath])
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:mediaCachePath withIntermediateDirectories:NO attributes:nil error:nil];
            
            // Add the cache version file
            NSString *cacheVersionFile = [mediaCachePath stringByAppendingPathComponent:mediaCacheVersionString];
            [[NSFileManager defaultManager]createFileAtPath:cacheVersionFile contents:nil attributes:nil];
        }
        else
        {
            // Check the cache version
            NSString *cacheVersionFile = [mediaCachePath stringByAppendingPathComponent:mediaCacheVersionString];
            if (![[NSFileManager defaultManager] fileExistsAtPath:cacheVersionFile])
            {
                NSLog(@"[MXMediaManager] New media cache version detected");
                [MXMediaManager clearCache];
            }
        }
    }
    cachePath = mediaCachePath;
    
    return cachePath;
}

+ (NSString*)getCacheVersionString
{
    return [NSString stringWithFormat:@"v%tu.%tu", [MXSDKOptions sharedInstance].mediaCacheAppVersion, kMXMediaCacheSDKVersion];
}

@end
