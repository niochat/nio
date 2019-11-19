/*
 Copyright 2017 Avery Pierce
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

import Foundation


public extension MXRoom {
    
    
    /**
     The current list of members of the room.
     
     - parameters:
     - completion: A block object called when the operation completes.
     - response: Provides the room members of the room on success
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func members(completion: @escaping (_ response: MXResponse<MXRoomMembers?>) -> Void) -> MXHTTPOperation {
        
        let httpOperation = __members(currySuccess(completion), failure: curryFailure(completion))
        return httpOperation!
    }
    
    
    
    // MARK: - Room Operations
    
    /**
     Send a generic non state event to a room.
     
     - parameters:
        - eventType: the type of the event.
        - content: the content that will be sent to the server as a JSON object.
        - localEcho: a pointer to an MXEvent object.
     
            When the event type is `MXEventType.roomMessage`, this pointer is set to an actual
            MXEvent object containing the local created event which should be used to echo the
            message in the messages list until the resulting event comes through the server sync.
            For information, the identifier of the created local event has the prefix:
            `kMXEventLocalEventIdPrefix`.
     
            You may specify nil for this parameter if you do not want this information.
     
            You may provide your own MXEvent object, in this case only its send state is updated.
     
            When the event type is `kMXEventTypeStringRoomEncrypted`, no local event is created.
     
        - completion: A block object called when the operation completes.
        - response: Provides the event id of the event generated on the home server on success
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func sendEvent(_ eventType: MXEventType, content: [String: Any], localEcho: inout MXEvent?, completion: @escaping (_ response: MXResponse<String?>) -> Void) -> MXHTTPOperation {
        
        let httpOperation = __sendEvent(ofType: eventType.identifier, content: content, localEcho: &localEcho, success: currySuccess(completion), failure: curryFailure(completion))
        return httpOperation!
    }

    
    
    
    /**
     Send a generic state event to a room.
     
     - parameters:
        - eventType: The type of the event.
        - content: the content that will be sent to the server as a JSON object.
        - stateKey: the optional state key.
        - completion: A block object called when the operation completes.
        - response: Provides the event id of the event generated on the home server on success.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func sendStateEvent(_ eventType: MXEventType, content: [String: Any], stateKey: String, completion: @escaping (_ response: MXResponse<String?>) -> Void) -> MXHTTPOperation {
        return __sendStateEvent(ofType: eventType.identifier, content: content, stateKey: stateKey, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    /**
     Send a room message to a room.
     
     - parameters:
        - content: the message content that will be sent to the server as a JSON object.
        - localEcho: a pointer to an MXEvent object.
     
            This pointer is set to an actual MXEvent object
            containing the local created event which should be used to echo the message in
            the messages list until the resulting event come through the server sync.
            For information, the identifier of the created local event has the prefix
            `kMXEventLocalEventIdPrefix`.
     
            You may specify nil for this parameter if you do not want this information.
     
            You may provide your own MXEvent object, in this case only its send state is updated.
     
        - completion: A block object called when the operation completes.
        - response: Provides the event id of the event generated on the home server on success
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func sendMessage(withContent content: [String: Any], localEcho: inout MXEvent?, completion: @escaping (_ response: MXResponse<String?>) -> Void) -> MXHTTPOperation {
        return __sendMessage(withContent: content, localEcho: &localEcho, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    
    /**
     Send a text message to the room.
     
     - parameters:
        - text: the text to send.
        - formattedText: the optional HTML formatted string of the text to send.
        - localEcho: a pointer to a MXEvent object.
     
            This pointer is set to an actual MXEvent object
            containing the local created event which should be used to echo the message in
            the messages list until the resulting event come through the server sync.
            For information, the identifier of the created local event has the prefix
            `kMXEventLocalEventIdPrefix`.

            You may specify nil for this parameter if you do not want this information.

            You may provide your own MXEvent object, in this case only its send state is updated.
     
        - completion: A block object called when the operation completes.
        - response: Provides the event id of the event generated on the home server on success.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func sendTextMessage(_ text: String, formattedText: String? = nil, localEcho: inout MXEvent?, completion: @escaping (_ response: MXResponse<String?>) -> Void) -> MXHTTPOperation {
        return __sendTextMessage(text, formattedText: formattedText, localEcho: &localEcho, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    
    /**
     Send an emote message to the room.
     
     - parameters:
        - emote: the emote body to send.
        - formattedText: the optional HTML formatted string of the emote.
        - localEcho: a pointer to a MXEvent object.
     
             This pointer is set to an actual MXEvent object
             containing the local created event which should be used to echo the message in
             the messages list until the resulting event come through the server sync.
             For information, the identifier of the created local event has the prefix
             `kMXEventLocalEventIdPrefix`.
             
             You may specify nil for this parameter if you do not want this information.
             
             You may provide your own MXEvent object, in this case only its send state is updated.
     
        - completion: A block object called when the operation completes.
        - response: Provides the event id of the event generated on the home server on success.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func sendEmote(_ emote: String, formattedText: String? = nil, localEcho: inout MXEvent?, completion: @escaping (_ response: MXResponse<String?>) -> Void) -> MXHTTPOperation {
        return __sendEmote(emote, formattedText: formattedText, localEcho: &localEcho, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    

    /**
     Send an image to the room.

     - parameters:
        - imageData: the data of the image to send.
        - size: the original size of the image.
        - mimeType:  the image mimetype.
        - thumbnail: optional thumbnail image (may be nil).
        - localEcho: a pointer to a MXEvent object.
     
             This pointer is set to an actual MXEvent object
             containing the local created event which should be used to echo the message in
             the messages list until the resulting event come through the server sync.
             For information, the identifier of the created local event has the prefix
             `kMXEventLocalEventIdPrefix`.
             
             You may specify nil for this parameter if you do not want this information.
             
             You may provide your own MXEvent object, in this case only its send state is updated.
     
        - completion: A block object called when the operation completes.
        - response: Provides the event id of the event generated on the home server on success.
     
     - returns: a `MXHTTPOperation` instance.
     */

    @nonobjc @discardableResult func sendImage(data imageData: Data, size: CGSize, mimeType: String, thumbnail: MXImage?, localEcho: inout MXEvent?, completion: @escaping (_ response: MXResponse<String?>) -> Void) -> MXHTTPOperation {
        return __sendImage(imageData, withImageSize: size, mimeType: mimeType, andThumbnail: thumbnail, localEcho: &localEcho, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    
    
    /**
     Send a video to the room.
     
     - parameters:
        - localURL: the local filesystem path of the video to send.
        - thumbnail: the UIImage hosting a video thumbnail.
        - localEcho: a pointer to a MXEvent object.
     
             This pointer is set to an actual MXEvent object
             containing the local created event which should be used to echo the message in
             the messages list until the resulting event come through the server sync.
             For information, the identifier of the created local event has the prefix
             `kMXEventLocalEventIdPrefix`.
             
             You may specify nil for this parameter if you do not want this information.
             
             You may provide your own MXEvent object, in this case only its send state is updated.
     
        - completion: A block object called when the operation completes.
        - response: Provides the event id of the event generated on the home server on success.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func sendVideo(localURL: URL, thumbnail: MXImage?, localEcho: inout MXEvent?, completion: @escaping (_ response: MXResponse<String?>) -> Void) -> MXHTTPOperation {
        return __sendVideo(localURL, withThumbnail: thumbnail, localEcho: &localEcho, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    /**
     Send a file to the room.
 
     - parameters:
        - localURL: the local filesystem path of the file to send.
        - mimeType: the mime type of the file.
        - localEcho: a pointer to a MXEvent object.
     
             This pointer is set to an actual MXEvent object
             containing the local created event which should be used to echo the message in
             the messages list until the resulting event come through the server sync.
             For information, the identifier of the created local event has the prefix
             `kMXEventLocalEventIdPrefix`.
             
             You may specify nil for this parameter if you do not want this information.
             
             You may provide your own MXEvent object, in this case only its send state is updated.
     
        - completion: A block object called when the operation completes.
        - response: Provides the event id of the event generated on the home server on success.
     
     - returns: a `MXHTTPOperation` instance.
     */
    
    @nonobjc @discardableResult func sendFile(localURL: URL, mimeType: String, localEcho: inout MXEvent?, completion: @escaping (_ response: MXResponse<String?>) -> Void) -> MXHTTPOperation {
        return __sendFile(localURL, mimeType: mimeType, localEcho: &localEcho, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    /**
     Send an audio file to the room.
     
     - parameters:
     - localURL: the local filesystem path of the file to send.
     - mimeType: the mime type of the file.
     - localEcho: a pointer to a MXEvent object.
     
     This pointer is set to an actual MXEvent object
     containing the local created event which should be used to echo the message in
     the messages list until the resulting event come through the server sync.
     For information, the identifier of the created local event has the prefix
     `kMXEventLocalEventIdPrefix`.
     
     You may specify nil for this parameter if you do not want this information.
     
     You may provide your own MXEvent object, in this case only its send state is updated.
     
     - completion: A block object called when the operation completes.
     - response: Provides the event id of the event generated on the home server on success.
     
     - returns: a `MXHTTPOperation` instance.
     */
    
    @nonobjc @discardableResult func sendAudioFile(localURL: URL, mimeType: String, localEcho: inout MXEvent?, completion: @escaping (_ response: MXResponse<String?>) -> Void) -> MXHTTPOperation {
        return __sendAudioFile(localURL, mimeType: mimeType, localEcho: &localEcho, success: currySuccess(completion), failure: curryFailure(completion), keepActualFilename: false)
    }
    
    /**
     Set the topic of the room.
     
     - parameters:
        - topic: the topic to set.
        - completion: A block object called when the operation completes.
        - response: Indicates whether the operation was a success or failure.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func setTopic(_ topic: String, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __setTopic(topic, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    
    /**
     Set the avatar of the room.
     
     - parameters:
         - url: the url of the avatar to set.
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was a success or failure.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func setAvatar(url: URL, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __setAvatar(url.absoluteString, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    
    /**
     Set the name of the room.
     
     - parameters:
         - name: the name to set.
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was a success or failure.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func setName(_ name: String, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __setName(name, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    /**
     Set the history visibility of the room.
     
     - parameters:
         - historyVisibility: the history visibility to set.
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was a success or failure.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func setHistoryVisibility(_ historyVisibility: MXRoomHistoryVisibility, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __setHistoryVisibility(historyVisibility.identifier, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    /**
     Set the join rule of the room.
     
     - parameters:
         - joinRule: the join rule to set.
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was a success or failure.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func setJoinRule(_ joinRule: MXRoomJoinRule, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __setJoinRule(joinRule.identifier, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    /**
     Set the guest access of the room.
     
     - parameters:
         - guestAccess: the guest access to set.
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was a success or failure.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func setGuestAccess(_ guestAccess: MXRoomGuestAccess, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __setGuestAccess(guestAccess.identifier, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    
    /**
     Set the directory visibility of the room.
     
     - parameters:
         - directoryVisibility: the directory visibility to set.
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was a success or failure.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func setDirectoryVisibility(_ directoryVisibility: MXRoomDirectoryVisibility, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __setDirectoryVisibility(directoryVisibility.identifier, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    /**
     Add an alias to the room.
     
     - parameters:
         - roomAlias: the alias to add.
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was a success or failure.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func addAlias(_ roomAlias: String, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __addAlias(roomAlias, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    /**
     Remove an alias from the room.
     
     - parameters:
         - roomAlias: the alias to remove.
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was a success or failure.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func removeAlias(_ roomAlias: String, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __removeAlias(roomAlias, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    /**
     Set the canonical alias of the room
     
     - parameters:
         - canonicalAlias: the canonical alias to set.
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was a success or failure.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func setCanonicalAlias(_ canonicalAlias: String, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __setCanonicalAlias(canonicalAlias, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    
    /**
     Get the visibility of the room in the current HS's room directory.
     
     **Note:** This information is not part of the room state because it is related
     to the current homeserver.
     There is currently no way to be updated on directory visibility change. That's why a
     request must be issued everytime.
     
     - parameters:
        - completion: A block object called when the operation completes.
        - response: Provides the room direcotyr visibility on success.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func getDirectoryVisibility(completion: @escaping (_ response: MXResponse<MXRoomDirectoryVisibility>) -> Void) -> MXHTTPOperation {
        return __directoryVisibility(currySuccess(transform: MXRoomDirectoryVisibility.init, completion), failure: curryFailure(completion))
    }
    
    
    /**
     Join this room where the user has been invited.
     
     - parameters:
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was a success or failure.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func join(completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __join(currySuccess(completion), failure: curryFailure(completion))
    }
    
    /**
     Leave this room.
     
     - parameters:
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was a success or failure.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func leave(completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __leave(currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    /**
     Invite a user to this room.
     
     A user can be invited one of three ways:
     1. By their user ID
     2. By their email address
     3. By a third party
     
     The `invitation` parameter specifies how this user should be reached.
     
     - parameters:
         - invitation: the way to reach the user.
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was successful.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func invite(_ invitation: MXRoomInvitee, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        switch invitation {
        case .userId(let userId):
            return __inviteUser(userId, success: currySuccess(completion), failure: curryFailure(completion))
            
        case .email(let emailAddress):
            return __inviteUser(byEmail: emailAddress, success: currySuccess(completion), failure: curryFailure(completion))
            
        case .thirdPartyId:
            // MXRoom doesn't have an obj-c convenience method for third party IDs,
            // so we drop to the matrixRestClient.
            return mxSession.matrixRestClient.invite(invitation, toRoom: roomId, completion: completion)
        }
    }
    
    
    /**
     Kick a user from this room.
     
     - parameters:
         - userId: the user id.
         - reason: the reason for being kicked.
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was successful.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func kickUser(_ userId: String, reason: String, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __kickUser(userId, reason: reason, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    /**
     Ban a user in this room.
     
     - parameters:
         - userId: the user id.
         - reason: the reason for being banned
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was successful.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func banUser(_ userId: String, reason: String, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __banUser(userId, reason: reason, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    /**
     Unban a user in this room.
     
     - parameters:
         - userId: the user id.
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was successful.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func unbanUser(_ userId: String, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __unbanUser(userId, success: currySuccess(completion), failure: curryFailure(completion))
    }
    

    /**
     Set the power level of a member of the room.
     
     - parameters:
         - userId: the id of the user.
         - powerLevel: the value to set.
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was successful.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func setPowerLevel(ofUser userId: String, powerLevel: Int, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __setPowerLevelOfUserWithUserID(userId, powerLevel: powerLevel, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    
    /**
     Inform the home server that the user is typing (or not) in this room.
     
     - parameters:
         - typing: Use `true` if the user is currently typing.
         - timeout: the length of time until the user should be treated as no longer typing. Can be set to `nil` if they are no longer typing.
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was successful.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func sendTypingNotification(typing: Bool, timeout: TimeInterval?, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        
        // The `timeout` variable should be set to -1 if it's not provided.
        let _timeout: Int
        if let timeout = timeout {
            // The `TimeInterval` type is a double value specified in seconds. Multiply by 1000 to get milliseconds.
            _timeout = Int(timeout * 1000 /* milliseconds */)
        } else {
            _timeout = -1;
        }
        
        return __sendTypingNotification(typing, timeout: UInt(_timeout), success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    /**
     Redact an event in this room.
     
     - parameters:
         - eventId: the id of the redacted event.
         - reason: the redaction reason.
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was successful.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func redactEvent(_ eventId: String, reason: String?, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __redactEvent(eventId, reason: reason, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    /**
     Report an event.
     
     - parameters:
         - eventId: the id of the event event.
         - score: the metric to let the user rate the severity of the abuse. It ranges from -100 “most offensive” to 0 “inoffensive”.
         - reason: the redaction reason.
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was successful.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func reportEvent(_ eventId: String, score: Int, reason: String?, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __reportEvent(eventId, score: score, reason: reason, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    /**
     Send a reply to an event with text message to the room.
     
     It's only supported to reply to event with 'm.room.message' event type and following message types: 'm.text', 'm.text', 'm.emote', 'm.notice', 'm.image', 'm.file', 'm.video', 'm.audio'.
     
     - parameters:
        - eventToReply: The event to reply.
        - textMessage: The text to send.
        - formattedTextMessage: The optional HTML formatted string of the text to send.
        - stringLocalizations: String localizations used when building reply message.
        - localEcho: a pointer to an MXEvent object.

             When the event type is `MXEventType.roomMessage`, this pointer is set to an actual
             MXEvent object containing the local created event which should be used to echo the
             message in the messages list until the resulting event comes through the server sync.
             For information, the identifier of the created local event has the prefix:
             `kMXEventLocalEventIdPrefix`.

             You may specify nil for this parameter if you do not want this information.

             You may provide your own MXEvent object, in this case only its send state is updated.

             When the event type is `kMXEventTypeStringRoomEncrypted`, no local event is created.

         - completion: A block object called when the operation completes.
         - response: Provides the event id of the event generated on the home server on success

         - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func sendReply(to eventToReply: MXEvent, textMessage: String, formattedTextMessage: String?, stringLocalizations: MXSendReplyEventStringsLocalizable?, localEcho: inout MXEvent?, completion: @escaping (_ response: MXResponse<String?>) -> Void) -> MXHTTPOperation {
        return __sendReply(to: eventToReply, withTextMessage: textMessage, formattedTextMessage: formattedTextMessage, stringLocalizations: stringLocalizations, localEcho: &localEcho, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    // MARK: - Room Tags Operations
    
    /**
     Add a tag to a room.
     
     Use this method to update the order of an existing tag.
     
     - parameters:
         - tag: the new tag to add to the room.
         - order: the order. See MXRoomTag.order.
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was successful.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func addTag(_ tag: String, withOrder order: String, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __addTag(tag, withOrder: order, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    /**
     Remove a tag from a room.
     
     - parameters:
         - tag: the tag to remove.
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was successful.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func removeTag(_ tag: String, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __removeTag(tag, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    /**
     Remove a tag and add another one.
     
     - parameters:
         - oldTag: the tag to remove.
         - newTag: the new tag to add. If this is nil, no new tag will be added.
         - newTagOrder: the order. See MXRoomTag.order.
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was successful.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func replaceTag(_ oldTag: String, with newTag: String?, withOrder newTagOrder: String, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __addTag(oldTag, withOrder: newTagOrder, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    // MARK: - Voice Over IP
    
    /**
     Place a voice or a video call into the room.
     
     - parameters:
         - video: true to make a video call.
         - completion: A block object called when the operation completes.
         - response: Provides the created `MXCall` instance on success.
     */
    @nonobjc func placeCall(withVideo hasVideo: Bool, completion: @escaping (_ response: MXResponse<MXCall>) -> Void) {
        __placeCall(withVideo: hasVideo, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    
    // MARK: - Crypto
    
    /**
     Enable encryption in this room.
     
     You can check if a room is encrypted via its state (MXRoomState.isEncrypted)
     
     - parameters:
         - algoritm: the crypto algorithm to use.
         - completion: A block object called when the operation completes.
         - response: Indicates whether the operation was successful.
     
     - returns: a `MXHTTPOperation` instance.
     */
    @nonobjc @discardableResult func enableEncryption(withAlgorithm algorithm: String, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MXHTTPOperation {
        return __enableEncryption(withAlgorithm: algorithm, success: currySuccess(completion), failure: curryFailure(completion))
    }
}

