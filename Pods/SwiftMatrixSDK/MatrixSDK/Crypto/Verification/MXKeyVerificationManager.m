/*
 Copyright 2019 New Vector Ltd
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

#import "MXKeyVerificationManager.h"
#import "MXKeyVerificationManager_Private.h"
#import "MXIncomingSASTransaction_Private.h"

#import "MXSession.h"
#import "MXCrypto_Private.h"
#import "MXCrossSigning_Private.h"
#import "MXTools.h"

#import "MXTransactionCancelCode.h"

#import "MXKeyVerificationRequest_Private.h"
#import "MXKeyVerificationByToDeviceRequest.h"
#import "MXKeyVerificationByDMRequest.h"

#import "MXKeyVerificationRequestByToDeviceJSONModel.h"
#import "MXKeyVerificationRequestByDMJSONModel.h"

#import "MXKeyVerificationStatusResolver.h"

#import "MXSASTransaction_Private.h"
#import "MXQRCodeTransaction_Private.h"

#import "MXQRCodeDataBuilder.h"

#pragma mark - Constants

NSString *const MXKeyVerificationErrorDomain = @"org.matrix.sdk.verification";
NSString *const MXKeyVerificationManagerNewRequestNotification       = @"MXKeyVerificationManagerNewRequestNotification";
NSString *const MXKeyVerificationManagerNotificationRequestKey       = @"MXKeyVerificationManagerNotificationRequestKey";
NSString *const MXKeyVerificationManagerNewTransactionNotification   = @"MXKeyVerificationManagerNewTransactionNotification";
NSString *const MXKeyVerificationManagerNotificationTransactionKey   = @"MXKeyVerificationManagerNotificationTransactionKey";

// Transaction timeout in seconds
NSTimeInterval const MXTransactionTimeout = 10 * 60.0;

// Request timeout in seconds
NSTimeInterval const MXRequestDefaultTimeout = 5 * 60.0;

static NSArray<MXEventTypeString> *kMXKeyVerificationManagerVerificationEventTypes;


@interface MXKeyVerificationManager ()
{
    // The queue to run background tasks
    dispatch_queue_t cryptoQueue;

    // All running transactions
    MXUsersDevicesMap<MXKeyVerificationTransaction*> *transactions;
    // Timer to cancel transactions
    NSTimer *transactionTimeoutTimer;

    // All pending requests
    // Request id -> request
    NSMutableDictionary<NSString*, MXKeyVerificationRequest*> *pendingRequestsMap;

    // Timer to cancel requests
    NSTimer *requestTimeoutTimer;

    MXKeyVerificationStatusResolver *statusResolver;
}

@property (nonatomic, strong) MXQRCodeDataBuilder *qrCodeDataBuilder;

@end

@implementation MXKeyVerificationManager

#pragma mark - Public methods -

#pragma mark Requests

- (void)requestVerificationByToDeviceWithUserId:(NSString*)userId
                                      deviceIds:(nullable NSArray<NSString*>*)deviceIds
                                        methods:(NSArray<NSString*>*)methods
                                        success:(void(^)(MXKeyVerificationRequest *request))success
                                        failure:(void(^)(NSError *error))failure
{
    NSLog(@"[MXKeyVerification] requestVerificationByToDeviceWithUserId: %@. deviceIds: %@", userId, deviceIds);
    if (deviceIds.count)
    {
        [self requestVerificationByToDeviceWithUserId2:userId deviceIds:deviceIds methods:methods success:success failure:failure];
    }
    else
    {
        [self otherDeviceIdsOfUser:userId success:^(NSArray<NSString *> *otherDeviceIds) {
            if (otherDeviceIds.count)
            {
                [self requestVerificationByToDeviceWithUserId2:userId deviceIds:otherDeviceIds methods:methods success:success failure:failure];
            }
            else
            {
                NSError *error = [NSError errorWithDomain:MXKeyVerificationErrorDomain
                                                     code:MXKeyVerificatioNoOtherDeviceCode
                                                 userInfo:@{
                                                            NSLocalizedDescriptionKey: [NSString stringWithFormat:@"The user has no other device"]
                                                            }];
                failure(error);
            }
        } failure:failure];
    }
}

- (void)otherDeviceIdsOfUser:(NSString*)userId
                     success:(void(^)(NSArray<NSString*> *deviceIds))success
                     failure:(void(^)(NSError *error))failure
{
    [self.crypto downloadKeys:@[userId] forceDownload:YES success:^(MXUsersDevicesMap<MXDeviceInfo *> *usersDevicesInfoMap, NSDictionary<NSString *,MXCrossSigningInfo *> *crossSigningKeysMap) {
        
        
        NSMutableArray *deviceIds = [[usersDevicesInfoMap deviceIdsForUser:userId] mutableCopy];
        
        MXCredentials *myUser = self.crypto.mxSession.matrixRestClient.credentials;
        if ([userId isEqualToString:myUser.userId])
        {
            [deviceIds removeObject:myUser.deviceId];
        }
        
        success(deviceIds);
    } failure:failure];
}
    
- (void)requestVerificationByToDeviceWithUserId2:(NSString*)userId
                                       deviceIds:(NSArray<NSString*>*)deviceIds
                                         methods:(NSArray<NSString*>*)methods
                                         success:(void(^)(MXKeyVerificationRequest *request))success
                                         failure:(void(^)(NSError *error))failure
{
    NSParameterAssert(deviceIds.count > 0);
    
    MXKeyVerificationRequestByToDeviceJSONModel *requestJSONModel = [MXKeyVerificationRequestByToDeviceJSONModel new];
    requestJSONModel.fromDevice = _crypto.myDevice.deviceId;
    requestJSONModel.transactionId = [MXTools generateSecret];
    requestJSONModel.methods = methods;
    requestJSONModel.timestamp = [NSDate date].timeIntervalSince1970 * 1000;
    
    MXUsersDevicesMap<NSDictionary*> *contentMap = [[MXUsersDevicesMap alloc] init];
    
    for (NSString *deviceId in deviceIds)
    {
        [contentMap setObject:requestJSONModel.JSONDictionary forUser:userId andDevice:deviceId];
    }
    
    [self.crypto.matrixRestClient sendToDevice:kMXMessageTypeKeyVerificationRequest contentMap:contentMap txnId:nil success:^{
        
        MXEvent *event = [MXEvent modelFromJSON:@{
                                                  @"sender": self.crypto.mxSession.myUserId,
                                                  @"type": kMXMessageTypeKeyVerificationRequest,
                                                  @"content": requestJSONModel.JSONDictionary
                                                  }];
        MXKeyVerificationByToDeviceRequest *request = [[MXKeyVerificationByToDeviceRequest alloc] initWithEvent:event andManager:self to:userId requestedOtherDeviceIds:deviceIds];
        [request updateState:MXKeyVerificationRequestStatePending notifiy:YES];
        [self addPendingRequest:request notify:NO];
        
        success(request);
        
    } failure:failure];
}

- (void)requestVerificationByDMWithUserId:(NSString*)userId
                                   roomId:(nullable NSString*)roomId
                             fallbackText:(NSString*)fallbackText
                                  methods:(NSArray<NSString*>*)methods
                                  success:(void(^)(MXKeyVerificationRequest *request))success
                                  failure:(void(^)(NSError *error))failure
{
    if (roomId)
    {
        [self requestVerificationByDMWithUserId2:userId roomId:roomId fallbackText:fallbackText methods:methods success:success failure:failure];
    }
    else
    {
        // Use an existing direct room if any
        MXRoom *room = [self.crypto.mxSession directJoinedRoomWithUserId:userId];
        if (room)
        {
            [self requestVerificationByDMWithUserId2:userId roomId:room.roomId fallbackText:fallbackText methods:methods success:success failure:failure];
        }
        else
        {
            // Create a new DM with E2E by default if possible
            [self.crypto.mxSession canEnableE2EByDefaultInNewRoomWithUsers:@[userId] success:^(BOOL canEnableE2E) {
                MXRoomCreationParameters *roomCreationParameters = [MXRoomCreationParameters parametersForDirectRoomWithUser:userId];
                
                if (canEnableE2E)
                {
                    roomCreationParameters.initialStateEvents = @[
                                                                  [MXRoomCreationParameters initialStateEventForEncryptionWithAlgorithm:kMXCryptoMegolmAlgorithm
                                                                   ]];
                }

                [self.crypto.mxSession createRoomWithParameters:roomCreationParameters success:^(MXRoom *room) {
                    [self requestVerificationByDMWithUserId2:userId roomId:room.roomId fallbackText:fallbackText methods:methods success:success failure:failure];
                } failure:failure];
            } failure:failure];
        }
    }
}

- (void)requestVerificationByDMWithUserId2:(NSString*)userId
                                    roomId:(NSString*)roomId
                              fallbackText:(NSString*)fallbackText
                                   methods:(NSArray<NSString*>*)methods
                                   success:(void(^)(MXKeyVerificationRequest *request))success
                                   failure:(void(^)(NSError *error))failure
{
    NSLog(@"[MXKeyVerification] requestVerificationByDMWithUserId: %@. RoomId: %@", userId, roomId);
    
    MXKeyVerificationRequestByDMJSONModel *request = [MXKeyVerificationRequestByDMJSONModel new];
    request.body = fallbackText;
    request.methods = methods;
    request.to = userId;
    request.fromDevice = _crypto.myDevice.deviceId;
    
    [self sendEventOfType:kMXEventTypeStringRoomMessage toRoom:roomId content:request.JSONDictionary success:^(NSString *eventId) {
        
        // Build the corresponding the event
        MXRoom *room = [self.crypto.mxSession roomWithRoomId:roomId];
        MXEvent *event = [room fakeRoomMessageEventWithEventId:eventId andContent:request.JSONDictionary];
        
        MXKeyVerificationRequest *request = [self verificationRequestInDMEvent:event];
        [request updateState:MXKeyVerificationRequestStatePending notifiy:YES];
        [self addPendingRequest:request notify:NO];
        
        success(request);
    } failure:failure];
}

#pragma mark Current requests

- (NSArray<MXKeyVerificationRequest*> *)pendingRequests
{
    return pendingRequestsMap.allValues;
}


#pragma mark Transactions

- (void)beginKeyVerificationWithUserId:(NSString*)userId
                           andDeviceId:(NSString*)deviceId
                                method:(NSString*)method
                               success:(void(^)(MXKeyVerificationTransaction *transaction))success
                               failure:(void(^)(NSError *error))failure
{
    [self beginKeyVerificationWithUserId:userId andDeviceId:deviceId transactionId:nil dmRoomId:nil dmEventId:nil method:method success:success failure:failure];
}

- (void)beginKeyVerificationFromRequest:(MXKeyVerificationRequest*)request
                                 method:(NSString*)method
                                success:(void(^)(MXKeyVerificationTransaction *transaction))success
                                failure:(void(^)(NSError *error))failure
{
    NSLog(@"[MXKeyVerification] beginKeyVerificationFromRequest: event: %@", request.requestId);
    
    // Sanity checks
    if (!request.otherDevice)
    {
        NSError *error = [NSError errorWithDomain:MXKeyVerificationErrorDomain
                                             code:MXKeyVerificationUnknownDeviceCode
                                         userInfo:@{
                                                    NSLocalizedDescriptionKey: [NSString stringWithFormat:@"from_device not found"]
                                                    }];
        failure(error);
        return;
    }
    
    if (request.state != MXKeyVerificationRequestStateAccepted && request.state != MXKeyVerificationRequestStateReady)
    {
        NSError *error = [NSError errorWithDomain:MXKeyVerificationErrorDomain
                                             code:MXKeyVerificationInvalidStateCode
                                         userInfo:@{
                                                    NSLocalizedDescriptionKey: [NSString stringWithFormat:@"The verification request has not been accepted. Current state: %@", @(request.state)]
                                                    }];
        failure(error);
        return;
    }
    
    switch (request.transport)
    {
        case MXKeyVerificationTransportDirectMessage:
            if ([request isKindOfClass:MXKeyVerificationByDMRequest.class])
            {
                MXKeyVerificationByDMRequest *requestByDM = (MXKeyVerificationByDMRequest*)request;
                [self beginKeyVerificationWithUserId:request.otherUser andDeviceId:request.otherDevice transactionId:request.requestId dmRoomId:requestByDM.roomId dmEventId:requestByDM.eventId method:method success:^(MXKeyVerificationTransaction *transaction) {
                    [self removePendingRequestWithRequestId:request.requestId];
                    success(transaction);
                } failure:failure];
            }
            break;
            
        case MXKeyVerificationTransportToDevice:
            [self beginKeyVerificationWithUserId:request.otherUser andDeviceId:request.otherDevice transactionId:request.requestId dmRoomId:nil dmEventId:nil method:method success:^(MXKeyVerificationTransaction * _Nonnull transaction) {
                [self removePendingRequestWithRequestId:request.requestId];
                success(transaction);
            } failure:failure];
            break;
    }
}

- (void)beginKeyVerificationWithUserId:(NSString*)userId
                           andDeviceId:(NSString*)deviceId
                         transactionId:(nullable NSString*)transactionId
                              dmRoomId:(nullable NSString*)dmRoomId
                             dmEventId:(nullable NSString*)dmEventId
                                method:(NSString*)method
                               success:(void(^)(MXKeyVerificationTransaction *transaction))success
                               failure:(void(^)(NSError *error))failure
{
    NSLog(@"[MXKeyVerification] beginKeyVerification: device: %@:%@ roomId: %@ method:%@", userId, deviceId, dmRoomId, method);

    // Make sure we have other device keys
    [self loadDeviceWithDeviceId:deviceId andUserId:userId success:^(MXDeviceInfo *otherDevice) {

        MXKeyVerificationTransaction *transaction;
        NSError *error;

        // We support only SAS at the moment
        if ([method isEqualToString:MXKeyVerificationMethodSAS])
        {
            MXOutgoingSASTransaction *sasTransaction = [[MXOutgoingSASTransaction alloc] initWithOtherDevice:otherDevice andManager:self];
            if (transactionId)
            {
                sasTransaction.transactionId = transactionId;
            }

            // Detect verification by DM
            if (dmRoomId)
            {
                [sasTransaction setDirectMessageTransportInRoom:dmRoomId originalEvent:dmEventId];
            }

            [sasTransaction start];

            transaction = sasTransaction;
            [self addTransaction:transaction];
        }
        else
        {
            error = [NSError errorWithDomain:MXKeyVerificationErrorDomain
                                        code:MXKeyVerificationUnsupportedMethodCode
                                    userInfo:@{
                                               NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unsupported verification method: %@", method]
                                               }];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (transaction)
            {
                success(transaction);
            }
            else
            {
                failure(error);
            }
        });

    } failure:^(NSError *error) {
        NSLog(@"[MXKeyVerification] beginKeyVerification: Error: %@", error);
        failure(error);
    }];
}

- (void)createQRCodeTransactionFromRequest:(MXKeyVerificationRequest*)request
                                qrCodeData:(nullable MXQRCodeData*)qrCodeData
                                   success:(void(^)(MXQRCodeTransaction *transaction))success
                                   failure:(void(^)(NSError *error))failure
{
    NSLog(@"[MXKeyVerification] createQRCodeTransactionFromRequest: event: %@", request.requestId);
    
    // Sanity checks
    if (!request.otherDevice)
    {
        NSError *error = [NSError errorWithDomain:MXKeyVerificationErrorDomain
                                             code:MXKeyVerificationUnknownDeviceCode
                                         userInfo:@{
                                                    NSLocalizedDescriptionKey: [NSString stringWithFormat:@"from_device not found"]
                                                    }];
        failure(error);
        return;
    }
    
    if (request.state != MXKeyVerificationRequestStatePending)
    {
        NSError *error = [NSError errorWithDomain:MXKeyVerificationErrorDomain
                                             code:MXKeyVerificationInvalidStateCode
                                         userInfo:@{
                                                    NSLocalizedDescriptionKey: [NSString stringWithFormat:@"The verification request has not been accepted. Current state: %@", @(request.state)]
                                                    }];
        failure(error);
        return;
    }
    
    NSString *dmRoomId;
    NSString *dmEventId;
    
    switch (request.transport)
    {
        case MXKeyVerificationTransportDirectMessage:
            if ([request isKindOfClass:MXKeyVerificationByDMRequest.class])
            {
                MXKeyVerificationByDMRequest *requestByDM = (MXKeyVerificationByDMRequest*)request;
                
                dmRoomId = requestByDM.roomId;
                dmEventId = requestByDM.eventId;
            }
            break;
        case MXKeyVerificationTransportToDevice:
            break;
    }
    
    [self createQRCodeTransactionWithQRCodeData:qrCodeData
                                         userId:request.otherUser
                                       deviceId:request.otherDevice
                                  transactionId:request.requestId
                                       dmRoomId:dmRoomId
                                      dmEventId:dmEventId
                                        success:success
                                        failure:failure];
}

- (void)createQRCodeTransactionWithQRCodeData:(nullable MXQRCodeData*)qrCodeData
                                       userId:(NSString*)userId
                                     deviceId:(NSString*)deviceId
                                transactionId:(nullable NSString*)transactionId
                                     dmRoomId:(nullable NSString*)dmRoomId
                                    dmEventId:(nullable NSString*)dmEventId
                                      success:(void(^)(MXQRCodeTransaction *transaction))success
                                      failure:(void(^)(NSError *error))failure
{
    NSLog(@"[MXKeyVerification] createQRCodeTransaction: device: %@:%@ roomId: %@", userId, deviceId, dmRoomId);
    
    // Make sure we have other device keys
    [self loadDeviceWithDeviceId:deviceId andUserId:userId success:^(MXDeviceInfo *otherDevice) {
        
        MXQRCodeTransaction *transaction = [[MXQRCodeTransaction alloc] initWithOtherDevice:otherDevice qrCodeData:qrCodeData andManager:self];
        
        
        if (transactionId)
        {
            transaction.transactionId = transactionId;
        }
        
        // Detect verification by DM
        if (dmRoomId)
        {
            [transaction setDirectMessageTransportInRoom:dmRoomId originalEvent:dmEventId];
        }
        
        [self addTransaction:transaction];
        
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (transaction)
            {
                success(transaction);
            }
            else
            {
                NSError *error = [NSError errorWithDomain:MXKeyVerificationErrorDomain
                                                     code:MXKeyVerificationUnknownIdentifier
                                                 userInfo:@{
                                                            NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Fail to create transaction with id: %@", transactionId]
                                                            }];
                
                failure(error);
            }
        });
        
    } failure:^(NSError *error) {
        NSLog(@"[MXKeyVerification] createQRCodeTransaction: Error: %@", error);
        dispatch_async(dispatch_get_main_queue(), ^{
            failure(error);
        });
    }];
}

- (void)removeQRCodeTransactionWithTransactionId:(NSString*)transactionId
{
    MXQRCodeTransaction *qrCodeTransaction = [self qrCodeTransactionWithTransactionId:transactionId];
    
    if (qrCodeTransaction)
    {
        [self removeTransactionWithTransactionId:qrCodeTransaction.transactionId];
    }
}

- (void)transactions:(void(^)(NSArray<MXKeyVerificationTransaction*> *transactions))complete
{
    MXWeakify(self);
    dispatch_async(self->cryptoQueue, ^{
        MXStrongifyAndReturnIfNil(self);

        NSArray<MXKeyVerificationTransaction*> *transactions = self->transactions.allObjects;
        dispatch_async(dispatch_get_main_queue(), ^{
            complete(transactions);
        });
    });
}


#pragma mark Verification status

- (nullable MXHTTPOperation *)keyVerificationFromKeyVerificationEvent:(MXEvent*)event
                                                              success:(void(^)(MXKeyVerification *keyVerification))success
                                                              failure:(void(^)(NSError *error))failure
{
    MXKeyVerificationTransport transport = MXKeyVerificationTransportToDevice;
    MXKeyVerification *keyVerification;

    // Check if it is a Verification by DM Event
    NSString *keyVerificationId = [self keyVerificationIdFromDMEvent:event];
    if (keyVerificationId)
    {
        transport = MXKeyVerificationTransportDirectMessage;
    }
    else
    {
        NSError *error = [NSError errorWithDomain:MXKeyVerificationErrorDomain
                                             code:MXKeyVerificationUnknownIdentifier
                                         userInfo:@{
                                                    NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unknown id or not supported transport"]
                                                    }];
        failure(error);
        return nil;
    }

    keyVerification = [self pendingKeyVerificationWithKeyVerificationId:keyVerificationId];
    if (keyVerification)
    {
        success(keyVerification);
        return nil;
    }


    return [statusResolver keyVerificationWithKeyVerificationId:keyVerificationId event:event transport:transport success:success failure:failure];
}

- (nullable NSString *)keyVerificationIdFromDMEvent:(MXEvent*)event
{
    NSString *keyVerificationId;

    // Original event or one of the thread?
    if (event.eventType == MXEventTypeRoomMessage
        && [event.content[@"msgtype"] isEqualToString:kMXMessageTypeKeyVerificationRequest])
    {
        keyVerificationId = event.eventId;
    }
    else if ([self isVerificationEventType:event.type])
    {
        MXKeyVerificationJSONModel *keyVerificationJSONModel;
        MXJSONModelSetMXJSONModel(keyVerificationJSONModel, MXKeyVerificationJSONModel, event.content);
        keyVerificationId = keyVerificationJSONModel.relatedEventId;
    }

    return keyVerificationId;
}

- (nullable MXKeyVerification *)pendingKeyVerificationWithKeyVerificationId:(NSString*)keyVerificationId
{
    MXKeyVerificationTransaction *transaction = [self transactionWithTransactionId:keyVerificationId];
    MXKeyVerificationRequest *request = [self pendingRequestWithRequestId:keyVerificationId];
    
    return [self->statusResolver keyVerificationFromRequest:request andTransaction:transaction];
}

#pragma mark - SDK-Private methods -

+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kMXKeyVerificationManagerVerificationEventTypes = @[
                                                    kMXMessageTypeKeyVerificationRequest,
                                                    kMXEventTypeStringKeyVerificationReady,
                                                    kMXEventTypeStringKeyVerificationStart,
                                                    kMXEventTypeStringKeyVerificationAccept,
                                                    kMXEventTypeStringKeyVerificationKey,
                                                    kMXEventTypeStringKeyVerificationMac,
                                                    kMXEventTypeStringKeyVerificationCancel,
                                                    kMXEventTypeStringKeyVerificationDone
                                                    ];
    });
}

- (instancetype)initWithCrypto:(MXCrypto *)crypto
{
    self = [super init];
    if (self)
    {
        _crypto = crypto;
        cryptoQueue = self.crypto.cryptoQueue;

        transactions = [MXUsersDevicesMap new];

        // Observe incoming to-device events
        [self setupIncomingToDeviceEvents];

        // Observe incoming DM events
        [self setupIncomingDMEvents];

        _requestTimeout = MXRequestDefaultTimeout;
        pendingRequestsMap = [NSMutableDictionary dictionary];
        [self setupVericationByDMRequests];

        statusResolver = [[MXKeyVerificationStatusResolver alloc] initWithManager:self matrixSession:crypto.mxSession];
        
        _qrCodeDataBuilder = [MXQRCodeDataBuilder new];
    }
    return self;
}

- (void)dealloc
{
    if (transactionTimeoutTimer)
    {
        [transactionTimeoutTimer invalidate];
        transactionTimeoutTimer = nil;
    }
}


#pragma mark - Requests

- (MXHTTPOperation*)sendToOtherInRequest:(MXKeyVerificationRequest*)request
                               eventType:(NSString*)eventType
                                 content:(NSDictionary*)content
                                 success:(dispatch_block_t)success
                                 failure:(void (^)(NSError *error))failure
{
    NSLog(@"[MXKeyVerification] sendToOtherInRequest: eventType: %@\n%@",
          eventType, content);
    
    MXHTTPOperation *operation;
    switch (request.transport)
    {
        case MXKeyVerificationTransportDirectMessage:
            if ([request isKindOfClass:MXKeyVerificationByDMRequest.class])
            {
                MXKeyVerificationByDMRequest *requestByDM = (MXKeyVerificationByDMRequest*)request;
                operation = [self sendMessage:request.otherUser roomId:requestByDM.roomId eventType:eventType relatedTo:requestByDM.eventId content:content success:success failure:failure];
            }
            break;
            
        case MXKeyVerificationTransportToDevice:
            if (request.otherDevice)
            {
                operation = [self sendToDevice:request.otherUser deviceId:request.otherDevice eventType:eventType content:content success:success failure:failure];
            }
            else
            {
                // This happens when cancelling our own request.
                // There is no otherDevice in this case. We broadcast to all devices we made the request to.
                if ([request isKindOfClass:MXKeyVerificationByToDeviceRequest.class])
                {
                    MXKeyVerificationByToDeviceRequest *requestByToDevice = (MXKeyVerificationByToDeviceRequest*)request;
                    if (requestByToDevice.requestedOtherDeviceIds)
                    {
                        operation = [self sendToDevices:request.otherUser deviceIds:requestByToDevice.requestedOtherDeviceIds eventType:eventType content:content success:success failure:failure];
                    }
                }
            }
                
            break;
    }
    
    // We should be always able to talk to the other peer
    NSParameterAssert(operation);
    
    return operation;
}

- (void)cancelVerificationRequest:(MXKeyVerificationRequest*)request
                          success:(void(^)(void))success
                          failure:(void(^)(NSError *error))failure
{
    MXTransactionCancelCode *cancelCode = MXTransactionCancelCode.user;

    // If there is transaction in progress, cancel it
    MXKeyVerificationTransaction *transaction = [self transactionWithTransactionId:request.requestId];
    if (transaction)
    {
        [self cancelTransaction:transaction code:cancelCode success:success failure:failure];
    }
    else
    {
        // Else only cancel the request
        MXKeyVerificationCancel *cancel = [MXKeyVerificationCancel new];
        cancel.transactionId = request.requestId;
        cancel.code = cancelCode.value;
        cancel.reason = cancelCode.humanReadable;
        
        [self sendToOtherInRequest:request eventType:kMXEventTypeStringKeyVerificationCancel content:cancel.JSONDictionary success:success failure:failure];
    }
}


#pragma mark - Transactions

- (MXHTTPOperation*)sendToOtherInTransaction:(MXKeyVerificationTransaction*)transaction
                                   eventType:(NSString*)eventType
                                     content:(NSDictionary*)content
                                     success:(void (^)(void))success
                                     failure:(void (^)(NSError *error))failure
{
    NSLog(@"[MXKeyVerification] sendToOtherInTransaction%@: eventType: %@\n%@",
          transaction.dmEventId ? @"(DM)" : @"",
          eventType, content);

    MXHTTPOperation *operation;
    switch (transaction.transport)
    {
        case MXKeyVerificationTransportToDevice:
            operation = [self sendToDevice:transaction.otherUserId deviceId:transaction.otherDeviceId eventType:eventType content:content success:success failure:failure];
            break;
        case MXKeyVerificationTransportDirectMessage:
            operation = [self sendMessage:transaction.otherUserId roomId:transaction.dmRoomId eventType:eventType relatedTo:transaction.dmEventId content:content success:success failure:failure];
            break;
    }

    return operation;
}

- (void)cancelTransaction:(MXKeyVerificationTransaction*)transaction
                     code:(MXTransactionCancelCode*)code
                  success:(void (^)(void))success
                  failure:(void (^)(NSError *error))failure
{
    NSLog(@"[MXKeyVerification] cancelTransaction. code: %@", code.value);
    
    MXKeyVerificationCancel *cancel = [MXKeyVerificationCancel new];
    cancel.transactionId = transaction.transactionId;
    cancel.code = code.value;
    cancel.reason = code.humanReadable;
    
    [self sendToOtherInTransaction:transaction eventType:kMXEventTypeStringKeyVerificationCancel content:cancel.JSONDictionary success:^{
        
        transaction.reasonCancelCode = code;
        
        if (success)
        {
            success();
        }
        
    } failure:^(NSError *error) {
        
        NSLog(@"[MXKeyVerification] cancelTransaction. Error: %@", error);
        if (failure)
        {
            failure(error);
        }
    }];
    
    [self removeTransactionWithTransactionId:transaction.transactionId];
}

// Special handling for incoming requests that are not yet valid transactions
- (void)cancelTransactionFromStartEvent:(MXEvent*)event code:(MXTransactionCancelCode*)code
{
    NSLog(@"[MXKeyVerification] cancelTransactionFromStartEvent. code: %@", code.value);

    MXKeyVerificationStart *keyVerificationStart;
    MXJSONModelSetMXJSONModel(keyVerificationStart, MXKeyVerificationStart, event.content);

    if (keyVerificationStart)
    {
        MXKeyVerificationCancel *cancel = [MXKeyVerificationCancel new];
        cancel.transactionId = keyVerificationStart.transactionId;
        cancel.code = code.value;
        cancel.reason = code.humanReadable;

        // Which transport? DM or to_device events?
        if (keyVerificationStart.relatedEventId)
        {
            [self sendMessage:event.sender roomId:event.roomId eventType:kMXEventTypeStringKeyVerificationCancel relatedTo:keyVerificationStart.relatedEventId content:cancel.JSONDictionary success:nil failure:^(NSError *error) {

                NSLog(@"[MXKeyVerification] cancelTransactionFromStartEvent. Error: %@", error);
            }];
        }
        else
        {
            [self sendToDevice:event.sender deviceId:keyVerificationStart.fromDevice eventType:kMXEventTypeStringKeyVerificationCancel content:cancel.JSONDictionary success:nil failure:^(NSError *error) {

                NSLog(@"[MXKeyVerification] cancelTransactionFromStartEvent. Error: %@", error);
            }];
        }

        [self removeTransactionWithTransactionId:keyVerificationStart.transactionId];
    }
}


#pragma mark - Incoming events

- (void)handleKeyVerificationEvent:(MXEvent*)event isToDeviceEvent:(BOOL)isToDeviceEvent
{
    dispatch_async(cryptoQueue, ^{

        BOOL eventFromMyUser = [event.sender isEqualToString:self.crypto.mxSession.myUserId];
        BOOL isEventIntendedForMyDevice = isToDeviceEvent || !eventFromMyUser;

        NSLog(@"[MXKeyVerification] handleKeyVerificationEvent(from my user: %@, isToDeviceEvent: %@, intendedForMyDevice: %@): eventType: %@ \n%@",
              eventFromMyUser ? @"YES": @"NO",
              isToDeviceEvent ? @"YES": @"NO",
              isEventIntendedForMyDevice ? @"MAYBE": @"NO",     // MAYBE because it depends on the type of event
              event.type,
              event.clearEvent ? event.clearEvent.JSONDictionary : event.JSONDictionary);

        switch (event.eventType)
        {
            case MXEventTypeKeyVerificationRequest:
                // Only requests by to_device come here
                [self handleToDeviceRequestEvent:event];
                break;
                
            case MXEventTypeKeyVerificationReady:
                [self handleReadyEvent:event isToDeviceEvent:isToDeviceEvent];
                break;
                
            case MXEventTypeKeyVerificationStart:
                if (isEventIntendedForMyDevice)
                {
                    [self handleStartEvent:event];
                }
                break;

            case MXEventTypeKeyVerificationCancel:
                if (isEventIntendedForMyDevice)
                {
                    [self handleCancelEvent:event];
                }
                break;

            case MXEventTypeKeyVerificationAccept:
                if (isEventIntendedForMyDevice)
                {
                    [self handleAcceptEvent:event];
                }
                break;

            case MXEventTypeKeyVerificationKey:
                if (isEventIntendedForMyDevice)
                {
                    [self handleKeyEvent:event];
                }
                break;

            case MXEventTypeKeyVerificationMac:
                if (isEventIntendedForMyDevice)
                {
                    [self handleMacEvent:event];
                }
                break;
            case MXEventTypeKeyVerificationDone:
                if (isEventIntendedForMyDevice)
                {
                    [self handleDoneEvent:event];
                }
                break;
            default:
                break;
        }
    });
}


- (void)handleToDeviceRequestEvent:(MXEvent*)event
{
    NSLog(@"[MXKeyVerification] handleToDeviceRequestEvent");
    
    MXKeyVerificationByToDeviceRequest *keyVerificationRequest = [[MXKeyVerificationByToDeviceRequest alloc] initWithEvent:event andManager:self to:self.crypto.mxSession.myUserId requestedOtherDeviceIds:@[]];
    
    if (!keyVerificationRequest)
    {
        return;
    }
    
    [self addPendingRequest:keyVerificationRequest notify:YES];
}

- (void)handleReadyEvent:(MXEvent*)event isToDeviceEvent:(BOOL)isToDeviceEvent
{
    NSLog(@"[MXKeyVerification] handleReadyEvent");
    
    MXKeyVerificationReady *keyVerificationReady;
    MXJSONModelSetMXJSONModel(keyVerificationReady, MXKeyVerificationReady, event.content);
    
    if (!keyVerificationReady)
    {
        return;
    }
    
    NSString *requestId = keyVerificationReady.transactionId;
    MXKeyVerificationRequest *request = [self pendingRequestWithRequestId:requestId];
    
    if (request)
    {
        MXCredentials *myCreds = _crypto.mxSession.matrixRestClient.credentials;

        BOOL eventFromMyUser = [event.sender isEqualToString:myCreds.userId];
        BOOL isEventIntendedForMyDevice = isToDeviceEvent || !eventFromMyUser;
        
        if (isEventIntendedForMyDevice)
        {
            [request handleReady:keyVerificationReady];
        }
        else
        {
            BOOL eventFromMyDevice = [keyVerificationReady.fromDevice isEqualToString:myCreds.deviceId];
            if (!eventFromMyDevice)
            {
                // This is a ready response to a request the user made from another device
                // Remove it from pending requests will ignore any other events related to this request id
                NSLog(@"[MXKeyVerification] handleReadyEvent: The request (%@) has been accepted on another device. Ignore it.", requestId);
                [self removePendingRequestWithRequestId:request.requestId];
            }
        }
    }
}

- (void)handleCancelEvent:(MXEvent*)event
{
    NSLog(@"[MXKeyVerification] handleCancelEvent");

    MXKeyVerificationCancel *cancelContent;
    MXJSONModelSetMXJSONModel(cancelContent, MXKeyVerificationCancel, event.content);

    if (cancelContent)
    {
        MXKeyVerificationTransaction *transaction = [self transactionWithTransactionId:cancelContent.transactionId];
        if (transaction)
        {
            [transaction handleCancel:cancelContent];
            [self removeTransactionWithTransactionId:transaction.transactionId];
        }

        NSString *requestId = cancelContent.transactionId;
        MXKeyVerificationRequest *request = [self pendingRequestWithRequestId:requestId];
        if (request)
        {
            [request handleCancel:cancelContent];
        }
    }
    else
    {
        NSLog(@"[MXKeyVerification] handleCancelEvent. Invalid event: %@", event.JSONDictionary);
    }
}

- (void)handleStartEvent:(MXEvent*)event
{
    NSLog(@"[MXKeyVerification] handleStartEvent");
    
    MXSASKeyVerificationStart *keyVerificationSASStart;
    MXJSONModelSetMXJSONModel(keyVerificationSASStart, MXSASKeyVerificationStart, event.content);
    
    if (keyVerificationSASStart)
    {
        [self handleSASKeyVerificationStart:keyVerificationSASStart withEvent:event];
        return;
    }
    
    MXQRCodeKeyVerificationStart *keyVerificationQRCodeStart;
    MXJSONModelSetMXJSONModel(keyVerificationQRCodeStart, MXQRCodeKeyVerificationStart, event.content);
    
    if (keyVerificationQRCodeStart)
    {
        [self handleQRCodeKeyVerificationStart:keyVerificationQRCodeStart withEvent:event];
        return;
    }
    
    NSLog(@"[MXKeyVerification] handleStartEvent: Unknown start event %@", event);
    [self cancelTransactionFromStartEvent:event code:MXTransactionCancelCode.unknownMethod];
}

#pragma mark SAS

- (void)handleSASKeyVerificationStart:(MXSASKeyVerificationStart*)keyVerificationStart withEvent:(MXEvent*)event
{
    NSLog(@"[MXKeyVerification] handleSASKeyVerificationStart");
    
    if (!keyVerificationStart)
    {
        return;
    }
    
    NSString *requestId = keyVerificationStart.transactionId;
    MXKeyVerificationRequest *request = [self pendingRequestWithRequestId:requestId];
    if (request)
    {
        // We have a start response. The request is complete
        [self removePendingRequestWithRequestId:request.requestId];
    }
    
    if ([event.relatesTo.relationType isEqualToString:MXEventRelationTypeReference])
    {
        if (!request
            || (request.isFromMyUser && !request.isFromMyDevice))
        {
            // This is a start response to a request we did not make. Ignore it
            NSLog(@"[MXKeyVerification] handleStartEvent: Start event for verification by DM(%@) not triggered by this device. Ignore it", requestId);
            return;
        }
    }
    
    if (!keyVerificationStart.isValid)
    {
        if (keyVerificationStart.transactionId && keyVerificationStart.fromDevice)
        {
            [self cancelTransactionFromStartEvent:event code:MXTransactionCancelCode.invalidMessage];
        }
        
        return;
    }
    
    
    // Make sure we have other device keys
    [self loadDeviceWithDeviceId:keyVerificationStart.fromDevice andUserId:event.sender success:^(MXDeviceInfo *otherDevice) {
        
        MXKeyVerificationTransaction *existingTransaction = [self transactionWithUser:event.sender andDevice:keyVerificationStart.fromDevice];
        
        if ([existingTransaction isKindOfClass:MXQRCodeTransaction.class])
        {
            MXQRCodeTransaction *existingQRCodeTransaction = (MXQRCodeTransaction*)existingTransaction;
            
            if (existingQRCodeTransaction.state == MXQRCodeTransactionStateUnknown)
            {
                // Remove fake QR code transaction
                [self removeQRCodeTransactionWithTransactionId:existingQRCodeTransaction.transactionId];
                existingTransaction = nil;
            }
        }

        if (existingTransaction)
        {
            NSLog(@"[MXKeyVerification] handleStartEvent: already existing transaction. Cancel both");
            
            [existingTransaction cancelWithCancelCode:MXTransactionCancelCode.invalidMessage];
            [self cancelTransactionFromStartEvent:event code:MXTransactionCancelCode.invalidMessage];
            return;
        }
        
        // Multiple keyshares between two devices: any two devices may only have at most one key verification in flight at a time.
        NSArray<MXKeyVerificationTransaction*> *transactionsWithUser = [self transactionsWithUser:event.sender];
        if (transactionsWithUser.count)
        {
            NSLog(@"[MXKeyVerification] handleStartEvent: already existing transaction with the user. Cancel both");
            
            [transactionsWithUser[0] cancelWithCancelCode:MXTransactionCancelCode.invalidMessage];
            [self cancelTransactionFromStartEvent:event code:MXTransactionCancelCode.invalidMessage];
            return;
        }
                    
        MXIncomingSASTransaction *transaction = [[MXIncomingSASTransaction alloc] initWithOtherDevice:otherDevice startEvent:event andManager:self];
        if (transaction)
        {
            if ([self isCreationDateValid:transaction])
            {
                [self addTransaction:transaction];
                
                if (request)
                {
                    NSLog(@"[MXKeyVerification] handleStartEvent: auto accept incoming transaction in response of a request");
                    [transaction accept];
                }
            }
            else
            {
                NSLog(@"[MXKeyVerification] handleStartEvent: Expired transaction: %@", transaction);
                [self cancelTransactionFromStartEvent:event code:MXTransactionCancelCode.timeout];
            }
        }
        else
        {
            NSLog(@"[MXKeyVerification] handleStartEvent: Unsupported transaction method: %@", event);
            [self cancelTransactionFromStartEvent:event code:MXTransactionCancelCode.unknownMethod];
        }
        
    } failure:^(NSError *error) {
        NSLog(@"[MXKeyVerification] handleStartEvent: Failed to get other device keys: %@", event);
        [self cancelTransactionFromStartEvent:event code:MXTransactionCancelCode.invalidMessage];
    }];
}

- (void)handleAcceptEvent:(MXEvent*)event
{
    NSLog(@"[MXKeyVerification] handleAcceptEvent");

    MXKeyVerificationAccept *acceptContent;
    MXJSONModelSetMXJSONModel(acceptContent, MXKeyVerificationAccept, event.content);

    if (acceptContent)
    {
        MXSASTransaction *transaction = [self sasTransactionWithTransactionId:acceptContent.transactionId];
        if (transaction)
        {
            [transaction handleAccept:acceptContent];
        }
        else
        {
            NSLog(@"[MXKeyVerification] handleAcceptEvent. Unknown SAS transaction: %@", event);
        }
    }
    else
    {
        NSLog(@"[MXKeyVerification] handleAcceptEvent. Invalid event: %@", event);
    }
}

- (void)handleKeyEvent:(MXEvent*)event
{
    NSLog(@"[MXKeyVerification] handleKeyEvent");

    MXKeyVerificationKey *keyContent;
    MXJSONModelSetMXJSONModel(keyContent, MXKeyVerificationKey, event.content);

    if (keyContent)
    {
        MXSASTransaction *transaction = [self sasTransactionWithTransactionId:keyContent.transactionId];
        if (transaction)
        {
            [transaction handleKey:keyContent];
        }
        else
        {
            NSLog(@"[MXKeyVerification] handleKeyEvent. Unknown SAS transaction: %@", event);
        }
    }
    else
    {
        NSLog(@"[MXKeyVerification] handleKeyEvent. Invalid event: %@", event);
    }
}

- (void)handleMacEvent:(MXEvent*)event
{
    NSLog(@"[MXKeyVerification] handleMacEvent");

    MXKeyVerificationMac *macContent;
    MXJSONModelSetMXJSONModel(macContent, MXKeyVerificationMac, event.content);

    if (macContent)
    {
        MXSASTransaction *transaction = [self sasTransactionWithTransactionId:macContent.transactionId];
        if (transaction)
        {
            [transaction handleMac:macContent];
        }
        else
        {
            NSLog(@"[MXKeyVerification] handleMacEvent. Unknown SAS transaction: %@", event);
        }
    }
    else
    {
        NSLog(@"[MXKeyVerification] handleMacEvent. Invalid event: %@", event);
    }
}

- (void)handleDoneEvent:(MXEvent*)event
{
    MXKeyVerificationDone *doneEvent;
    MXJSONModelSetMXJSONModel(doneEvent, MXKeyVerificationDone, event.content);
    
    if (doneEvent)
    {
        MXQRCodeTransaction *qrCodeTransaction = [self qrCodeTransactionWithTransactionId:doneEvent.transactionId];
        if (qrCodeTransaction)
        {
            [qrCodeTransaction handleDone:doneEvent];
        }
        else
        {
            NSLog(@"[MXKeyVerification] handleDoneEvent. Not handled for SAS transaction: %@", event);
        }
        
        MXKeyVerificationTransaction *transaction = [self transactionWithTransactionId:doneEvent.transactionId];
        if (transaction && transaction.otherDeviceId)
        {
            BOOL eventFromMyDevice = [transaction.otherDeviceId isEqualToString:self.crypto.mxSession.myDeviceId];
            if (!eventFromMyDevice)
            {
                NSLog(@"[MXKeyVerification] handleDoneEvent: requestAllPrivateKeys");
                [self.crypto requestAllPrivateKeys];
            }
        }
        else
        {
            // The done event from the other can happen long time after.
            // That means the transaction can be no more in memory. In this case, request private keys with no condition
            NSLog(@"[MXKeyVerification] handleDoneEvent: requestAllPrivateKeys anyway");
            [self.crypto requestAllPrivateKeys];
        }
    }
    else
    {
        NSLog(@"[MXKeyVerification] handleMacEvent. Invalid event: %@", event);
    }
}

#pragma mark QR Code

- (void)handleQRCodeKeyVerificationStart:(MXQRCodeKeyVerificationStart*)keyVerificationStart withEvent:(MXEvent*)event
{
    NSLog(@"[MXKeyVerification] handleQRCodeKeyVerificationStart");
    
    if (!keyVerificationStart)
    {
        return;
    }
    
    NSString *requestId = keyVerificationStart.transactionId;
    MXKeyVerificationRequest *request = [self pendingRequestWithRequestId:requestId];
    if (request)
    {
        // We have a start response. The request is complete
        [self removePendingRequestWithRequestId:request.requestId];
    }
    
    if ([event.relatesTo.relationType isEqualToString:MXEventRelationTypeReference])
    {
        if (!request
            || (request.isFromMyUser && !request.isFromMyDevice))
        {
            // This is a start response to a request we did not make. Ignore it
            NSLog(@"[MXKeyVerification] handleStartEvent: Start event for verification by DM(%@) not triggered by this device. Ignore it", requestId);
            return;
        }
    }
    
    if (!keyVerificationStart.isValid)
    {
        [self cancelTransactionFromStartEvent:event code:MXTransactionCancelCode.invalidMessage];
        return;
    }
    
    MXQRCodeTransaction *qrCodeTransaction = [self qrCodeTransactionWithTransactionId:requestId];
    
    // Verify existing transaction
    if (!qrCodeTransaction)
    {
        NSLog(@"[MXKeyVerification] handleStartEvent: Start event for verification not triggered by this device no existing transaction. Start event: %@", event);
        [self cancelTransactionFromStartEvent:event code:MXTransactionCancelCode.userMismatchError];
        return;
    }
    
    // Verify sender user match
    if (![qrCodeTransaction.otherUserId isEqualToString:event.sender])
    {
        NSLog(@"[MXKeyVerification] handleStartEvent: Invalid start event sender user mismatch. Start event: %@.", event);
        [self cancelTransactionFromStartEvent:event code:MXTransactionCancelCode.userMismatchError];
        return;
    }
    
    // Verify sender device match
    if (![qrCodeTransaction.otherDevice.deviceId isEqualToString:keyVerificationStart.fromDevice])
    {
        NSLog(@"[MXKeyVerification] handleStartEvent: Invalid start event sender device mismatch. Start event: %@.", event);
        [self cancelTransactionFromStartEvent:event code:MXTransactionCancelCode.userMismatchError];
        return;
    }
    
    // Verify shared secret match
    [qrCodeTransaction handleStart:keyVerificationStart];
}


#pragma mark - Transport -
#pragma mark to_device

- (void)setupIncomingToDeviceEvents
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onToDeviceEvent:) name:kMXSessionOnToDeviceEventNotification object:_crypto.mxSession];
}

- (void)onToDeviceEvent:(NSNotification *)notification
{
    MXEvent *event = notification.userInfo[kMXSessionNotificationEventKey];
    
    if ([self isVerificationEventType:event.type])
    {
        [self handleKeyVerificationEvent:event isToDeviceEvent:YES];
    }
}

- (MXHTTPOperation*)sendToDevice:(NSString*)userId
                        deviceId:(NSString*)deviceId
                       eventType:(NSString*)eventType
                         content:(NSDictionary*)content
                         success:(void (^)(void))success
                         failure:(void (^)(NSError *error))failure
{
    return [self sendToDevices:userId deviceIds:@[deviceId] eventType:eventType content:content success:success failure:failure];
}

- (MXHTTPOperation*)sendToDevices:(NSString*)userId
                        deviceIds:(NSArray<NSString*>*)deviceIds
                        eventType:(NSString*)eventType
                          content:(NSDictionary*)content
                          success:(void (^)(void))success
                          failure:(void (^)(NSError *error))failure
{
    MXUsersDevicesMap<NSDictionary*> *contentMap = [[MXUsersDevicesMap alloc] init];
    
    for (NSString *deviceId in deviceIds)
    {
        [contentMap setObject:content forUser:userId andDevice:deviceId];
    }
    
    return [self.crypto.matrixRestClient sendToDevice:eventType contentMap:contentMap txnId:nil success:success failure:failure];
}


#pragma mark DM

- (void)setupIncomingDMEvents
{
    [_crypto.mxSession listenToEventsOfTypes:kMXKeyVerificationManagerVerificationEventTypes onEvent:^(MXEvent *event, MXTimelineDirection direction, id customObject) {
        if (direction == MXTimelineDirectionForwards)
        {
            [self handleKeyVerificationEvent:event isToDeviceEvent:NO];
        }
    }];
}

- (BOOL)isVerificationEventType:(MXEventTypeString)type
{
    return [kMXKeyVerificationManagerVerificationEventTypes containsObject:type];
}

- (MXHTTPOperation*)sendMessage:(NSString*)userId
                         roomId:(NSString*)roomId
                      eventType:(NSString*)eventType
                      relatedTo:(NSString*)relatedTo
                        content:(NSDictionary*)content
                        success:(void (^)(void))success
                        failure:(void (^)(NSError *error))failure
{
    NSMutableDictionary *eventContent = [content mutableCopy];

    eventContent[@"m.relates_to"] = @{
                                      @"rel_type": MXEventRelationTypeReference,
                                      @"event_id": relatedTo,
                                      };

    [eventContent removeObjectForKey:@"transaction_id"];

    return [self sendEventOfType:eventType toRoom:roomId content:eventContent success:^(NSString *eventId) {
        if (success)
        {
            success();
        }
    } failure:failure];
}

- (void)setupVericationByDMRequests
{
    NSArray *types = @[
                       kMXEventTypeStringRoomMessage
                       ];

    [_crypto.mxSession listenToEventsOfTypes:types onEvent:^(MXEvent *event, MXTimelineDirection direction, id customObject) {
        if (direction == MXTimelineDirectionForwards
            && [event.content[@"msgtype"] isEqualToString:kMXMessageTypeKeyVerificationRequest])
        {
            MXKeyVerificationByDMRequest *requestByDM = [[MXKeyVerificationByDMRequest alloc] initWithEvent:event andManager:self];
            if (requestByDM)
            {
                [self handleKeyVerificationRequestByDM:requestByDM event:event];
            }
        }
    }];
}


- (void)handleKeyVerificationRequestByDM:(MXKeyVerificationByDMRequest*)request event:(MXEvent*)event
{
    NSLog(@"[MXKeyVerification] handleKeyVerificationRequestByDM: %@", request);

    if (![request.request.to isEqualToString:self.crypto.mxSession.myUserId])
    {
        NSLog(@"[MXKeyVerification] handleKeyVerificationRequestByDM: Request for another user: %@", request.request.to);
        return;
    }

    MXWeakify(self);
    dispatch_async(dispatch_get_main_queue(), ^{
        MXStrongifyAndReturnIfNil(self);

        // This is a live event, we should have all data
        [self->statusResolver keyVerificationWithKeyVerificationId:request.requestId event:event transport:MXKeyVerificationTransportDirectMessage success:^(MXKeyVerification * _Nonnull keyVerification) {

            if (keyVerification.request.state == MXKeyVerificationRequestStatePending)
            {
                [self addPendingRequest:request notify:YES];
            }

        } failure:^(NSError *error) {
            NSLog(@"[MXKeyVerificationRequest] handleKeyVerificationRequestByDM: Failed to resolve state: %@", request.requestId);
        }];
    });
}



#pragma mark - Private methods -

- (void)loadDeviceWithDeviceId:(NSString*)deviceId
                     andUserId:(NSString*)userId
                       success:(void (^)(MXDeviceInfo *otherDevice))success
                       failure:(void (^)(NSError *error))failure
{
    MXWeakify(self);
    [_crypto downloadKeys:@[userId] forceDownload:NO success:^(MXUsersDevicesMap<MXDeviceInfo *> *usersDevicesInfoMap, NSDictionary<NSString *,MXCrossSigningInfo *> *crossSigningKeysMap) {
        MXStrongifyAndReturnIfNil(self);

        dispatch_async(self->cryptoQueue, ^{
            MXDeviceInfo *otherDevice = [usersDevicesInfoMap objectForDevice:deviceId forUser:userId];
            if (otherDevice)
            {
                success(otherDevice);
            }
            else
            {
                NSError *error = [NSError errorWithDomain:MXKeyVerificationErrorDomain
                                                     code:MXKeyVerificationUnknownDeviceCode
                                                 userInfo:@{
                                                            NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unknown device: %@:%@", userId, deviceId]
                                                            }];
                failure(error);
            }
        });

    } failure:failure];
}

/**
 Send a message to a room even if it is e2e encrypted.
 This may require to mark unknown devices as known, which is legitimate because
 we are going to verify them or their user.
 */
- (MXHTTPOperation*)sendEventOfType:(MXEventTypeString)eventType
                             toRoom:(NSString*)roomId
                            content:(NSDictionary*)content
                            success:(void (^)(NSString *eventId))success
                            failure:(void (^)(NSError *error))failure
{
    // Check we have a room
    MXRoom *room = [_crypto.mxSession roomWithRoomId:roomId];
    if (!room)
    {
        NSError *error = [NSError errorWithDomain:MXKeyVerificationErrorDomain
                                             code:MXKeyVerificationUnknownRoomCode
                                         userInfo:@{
                                                    NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unknown room: %@", roomId]
                                                    }];
        if (failure)
        {
            failure(error);
        }
        return nil;
    }

    MXHTTPOperation *operation = [MXHTTPOperation new];
    operation = [room sendEventOfType:eventType content:content localEcho:nil success:success failure:^(NSError *error) {

        if ([error.domain isEqualToString:MXEncryptingErrorDomain] &&
            error.code == MXEncryptingErrorUnknownDeviceCode)
        {
            // Acknownledge unknown devices
            MXUsersDevicesMap<MXDeviceInfo *> *unknownDevices = error.userInfo[MXEncryptingErrorUnknownDeviceDevicesKey];
            [self.crypto setDevicesKnown:unknownDevices complete:^{
                // And retry
                MXHTTPOperation *operation2 = [room sendEventOfType:eventType content:content localEcho:nil success:success failure:failure];
                [operation mutateTo:operation2];
            }];
        }
        else if (failure)
        {
            failure(error);
        }
    }];

    return operation;
}

- (void)computeReadyMethodsFromVerificationRequestWithId:(NSString*)transactionId
                                     andSupportedMethods:(NSArray<NSString*>*)supportedMethods
                                              completion:(void (^)(NSArray<NSString*>* readyMethods, MXQRCodeData *qrCodeData))completion;
{
    MXKeyVerificationRequest *keyVerificationRequest = [self pendingRequestWithRequestId:transactionId];
    
    if (!keyVerificationRequest)
    {
        NSLog(@"[MXKeyVerification] computeReadyMethodsFromVerificationRequestWithId: Failed to find request with ID: %@", transactionId);
    }
    
    NSMutableSet<NSString*> *readyMethods = [NSMutableSet new];
    MXQRCodeData *outputQRCodeData;
    
    NSArray<NSString*> *incomingMethods = keyVerificationRequest.methods;
    
    if ([incomingMethods containsObject:MXKeyVerificationMethodSAS] && [supportedMethods containsObject:MXKeyVerificationMethodSAS])
    {
        // Other can do SAS and so do I
        [readyMethods addObject:MXKeyVerificationMethodSAS];
    }
    
    if ([incomingMethods containsObject:MXKeyVerificationMethodQRCodeScan] || [incomingMethods containsObject:MXKeyVerificationMethodQRCodeShow])
    {
        // Other user wants to verify using QR code. Cross-signing has to be setup
        MXQRCodeData *qrCodeData = [self createQRCodeDataWithTransactionId:keyVerificationRequest.requestId
                                                               otherUserId:keyVerificationRequest.otherUser
                                                             otherDeviceId:keyVerificationRequest.fromDevice];
        
        if (qrCodeData)
        {
            if ([incomingMethods containsObject:MXKeyVerificationMethodQRCodeScan] && [supportedMethods containsObject:MXKeyVerificationMethodQRCodeShow])
            {
                // Other can Scan and I can show QR code
                [readyMethods addObject:MXKeyVerificationMethodQRCodeShow];
                [readyMethods addObject:MXKeyVerificationMethodReciprocate];
            }
            
            if ([incomingMethods containsObject:MXKeyVerificationMethodQRCodeShow] && [supportedMethods containsObject:MXKeyVerificationMethodQRCodeScan])
            {
                // Other can show and I can scan QR code
                [readyMethods addObject:MXKeyVerificationMethodQRCodeScan];
                [readyMethods addObject:MXKeyVerificationMethodReciprocate];
            }
            
            if ([readyMethods containsObject:MXKeyVerificationMethodReciprocate])
            {
                outputQRCodeData = qrCodeData;
            }
        }
    }
    
    completion([readyMethods allObjects], outputQRCodeData);
}

- (BOOL)isOtherQRCodeDataKeysValid:(MXQRCodeData*)otherQRCodeData otherUserId:(NSString*)otherUserId otherDevice:(MXDeviceInfo*)otherDevice
{
    BOOL isOtherQRCodeDataValid = YES;
    
    MXCrossSigning *crossSigning = self.crypto.crossSigning;
    
    NSString *masterKeyPublic = crossSigning.myUserCrossSigningKeys.masterKeys.keys;
    
    if ([otherQRCodeData isMemberOfClass:MXVerifyingAnotherUserQRCodeData.class])
    {
        MXVerifyingAnotherUserQRCodeData *verifyingAnotherUserQRCodeData = (MXVerifyingAnotherUserQRCodeData*)otherQRCodeData;
        
        MXCrossSigningInfo *otherUserCrossSigningKeys = [self.crypto crossSigningKeysForUser:otherUserId];
        NSString *otherUserMasterKeyPublic = otherUserCrossSigningKeys.masterKeys.keys;
    
        // verifyingAnotherUserQRCodeData.otherUserCrossSigningMasterKeyPublic -> Current user master key public
        if (![verifyingAnotherUserQRCodeData.otherUserCrossSigningMasterKeyPublic isEqualToString:masterKeyPublic])
        {
            NSLog(@"[MXKeyVerification] checkOtherQRCodeData: Invalid other master key %@", verifyingAnotherUserQRCodeData.otherUserCrossSigningMasterKeyPublic);
            isOtherQRCodeDataValid = NO;
        }
        // verifyingAnotherUserQRCodeData.userCrossSigningMasterKeyPublic -> Other user master key public
        else if (![verifyingAnotherUserQRCodeData.userCrossSigningMasterKeyPublic isEqualToString:otherUserMasterKeyPublic])
        {
            NSLog(@"[MXKeyVerification] checkOtherQRCodeData: Invalid user master key %@", verifyingAnotherUserQRCodeData.userCrossSigningMasterKeyPublic);
            isOtherQRCodeDataValid = NO;
        }
    }
    else if ([otherQRCodeData isMemberOfClass:MXSelfVerifyingMasterKeyTrustedQRCodeData.class])
    {
        MXSelfVerifyingMasterKeyTrustedQRCodeData *selfVerifyingMasterKeyTrustedQRCodeData = (MXSelfVerifyingMasterKeyTrustedQRCodeData*)otherQRCodeData;
        
        NSString *currentDeviceKey = self.currentDevice.fingerprint;
        
        // selfVerifyingMasterKeyTrustedQRCodeData.userCrossSigningMasterKeyPublic -> Current user master key public
        if (![selfVerifyingMasterKeyTrustedQRCodeData.userCrossSigningMasterKeyPublic isEqualToString:masterKeyPublic])
        {
            NSLog(@"[MXKeyVerification] checkOtherQRCodeData: Invalid user master key %@", selfVerifyingMasterKeyTrustedQRCodeData.userCrossSigningMasterKeyPublic);
            isOtherQRCodeDataValid = NO;
        }
        // selfVerifyingMasterKeyTrustedQRCodeData.otherDeviceKey -> Current device key
        else if (![selfVerifyingMasterKeyTrustedQRCodeData.otherDeviceKey isEqualToString:currentDeviceKey])
        {
            NSLog(@"[MXKeyVerification] checkOtherQRCodeData: Invalid other device key %@", selfVerifyingMasterKeyTrustedQRCodeData.otherDeviceKey);
            isOtherQRCodeDataValid = NO;
        }
    }
    else if ([otherQRCodeData isMemberOfClass:MXSelfVerifyingMasterKeyNotTrustedQRCodeData.class])
    {
        MXSelfVerifyingMasterKeyNotTrustedQRCodeData *selfVerifyingMasterKeyNotTrustedQRCodeData = (MXSelfVerifyingMasterKeyNotTrustedQRCodeData*)otherQRCodeData;
        NSString *otherDeviceKey = otherDevice.fingerprint;
        
        // selfVerifyingMasterKeyNotTrustedQRCodeData.currentDeviceKey -> other device key
        if (![selfVerifyingMasterKeyNotTrustedQRCodeData.currentDeviceKey isEqualToString:otherDeviceKey])
        {
            NSLog(@"[MXKeyVerification] checkOtherQRCodeData: Current device key %@", selfVerifyingMasterKeyNotTrustedQRCodeData.currentDeviceKey);
            isOtherQRCodeDataValid = NO;
        }
        // selfVerifyingMasterKeyNotTrustedQRCodeData.userCrossSigningMasterKeyPublic -> Current user master key public
        else if (![selfVerifyingMasterKeyNotTrustedQRCodeData.userCrossSigningMasterKeyPublic isEqualToString:masterKeyPublic])
        {
            NSLog(@"[MXKeyVerification] checkOtherQRCodeData: Invalid user master key %@", selfVerifyingMasterKeyNotTrustedQRCodeData.userCrossSigningMasterKeyPublic);
            isOtherQRCodeDataValid = NO;
        }
    }
    
    return isOtherQRCodeDataValid;
}

#pragma mark - Requests queue

- (nullable MXKeyVerificationByDMRequest*)verificationRequestInDMEvent:(MXEvent*)event
{
    MXKeyVerificationByDMRequest *request;
    if ([event.content[@"msgtype"] isEqualToString:kMXMessageTypeKeyVerificationRequest])
    {
        request = [[MXKeyVerificationByDMRequest alloc] initWithEvent:event andManager:self];
    }
    return request;
}

- (nullable MXKeyVerificationRequest*)pendingRequestWithRequestId:(NSString*)requestId
{
    return pendingRequestsMap[requestId];
}

- (void)addPendingRequest:(MXKeyVerificationRequest *)request notify:(BOOL)notify
{
    if (!pendingRequestsMap[request.requestId])
    {
        pendingRequestsMap[request.requestId] = request;

        if (notify)
        {
            dispatch_async(dispatch_get_main_queue(),^{
                [[NSNotificationCenter defaultCenter] postNotificationName:MXKeyVerificationManagerNewRequestNotification object:self userInfo:
                 @{
                   MXKeyVerificationManagerNotificationRequestKey: request
                   }];
            });
        }
    }
    [self scheduleRequestTimeoutTimer];
}

- (void)removePendingRequestWithRequestId:(NSString*)requestId
{
    if (pendingRequestsMap[requestId])
    {
        [pendingRequestsMap removeObjectForKey:requestId];
        [self scheduleRequestTimeoutTimer];
    }
}


#pragma mark - Timeout management

- (nullable NSDate*)oldestRequestDate
{
    NSDate *oldestRequestDate;
    for (MXKeyVerificationRequest *request in pendingRequestsMap.allValues)
    {
        if (!oldestRequestDate
            || request.timestamp < oldestRequestDate.timeIntervalSince1970)
        {
            oldestRequestDate = [NSDate dateWithTimeIntervalSince1970:(request.timestamp / 1000)];
        }
    }
    return oldestRequestDate;
}

- (BOOL)isRequestStillValid:(MXKeyVerificationRequest*)request
{
    NSDate *requestDate = [NSDate dateWithTimeIntervalSince1970:(request.timestamp / 1000)];
    return (requestDate.timeIntervalSinceNow > -_requestTimeout);
}

- (void)scheduleRequestTimeoutTimer
{
    if (requestTimeoutTimer)
    {
        if (!pendingRequestsMap.count)
        {
            NSLog(@"[MXKeyVerificationRequest] scheduleTimeoutTimer: Disable timer as there is no more requests");
            [requestTimeoutTimer invalidate];
            requestTimeoutTimer = nil;
        }

        return;
    }

    NSDate *oldestRequestDate = [self oldestRequestDate];
    if (oldestRequestDate)
    {
        NSLog(@"[MXKeyVerificationRequest] scheduleTimeoutTimer: Create timer");

        NSDate *timeoutDate = [oldestRequestDate dateByAddingTimeInterval:self.requestTimeout];
        requestTimeoutTimer = [[NSTimer alloc] initWithFireDate:timeoutDate
                                                      interval:0
                                                        target:self
                                                      selector:@selector(onRequestTimeoutTimer)
                                                      userInfo:nil
                                                       repeats:NO];
        [[NSRunLoop mainRunLoop] addTimer:requestTimeoutTimer forMode:NSDefaultRunLoopMode];
    }
}

- (void)onRequestTimeoutTimer
{
    NSLog(@"[MXKeyVerificationRequest] onTimeoutTimer");
    requestTimeoutTimer = nil;

    [self checkRequestTimeoutsWithCompletion:^{
        [self scheduleRequestTimeoutTimer];
    }];
}

- (void)checkRequestTimeoutsWithCompletion:(dispatch_block_t)completionBlock
{
    dispatch_group_t group = dispatch_group_create();
    for (MXKeyVerificationRequest *request in pendingRequestsMap.allValues)
    {
        if (![self isRequestStillValid:request])
        {
            NSLog(@"[MXKeyVerificationRequest] checkTimeouts: timeout %@", request);
            
            dispatch_group_enter(group);
            [request cancelWithCancelCode:MXTransactionCancelCode.timeout success:^{
                dispatch_group_leave(group);
            } failure:^(NSError * _Nonnull error) {
                dispatch_group_leave(group);
            }];
        }
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), completionBlock);
}


#pragma mark - Transactions queue

- (MXKeyVerificationTransaction*)transactionWithUser:(NSString*)userId andDevice:(NSString*)deviceId
{
    return [transactions objectForDevice:deviceId forUser:userId];
}

- (NSArray<MXKeyVerificationTransaction*>*)transactionsWithUser:(NSString*)userId
{
    return [transactions objectsForUser:userId];
}

- (MXKeyVerificationTransaction*)transactionWithTransactionId:(NSString*)transactionId
{
    MXKeyVerificationTransaction *transaction;
    for (MXKeyVerificationTransaction *t in transactions.allObjects)
    {
        if ([t.transactionId isEqualToString:transactionId])
        {
            transaction = t;
            break;
        }
    }

    return transaction;
}

- (MXSASTransaction*)sasTransactionWithTransactionId:(NSString*)transactionId
{
    MXSASTransaction *sasTransaction;
    
    MXKeyVerificationTransaction *transaction = [self transactionWithTransactionId:transactionId];
    
    if ([transaction isKindOfClass:MXSASTransaction.class])
    {
        sasTransaction = (MXSASTransaction *)transaction;
    }
    
    return sasTransaction;
}

- (MXQRCodeTransaction*)qrCodeTransactionWithTransactionId:(NSString*)transactionId
{
    MXQRCodeTransaction *qrCodeTransaction;
    
    MXKeyVerificationTransaction *transaction = [self transactionWithTransactionId:transactionId];
    
    if ([transaction isKindOfClass:MXQRCodeTransaction.class])
    {
        qrCodeTransaction = (MXQRCodeTransaction *)transaction;
    }
    
    return qrCodeTransaction;
}

- (void)addTransaction:(MXKeyVerificationTransaction*)transaction
{
    [transactions setObject:transaction forUser:transaction.otherUserId andDevice:transaction.otherDeviceId];
    [self scheduleTransactionTimeoutTimer];

    dispatch_async(dispatch_get_main_queue(),^{
        [[NSNotificationCenter defaultCenter] postNotificationName:MXKeyVerificationManagerNewTransactionNotification object:self userInfo:
         @{
           MXKeyVerificationManagerNotificationTransactionKey: transaction
           }];
    });
}

- (void)removeTransactionWithTransactionId:(NSString*)transactionId
{
    MXKeyVerificationTransaction *transaction = [self transactionWithTransactionId:transactionId];
    if (transaction)
    {
        [transactions removeObjectForUser:transaction.otherUserId andDevice:transaction.otherDeviceId];
        [self scheduleTransactionTimeoutTimer];
    }
}

- (nullable NSDate*)oldestTransactionCreationDate
{
    NSDate *oldestCreationDate;
    for (MXKeyVerificationTransaction *transaction in transactions.allObjects)
    {
        if (!oldestCreationDate
            || transaction.creationDate.timeIntervalSince1970 < oldestCreationDate.timeIntervalSince1970)
        {
            oldestCreationDate = transaction.creationDate;
        }
    }
    return oldestCreationDate;
}

- (BOOL)isCreationDateValid:(MXKeyVerificationTransaction*)transaction
{
    return (transaction.creationDate.timeIntervalSinceNow > -MXTransactionTimeout);
}


#pragma mark Timeout management

- (void)scheduleTransactionTimeoutTimer
{
    if (transactionTimeoutTimer)
    {
        if (!transactions.count)
        {
            NSLog(@"[MXKeyVerification] scheduleTimeoutTimer: Disable timer as there is no more transactions");
            [transactionTimeoutTimer invalidate];
            transactionTimeoutTimer = nil;
        }

        return;
    }

    NSDate *oldestCreationDate = [self oldestTransactionCreationDate];
    if (oldestCreationDate)
    {
        MXWeakify(self);
        dispatch_async(dispatch_get_main_queue(), ^{
            MXStrongifyAndReturnIfNil(self);

            if (self->transactionTimeoutTimer)
            {
                return;
            }

            NSLog(@"[MXKeyVerification] scheduleTimeoutTimer: Create timer");

            NSDate *timeoutDate = [oldestCreationDate dateByAddingTimeInterval:MXTransactionTimeout];
            self->transactionTimeoutTimer = [[NSTimer alloc] initWithFireDate:timeoutDate
                                                          interval:0
                                                            target:self
                                                          selector:@selector(onTransactionTimeoutTimer)
                                                          userInfo:nil
                                                           repeats:NO];
            [[NSRunLoop mainRunLoop] addTimer:self->transactionTimeoutTimer forMode:NSDefaultRunLoopMode];
        });
    }
}

- (void)onTransactionTimeoutTimer
{
    NSLog(@"[MXKeyVerification] onTimeoutTimer");
    self->transactionTimeoutTimer = nil;

    if (cryptoQueue)
    {
        dispatch_async(cryptoQueue, ^{
            [self checkTransactionTimeouts];
            [self scheduleTransactionTimeoutTimer];
        });
    }
}

- (void)checkTransactionTimeouts
{
    for (MXKeyVerificationTransaction *transaction in transactions.allObjects)
    {
        if (![self isCreationDateValid:transaction])
        {
            NSLog(@"[MXKeyVerification] checkTimeouts: timeout %@", transaction);
            [transaction cancelWithCancelCode:MXTransactionCancelCode.timeout];
        }
    }
}

#pragma mark - QR Code

- (MXQRCodeData*)createQRCodeDataWithTransactionId:(NSString*)transactionId otherUserId:(NSString*)otherUserId otherDeviceId:(NSString*)otherDeviceId
{
    MXQRCodeData *qrCodeData;
    
    NSString *currentUserId = self.crypto.mxSession.myUserId;
    MXUserTrustLevel *currentUserTrustLevel = [self.crypto trustLevelForUser:currentUserId];
    
    if ([otherUserId isEqualToString:currentUserId])
    {
        if (currentUserTrustLevel.isCrossSigningVerified)
        {
            // This is a self verification and I am the old device (Osborne2)
            qrCodeData = [self createSelfVerifyingMasterKeyTrustedQRCodeDataWithTransactionId:transactionId otherDeviceId:otherUserId];
        }
        else
        {
            // This is a self verification and I am the new device (Dynabook)
            qrCodeData = [self createSelfVerifyingMasterKeyNotTrustedQRCodeDataWithTransactionId:transactionId];
        }
    }
    else
    {
        qrCodeData = [self createVerifyingAnotherUserQRCodeDataWithTransactionId:transactionId otherUserId:otherUserId];
    }
    
    return qrCodeData;
}

- (MXVerifyingAnotherUserQRCodeData*)createVerifyingAnotherUserQRCodeDataWithTransactionId:(NSString*)transactionId
                                                                               otherUserId:(NSString*)otherUserId
{
    MXCrossSigningInfo *myUserCrossSigningKeys = self.crypto.crossSigning.myUserCrossSigningKeys;
    MXCrossSigningInfo *otherUserCrossSigningKeys = [self.crypto crossSigningKeysForUser:otherUserId];

    NSString *userCrossSigningMasterKeyPublic = myUserCrossSigningKeys.masterKeys.keys;
    NSString *otherUserCrossSigningMasterKeyPublic = otherUserCrossSigningKeys.masterKeys.keys;

    if (!userCrossSigningMasterKeyPublic || !otherUserCrossSigningMasterKeyPublic)
    {
        NSLog(@"[MXKeyVerification] createVerifyingAnotherUserQRCodeData fails to get userCrossSigningMasterKeyPublic or otherUserCrossSigningMasterKeyPublic");
        return nil;
    }

    return [self.qrCodeDataBuilder buildVerifyingAnotherUserQRCodeDataWithTransactionId:transactionId
                                                        userCrossSigningMasterKeyPublic:userCrossSigningMasterKeyPublic
                                                   otherUserCrossSigningMasterKeyPublic:otherUserCrossSigningMasterKeyPublic];
}

// Create a QR code to display on the old device (Osborne2) of current user
- (MXSelfVerifyingMasterKeyTrustedQRCodeData*)createSelfVerifyingMasterKeyTrustedQRCodeDataWithTransactionId:(NSString*)transactionId
                                                                                               otherDeviceId:(NSString*)otherDeviceId
{
    MXCrossSigningInfo *myUserCrossSigningKeys = self.crypto.crossSigning.myUserCrossSigningKeys;
    NSString *currentUserId = self.crypto.mxSession.myUserId;
    MXDeviceInfo *otherDevice = [self.crypto deviceWithDeviceId:otherDeviceId ofUser:currentUserId];
    
    NSString *userCrossSigningMasterKeyPublic = myUserCrossSigningKeys.masterKeys.keys;
    NSString *otherDeviceKey = otherDevice.fingerprint;
    
    if (!userCrossSigningMasterKeyPublic || !otherDeviceKey)
    {
        NSLog(@"[MXKeyVerification] createSelfVerifyingMasterKeyTrustedQRCodeData fails to get userCrossSigningMasterKeyPublic or otherDeviceKey");
        return nil;
    }
    
    return [self.qrCodeDataBuilder buildSelfVerifyingMasterKeyTrustedQRCodeDataWithTransactionId:transactionId
                                                                 userCrossSigningMasterKeyPublic:userCrossSigningMasterKeyPublic
                                                                                  otherDeviceKey:otherDeviceKey];
}

// Create a QR code to display on the new device (Dynabook) of current user
- (MXSelfVerifyingMasterKeyNotTrustedQRCodeData*)createSelfVerifyingMasterKeyNotTrustedQRCodeDataWithTransactionId:(NSString*)transactionId
{
    MXCrossSigningInfo *myUserCrossSigningKeys = self.crypto.crossSigning.myUserCrossSigningKeys;

    NSString *userCrossSigningMasterKeyPublic = myUserCrossSigningKeys.masterKeys.keys;
    NSString *currentDeviceKey = self.currentDevice.fingerprint;

    if (!userCrossSigningMasterKeyPublic || !currentDeviceKey)
    {
        NSLog(@"[MXKeyVerification] createSelfVerifyingMasterKeyNotTrustedQRCodeData fails to get userCrossSigningMasterKeyPublic or currentDeviceKey");
        return nil;
    }

    return [self.qrCodeDataBuilder buildSelfVerifyingMasterKeyNotTrustedQRCodeDataWithTransactionId:transactionId
                                                                                   currentDeviceKey:currentDeviceKey
                                                                    userCrossSigningMasterKeyPublic:userCrossSigningMasterKeyPublic];
}

- (MXDeviceInfo*)currentDevice
{
    NSString *currentUserId = self.crypto.mxSession.myUserId;
    NSString *currentDeviceId = self.crypto.mxSession.matrixRestClient.credentials.deviceId;
    return [self.crypto deviceWithDeviceId:currentDeviceId ofUser:currentUserId];
}

@end
