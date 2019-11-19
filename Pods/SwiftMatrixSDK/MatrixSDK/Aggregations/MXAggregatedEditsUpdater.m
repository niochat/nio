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

#import "MXAggregatedEditsUpdater.h"

#import "MXSession.h"
#import "MXTools.h"

#import "MXEventRelations.h"
#import "MXEventReplace.h"
#import "MXEventEditsListener.h"
#import "MXReplyEventParser.h"

@interface MXAggregatedEditsUpdater ()

@property (nonatomic, weak) MXSession *mxSession;
@property (nonatomic) NSString *myUserId;
@property (nonatomic, weak) id<MXStore> matrixStore;
@property (nonatomic) NSMutableArray<MXEventEditsListener*> *listeners;
@property (nonatomic) NSArray<NSString*> *editSupportedMessageTypes;

@end

@implementation MXAggregatedEditsUpdater

- (instancetype)initWithMatrixSession:(MXSession *)mxSession
                     aggregationStore:(id<MXAggregationsStore>)store
                          matrixStore:(id<MXStore>)matrixStore
{
    self = [super init];
    if (self)
    {
        self.mxSession = mxSession;
        self.myUserId = mxSession.matrixRestClient.credentials.userId;
        self.matrixStore = matrixStore;
        self.listeners = [NSMutableArray array];
        self.editSupportedMessageTypes = @[kMXMessageTypeText, kMXMessageTypeEmote];
    }
    return self;
}


#pragma mark - Requests

- (MXHTTPOperation*)replaceTextMessageEvent:(MXEvent*)event
                            withTextMessage:(nullable NSString*)text
                              formattedText:(nullable NSString*)formattedText
                             localEchoBlock:(nullable void (^)(MXEvent *localEcho))localEchoBlock
                                    success:(void (^)(NSString *eventId))success
                                    failure:(void (^)(NSError *error))failure;
{
    NSString *roomId = event.roomId;
    MXRoom *room = [self.mxSession roomWithRoomId:roomId];
    if (!room)
    {
        NSLog(@"[MXAggregations] replaceTextMessageEvent: Error: Unknown room: %@", roomId);
        failure(nil);
        return nil;
    }

    // If it is not already done, decrypt the event to build the new content
    if (event.isEncrypted && !event.clearEvent)
    {
        if (![self.mxSession decryptEvent:event inTimeline:nil])
        {
            NSLog(@"[MXAggregations] replaceTextMessageEvent: Fail to decrypt original event: %@", event.eventId);
            failure(nil);
            return nil;
        }
    }
    
    NSString *messageType = event.content[@"msgtype"];
    
    if (![self.editSupportedMessageTypes containsObject:messageType])
    {
        NSLog(@"[MXAggregations] replaceTextMessageEvent: Error: Only message types %@ are supported", self.editSupportedMessageTypes);
        failure(nil);
        return nil;
    }
    
    NSString *finalText;
    NSString *finalFormattedText;
    
    if (event.isReplyEvent)
    {
        MXReplyEventParser *replyEventParser = [MXReplyEventParser new];
        MXReplyEventParts *replyEventParts = [replyEventParser parse:event];
        
        if (replyEventParts)
        {
            finalText = [NSString stringWithFormat:@"%@%@", replyEventParts.bodyParts.replyTextPrefix, text];
            NSString *formattedReplyText = formattedText ?: text;
            finalFormattedText = [NSString stringWithFormat:@"%@%@", replyEventParts.formattedBodyParts.replyTextPrefix, formattedReplyText];
        }
        else
        {
            NSLog(@"[MXAggregations] replaceTextMessageEvent: Fail to parse reply event: %@", event.eventId);
            failure(nil);
            return nil;
        }
    }
    else
    {
        finalText = text;
        finalFormattedText = formattedText;
    }
    
    NSMutableDictionary *content = [NSMutableDictionary new];
    NSMutableDictionary *compatibilityContent = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                                @"msgtype": messageType,
                                                                                                @"body": [NSString stringWithFormat:@"* %@", finalText]
                                                                                                }];
    
    NSMutableDictionary *newContent = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                      @"msgtype": messageType,
                                                                                      @"body": finalText
                                                                                      }];
    
    
    if (finalFormattedText)
    {
        // Send the HTML formatted string
        
        [compatibilityContent addEntriesFromDictionary:@{
                                                         @"formatted_body": [NSString stringWithFormat:@"* %@", finalFormattedText],
                                                         @"format": kMXRoomMessageFormatHTML
                                                         }];
        
        
        [newContent addEntriesFromDictionary:@{
                                               @"formatted_body": finalFormattedText,
                                               @"format": kMXRoomMessageFormatHTML
                                               }];
    }
    
    
    [content addEntriesFromDictionary:compatibilityContent];
    
    content[@"m.new_content"] = newContent;
    
    content[@"m.relates_to"] = @{
                                 @"rel_type" : @"m.replace",
                                 @"event_id": event.eventId
                                 };
    
    MXHTTPOperation *operation;
    MXEvent *localEcho;
    if (event.isLocalEvent)
    {
        // Need to wait to get the final event id of the message being sent
        NSLog(@"[MXAggregations] replaceTextMessageEvent: Event to edit is a local echo. Wait for the end of the sending");
        operation = [MXHTTPOperation new];

        MXWeakify(self);
        __block id observer;
        observer = [[NSNotificationCenter defaultCenter] addObserverForName:kMXEventDidChangeSentStateNotification object:event queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
            MXStrongifyAndReturnIfNil(self);

            if (event.sentState == MXEventSentStateSent)
            {
                NSLog(@"[MXAggregations] replaceTextMessageEvent: Edit request can be done now");

                [[NSNotificationCenter defaultCenter] removeObserver:observer];
                observer = nil;

                MXHTTPOperation *operation2 = [self replaceTextMessageEvent:event withTextMessage:text formattedText:formattedText localEchoBlock:localEchoBlock success:success failure:failure];

                [operation mutateTo:operation2];
            }
        }];

        if (localEchoBlock)
        {
            // Build a temporary local echo
            localEcho = [room fakeEventWithEventId:nil eventType:kMXEventTypeStringRoomMessage andContent:content];
            localEcho.sentState = event.sentState;
        }
    }
    else
    {
        operation = [room sendEventOfType:kMXEventTypeStringRoomMessage content:content localEcho:&localEcho success:success failure:failure];
    }

    if (localEchoBlock && localEcho)
    {
        localEchoBlock(localEcho);
    }
    
    return operation;
}


#pragma mark - Data update listener

- (id)listenToEditsUpdateInRoom:(NSString *)roomId block:(void (^)(MXEvent* replaceEvent))block
{
    MXEventEditsListener *listener = [MXEventEditsListener new];
    listener.roomId = roomId;
    listener.notificationBlock = block;
    
    [self.listeners addObject:listener];
    
    return listener;
}

- (void)removeListener:(id)listener
{
    [self.listeners removeObject:listener];
}

#pragma mark - Data update

- (void)handleReplace:(MXEvent *)replaceEvent
{
    NSString *roomId = replaceEvent.roomId;
    MXEvent *event = [self.matrixStore eventWithEventId:replaceEvent.relatesTo.eventId inRoom:roomId];

    if (event)
    {
        if (![event.unsignedData.relations.replace.eventId isEqualToString:replaceEvent.eventId])
        {
            MXEvent *editedEvent = [event editedEventFromReplacementEvent:replaceEvent];

            if (editedEvent)
            {
                [self.matrixStore replaceEvent:editedEvent inRoom:roomId];

                if (editedEvent.isEncrypted && !editedEvent.clearEvent)
                {
                    [self.mxSession decryptEvent:editedEvent inTimeline:nil];
                }


                [self notifyEventEditsListenersOfRoom:roomId replaceEvent:replaceEvent];
            }
        }
    }
    else
    {
        NSLog(@"[MXAggregations] handleReplace: Unknown event id: %@", replaceEvent.relatesTo.eventId);
    }
}

//- (void)handleRedaction:(MXEvent *)event
//{
//}

#pragma mark - Private

- (void)notifyEventEditsListenersOfRoom:(NSString*)roomId replaceEvent:(MXEvent*)replaceEvent
{
    for (MXEventEditsListener *listener in self.listeners)
    {
        if ([listener.roomId isEqualToString:roomId])
        {
            listener.notificationBlock(replaceEvent);
        }
    }
}

@end
