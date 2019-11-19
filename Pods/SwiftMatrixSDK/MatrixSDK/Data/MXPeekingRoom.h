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

#import "MXRoom.h"

/**
 A `MXPeekingRoom` instance allows to get data from a room the user has not necessarly
 joined.

 Thus, an end user can peek into a room without joining it.
 This only works if the history visibility for the room is world_readable.

 A `MXPeekingRoom` instance retrieves data by its own means: it firstly makes an
 /initialSync  request then it starts an events stream (/events long poll requests).

 So, `MXPeekingRoom` instances get their data apart from the MXSession /sync mechanism.
 They are not listed in [MXSession rooms].
 */
@interface MXPeekingRoom : MXRoom

/**
 Start getting room data from the homeserver and keep sync'ed with it.
 
 Use [MXPeekingRoom close] to stop syncing with the homeserver.

 TODO: The live events stream is not yet implemented.

 @param onServerSyncDone A block object called when the room data (last messages and state)
                         is up-to-date with the homeserver.
 @param failure A block object called when the operation fails.
 */
- (void)start:(void (^)(void))onServerSyncDone
      failure:(void (^)(NSError *error))failure;

/**
 Close the preview of the room.

 No more data is retrieved from the homeserver.
*/
- (void)close;

/**
 Pause the events stream of this room.
 */
- (void)pause;

/**
 Resume the events stream of this room.
 */
- (void)resume;

@end
