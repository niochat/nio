/*
 * Copyright 2019 The Matrix.org Foundation C.I.C
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "MXAggregatedReferencesUpdater.h"

#import "MXSession.h"

@interface MXAggregatedReferencesUpdater ()

@property (nonatomic, weak) MXSession *mxSession;
@property (nonatomic, weak) id<MXStore> matrixStore;

@end


@implementation MXAggregatedReferencesUpdater

- (instancetype)initWithMatrixSession:(MXSession *)mxSession
                          matrixStore:(id<MXStore>)matrixStore
{
    self = [super init];
    if (self)
    {
        self.mxSession = mxSession;
        self.matrixStore = matrixStore;
    }
    return self;
}


#pragma mark - Data update

- (void)handleReference:(MXEvent *)referenceEvent
{
    MXEventContentRelatesTo *relation = referenceEvent.relatesTo;

    NSString *roomId = referenceEvent.roomId;
    MXEvent *event = [self.matrixStore eventWithEventId:relation.eventId inRoom:roomId];

    if (event)
    {
        MXEvent *newEvent = [event eventWithNewReferenceRelation:referenceEvent];

        if (newEvent)
        {
            [self.matrixStore replaceEvent:newEvent inRoom:roomId];

            if (newEvent.isEncrypted && !newEvent.clearEvent)
            {
                [self.mxSession decryptEvent:newEvent inTimeline:nil];
            }

            // TODO or not?
            //[self notifyEventEditsListenersOfRoom:roomId replaceEvent:replaceEvent];
        }
    }
    else
    {
        NSLog(@"[MXAggregations] handleReference: Unknown event id: %@", relation.eventId);
    }
}

@end
