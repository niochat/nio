//
//  MXSession.swift
//  MatrixSDK
//
//  Created by Avery Pierce on 2/11/17.
//  Copyright © 2017 matrix.org. All rights reserved.
//  Copyright 2019 The Matrix.org Foundation C.I.C
//

import Foundation


public extension MXSession {
    
    /**
     Start fetching events from the home server.
     
     If the attached MXStore does not cache data permanently, the function will begin by making
     an initialSync request to the home server to get information about the rooms the user has
     interactions with.
     Then, it will start the events streaming, a long polling connection to the home server to
     listen to new coming events.
     
     If the attached MXStore caches data permanently, the function will do an initialSync only at
     the first launch. Then, for next app launches, the SDK will load events from the MXStore and
     will resume the events streaming from where it had been stopped the time before.
     
     - parameters:
        - filterId: the id of the filter to use.
        - completion: A block object called when the operation completes. In case of failure during
     the initial sync, the session state is `MXSessionStateInitialSyncFailed`.
        - response: Indicates whether the operation was successful.
     */
    @nonobjc func start(withSyncFilterId filterId: String? = nil, completion: @escaping (_ response: MXResponse<Void>) -> Void) {
        __start(withSyncFilterId:filterId, onServerSyncDone: currySuccess(completion), failure: curryFailure(completion))
    }


    /**
     Start fetching events from the home server with a filter object.

     - parameters:
        - filter: The filter to use.
        - completion: A block object called when the operation completes. In case of failure during
     the initial sync, the session state is `MXSessionStateInitialSyncFailed`.
        - response: Indicates whether the operation was successful.
     */
    @nonobjc func start(withSyncFilter filter: MXFilterJSONModel, completion: @escaping (_ response: MXResponse<Void>) -> Void) {
        __start(withSyncFilter:filter, onServerSyncDone: currySuccess(completion), failure: curryFailure(completion))
    }


    /**
     Perform an events stream catchup in background (by keeping user offline).
     
     - parameters:
        - timeout: the max time to perform the catchup
        - completion: A block called when the SDK has completed a catchup, or times out.
        - response: Indicates whether the sync was successful.
     */
    @nonobjc func backgroundSync(withTimeout timeout: TimeInterval, completion: @escaping (_ response: MXResponse<Void>) -> Void) {
        let timeoutMilliseconds = UInt32(timeout * 1000)
        __backgroundSync(timeoutMilliseconds, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    
    
    /**
     Invalidate the access token, so that it can no longer be used for authorization.
     
     - parameters:
        - completion: A block called when the SDK has completed a catchup, or times out.
        - response: Indicates whether the sync was successful.
     
     - returns: an `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func logout(completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __logout(currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    
    /**
     Deactivate the user's account, removing all ability for the user to login again.
     
     This API endpoint uses the User-Interactive Authentication API.
     
     An access token should be submitted to this endpoint if the client has an active session.
     The homeserver may change the flows available depending on whether a valid access token is provided.
     
     - parameters:
         - authParameters The additional authentication information for the user-interactive authentication API.
         - eraseAccount Indicating whether the account should be erased.
         - completion: A block object called when the operation completes.
         - response: indicates whether the request succeeded or not.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func deactivateAccount(withAuthParameters authParameters: [String: Any], eraseAccount: Bool,  completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __deactivateAccount(withAuthParameters: authParameters, eraseAccount: eraseAccount, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    /**
     Define the Matrix storage component to use.
     
     It must be set before calling [MXSession start].
     Else, by default, the MXSession instance will use MXNoStore as storage.
     
     - parameters:
        - store: the store to use for the session.
        - completion: A block object called when the operation completes. If the operation was
     successful, the SDK is then able to serve this data to its client. Note the data may not
     be up-to-date. You need to call [MXSession start] to ensure the sync with the home server.
        - response: indicates whether the operation was successful.
     */
    @nonobjc func setStore(_ store: MXStore, completion: @escaping (_ response: MXResponse<Void>) -> Void) {
        __setStore(store, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    /**
     Enable End-to-End encryption.
     
     In case of enabling, the operation will complete when the session will be ready
     to make encrytion with other users devices
     
     - parameters:
        - isEnabled: `false` stops crypto and erases crypto data.
        - completion: A block called when the SDK has completed a catchup, or times out.
        - response: Indicates whether the sync was successful.
     */
    @nonobjc func enableCrypto(_ isEnabled: Bool, completion: @escaping (_ response: MXResponse<Void>) -> Void) {
        __enableCrypto(isEnabled, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    
    
    

    /**
     Create a room.

     - parameters:
        - parameters: The parameters for room creation.
        - completion: A block object called when the operation completes.
        - response: Provides a MXRoom object on success.

     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func createRoom(parameters: MXRoomCreationParameters, completion: @escaping (_ response: MXResponse<MXRoom>) -> Void) -> MXHTTPOperation {
        return __createRoom(with: parameters, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    

    /**
     Create a room.
     
     - parameters:
     - parameters: The parameters. Refer to the matrix specification for details.
     - completion: A block object called when the operation completes.
     - response: Provides a MXCreateRoomResponse object on success.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func createRoom(parameters: [String: Any], completion: @escaping (_ response: MXResponse<MXRoom>) -> Void) -> MXHTTPOperation {
        return __createRoom(parameters, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    
    
    
    /**
     Join a room, optionally where the user has been invited by a 3PID invitation.
     
     - parameters:
        - roomIdOrAlias: The id or an alias of the room to join.
        - viaServers The server names to try and join through in addition to those that are automatically chosen.
        - signUrl: the url provided in an invitation.
        - completion: A block object called when the operation completes.
        - response: Provides the room on success.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func joinRoom(_ roomIdOrAlias: String, viaServers: [String]? = nil, withSignUrl signUrl: URL? = nil, completion: @escaping (_ response: MXResponse<MXRoom>) -> Void) -> MXHTTPOperation {
        if let signUrl = signUrl {
            return __joinRoom(roomIdOrAlias, viaServers: viaServers, withSignUrl: signUrl.absoluteString, success: currySuccess(completion), failure: curryFailure(completion))
        } else {
            return __joinRoom(roomIdOrAlias, viaServers: viaServers, success: currySuccess(completion), failure: curryFailure(completion))
        }
    }

    
    /**
     Leave a room.
     
     - parameters:
        - roomId: the id of the room to leave.
        - completion: A block object called when the operation completes.
        - response: Indicates whether the operation was successful.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func leaveRoom(_ roomId: String, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __leaveRoom(roomId, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    
    
    
    
    /// list of all rooms.
    @nonobjc var rooms: [MXRoom] {
        return __rooms()
    }

    
    

    /**
     Start peeking a room.
     
     The operation succeeds only if the history visibility for the room is world_readable.
     
     - parameters:
        - roomId: The room id to the room.
        - completion: A block object called when the operation completes.
        - response: Provides the `MXPeekingRoom` to get the room data on success.
    */
    @nonobjc func peek(inRoom roomId: String, completion: @escaping (_ response: MXResponse<MXPeekingRoom>) -> Void) {
        return __peekInRoom(withRoomId: roomId, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    
    
    
    
    /**
     Ignore a list of users.
     
     - parameters:
        - userIds: a list of users ids
        - completion: A block object called when the operation completes.
        - response: Indicates whether the operation was successful
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func ignore(users userIds: [String], completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __ignoreUsers(userIds, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    /**
     Unignore a list of users.
     
     - parameters:
        - userIds: a list of users ids
        - completion: A block object called when the operation completes.
        - response: Indicates whether the operation was successful
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func unIgnore(users userIds: [String], completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __unIgnoreUsers(userIds, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    /**
     Register a global listener to events related to the current session.
     
     The listener will receive all events including all events of all rooms.
     
     - parameters:
        - types: an array of event types to listen to
        - block: the block that will be called once a new event has been handled.
    
     - returns: a reference to use to unregister the listener
     */
    @nonobjc func listenToEvents(_ types: [MXEventType]? = nil, _ block: @escaping MXOnSessionEvent) -> Any {
        let legacyBlock: __MXOnSessionEvent = { (event, direction, customObject) in
            guard let event = event else { return }
            block(event, MXTimelineDirection(identifer: direction), customObject)
        }
        
        if let types = types {
            let typeStrings = types.map({ return $0.identifier })
            return __listen(toEventsOfTypes: typeStrings, onEvent: legacyBlock)
        } else {
            return __listen(toEvents: legacyBlock)
        }
    }
}
