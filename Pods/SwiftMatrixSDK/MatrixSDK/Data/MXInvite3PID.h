/*
 Copyright 2016 OpenMarket Ltd
 
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
 `MXInvite3PID` represents a third party IDs to invite into the room
 (see the property 'dictionary' for the resulting dictionary).
 */
@interface MXInvite3PID : NSObject

/**
 The hostname+port of the identity server which should be used for third party identifier lookups.
 */
@property (nonatomic) NSString *identityServer;

/**
 The kind of address being passed in the address field, for example email.
 */
@property (nonatomic) NSString *medium;

/**
 The invitee's third party identifier.
 */
@property (nonatomic) NSString *address;

/**
 The resulting dictionary. Return nil if one the 3 properties has not been defined. They are all required
 to invite a third party ID.
 */
@property (nonatomic, readonly) NSDictionary<NSString *, id> *dictionary;

@end
