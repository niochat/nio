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

#import "MXFilterObject.h"

/**
 `MXFilter` defines a matrix filter which may be used during Matrix requests.
 */
@interface MXFilter : MXFilterObject

/**
 A list of event types to include. If this list is absent then all event types are included.
 A '*' can be used as a wildcard to match any sequence of characters.
 */
@property (nonatomic) NSArray<NSString*> *types;

/**
 A list of event types to exclude. If this list is absent then no event types are excluded.
 A matching type will be excluded even if it is listed in the 'types' filter.
 A '*' can be used as a wildcard to match any sequence of characters.
 */
@property (nonatomic) NSArray<NSString*> *notTypes;

/**
 A list of senders IDs to include. If this list is absent then all senders are included.
 */
@property (nonatomic) NSArray<NSString*> *senders;

/**
 A list of sender IDs to exclude. If this list is absent then no senders are excluded.
 A matching sender will be excluded even if it is listed in the 'senders' filter.
 */
@property (nonatomic) NSArray<NSString*> *notSenders;

/**
 The maximum number of events to return.
 */
@property (nonatomic) NSUInteger limit;

@end
