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

#import <Foundation/Foundation.h>

/**
 Call states.
 */
typedef enum : NSUInteger
{
    // The `MXBugReportRestClient` instance is ready to send a bug report
    MXBugReportStateReady,

    // Log files are being zipped
    MXBugReportStateProgressZipping,

    // Bug report data is being sent
    MXBugReportStateProgressUploading
} MXBugReportState;

/**
 `MXBugReportRestClient` allows to report bugs.
 
 Bug reports are sent to the bugreport API (https://github.com/matrix-org/rageshake).
 It purposefully does not use Matrix as bug reports may be made when Matrix is 
 not responsive (which may be the cause of the bug).
 */
@interface MXBugReportRestClient : NSObject

/**
 The state of the instance.
 */
@property (nonatomic, readonly) MXBugReportState state;

/**
 Create an instance based on an endpoint url.

 @param bugReportEndpoint the endpoint URL.
 @return a MXBugReportRestClient instance.
 */
- (instancetype)initWithBugReportEndpoint:(NSString *)bugReportEndpoint;

/**
 Send a bug report.
 
 Note that only one submission can be done at a time.
 
 @param text the bug description.
 @param sendLogs flag to indicate to attached log files or not.
 @param sendCrashLog flag to indicate to attached crash log or not.
 @param files a list of local files to send. Their extension must be "jpg", "png" or "txt".
 @param gitHubLabels labels to attach to the created GitHub issue.
 @param progress A block object called to indicate the progress in the step of
                 MXBugReportStateProgressZipping or MXBugReportStateProgressUploading.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (void)sendBugReport:(NSString*)text
             sendLogs:(BOOL)sendLogs
         sendCrashLog:(BOOL)sendCrashLog
            sendFiles:(NSArray<NSURL*>*)files
   attachGitHubLabels:(NSArray<NSString*>*)gitHubLabels
             progress:(void (^)(MXBugReportState state, NSProgress *progress))progress
              success:(void (^)(void))success
              failure:(void (^)(NSError *error))failure;

/**
 Interrupt any current operation.
 */
- (void)cancel;


#pragma mark - Information sent with each bug report

/**
 The app name.
 */
@property (nonatomic) NSString *appName;

/**
 The app version.
 */
@property (nonatomic) NSString *version;

/**
 The app build number.
 */
@property (nonatomic) NSString *build;

/**
 The app user agent.
 Default is "iOS" or "MacOS".
 */
@property (nonatomic) NSString *userAgent;

/**
 The device we are running.
 Default is UIDevice.model.
 */
@property (nonatomic) NSString *deviceModel;

/**
 The OS name and version used by the device.
 */
@property (nonatomic) NSString *deviceOS;

/**
 Additional custom information to send to the bug report API.
 */
@property (nonatomic) NSDictionary<NSString*, NSString*> *others;

@end
