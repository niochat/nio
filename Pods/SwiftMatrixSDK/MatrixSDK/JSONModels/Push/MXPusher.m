/*
 Copyright 2019 The Matrix.org Foundation C.I.C

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

#import "MXPusher.h"

@implementation MXPusher

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXPusher *pusher;

    NSString *pushkey, *kind, *appId, *appDisplayName, *deviceDisplayName, *profileTag, *lang;
    MXJSONModelSetString(pushkey, JSONDictionary[@"pushkey"]);
    MXJSONModelSetString(kind, JSONDictionary[@"kind"]);
    MXJSONModelSetString(appId, JSONDictionary[@"app_id"]);
    MXJSONModelSetString(appDisplayName, JSONDictionary[@"app_display_name"]);
    MXJSONModelSetString(deviceDisplayName, JSONDictionary[@"device_display_name"]);
    MXJSONModelSetString(profileTag, JSONDictionary[@"profile_tag"]);
    MXJSONModelSetString(lang, JSONDictionary[@"lang"]);

    MXPusherData *data;
    MXJSONModelSetMXJSONModel(data, MXPusherData, JSONDictionary[@"data"]);

    if (pushkey && kind && appId && appDisplayName && deviceDisplayName && lang && data)
    {
        pusher = [MXPusher new];
        pusher->_pushkey = pushkey;
        pusher->_kind = kind;
        pusher->_appId = appId;
        pusher->_appDisplayName = appDisplayName;
        pusher->_deviceDisplayName = deviceDisplayName;
        pusher->_profileTag = profileTag;
        pusher->_lang = lang;
        pusher->_data = data;
    }

    return pusher;
}

@end
