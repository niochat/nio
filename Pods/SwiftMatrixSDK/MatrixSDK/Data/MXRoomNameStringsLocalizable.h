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

@import Foundation;

/**
 The `MXRoomNameStringsLocalizable` protocol defines an interface that must be implemented
 to provide string localizations for computing room name according to Matrix
 room summaries (https://github.com/matrix-org/matrix-doc/issues/688).
 This interface is used by `MXRoomSummaryUpdater`.
 */
@protocol MXRoomNameStringsLocalizable <NSObject>

@required

@property (copy, readonly, nonnull) NSString *emptyRoom;
@property (copy, readonly, nonnull) NSString *twoMembers;
@property (copy, readonly, nonnull) NSString *moreThanTwoMembers;

@end

