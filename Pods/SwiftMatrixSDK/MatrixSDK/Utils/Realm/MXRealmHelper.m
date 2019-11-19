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

#import "MXRealmHelper.h"

#import <Realm/Realm.h>

static NSString* const kRealmFileExtension = @"realm";

@implementation MXRealmHelper

+ (NSString*)realmFileExtension
{
    return kRealmFileExtension;
}

+ (void)deleteRealmFilesForConfiguration:(RLMRealmConfiguration*)realmConfiguration
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *realmFileURL = realmConfiguration.fileURL;
    
    if (realmFileURL)
    {
        NSArray<NSURL *> *realmFileURLs = @[
                                            realmFileURL,
                                            [realmFileURL URLByAppendingPathExtension:@"lock"],
                                            [realmFileURL URLByAppendingPathExtension:@"note"],
                                            [realmFileURL URLByAppendingPathExtension:@"management"]
                                            ];
        for (NSURL *url in realmFileURLs)
        {
            NSError *error = nil;
            [fileManager removeItemAtURL:url error:&error];
            
            if (error)
            {
                NSLog(@"[MXRealmHelper] Fail to delete Realm file with URL %@ with error: %@", url, error);
            }
        }
    }
}

@end
