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
 `MXUsersDevicesInfoMap` is an abstract class to extract data from a map of maps
  where the 1st map keys are userIds and 2nd map keys are deviceId.
 */
@interface MXUsersDevicesMap<__covariant ObjectType> : NSObject <NSCoding, NSCopying>

/**
 Constructor from an exisiting map.
 */
- (instancetype)initWithMap:(NSDictionary<NSString*, NSDictionary<NSString*, ObjectType>*>*)map;

/**
 The map of maps (userId -> deviceId -> Object).
 */
@property (nonatomic, readonly) NSDictionary<NSString* /* userId */,
                                    NSDictionary<NSString* /* deviceId */, ObjectType>*> *map;
/**
 Number of stored objects.
 */
@property (nonatomic, readonly) NSUInteger count;

/**
 Helper methods to extract information from 'map'.
 */
- (NSArray<NSString*>*)userIds;
- (NSArray<NSString*>*)deviceIdsForUser:(NSString*)userId;
- (ObjectType)objectForDevice:(NSString*)deviceId forUser:(NSString*)userId;
- (NSArray<ObjectType>*)objectsForUser:(NSString*)userId;
- (NSArray<ObjectType>*)allObjects;

/**
 Feed helper methods.
 */
- (void)setObject:(ObjectType)object forUser:(NSString*)userId andDevice:(NSString*)deviceId;
- (void)setObjects:(NSDictionary<NSString* /* deviceId */, ObjectType>*)objectsPerDevices forUser:(NSString*)userId;
- (void)addEntriesFromMap:(MXUsersDevicesMap*)map;
- (void)removeAllObjects;
- (void)removeObjectsForUser:(NSString*)userId;
- (void)removeObjectForUser:(NSString*)userId andDevice:(NSString*)deviceId;

@end

