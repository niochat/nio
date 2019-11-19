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

#import <Foundation/Foundation.h>

/**
 `MXFilterObject` is the base class for representating filters which may be used during
 Matrix requests.
 The specification of these filters can be found at https://matrix.org/docs/spec/client_server/r0.3.0.html#filtering.
 */
@interface MXFilterObject : NSObject
{
    @protected
    NSMutableDictionary<NSString *, id> *dictionary;
}

/**
 The JSON object representating the filter.
 */
@property (nonatomic, readonly) NSDictionary<NSString *, id> *dictionary;

/**
 The JSON string representating the filter.
 */
@property (nonatomic, readonly) NSString *jsonString;

/**
 Create a filter from a dictionary.

 This contructor allows to use filter fields that may not be yet in the Matrix
 specification.
 The `[MXFilterObject init]` constructor can be used also used with the setters defined
 by the subclass of `MXFilterObject`.

 @param dictionary the JSON filter definition.
 @return a new filter.
 */
- (instancetype)initWithDictionary:(NSDictionary*)dictionary;

@end
