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

#import "MXMediaManager.h"

#import "MXSession.h"
#import "MXHTTPOperation.h"
#import "MXTools.h"

#import "MXAllowedCertificates.h"
#import <AFNetworking/AFSecurityPolicy.h>

NSString *const kMXMediaLoaderStateDidChangeNotification = @"kMXMediaLoaderStateDidChangeNotification";

NSString *const kMXMediaLoaderProgressValueKey = @"kMXMediaLoaderProgressValueKey";
NSString *const kMXMediaLoaderCompletedBytesCountKey = @"kMXMediaLoaderCompletedBytesCountKey";
NSString *const kMXMediaLoaderTotalBytesCountKey = @"kMXMediaLoaderTotalBytesCountKey";
NSString *const kMXMediaLoaderCurrentDataRateKey = @"kMXMediaLoaderCurrentDataRateKey";

NSString *const kMXMediaLoaderFilePathKey = @"kMXMediaLoaderFilePathKey";
NSString *const kMXMediaLoaderErrorKey = @"kMXMediaLoaderErrorKey";

NSString *const kMXMediaUploadIdPrefix = @"upload-";

@implementation MXMediaLoader

@synthesize statisticsDict;

- (id)init
{
    if (self = [super init])
    {
        _state = MXMediaLoaderStateIdle;
    }
    return self;
}

- (void)setState:(MXMediaLoaderState)state
{
    _state = state;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXMediaLoaderStateDidChangeNotification
                                                        object:self
                                                      userInfo:nil];
}

- (void)cancel
{
    // Cancel potential connection
    if (downloadConnection)
    {
        NSLog(@"[MXMediaLoader] Media download has been cancelled (%@)", self.downloadMediaURL);
        if (onError){
            onError(nil);
        }
        
        // Reset blocks
        onSuccess = nil;
        onError = nil;
        [downloadConnection cancel];
        downloadConnection = nil;
        downloadData = nil;
    }
    else
    {
        if (operation && operation.operation
            && operation.operation.state != NSURLSessionTaskStateCanceling && operation.operation.state != NSURLSessionTaskStateCompleted)
        {
            NSLog(@"[MXMediaLoader] Media upload has been cancelled");
            [operation cancel];
            operation = nil;
        }
        
        // Reset blocks
        onSuccess = nil;
        onError = nil;
    }
    statisticsDict = nil;
    
    self.state = MXMediaLoaderStateCancelled;
}

- (void)dealloc
{
    [self cancel];
    
    mxSession = nil;
}

#pragma mark - Download

- (void)downloadMediaFromURL:(NSString *)url
              withIdentifier:(NSString *)downloadId
           andSaveAtFilePath:(NSString *)filePath
                     success:(blockMXMediaLoader_onSuccess)success
                     failure:(blockMXMediaLoader_onError)failure
{
    [self downloadMediaFromURL:url withData:nil identifier:downloadId andSaveAtFilePath:filePath success:success failure:failure];
}

- (void)downloadMediaFromURL:(NSString *)url
                    withData:(NSDictionary *)data
                  identifier:(NSString *)downloadId
           andSaveAtFilePath:(NSString *)filePath
                     success:(blockMXMediaLoader_onSuccess)success
                     failure:(blockMXMediaLoader_onError)failure
{
    // Report provided params
    _downloadMediaURL = url;
    _downloadId = downloadId;
    _downloadOutputFilePath = filePath;
    onSuccess = success;
    onError = failure;
    
    downloadStartTime = statsStartTime = CFAbsoluteTimeGetCurrent();
    lastProgressEventTimeStamp = -1;
    
    // Start downloading
    NSURL *nsURL = [NSURL URLWithString:url];
    downloadData = [[NSMutableData alloc] init];
    
    if (data)
    {
        // Use an HTTP POST method to send this data as JSON object.
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:nsURL];
        request.HTTPMethod = @"POST";
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
        
        downloadConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    }
    else
    {
        // Use a GET method by default
        downloadConnection = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:nsURL] delegate:self];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    expectedSize = response.expectedContentLength;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSLog(@"[MXMediaLoader] Failed to download media (%@): %@", self.downloadMediaURL, error);
    // send the latest known download info
    [self progressCheckTimeout:nil];
    statisticsDict = nil;
    _error = error;
    if (onError)
    {
        onError (error);
    }
    
    downloadData = nil;
    downloadConnection = nil;
    
    self.state = MXMediaLoaderStateDownloadFailed;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // Append data
    [downloadData appendData:data];
    
    if (expectedSize > 0)
    {
        float progressValue = ((float)downloadData.length) / ((float)expectedSize);
        if (progressValue > 1)
        {
            // Should never happen
            progressValue = 1.0;
        }
        
        CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
        CGFloat meanRate = downloadData.length / (currentTime - downloadStartTime);
        
        // build the user info dictionary
        NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
        [dict setValue:[NSNumber numberWithFloat:progressValue] forKey:kMXMediaLoaderProgressValueKey];
        [dict setValue:[NSNumber numberWithUnsignedInteger:downloadData.length] forKey:kMXMediaLoaderCompletedBytesCountKey];
        [dict setValue:[NSNumber numberWithLongLong:expectedSize] forKey:kMXMediaLoaderTotalBytesCountKey];
        [dict setValue:[NSNumber numberWithFloat:meanRate] forKey:kMXMediaLoaderCurrentDataRateKey];
        
        statisticsDict = dict;
        
        // after 0.1s, resend the progress info
        // the download can be stuck
        [progressCheckTimer invalidate];
        progressCheckTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(progressCheckTimeout:) userInfo:self repeats:NO];
        
        // trigger the event only each 0.1s to avoid send to many events
        if ((lastProgressEventTimeStamp == -1) || ((currentTime - lastProgressEventTimeStamp) > 0.1))
        {
            lastProgressEventTimeStamp = currentTime;
            self.state = MXMediaLoaderStateDownloadInProgress;
        }
    }
}

- (IBAction)progressCheckTimeout:(id)sender
{
    // Trigger a state change notification to notify about the progress update.
    self.state = MXMediaLoaderStateDownloadInProgress;
    
    [progressCheckTimer invalidate];
    progressCheckTimer = nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // send the latest known upload info
    [self progressCheckTimeout:nil];
    statisticsDict = nil;
    _error = nil;
    
    if (downloadData.length)
    {
        // Cache the downloaded data
        if ([MXMediaManager writeMediaData:downloadData toFilePath:_downloadOutputFilePath])
        {
            // Call registered block
            if (onSuccess)
            {
                onSuccess(_downloadOutputFilePath);
            }
            
            self.state = MXMediaLoaderStateDownloadCompleted;
        }
        else
        {
            NSLog(@"[MXMediaLoader] Failed to write file: %@", self.downloadMediaURL);
            if (onError){
                onError(nil);
            }
            
            self.state = MXMediaLoaderStateDownloadFailed;
        }
    }
    else
    {
        NSLog(@"[MXMediaLoader] Failed to download media: %@", self.downloadMediaURL);
        if (onError){
            onError(nil);
        }
        
        self.state = MXMediaLoaderStateDownloadFailed;
    }
    
    downloadData = nil;
    downloadConnection = nil;
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    NSURLProtectionSpace *protectionSpace = [challenge protectionSpace];
    if ([protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
    {
        SecTrustRef serverTrust = [protectionSpace serverTrust];
        
        // Check first whether there are some pinned certificates (certificate included in the bundle).
        NSSet <NSData *> *certificates = [AFSecurityPolicy certificatesInBundle:[NSBundle mainBundle]];
        if (certificates && certificates.count > 0)
        {
            NSMutableArray *pinnedCertificates = [NSMutableArray array];
            for (NSData *certificateData in certificates)
            {
                [pinnedCertificates addObject:(__bridge_transfer id)SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certificateData)];
            }
            // Only use these certificates to pin against, and do not trust the built-in anchor certificates.
            SecTrustSetAnchorCertificates(serverTrust, (__bridge CFArrayRef)pinnedCertificates);
        }
        else
        {
            // Check whether some certificates have been trusted by the user (self-signed certificates support).
            certificates = [MXAllowedCertificates sharedInstance].certificates;
            if (certificates.count)
            {
                NSMutableArray *allowedCertificates = [NSMutableArray array];
                for (NSData *certificateData in certificates)
                {
                    [allowedCertificates addObject:(__bridge_transfer id)SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certificateData)];
                }
                // Add all the allowed certificates to the chain of trust
                SecTrustSetAnchorCertificates(serverTrust, (__bridge CFArrayRef)allowedCertificates);
                // Reenable trusting the built-in anchor certificates in addition to those passed in via the SecTrustSetAnchorCertificates API.
                SecTrustSetAnchorCertificatesOnly(serverTrust, false);
            }
        }

        // Re-evaluate the trust policy
        SecTrustResultType secresult = kSecTrustResultInvalid;
        if (SecTrustEvaluate(serverTrust, &secresult) != errSecSuccess)
        {
            // Trust evaluation failed
            [connection cancel];

            // Generate same kind of error as AFNetworking
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorCancelled userInfo:nil];
            [self connection:connection didFailWithError:error];
        }
        else
        {
            switch (secresult)
            {
                case kSecTrustResultUnspecified:    // The OS trusts this certificate implicitly.
                case kSecTrustResultProceed:        // The user explicitly told the OS to trust it.
                {
                    NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
                    [challenge.sender useCredential:credential forAuthenticationChallenge:challenge];
                    break;
                }

                default:
                {
                    // Consider here the leaf certificate (the one at index 0).
                    SecCertificateRef certif = SecTrustGetCertificateAtIndex(serverTrust, 0);

                    NSData *certificate = (__bridge NSData*)SecCertificateCopyData(certif);

                    // Was it already trusted by the user ?
                    if ([[MXAllowedCertificates sharedInstance] isCertificateAllowed:certificate])
                    {
                        NSURLCredential *credential = [NSURLCredential credentialForTrust:protectionSpace.serverTrust];
                        [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
                    }
                    else
                    {
                        NSLog(@"[MXMediaLoader] Certificate check failed for %@", protectionSpace);
                        [connection cancel];

                        // Generate same kind of error as AFNetworking
                        NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorCancelled userInfo:nil];
                        [self connection:connection didFailWithError:error];
                    }
                    break;
                }
            }
        }
    }
    else if ([protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodClientCertificate])
    {
        [challenge.sender performDefaultHandlingForAuthenticationChallenge:challenge];
    }
    else
    {
        [challenge.sender cancelAuthenticationChallenge:challenge];
    }
}

#pragma mark - Upload

- (id)initForUploadWithMatrixSession:(MXSession*)matrixSession initialRange:(CGFloat)initialRange andRange:(CGFloat)range
{
    if (self = [super init])
    {
        // Create a unique upload Id
        _uploadId = [NSString stringWithFormat:@"%@%@", kMXMediaUploadIdPrefix, [[NSProcessInfo processInfo] globallyUniqueString]];
        
        mxSession = matrixSession;
        _uploadInitialRange = initialRange;
        _uploadRange = range;
    }
    return self;
}

- (void)uploadData:(NSData *)data filename:(NSString*)filename mimeType:(NSString *)mimeType success:(blockMXMediaLoader_onSuccess)success failure:(blockMXMediaLoader_onError)failure
{
    statsStartTime = CFAbsoluteTimeGetCurrent();
    lastTotalBytesWritten = 0;

    MXWeakify(self);
    operation = [mxSession.matrixRestClient uploadContent:data
                                                 filename:filename
                                                 mimeType:mimeType
                                                  timeout:30
                                                  success:^(NSString *url) {
                                                      MXStrongifyAndReturnIfNil(self);

                                                      if (success)
                                                      {
                                                          success(url);
                                                      }
                                                      
                                                      self.state = MXMediaLoaderStateUploadCompleted;
                                                      
                                                  } failure:^(NSError *error) {
                                                      MXStrongifyAndReturnIfNil(self);
                                                      self.error = error;
                                                      
                                                      if (failure)
                                                      {
                                                          failure (error);
                                                      }
                                                      
                                                      self.state = MXMediaLoaderStateUploadFailed;
                                                      
                                                  } uploadProgress:^(NSProgress *uploadProgress) {
                                                      [self updateUploadProgress:uploadProgress];
                                                  }];
}

- (void)updateUploadProgress:(NSProgress*)uploadProgress
{
    int64_t totalBytesWritten = uploadProgress.completedUnitCount;
    int64_t totalBytesExpectedToWrite = uploadProgress.totalUnitCount;

    // Compute the bytes written since last time
    int64_t bytesWritten = totalBytesWritten - lastTotalBytesWritten;
    lastTotalBytesWritten = totalBytesWritten;

    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    if (!statisticsDict)
    {
        statisticsDict = [[NSMutableDictionary alloc] init];
    }
    
    CGFloat progressValue = self.uploadInitialRange + (((float)totalBytesWritten) /  ((float)totalBytesExpectedToWrite) * self.uploadRange);
    [statisticsDict setValue:[NSNumber numberWithFloat:progressValue] forKey:kMXMediaLoaderProgressValueKey];
    
    CGFloat dataRate = 0;
    if (currentTime != statsStartTime)
    {
        dataRate = bytesWritten / (currentTime - statsStartTime);
    }
    else
    {
        dataRate = bytesWritten / 0.001;
    }
    statsStartTime = currentTime;
    
    [statisticsDict setValue:[NSNumber numberWithLongLong:totalBytesWritten] forKey:kMXMediaLoaderCompletedBytesCountKey];
    [statisticsDict setValue:[NSNumber numberWithLongLong:totalBytesExpectedToWrite] forKey:kMXMediaLoaderTotalBytesCountKey];
    [statisticsDict setValue:[NSNumber numberWithFloat:dataRate] forKey:kMXMediaLoaderCurrentDataRateKey];
    
    self.state = MXMediaLoaderStateUploadInProgress;
}

@end
