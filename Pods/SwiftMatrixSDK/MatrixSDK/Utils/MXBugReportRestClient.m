/*
 Copyright 2017 Vector Creations Ltd

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

#import "MXBugReportRestClient.h"

#import "MXLogger.h"
#import "MatrixSDK.h"

#import <AFNetworking/AFNetworking.h>
#import <GZIP/GZIP.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#elif TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#include <sys/sysctl.h>
#endif

#ifdef MX_CRYPTO
#import <OLMKit/OLMKit.h>
#endif

#if __has_include(<MatrixKit/MatrixKit.h>)
#import <MatrixKit/MatrixKit.h>
#endif

@interface MXBugReportRestClient ()
{
    // The bug report API server URL.
    NSString *bugReportEndpoint;

    // Use AFNetworking as HTTP client.
    AFURLSessionManager *manager;

    // The queue where log files are zipped.
    dispatch_queue_t dispatchQueue;

    // The temporary zipped log files.
    NSMutableArray<NSURL*> *logZipFiles;

    // The zip file within `logZipFiles` that is used for the crash log.
    NSURL *crashLogZipFile;
}

@end

@implementation MXBugReportRestClient

- (instancetype)initWithBugReportEndpoint:(NSString *)theBugReportEndpoint
{
    self = [super init];
    if (self)
    {
        bugReportEndpoint = theBugReportEndpoint;

        manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];

        dispatchQueue = dispatch_queue_create("MXBugReportRestClient", DISPATCH_QUEUE_SERIAL);

        logZipFiles = [NSMutableArray array];

        _state = MXBugReportStateReady;

#if TARGET_OS_IPHONE
        _userAgent = @"iOS";
        _deviceModel = [[UIDevice currentDevice] model];
        _deviceOS = [NSString stringWithFormat:@"%@ %@", [[UIDevice currentDevice] systemName], [[UIDevice currentDevice] systemVersion]];
#elif TARGET_OS_OSX
        _userAgent = @"MacOS";
        _deviceOS = [NSString stringWithFormat:@"Mac OS X %@", [[NSProcessInfo processInfo] operatingSystemVersionString]];

        size_t len = 0;
        sysctlbyname("hw.model", NULL, &len, NULL, 0);
        if (len)
        {
            char *model = malloc(len*sizeof(char));
            sysctlbyname("hw.model", model, &len, NULL, 0);
            _deviceModel = [NSString stringWithUTF8String:model];
            free(model);
        }
#endif

    }

    return self;
}

- (void)sendBugReport:(NSString *)text sendLogs:(BOOL)sendLogs sendCrashLog:(BOOL)sendCrashLog sendFiles:(NSArray<NSURL*>*)files attachGitHubLabels:(NSArray<NSString*>*)gitHubLabels progress:(void (^)(MXBugReportState, NSProgress *))progress success:(void (^)(void))success failure:(void (^)(NSError *))failure
{
    if (_state != MXBugReportStateReady)
    {
        NSLog(@"[MXBugReport] sendBugReport failed. There is already a submission in progress. state: %@", @(_state));

        if (failure)
        {
            failure(nil);
        }
        return;
    }

    if (sendLogs || sendCrashLog)
    {
        // Zip log files into temporary files
        [self zipFiles:sendLogs crashLog:sendCrashLog progress:progress complete:^{
            [self sendBugReport:text sendFiles:files attachGitHubLabels:gitHubLabels progress:progress success:success failure:failure];
        }];
    }
    else
    {
        [self sendBugReport:text sendFiles:files attachGitHubLabels:gitHubLabels progress:progress success:success failure:failure];
    }
}

-(void)sendBugReport:(NSString *)text sendFiles:(NSArray<NSURL*>*)files attachGitHubLabels:(NSArray<NSString*>*)gitHubLabels progress:(void (^)(MXBugReportState, NSProgress *))progress success:(void (^)(void))success failure:(void (^)(NSError *))failure
{
    // The bugreport api needs at least app and version to render well
    NSParameterAssert(_appName && _version);

    _state = MXBugReportStateProgressUploading;

    NSString *apiPath = [NSString stringWithFormat:@"%@/submit", bugReportEndpoint];

    NSDate *startDate = [NSDate date];

    if (progress)
    {
        // Inform about t0 of the upload
        NSProgress *progressT0 = [NSProgress progressWithTotalUnitCount:1];
        progress(_state, progressT0);
    }

    // Populate multipart form data
    NSError *error;
    MXWeakify(self);
    NSMutableURLRequest *request = [[AFHTTPRequestSerializer serializer] multipartFormRequestWithMethod:@"POST" URLString:apiPath parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        MXStrongifyAndReturnIfNil(self);

        // Fill params defined in https://github.com/matrix-org/rageshake#post-apisubmit
        if (text)
        {
            [formData appendPartWithFormData:[text dataUsingEncoding:NSUTF8StringEncoding] name:@"text"];
        }
        if (self.userAgent)
        {
            [formData appendPartWithFormData:[self.userAgent dataUsingEncoding:NSUTF8StringEncoding] name:@"user_agent"];
        }
        if (self.appName)
        {
            [formData appendPartWithFormData:[self.appName dataUsingEncoding:NSUTF8StringEncoding] name:@"app"];
        }
        if (self.version)
        {
            [formData appendPartWithFormData:[self.version dataUsingEncoding:NSUTF8StringEncoding] name:@"version"];
        }

        // Add each zipped log file
        for (NSURL *logZipFile in self->logZipFiles)
        {
            [formData appendPartWithFileURL:logZipFile
                                       name:@"compressed-log"
                                   fileName:logZipFile.absoluteString.lastPathComponent
                                   mimeType:@"application/octet-stream"
                                      error:nil];
        }

        // Add additional files
        for (NSURL *fileURL in files)
        {
            [formData appendPartWithFileURL:fileURL
                                       name:@"file"
                                   fileName:fileURL.absoluteString.lastPathComponent
                                   mimeType:@"application/octet-stream"
                                      error:nil];
        }

        // Attach GitHub labels
        for (NSString *label in gitHubLabels)
        {
            [formData appendPartWithFormData:[label dataUsingEncoding:NSUTF8StringEncoding] name:@"label"];
        }

        // Add iOS specific params
        if (self.build)
        {
            [formData appendPartWithFormData:[self.build dataUsingEncoding:NSUTF8StringEncoding] name:@"build"];
        }

#if __has_include(<MatrixKit/MatrixKit.h>)
        [formData appendPartWithFormData:[MatrixKitVersion dataUsingEncoding:NSUTF8StringEncoding] name:@"matrix_kit_version"];
#endif

        [formData appendPartWithFormData:[MatrixSDKVersion dataUsingEncoding:NSUTF8StringEncoding] name:@"matrix_sdk_version"];

#ifdef MX_CRYPTO
        [formData appendPartWithFormData:[[OLMKit versionString] dataUsingEncoding:NSUTF8StringEncoding] name:@"olm_kit_version"];
#endif

        if (self.deviceModel)
        {
            [formData appendPartWithFormData:[self.deviceModel dataUsingEncoding:NSUTF8StringEncoding] name:@"device"];
        }
        if (self.deviceOS)
        {
            [formData appendPartWithFormData:[self.deviceOS dataUsingEncoding:NSUTF8StringEncoding] name:@"os"];
        }

        // Additional custom data
        for (NSString *key in self.others)
        {
            [formData appendPartWithFormData:[self.others[key] dataUsingEncoding:NSUTF8StringEncoding] name:key];
        }

    } error:&error];

    if (error)
    {
        NSLog(@"[MXBugReport] sendBugReport: multipartFormRequestWithMethod failed. Error: %@", error);

        _state = MXBugReportStateReady;

        if (failure)
        {
            failure(error);
        }
        return;
    }

    // Launch the request
    NSURLSessionUploadTask *uploadTask = [manager
                                          uploadTaskWithStreamedRequest:request
                                          progress:^(NSProgress * _Nonnull uploadProgress) {
                                              MXStrongifyAndReturnIfNil(self);

                                              NSLog(@"[MXBugReport] sendBugReport: uploadProgress: %@", @(uploadProgress.fractionCompleted));

                                              if (progress)
                                              {
                                                  // Move to the main queue
                                                  MXWeakify(self);
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                      MXStrongifyAndReturnIfNil(self);

                                                      progress(self.state, uploadProgress);
                                                  });
                                              }
                                          }
                                          completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                              MXStrongifyAndReturnIfNil(self);

                                              [self deleteZipZiles];

                                              self->_state = MXBugReportStateReady;

                                              if (error)
                                              {
                                                  NSLog(@"[MXBugReport] sendBugReport: report failed. Error: %@", error);

                                                  if (failure)
                                                  {
                                                      failure(error);
                                                  }
                                              }
                                              else
                                              {
                                                  NSLog(@"[MXBugReport] sendBugReport: report done in %.3fms", [[NSDate date] timeIntervalSinceDate:startDate] * 1000);

                                                  if (success)
                                                  {
                                                      success();
                                                  }
                                              }
                                          }];

    [uploadTask resume];
}

- (void)cancel
{
    [manager invalidateSessionCancelingTasks:YES resetSession:NO];

    _state = MXBugReportStateReady;

    [self deleteZipZiles];
}


#pragma mark - Private methods
- (void)zipFiles:(BOOL)logs crashLog:(BOOL)crashLog progress:(void (^)(MXBugReportState, NSProgress *))progress complete:(void (^)(void))complete
{
    // Put all files to send in the same array
    NSMutableArray *logFiles = [NSMutableArray array];

    NSString *crashLogFile = [MXLogger crashLog];
    if (crashLog && crashLogFile)
    {
        [logFiles addObject:crashLogFile];
    }
    if (logs)
    {
        [logFiles addObjectsFromArray:[MXLogger logFiles]];
    }

    if (logFiles.count)
    {
        _state = MXBugReportStateProgressZipping;

        NSProgress *zipProgress = [NSProgress progressWithTotalUnitCount:logFiles.count];
        progress(_state, zipProgress);

        MXWeakify(self);
        dispatch_async(dispatchQueue, ^{
            MXStrongifyAndReturnIfNil(self);

            NSDate *startDate = [NSDate date];
            NSUInteger size = 0, zipSize = 0;

            for (NSString *logFile in logFiles)
            {
                // Use a temporary file for the export
                NSURL *logZipFile = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:logFile.lastPathComponent]];

                [[NSFileManager defaultManager] removeItemAtURL:logZipFile error:nil];

                NSData *logData = [NSData dataWithContentsOfFile:logFile];
                NSData *logZipData = [logData gzippedData];

                size += logData.length;
                zipSize += logZipData.length;

                if ([logZipData writeToURL:logZipFile atomically:YES])
                {
                    [self->logZipFiles addObject:logZipFile];

                    if ([logFile isEqualToString:crashLogFile])
                    {
                        // Tag the crash log. It
                        self->crashLogZipFile = logZipFile;
                    }
                }
                else
                {
                    NSLog(@"[MXBugReport] zipLogFiles: Failed to zip %@", logFile);
                }

                if (progress)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{

                        zipProgress.completedUnitCount++;
                        progress(self.state, zipProgress);
                    });
                }
            }

            NSLog(@"[MXBugReport] zipLogFiles: Zipped %tu logs (%@ to %@) in %.3fms", logFiles.count,
                  [NSByteCountFormatter stringFromByteCount:size countStyle:NSByteCountFormatterCountStyleFile],
                  [NSByteCountFormatter stringFromByteCount:zipSize countStyle:NSByteCountFormatterCountStyleFile],
                  [[NSDate date] timeIntervalSinceDate:startDate] * 1000);

            dispatch_async(dispatch_get_main_queue(), ^{
                complete();
            });
        });
    }
    else
    {
        complete();
    }
}

- (void)deleteZipZiles
{
    MXWeakify(self);
    dispatch_async(dispatchQueue, ^{
        MXStrongifyAndReturnIfNil(self);

        for (NSURL *logZipFile in self->logZipFiles)
        {
            [[NSFileManager defaultManager] removeItemAtURL:logZipFile error:nil];
        }

        [self->logZipFiles removeAllObjects];
    });
}

@end
