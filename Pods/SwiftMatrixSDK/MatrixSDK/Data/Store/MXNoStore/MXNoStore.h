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

#import "MXStore.h"

/**
 `MXNoStore` is an implementation of the `MXStore` interface where no event is stored.
 That means that the Matrix SDK will always make requests to the home server to get events,
 even for those it already fetched.
 
 It stores minimal information like tokens in memory to make the SDK able to work using it.
 */
@interface MXNoStore : NSObject <MXStore>

@end
