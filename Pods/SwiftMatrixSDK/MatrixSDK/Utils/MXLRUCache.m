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

#import "MXLRUCache.h"

@interface MXLRUCacheItem : NSObject

/**
 The item counter
 */
@property NSUInteger refCount;

/**
 The cached object
 */
@property NSObject* object;

/**
 The object key
 */
@property NSString* key;

@end

@implementation MXLRUCacheItem
@end


@interface MXLRUCache ()
{
    // the cached objects list
    // sorted by regCount
    NSMutableArray<MXLRUCacheItem *> *cachedObjects;
    
    // the cached objects keys
    NSMutableArray<NSString*> *cachedKeys;
    
    //
    NSUInteger capacity;
}
@end

@implementation MXLRUCache

- (id)initWithCapacity:(NSUInteger)aCapacity
{
    self = [super init];
    if (self)
    {
        capacity = aCapacity;
        cachedObjects = [[NSMutableArray alloc] initWithCapacity:capacity];
        cachedKeys = [[NSMutableArray alloc] initWithCapacity:capacity];
    }
    return self;
}

- (void)sortCachedItems
{
    cachedObjects = [[cachedObjects sortedArrayUsingComparator:^NSComparisonResult(id a, id b)
     {
         MXLRUCacheItem* item1 = (MXLRUCacheItem*)a;
         MXLRUCacheItem* item2 = (MXLRUCacheItem*)b;
         
         return item2.refCount - item1.refCount;
     }] mutableCopy];
    
    [cachedKeys removeAllObjects];
    
    for(MXLRUCacheItem* item in cachedObjects)
    {
        [cachedKeys addObject:item.key];
    }
}


/**
 Retrieve an object from its key.
 @param key the object key
 @return the cached object if it is found else nil
 */
- (NSObject*)get:(NSString*)key
{
    NSObject* object = nil;
    
    if (key)
    {
        @synchronized(cachedObjects)
        {
            NSUInteger pos = [cachedKeys indexOfObject:key];
            
            if (pos != NSNotFound)
            {
                MXLRUCacheItem* item = [cachedObjects objectAtIndex:pos];
                
                object = item.object;
                
                // update the count order
                item.refCount++;
                [self sortCachedItems];
            }
        }
    }
    
    return object;
}

/**
 Put an object from its key.
 @param key the object key
 @param object the object to store
 */
- (void)put:(NSString*)key object:(NSObject*)object
{
    if (key)
    {
        @synchronized(cachedObjects)
        {
            NSUInteger pos = [cachedKeys indexOfObject:key];
            
            if (pos == NSNotFound)
            {
                MXLRUCacheItem* item = [[MXLRUCacheItem alloc] init];
        
                item.object = object;
                item.refCount = 1;
                item.key = key;

                // remove the less used object
                if (cachedKeys.count >= capacity)
                {
                    [cachedObjects removeLastObject];
                    [cachedKeys removeLastObject];
                    
                }
                
                [cachedObjects addObject:item];
                [cachedKeys addObject:key];
            }
        }
    }
}

/**
 Clear the LRU cache.
 */
- (void)clear
{
    @synchronized(cachedObjects)
    {
        [cachedObjects removeAllObjects];
        [cachedKeys removeAllObjects];
    }
}

@end
