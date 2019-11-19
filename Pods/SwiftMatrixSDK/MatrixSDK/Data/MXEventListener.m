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

#import "MXEventListener.h"

@interface MXEventListener ()

@end

@implementation MXEventListener

-(instancetype)initWithSender:(id)sender
                andEventTypes:(NSArray<MXEventTypeString> *)eventTypes
             andListenerBlock:(MXOnEvent)listenerBlock
{
    self = [super init];
    if (self)
    {
        _sender = sender;
        _eventTypes = [eventTypes copy];
        _listenerBlock =listenerBlock;
    }
    
    return self;
}

- (void)notify:(MXEvent*)event direction:(MXTimelineDirection)direction andCustomObject:(id)customObject
{
    // Check if the event match with eventTypes
    BOOL match = NO;
    if (_eventTypes)
    {
        if (NSNotFound != [_eventTypes indexOfObject:event.type])
        {
            match = YES;
        }
    }
    else
    {
        // Listen for all events
        match = YES;
    }
    
    // If YES, call the listener block
    if (match)
    {
        _listenerBlock(event, direction, customObject);
    }
}

@end
