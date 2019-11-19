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

#import "MXJSONModel.h"

#import "MXFilter.h"
#import "MXRoomFilter.h"

/**
 `MXFilterJSONModel` represents a matrix filter model as exchanged through the Matrix
 Client-Server API.
 */
@interface MXFilterJSONModel : MXJSONModel

/**
 List of event fields to include. If this list is absent then all fields are included.
 The entries may include '.' charaters to indicate sub-fields. So ['content.body']
 will include the 'body' field of the 'content' object.
 A literal '.' character in a field name may be escaped using a '\'.
 A server may include more fields than were requested.
 */
@property (nonatomic) NSArray<NSString*> *eventFields;

/**
 The format to use for events.
 'client' will return the events in a format suitable for clients.
 'federation' will return the raw event as receieved over federation.
 The default is 'client'. One of: ["client", "federation"].
 */
@property (nonatomic) NSString *eventFormat;

/**
 The presence updates to include.
 */
@property (nonatomic) MXFilter *presence;

/**
 The user account data that isn't associated with rooms to include.
 */
@property (nonatomic) MXFilter *accountData;

/**
 Filters to be applied to room data.
 */
@property (nonatomic) MXRoomFilter *room;


#pragma mark - Factory

/**
 Build a Matrix filter to retrieve a max given number of messages per room in /sync requests.

 @param messageLimit messageLimit the messages count limit.
 @return the Matrix filter.
 */
+ (MXFilterJSONModel*)syncFilterWithMessageLimit:(NSUInteger)messageLimit;

/**
 Build a Matrix filter to enable room members lazy loading in /sync requests.

 @return the Matrix filter.
 */
+ (MXFilterJSONModel*)syncFilterForLazyLoading;

/**
 Build a Matrix filter to enable room members lazy loading in /sync requests
 with a message count limit per room.

 @param messageLimit messageLimit the messages count limit.
 @return the Matrix filter.
 */
+ (MXFilterJSONModel*)syncFilterForLazyLoadingWithMessageLimit:(NSUInteger)messageLimit;

@end
