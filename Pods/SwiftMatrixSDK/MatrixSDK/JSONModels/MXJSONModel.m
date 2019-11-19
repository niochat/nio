/*
 Copyright 2014 OpenMarket Ltd
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

#import "MXTools.h"

@implementation MXJSONModel


#pragma mark - Class methods
+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    NSAssert(NO, @"%@ must implement modelFromJSON", self);
    return nil;
}

+ (NSArray *)modelsFromJSON:(NSArray *)JSONDictionaries
{
    NSMutableArray *models;
    
    for (NSDictionary *JSONDictionary in JSONDictionaries)
    {
        id model = [self modelFromJSON:JSONDictionary];
        if (model)
        {
            if (nil == models)
            {
                models = [NSMutableArray array];
            }
            
            [models addObject:model];
        }
    }
    return models;
}

+ (NSDictionary *)removeNullValuesInJSON:(NSDictionary *)JSONDictionary
{
    // A new dictionary is created and returned only if necessary
    NSMutableDictionary *dictionary;

    for (NSString *key in JSONDictionary)
    {
        id value = JSONDictionary[key];
        if ([value isEqual:[NSNull null]])
        {
            if (!dictionary)
            {
               dictionary = [NSMutableDictionary dictionaryWithDictionary:JSONDictionary];
            }

            if ([key isEqualToString:kMXRoomTagServerNotice])
            {
                // Use an empty dict
                dictionary[key] = @{};
            }
            else
            {
                [dictionary removeObjectForKey:key];
            }
        }
        else if ([value isKindOfClass:[NSDictionary class]])
        {
            NSDictionary *subDictionary = [MXJSONModel removeNullValuesInJSON:value];
            if (subDictionary != value)
            {
                if (!dictionary)
                {
                    dictionary = [NSMutableDictionary dictionaryWithDictionary:JSONDictionary];
                }

                dictionary[key] = subDictionary;

            }
        }
        else if ([value isKindOfClass:[NSArray class]])
        {
            // Check dictionaries in this array
            NSArray *arrayValue = value;
            NSMutableArray *newArrayValue;

            for (NSInteger i = 0; i < arrayValue.count; i++)
            {
                NSObject *arrayItem = arrayValue[i];

                if ([arrayItem isKindOfClass:[NSDictionary class]])
                {
                    NSDictionary *subDictionary = [MXJSONModel removeNullValuesInJSON:(NSDictionary*)arrayItem];
                    if (subDictionary != arrayItem)
                    {
                        // This dictionary need to be sanitised. Update its parent array
                        if (!newArrayValue)
                        {
                            newArrayValue = [NSMutableArray arrayWithArray:arrayValue];
                        }

                        [newArrayValue replaceObjectAtIndex:i withObject:subDictionary];
                    }
                }
            }

            if (newArrayValue)
            {
                // The array has changed, update it in the dictionary
                if (!dictionary)
                {
                    dictionary = [NSMutableDictionary dictionaryWithDictionary:JSONDictionary];
                }

                dictionary[key] = newArrayValue;
            }
        }
    }

    if (dictionary)
    {
        return dictionary;
    }
    else
    {
        return JSONDictionary;
    }
}


#pragma mark - Instance methods
- (NSDictionary *)JSONDictionary
{
    NSAssert(NO, @"%@ does not implement JSONDictionary", self.class);
    return nil;
}

- (NSDictionary *)others
{
    NSAssert(NO, @"%@ does not implement others", self.class);
    return nil;
}

- (NSString *)jsonString
{
    return [MXTools serialiseJSONObject:self.JSONDictionary];
}


#pragma mark - NSCopying
- (id)copyWithZone:(NSZone *)zone
{
    NSAssert(NO, @"%@ does not implement NSCopying", self.class);
    return nil;
}


#pragma mark - NSCoding
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    NSAssert(NO, @"%@ does not implement NSCoding", self.class);
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    NSAssert(NO, @"%@ does not implement NSCoding", self.class);
}

@end
