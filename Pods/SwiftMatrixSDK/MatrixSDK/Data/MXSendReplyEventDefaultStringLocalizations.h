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
#import "MXSendReplyEventStringsLocalizable.h"

/**
 A `MXSendReplyEventDefaultStringLocalizations` instance represents default localization strings used when send reply event to a message in a room.
 */
@interface MXSendReplyEventDefaultStringLocalizations : NSObject<MXSendReplyEventStringsLocalizable>

@property (copy, readonly, nonnull) NSString *senderSentAnImage;
@property (copy, readonly, nonnull) NSString *senderSentAVideo;
@property (copy, readonly, nonnull) NSString *senderSentAnAudioFile;
@property (copy, readonly, nonnull) NSString *senderSentAFile;
@property (copy, readonly, nonnull) NSString *messageToReplyToPrefix;

@end
