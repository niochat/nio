/*
 Copyright 2016 OpenMarket Ltd
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
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#elif TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#endif

@class MXSession;
@class MXHTTPOperation;

/**
 `MXMediaLoaderState` represents the states in the life cycle of a MXMediaLoader instance.
 */
typedef enum : NSUInteger
{
    /**
     The loader has just been created.
     */
    MXMediaLoaderStateIdle,
    
    /**
     The loader has been instantiated as a downloader, and the download is in progress.
     The download statistics are available in the property `statisticsDict`.
     */
    MXMediaLoaderStateDownloadInProgress,
    
    /**
     The loader has been instantiated as a downloader, and the download is completed.
     The downloaded data are available at the output file path: `downloadOutputFilePath`.
     */
    MXMediaLoaderStateDownloadCompleted,
    
    /**
     The loader has been instantiated as downloader, and the download failed.
     The error is available in the property `error`.
     */
    MXMediaLoaderStateDownloadFailed,
    
    /**
     The loader has been instantiated as a uploader, and the upload is in progress.
     The statistics are available in the property `statisticsDict`.
     */
    MXMediaLoaderStateUploadInProgress,
    
    /**
     The loader has been instantiated as a uploader, and the upload is completed.
     */
    MXMediaLoaderStateUploadCompleted,
    
    /**
     The loader has been instantiated as uploader, and the upload failed.
     The error is available in the property `error`.
     */
    MXMediaLoaderStateUploadFailed,
    
    /**
     The current operation (downloading or uploading) has been cancelled.
     */
    MXMediaLoaderStateCancelled
    
} MXMediaLoaderState;

/**
 Posted when the state of the MXMediaLoader changes.
 The notification object is the loader itself.
 */
FOUNDATION_EXPORT NSString *const kMXMediaLoaderStateDidChangeNotification;

/**
 Notifications `userInfo` keys
 */
extern NSString *const kMXMediaLoaderProgressValueKey;
extern NSString *const kMXMediaLoaderCompletedBytesCountKey;
extern NSString *const kMXMediaLoaderTotalBytesCountKey;
extern NSString *const kMXMediaLoaderCurrentDataRateKey;
extern NSString *const kMXMediaLoaderFilePathKey;
extern NSString *const kMXMediaLoaderErrorKey;

/**
 The callback blocks
 */
typedef void (^blockMXMediaLoader_onSuccess) (NSString *url); // url is the output file path for successful download, or a remote url for upload.
typedef void (^blockMXMediaLoader_onError) (NSError *error);

/**
 The prefix of upload identifier
 */
extern NSString *const kMXMediaUploadIdPrefix;

/**
 `MXMediaLoader` defines a class to download/upload media. It provides progress information during the operation.
 */
@interface MXMediaLoader : NSObject <NSURLConnectionDataDelegate, NSURLConnectionDelegate>
{    
    blockMXMediaLoader_onSuccess onSuccess;
    blockMXMediaLoader_onError onError;
    
    // Media download
    long long expectedSize;
    NSMutableData *downloadData;
    NSURLConnection *downloadConnection;
    
    // Media upload
    MXSession* mxSession;
    MXHTTPOperation* operation;
    
    // Statistic info (bitrate, remaining time...)
    CFAbsoluteTime statsStartTime;
    CFAbsoluteTime downloadStartTime;
    CFAbsoluteTime lastProgressEventTimeStamp;
    int64_t lastTotalBytesWritten;
    NSTimer* progressCheckTimer;
}

/**
 The current state of the loader.
 */
@property (nonatomic, readonly) MXMediaLoaderState state;

/**
 Statistics on the operation in progress.
 - kMXMediaLoaderProgressValueKey: progress value in [0, 1] range (NSNumber object) [In case of upload, the properties
 `uploadInitialRange` and `uploadRange` are taken into account in this progress value].
 - kMXMediaLoaderCompletedBytesCountKey: the number of bytes that have already been completed by the current job (NSNumber object).
 - kMXMediaLoaderTotalBytesCountKey: the total number of bytes tracked for the current job (NSNumber object).
 - kMXMediaLoaderCurrentDataRateKey: The observed data rate in Bytes/s (NSNumber object).
 */
@property (strong, readonly) NSMutableDictionary* statisticsDict;

/**
 The potential error observed by the loader.
 Default is nil.
 */
@property (strong) NSError *error;

/**
 Download id defined when a media loader is instantiated as a downloader.
 Default is nil.
 */
@property (strong, readonly) NSString *downloadId;

/**
 The downloaded media url defined when a media loader is instantiated as a downloader.
 Default is nil.
 */
@property (strong, readonly) NSString *downloadMediaURL;

/**
 The targeted output file path defined when a media loader is instantiated as a downloader.
 Default is nil.
 */
@property (strong, readonly) NSString *downloadOutputFilePath;

/**
 Upload id defined when a media loader is instantiated as uploader.
 Default is nil.
 */
@property (strong, readonly) NSString *uploadId;

@property (readonly) CGFloat uploadInitialRange;
@property (readonly) CGFloat uploadRange;

/**
 Cancel the operation.
 */
- (void)cancel;

/**
 Download data from the provided URL.
 
 @param url remote media url.
 @param downloadId the download identifier.
 @param filePath output file in which downloaded media must be saved.
 @param success a block called when the operation succeeds.
 @param failure a block called when the operation fails.
 */
- (void)downloadMediaFromURL:(NSString *)url
              withIdentifier:(NSString *)downloadId
           andSaveAtFilePath:(NSString *)filePath
                     success:(blockMXMediaLoader_onSuccess)success
                     failure:(blockMXMediaLoader_onError)failure;

/**
 Download data from the provided URL with optionally a dictionary of data to post.
 
 @param url remote media url.
 @param data (optional) a dictionary of data sent as a JSON object in the message body.
 @param downloadId the download identifier.
 @param filePath output file in which downloaded media must be saved.
 @param success a block called when the operation succeeds.
 @param failure a block called when the operation fails.
 */
- (void)downloadMediaFromURL:(NSString *)url
                    withData:(NSDictionary *)data
                  identifier:(NSString *)downloadId
           andSaveAtFilePath:(NSString *)filePath
                     success:(blockMXMediaLoader_onSuccess)success
                     failure:(blockMXMediaLoader_onError)failure;

/**
 Initialise a media loader to upload data to a matrix content repository.
 Note: An upload could be a subpart of a global upload. For example, upload a video can be split in two parts :
 1 - upload the thumbnail -> initialRange = 0, range = 0.1 : assume that the thumbnail upload is 10% of the upload process
 2 - upload the media -> initialRange = 0.1, range = 0.9 : the media upload is 90% of the global upload
 
 @param mxSession the matrix session used to upload media.
 @param anInitialRange the global upload progress already did done before this current upload.
 @param aRange the range value of this upload in the global scope.
 @return the newly created instance.
 */
- (id)initForUploadWithMatrixSession:(MXSession*)mxSession initialRange:(CGFloat)anInitialRange andRange:(CGFloat)aRange;

/**
 Upload data.
 
 @param data data to upload.
 @param filename optional filename
 @param mimeType media mimetype.
 @param success a block called when the operation succeeds.
 @param failure a block called when the operation fails.
 */
- (void)uploadData:(NSData *)data
          filename:(NSString*)filename
          mimeType:(NSString *)mimeType
           success:(blockMXMediaLoader_onSuccess)success
           failure:(blockMXMediaLoader_onError)failure;

@end
