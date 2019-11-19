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

#import <Realm/Realm.h>
#import "MXAntivirusScanStatus.h"

/**
 MXRealmMediaScan property names.
 */
extern const struct MXRealmMediaScanAttributes {
    __unsafe_unretained NSString *url;
    __unsafe_unretained NSString *antivirusScanStatusRawValue;
    __unsafe_unretained NSString *antivirusScanInfo;
    __unsafe_unretained NSString *antivirusScanDate;
} MXRealmMediaScanAttributes;

/**
 MXRealmMediaScan relatioship names.
 */
extern const struct MXRealmMediaScanRelationships {
    __unsafe_unretained NSString *event;
} MXRealmMediaScanRelationships;

/**
 `MXRealmMediaScan` is a Realm representation of `MXMediaScan`.
 */
@interface MXRealmMediaScan : RLMObject

/**
 The media URL.
 */
@property NSString *url;

/**
 The current scan status raw value.
 */
@property NSInteger antivirusScanStatusRawValue;

/**
 The current scan status. Ignored by Realm.
 */
@property (readonly) MXAntivirusScanStatus antivirusScanStatus;

/**
 The potential information returned by the antivirus scanner.
 */
@property NSString *antivirusScanInfo;

/**
 The last scan date.
 */
@property NSDate *antivirusScanDate;

/**
 The owner event. Inverse relationship.
 */
@property (readonly) RLMLinkingObjects *event;

@end

RLM_ARRAY_TYPE(MXRealmMediaScan)
