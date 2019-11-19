/*
 Copyright 2014 OpenMarket Ltd

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

#import "MXReceiptData.h"

@implementation MXReceiptData

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [self init];
    if (self)
    {
        _eventId = [aDecoder decodeObjectForKey:@"eventId"];
        _userId = [aDecoder decodeObjectForKey:@"userId"];
        _ts = (uint64_t)[aDecoder decodeInt64ForKey:@"ts"];
    }
    return self;
}

-(void)encodeWithCoder:(NSCoder *)aCoder
{
    // All properties are mandatory except eventStreamToken
    [aCoder encodeObject:_eventId forKey:@"eventId"];
    [aCoder encodeObject:_userId forKey:@"userId"];
    [aCoder encodeInt64:(int64_t)_ts forKey:@"ts"];
    
    // TODO need some new fields
}

- (id)copyWithZone:(NSZone *)zone
{
    MXReceiptData *metaData = [[MXReceiptData allocWithZone:zone] init];

    metaData->_ts = _ts;
    metaData->_eventId = [_eventId copyWithZone:zone];
    metaData->_userId = [_userId copyWithZone:zone];

    return metaData;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MXReceiptData: %p> userId: %@ - eventId: %@ - ts: %@", self, _userId, _eventId, @(_ts)];
}

@end
