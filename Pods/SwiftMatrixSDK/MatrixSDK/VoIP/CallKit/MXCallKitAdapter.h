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

#if TARGET_OS_IPHONE

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@class MXCall;
@class MXCallKitConfiguration;
@protocol MXCallAudioSessionConfigurator;

/**
 Posted when then system has activated AVAudioSession.
 */
extern NSString * const kMXCallKitAdapterAudioSessionDidActive;

@interface MXCallKitAdapter : NSObject

/**
 The AVAudioSession configurator.
 */
@property (nonatomic, nullable, strong) id<MXCallAudioSessionConfigurator> audioSessionConfigurator;

- (instancetype)initWithConfiguration:(MXCallKitConfiguration *)configuration NS_DESIGNATED_INITIALIZER;

- (void)startCall:(MXCall *)call;
- (void)endCall:(MXCall *)call;

- (void)reportIncomingCall:(MXCall *)call;

- (void)reportCall:(MXCall *)call startedConnectingAtDate:(nullable NSDate *)date;
- (void)reportCall:(MXCall *)call connectedAtDate:(nullable NSDate *)date;

/**
 Tell about support of CallKit by the OS
 
 @return true if iOS version >= 10.0 otherwise false
 */
+ (BOOL)callKitAvailable;

@end

NS_ASSUME_NONNULL_END

#endif
