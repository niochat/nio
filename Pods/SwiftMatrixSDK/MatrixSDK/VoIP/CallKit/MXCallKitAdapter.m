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

#import "MXCallKitAdapter.h"

@import AVFoundation;
@import CallKit;
@import UIKit;

#import "MXCall.h"
#import "MXCallAudioSessionConfigurator.h"
#import "MXCallKitConfiguration.h"
#import "MXUser.h"
#import "MXSession.h"

NSString * const kMXCallKitAdapterAudioSessionDidActive = @"kMXCallKitAdapterAudioSessionDidActive";

@interface MXCallKitAdapter () <CXProviderDelegate>

@property (nonatomic) CXProvider *provider;
@property (nonatomic) CXCallController *callController;

@property (nonatomic) NSMutableDictionary<NSUUID *, MXCall *> *calls;

@end

@implementation MXCallKitAdapter

- (instancetype)init
{
    return [self initWithConfiguration:[[MXCallKitConfiguration alloc] init]];
}

- (instancetype)initWithConfiguration:(MXCallKitConfiguration *)configuration
{
    if (self = [super init])
    {
        CXProviderConfiguration *providerConfiguration = [[CXProviderConfiguration alloc] initWithLocalizedName:configuration.name];
        providerConfiguration.ringtoneSound = configuration.ringtoneName;
        providerConfiguration.maximumCallGroups = 1;
        providerConfiguration.maximumCallsPerCallGroup = 1;
        providerConfiguration.supportedHandleTypes = [NSSet setWithObject:@(CXHandleTypeGeneric)];
        providerConfiguration.supportsVideo = configuration.supportsVideo;
        
        if (configuration.iconName)
        {
            providerConfiguration.iconTemplateImageData = UIImagePNGRepresentation([UIImage imageNamed:configuration.iconName]);
        }
        
        _provider = [[CXProvider alloc] initWithConfiguration:providerConfiguration];
        [_provider setDelegate:self queue:nil];
        
        _callController = [[CXCallController alloc] initWithQueue:dispatch_get_main_queue()];
        
        _calls = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (void)dealloc
{
    // CXProvider instance must be invalidated otherwise it will be leaked
    [_provider setDelegate:nil queue:nil];
    [_provider invalidate];
    _provider = nil;
}

#pragma mark - Public

- (void)startCall:(MXCall *)call
{
    NSUUID *callUUID = call.callUUID;

    [self contactIdentifierForCall:call onComplete:^(NSString *contactIdentifier) {

        CXHandle *handle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:call.room.roomId];
        CXStartCallAction *action = [[CXStartCallAction alloc] initWithCallUUID:callUUID handle:handle];
        action.contactIdentifier = contactIdentifier;

        CXTransaction *transaction = [[CXTransaction alloc] initWithAction:action];
        [self.callController requestTransaction:transaction completion:^(NSError * _Nullable error) {
            CXCallUpdate *update = [[CXCallUpdate alloc] init];
            update.remoteHandle = handle;
            update.localizedCallerName = contactIdentifier;
            update.hasVideo = call.isVideoCall;
            update.supportsHolding = NO;
            update.supportsGrouping = NO;
            update.supportsUngrouping = NO;
            update.supportsDTMF = NO;

            [self.provider reportCallWithUUID:callUUID updated:update];

            [self.calls setObject:call forKey:callUUID];
        }];
    }];
}

- (void)endCall:(MXCall *)call;
{
    MXCallEndReason endReason = call.endReason;
    
    if (endReason == MXCallEndReasonHangup)
    {
        CXEndCallAction *action = [[CXEndCallAction alloc] initWithCallUUID:call.callUUID];
        CXTransaction *transaction = [[CXTransaction alloc] initWithAction:action];
        [self.callController requestTransaction:transaction completion:^(NSError *_Nullable error){}];
    }
    else
    {
        CXCallEndedReason reason = CXCallEndedReasonFailed;
        switch (endReason)
        {
            case MXCallEndReasonRemoteHangup:
                reason = CXCallEndedReasonRemoteEnded;
                break;
            case MXCallEndReasonHangupElsewhere:
                reason = CXCallEndedReasonDeclinedElsewhere;
                break;
            case MXCallEndReasonBusy:
            case MXCallEndReasonMissed:
                reason = CXCallEndedReasonUnanswered;
                break;
            case MXCallEndReasonAnsweredElseWhere:
                reason = CXCallEndedReasonAnsweredElsewhere;
                break;
            default:
                break;
        }
        
        [self.provider reportCallWithUUID:call.callUUID endedAtDate:nil reason:reason];
    }
}

- (void)reportIncomingCall:(MXCall *)call {
    MXSession *mxSession = call.room.mxSession;
    MXUser *caller = [mxSession userWithUserId:call.callerId];
    NSUUID *callUUID = call.callUUID;
    
    CXHandle *handle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:call.room.roomId];
    
    CXCallUpdate *update = [[CXCallUpdate alloc] init];
    update.remoteHandle = handle;
    update.localizedCallerName = caller.displayname;
    update.hasVideo = call.isVideoCall;
    update.supportsHolding = NO;
    update.supportsGrouping = NO;
    update.supportsUngrouping = NO;
    update.supportsDTMF = NO;
    
    [self.provider reportNewIncomingCallWithUUID:callUUID update:update completion:^(NSError * _Nullable error) {
        if (error)
        {
            [call hangup];
            return;
        }
        
        self.calls[callUUID] = call;
        
        // Workaround from https://forums.developer.apple.com/message/169511 suggests configuring audio in the
        // completion block of the `reportNewIncomingCallWithUUID:update:completion:` method instead of in
        // `provider:performAnswerCallAction:` per the WWDC examples.
        [self.audioSessionConfigurator configureAudioSessionForVideoCall:call.isVideoCall];
    }];
    
}

- (void)reportCall:(MXCall *)call startedConnectingAtDate:(nullable NSDate *)date
{
    [self.provider reportOutgoingCallWithUUID:call.callUUID startedConnectingAtDate:date];
}

- (void)reportCall:(MXCall *)call connectedAtDate:(nullable NSDate *)date
{
    [self.provider reportOutgoingCallWithUUID:call.callUUID connectedAtDate:date];
}

+ (BOOL)callKitAvailable
{
	if (@available(iOS 10.0, *)) {
		// CallKit currently illegal in China
		// https://github.com/vector-im/riot-ios/issues/1941

		return ![NSLocale.currentLocale.countryCode isEqual: @"CN"];
	}

	return NO;
}

#pragma mark - CXProviderDelegate

- (void)providerDidReset:(CXProvider *)provider
{
    NSLog(@"Provider did reset");
}

- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession
{
    [self.audioSessionConfigurator audioSessionDidActivate:audioSession];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXCallKitAdapterAudioSessionDidActive object:nil];
}

- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession
{
    [self.audioSessionConfigurator audioSessionDidDeactivate:audioSession];
}

- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action
{
    MXCall *call = self.calls[action.callUUID];
    if (call)
    {
        [self.audioSessionConfigurator configureAudioSessionForVideoCall:call.isVideoCall];
    }
    
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action
{
    MXCall *call = self.calls[action.callUUID];
    if (call)
    {
        [call answer];
    }
    
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action
{
    MXCall *call = self.calls[action.callUUID];
    if (call)
    {
        [call hangup];
        [self.calls removeObjectForKey:action.UUID];
    }
    
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performSetMutedCallAction:(CXSetMutedCallAction *)action
{
    MXCall *call = self.calls[action.callUUID];
    if (call)
    {
        [call setAudioMuted:action.isMuted];
    }

    [action fulfill];
}


#pragma mark - Private methods

- (void)contactIdentifierForCall:(MXCall *)call onComplete:(void (^)(NSString *contactIdentifier))onComplete
{
    if (call.isConferenceCall)
    {
        onComplete(call.room.summary.displayname);
    }
    else
    {
        [call calleeId:^(NSString *calleeId) {
            MXUser *callee = [call.room.mxSession userWithUserId:calleeId];
            onComplete(callee.displayname);
        }];
    }
}

@end

#endif
