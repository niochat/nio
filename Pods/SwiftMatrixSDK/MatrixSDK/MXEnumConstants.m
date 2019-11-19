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

#import "MXEnumConstants.h"

#import "MXSDKOptions.h"

/**
 Matrix content respository path
 */
NSString *const kMXContentUriScheme  = @"mxc://";
NSString *const kMXContentPrefixPath = @"_matrix/media/v1";

/**
 Prefix used in path of antivirus server API requests.
 */
NSString *const kMXAntivirusAPIPrefixPathUnstable = @"_matrix/media_proxy/unstable";

/**
 Membership definitions - String version
 */
NSString *const kMXMembershipStringInvite = @"invite";
NSString *const kMXMembershipStringJoin   = @"join";
NSString *const kMXMembershipStringLeave  = @"leave";
NSString *const kMXMembershipStringBan    = @"ban";

/**
 Room visibility in the homeserver directory.
 */
NSString *const kMXRoomDirectoryVisibilityPrivate   = @"private";
NSString *const kMXRoomDirectoryVisibilityPublic    = @"public";

/**
 Room history visibility.
 */
NSString *const kMXRoomHistoryVisibilityWorldReadable= @"world_readable";
NSString *const kMXRoomHistoryVisibilityShared       = @"shared";
NSString *const kMXRoomHistoryVisibilityInvited      = @"invited";
NSString *const kMXRoomHistoryVisibilityJoined       = @"joined";

/**
 Room join rule.
 */
NSString *const kMXRoomJoinRulePublic  = @"public";
NSString *const kMXRoomJoinRuleInvite  = @"invite";
NSString *const kMXRoomJoinRulePrivate = @"private";
NSString *const kMXRoomJoinRuleKnock   = @"knock";

/**
 Room presets
 */
NSString *const kMXRoomPresetPrivateChat = @"private_chat";
NSString *const kMXRoomPresetTrustedPrivateChat = @"trusted_private_chat";
NSString *const kMXRoomPresetPublicChat = @"public_chat";

/**
 Room guest access.
 */
NSString *const kMXRoomGuestAccessCanJoin   = @"can_join";
NSString *const kMXRoomGuestAccessForbidden = @"forbidden";

NSString *const kMXRoomMessageFormatHTML = @"org.matrix.custom.html";

NSString *const kMXMatrixDotToUrl = @"https://matrix.to";


#pragma mark - Analytics

NSString *const kMXAnalyticsStartupCategory = @"startup";

NSString *const kMXAnalyticsStartupInititialSync = @"initialSync";
NSString *const kMXAnalyticsStartupIncrementalSync = @"incrementalSync";
NSString *const kMXAnalyticsStartupStorePreload = @"storePreload";
NSString *const kMXAnalyticsStartupMountData = @"mountData";
NSString *const kMXAnalyticsStartupLaunchScreen = @"launchScreen";

NSString *const kMXAnalyticsStatsCategory = @"stats";
NSString *const kMXAnalyticsStatsRooms = @"rooms";
