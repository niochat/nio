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

#import "MXEventScan.h"

#import "MXMediaScan.h"
#import "MXAntivirusScanStatusFormatter.h"

@implementation MXEventScan

#pragma mark - NSObject override

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:[MXEventScan class]])
    {
        return NO;
    }
    
    return [self isEqualToEventScan:(MXEventScan *)object];
}

- (NSUInteger)hash
{
    return [self.eventId hash] ^ [self.mediaScans hash];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"eventId: %@\nantivirus status: %@\nantivirus scan date: %@\nMedia scans: %@",
            self.eventId,
            [MXAntivirusScanStatusFormatter stringFromAntivirusScanStatus:self.antivirusScanStatus],
            self.antivirusScanDate,
            self.mediaScans
            ];
}

#pragma mark - Private

- (BOOL)isEqualToEventScan:(MXEventScan*)eventScan
{
    return [_eventId isEqualToString:eventScan.eventId]
    && _antivirusScanStatus == eventScan.antivirusScanStatus
    && (_mediaScans == eventScan.mediaScans || [_mediaScans isEqualToArray:eventScan.mediaScans])
    ;
}

@end
