/*
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

#import "MXRoomSummary.h"

@class MXPeekingRoom;

/**
 A `MXPeekingRoomSummary` instance works with the combination of a `MXPeekingRoomSummary`
 object where data for both is mounted in memory.
 */
@interface MXPeekingRoomSummary : MXRoomSummary

/**
 Set the ephemeral `MXPeekingRoom` object attached to this room summary.

 @param peekingRoom the room associated with this summary.
 */
- (void)setPeekingRoom:(MXPeekingRoom*)peekingRoom;

@end
