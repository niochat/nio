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


#import "MXKeyVerificationByDMRequest.h"

#import "MXKeyVerificationRequest_Private.h"
#import "MXKeyVerificationManager_Private.h"
#import "MXCrypto_Private.h"

#import "MXEvent.h"


@implementation MXKeyVerificationByDMRequest

- (instancetype)initWithEvent:(MXEvent*)event andManager:(MXKeyVerificationManager*)manager
{
    // Check verification by DM request format
    MXKeyVerificationRequestByDMJSONModel *request;
    MXJSONModelSetMXJSONModel(request, MXKeyVerificationRequestByDMJSONModel.class, event.content);
    
    if (!request)
    {
        return nil;
    }
    
    self = [super initWithEvent:event andManager:manager];
    if (self)
    {
        _request = request;
        _roomId = event.roomId;
        _eventId = event.eventId;
        
        MXCredentials *myCreds = manager.crypto.mxSession.matrixRestClient.credentials;
        self.isFromMyUser = [event.sender isEqualToString:myCreds.userId];
        self.isFromMyDevice = [request.fromDevice isEqualToString:myCreds.deviceId];
    }
    return self;
}


// Shortcuts
- (NSString *)requestId
{
    return self.event.eventId;
}

- (MXKeyVerificationTransport)transport
{
    return MXKeyVerificationTransportDirectMessage;
}

- (NSString *)fromDevice
{
    return _request.fromDevice;
}

- (uint64_t)timestamp
{
    return self.event.ageLocalTs;
}

- (NSArray<NSString *> *)methods
{
    return _request.methods;
}

// Shortcuts to the original request
- (NSString *)otherUser
{
    return self.isFromMyUser ? _request.to : self.event.sender;
}

- (NSString *)otherDevice
{
    return self.isFromMyDevice ? self.acceptedData.fromDevice : _request.fromDevice;
}

@end
