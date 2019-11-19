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

#import "MXMemoryRoomStore.h"

/**
 `MXFileRoomStore` extends MXMemoryRoomStore to be able to serialise it for storing
 data into file system.
 
 This serialisation is done in the context of the multi-threading managed by [MXFileStore commit].
 @see [MXFileRoomStore encodeWithCoder] for more details.
 */
@interface MXFileRoomStore : MXMemoryRoomStore <NSCoding>

@end
