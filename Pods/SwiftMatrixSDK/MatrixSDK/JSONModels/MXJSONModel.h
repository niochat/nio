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

#import <Foundation/Foundation.h>


/**
 A class that inherits from `MXJSONModel` represents the response to a request
 to a Matrix home server.
 
 Matrix home server responses are JSON strings. `MXJSONModel` derived classes map
 the members of the JSON object into their properties.
 
 Some of the methods below are pure virtual methods in C++ definition and must be
 implemented by the derived class if they are used by the code.
 */
@interface MXJSONModel : NSObject <NSCopying, NSCoding>


#pragma mark - Class methods
/**
 Create a model instance from a JSON dictionary.
 
 @param JSONDictionary the JSON data.
 @return the newly created instance.
 */
+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary;

/**
 Create model instances from an array of JSON dictionaries.
 
 @param JSONDictionaries the JSON data array.
 @return the newly created instances.
 */
+ (NSArray *)modelsFromJSON:(NSArray *)JSONDictionaries;

/**
 Clean a JSON dictionary by removing null values
 
 @param JSONDictionary the JSON data.
 @return JSON data without null values
 */
+ (NSDictionary *)removeNullValuesInJSON:(NSDictionary *)JSONDictionary;


#pragma mark - Instance methods
/**
 Rebuild the original JSON dictionary
 */
- (NSDictionary *)JSONDictionary;

/**
 This dictionary contains keys/values that have been in the JSON source object
 but not decoded.
 TODO: To implement so that app can manage custom events or paramaters.
 */
- (NSDictionary *)others;

/**
 The JSON string representating the filter.
 */
- (NSString *)jsonString;

@end


#pragma mark - Validation methods
/**
 Validate then set the value into the variable.
 
 @param var the variable to set the value to.
 @param class the expected class.
 @param value the value to set.
 */
#define MXJSONModelSet(var, class, value) \
    if (value) \
    { \
        if ([value isKindOfClass:class]) var = value; \
        else MXJSONModelSetLogError(class, value)  \
    }

/**
 Typed declinations of MXJSONModelSet.

 @param var the variable to set the value to.
 @param value the value to set.
 */
#define MXJSONModelSetArray(var, value)         MXJSONModelSet(var, NSArray.class, value)
#define MXJSONModelSetDictionary(var, value)    MXJSONModelSet(var, NSDictionary.class, value)
#define MXJSONModelSetString(var, value)        MXJSONModelSet(var, NSString.class, value)
#define MXJSONModelSetNumber(var, value)        MXJSONModelSet(var, NSNumber.class, value)

/**
 Validate then set a numerical value into the variable.

 @param var the variable to set the value to.
 @param value the value to set.
 */
#define MXJSONModelSetBoolean(var, value)       MXJSONModelSetNumberValue(var, boolValue, value)
#define MXJSONModelSetInteger(var, value)       MXJSONModelSetNumberValue(var, integerValue, value)
#define MXJSONModelSetUInteger(var, value)      MXJSONModelSetNumberValue(var, unsignedIntegerValue, value)
#define MXJSONModelSetUInt64(var, value)        MXJSONModelSetNumberValue(var, unsignedLongLongValue, value)

#define MXJSONModelSetNumberValue(var, method, value)  \
    if (value) \
    { \
        if ([value isKindOfClass:NSNumber.class]) var = [((NSNumber*)value) method]; \
        else MXJSONModelSetLogError(NSNumber.class, value)  \
    }

/**
 Validate, decode the MXJSONModel object in 'value', then set it into the variable.

 @param var the variable to set the value to.
 @param MXJSONModelClass the class to use to decode 'value'.
 @param value the value to decode, then set.
 */
#define MXJSONModelSetMXJSONModel(var, MXJSONModelClass, value) \
    if (value) \
    { \
        if ([value isKindOfClass:NSDictionary.class]) var = [MXJSONModelClass modelFromJSON:value]; \
        else MXJSONModelSetLogError(NSDictionary.class, value)  \
    }

/**
 Same as 'MXJSONModelSetMXJSONModel' but for array of MXJSONModel objects.

 @param var the variable to set the value to.
 @param MXJSONModelClass the class to use to decode 'values'.
 @param values the values to decode, then set.
 */
#define MXJSONModelSetMXJSONModelArray(var, MXJSONModelClass, values) \
    if (values) \
    { \
        if ([values isKindOfClass:NSArray.class]) var = [MXJSONModelClass modelsFromJSON:values]; \
        else MXJSONModelSetLogError(NSArray.class, values)  \
    }

/**
 Log a validation error.
 */
#define MXJSONModelSetLogError(theClass, value) \
    { \
        NSLog(@"[MXJSONModelSet] ERROR: Unexpected type for parsing at %@:%d. Expected: %@. Got: %@ (%@)", \
            @(__FILE__).lastPathComponent, __LINE__, theClass, value, NSStringFromClass([value class])); \
    }
