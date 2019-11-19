
#import <Foundation/Foundation.h>

/**
 Found at http://stackoverflow.com/questions/21672923/canonicalize-json-so-equivalent-objects-have-the-same-hash/21720585#21720585

 This category allows to produce a canonical JSON string from a NSDictionary.
 
 Usage: 
     NSData * JSONData = [NSJSONSerialization dataWithJSONObject:[jsonObject objectWithSortedKeys] options:0 error:&error];
 */

@interface NSObject (sortedKeys)

/// Returns a proxy for the object in which all dictionary keys, including those of child objects at any level, will always be enumerated in sorted order.
- (id)objectWithSortedKeys;

@end
