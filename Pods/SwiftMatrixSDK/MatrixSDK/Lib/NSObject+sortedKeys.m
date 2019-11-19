#import "NSObject+sortedKeys.h"

/// A CbxSortedKeyWrapper intercepts calls to methods like -allKeys, -objectEnumerator, -enumerateKeysAndObjectsUsingBlock:, etc. and makes them enumerate a sorted array of keys, thus ensuring that keys are enumerated in a stable order. It also replaces objects returned by any other methods (including, say, -objectForKey: or -objectAtIndex:) with wrapped versions of those objects, thereby ensuring that child objects are similarly sorted. There are a lot of flaws in this approach, but it works well enough for NSJSONSerialization.
@interface CbxSortedKeyWrapper: NSProxy

+ (id)sortedKeyWrapperForObject:(id)object;

@end

@implementation NSObject (sortedKeys)

- (id)objectWithSortedKeys {
    return [CbxSortedKeyWrapper sortedKeyWrapperForObject:self];
}

@end

@implementation CbxSortedKeyWrapper {
    id _representedObject;
    NSArray * _keys;
}


+ (id)sortedKeyWrapperForObject:(id)object {
    if(!object) {
        return nil;
    }

    CbxSortedKeyWrapper * wrapper = [self alloc];
    wrapper->_representedObject = [object copy];

    if([wrapper->_representedObject respondsToSelector:@selector(allKeys)]) {
        wrapper->_keys = [[wrapper->_representedObject allKeys] sortedArrayUsingSelector:@selector(compare:)];
    }

    return wrapper;
}

- (NSMethodSignature*)methodSignatureForSelector:(SEL)aSelector {
    return [_representedObject methodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation*)invocation {
    [invocation invokeWithTarget:_representedObject];

    BOOL returnsObject = invocation.methodSignature.methodReturnType[0] == '@';

    if(returnsObject) {
        __unsafe_unretained id out = nil;
        [invocation getReturnValue:&out];

        __unsafe_unretained id wrapper = [CbxSortedKeyWrapper sortedKeyWrapperForObject:out];
        [invocation setReturnValue:&wrapper];
    }
}

- (NSEnumerator *)keyEnumerator {
    return [_keys objectEnumerator];
}

- (NSEnumerator *)objectEnumerator {
    if(_keys) {
        return [[self allValues] objectEnumerator];
    }
    else {
        return [CbxSortedKeyWrapper sortedKeyWrapperForObject:[_representedObject objectEnumerator]];
    }
}

- (NSArray *)allKeys {
    return _keys;
}

- (NSArray *)allValues {
    return [CbxSortedKeyWrapper sortedKeyWrapperForObject:[_representedObject objectsForKeys:_keys notFoundMarker:[NSNull null]]];
}

- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id key, id obj, BOOL *stop))block {
    [_keys enumerateObjectsUsingBlock:^(id key, NSUInteger idx, BOOL *stop) {
        id obj = [CbxSortedKeyWrapper sortedKeyWrapperForObject:self->_representedObject[key]];
        block(key, obj, stop);
    }];
}

- (void)enumerateKeysAndObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (^)(id key, id obj, BOOL *stop))block {
    [_keys enumerateObjectsWithOptions:opts usingBlock:^(id key, NSUInteger idx, BOOL *stop) {
        id obj = [CbxSortedKeyWrapper sortedKeyWrapperForObject:self->_representedObject[key]];
        block(key, obj, stop);
    }];
}

- (void)enumerateObjectsUsingBlock:(void (^)(id obj, NSUInteger idx, BOOL *stop))block {
    [_representedObject enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL * stop) {
        block([CbxSortedKeyWrapper sortedKeyWrapperForObject:obj], idx, stop);
    }];
}

- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (^)(id obj, NSUInteger idx, BOOL *stop))block {
    [_representedObject enumerateObjectsWithOptions:opts usingBlock:^(id obj, NSUInteger idx, BOOL * stop) {
        block([CbxSortedKeyWrapper sortedKeyWrapperForObject:obj], idx, stop);
    }];
}

- (void)enumerateObjectsAtIndexes:(NSIndexSet *)indexSet options:(NSEnumerationOptions)opts usingBlock:(void (^)(id obj, NSUInteger idx, BOOL *stop))block {
    [_representedObject enumerateObjectsAtIndexes:indexSet options:opts usingBlock:^(id obj, NSUInteger idx, BOOL * stop) {
        block([CbxSortedKeyWrapper sortedKeyWrapperForObject:obj], idx, stop);
    }];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id *)stackbuf count:(NSUInteger)len {
    NSUInteger count = [_keys countByEnumeratingWithState:state objects:stackbuf count:len];
    for(NSUInteger i = 0; i < count; i++) {
        stackbuf[i] = [CbxSortedKeyWrapper sortedKeyWrapperForObject:stackbuf[i]];
    }
    return count;
}

@end
