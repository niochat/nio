/*
 Copyright 2017 Vector Creations Ltd
 
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

NS_ASSUME_NONNULL_BEGIN

/**
 The `MXCallKitConfiguration` describes the desired appereance and behaviour for CallKit.
 */
@interface MXCallKitConfiguration : NSObject

/**
 The string associated with the application and which will be displayed in the native in-call UI
 to help user identify the source of the call
 
 Defaults to bundle display name.
 */
@property (nonatomic, copy) NSString *name;

/**
 The name of the ringtone sound located in app bundle and that will be played on incoming call. 
 */
@property (nonatomic, nullable, copy) NSString *ringtoneName;

/**
 The name of the icon associated with the application. It will be displayed in the native in-call UI.
 
 The icon image should be a square with side length of 40 points. 
 The alpha channel of the image is used to create a white image mask.
 */
@property (nonatomic, nullable, copy) NSString *iconName;

/**
 Tells whether video calls is supported.
 
 Defaults to YES.
 */
@property (nonatomic) BOOL supportsVideo;


- (instancetype)initWithName:(NSString *)name
                ringtoneName:(nullable NSString *)ringtoneName
                    iconName:(nullable NSString *)iconName
               supportsVideo:(BOOL)supportsVideo NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
