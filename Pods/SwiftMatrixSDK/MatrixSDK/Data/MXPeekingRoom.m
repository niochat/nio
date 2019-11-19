/*
 Copyright 2016 OpenMarket Ltd
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

#import "MXPeekingRoom.h"

#import "MXMemoryStore.h"
#import "MXSession.h"
#import "MXTools.h"
#import "MXPeekingRoomSummary.h"

@interface MXPeekingRoom ()
{
    /**
     The current pending request.
     */
    MXHTTPOperation *httpOperation;

    /**
     The ephemeral summary of this room.
     */
    MXPeekingRoomSummary *summary;
}

@end

@implementation MXPeekingRoom

- (id)initWithRoomId:(NSString *)roomId andMatrixSession:(MXSession *)mxSession
{
    // Do not store the data we will get from the hs to the session store
    // but to an ephemeral store
    MXMemoryStore *memoryStore = [[MXMemoryStore alloc] init];
    [memoryStore openWithCredentials:mxSession.matrixRestClient.credentials onComplete:nil failure:nil];

    // Same thing for the summary
    summary = [[MXPeekingRoomSummary alloc] initWithRoomId:roomId matrixSession:mxSession andStore:memoryStore];
    [summary setPeekingRoom:self];

    return [self initWithRoomId:roomId matrixSession:mxSession andStore:memoryStore];
}

- (void)start:(void (^)(void))onServerSyncDone failure:(void (^)(NSError *error))failure
{
    // Make an /initialSync request to get data
    // Use a 0 messages limit for now because:
    //    - /initialSync is marked as obsolete in the spec
    //    - MXEventTimeline does not have methods to handle /initialSync responses
    // So, avoid to write temparary code and let the user uses [MXEventTimeline paginate]
    // to get room messages.
    MXWeakify(self);
    httpOperation = [self.mxSession.matrixRestClient initialSyncOfRoom:self.roomId withLimit:0 success:^(MXRoomInitialSync *roomInitialSync) {
        MXStrongifyAndReturnIfNil(self);
        
        if (!self->httpOperation)
        {
            return;
        }
        self->httpOperation = nil;

        [self liveTimeline:^(MXEventTimeline *liveTimeline) {
            [liveTimeline initialiseState:roomInitialSync.state];

            // @TODO: start the events stream

            onServerSyncDone();
        }];

    } failure:failure];
}

- (MXRoomSummary *)summary
{
    // Use the ephemeral summary
    return summary;
}

- (void)close
{
    // Cancel the current server request (if any)
    [httpOperation cancel];
    httpOperation = nil;

    [super close];
}

- (void)pause
{
    // @TODO
}

- (void)resume
{
    // @TODO
}

@end
