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

#import "MXMediaScan.h"

#import "MXAntivirusScanStatusFormatter.h"

@implementation MXMediaScan

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:[MXMediaScan class]])
    {
        return NO;
    }
    
    return [self isEqualToMediaScan:(MXMediaScan *)object];
}

- (BOOL)isEqualToMediaScan:(MXMediaScan*)mediaScan
{
    return [_url isEqualToString:mediaScan.url]
        && _antivirusScanStatus == mediaScan.antivirusScanStatus
        && (_antivirusScanInfo == mediaScan.antivirusScanInfo || [_antivirusScanInfo isEqualToString:mediaScan.antivirusScanInfo])
        && (_antivirusScanDate == mediaScan.antivirusScanDate || [_antivirusScanDate isEqualToDate:mediaScan.antivirusScanDate]);
    ;
}

- (NSUInteger)hash
{
    return [self.url hash];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"url: %@\nantivirus status: %@\nantivirus scan info: %@\nantivirus scan date: %@\n",
            self.url,
            [MXAntivirusScanStatusFormatter stringFromAntivirusScanStatus:self.antivirusScanStatus],
            self.antivirusScanInfo,
            self.antivirusScanDate
            ];
}

@end
