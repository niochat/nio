//
//  IntentHandler.swift
//  NioIntentsExtension
//
//  Created by Finn Behrens on 15.06.21.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

import Intents
import CoreSpotlight
import CoreServices

import NioKit
import MatrixSDK

// As an example, this class is set up to handle Message intents.
// You will want to replace this or add other intents as appropriate.
// The intents you wish to handle must be declared in the extension's Info.plist.

// You can test your example integration by saying things to Siri like:
// "Send a message using <myApp>"
// "<myApp> John saying hello"
// "Search for messages in <myApp>"

public class IntentHandler: INExtension, INSendMessageIntentHandling, INSearchForMessagesIntentHandling, INSetMessageAttributeIntentHandling {
    
    override public func handler(for intent: INIntent) -> Any {
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.
        
        return self
    }
    
    // MARK: - INSendMessageIntentHandling
    
    // Implement resolution methods to provide additional information about your intent (optional).
    @MainActor
    public func resolveRecipients(for intent: INSendMessageIntent) async -> [INSendMessageRecipientResolutionResult] {
        guard let recipients = intent.recipients,
              recipients.count != 0
        else {
            return [INSendMessageRecipientResolutionResult.needsValue()]
        }
        
        let store = AccountStore.shared
        
        //await store.loginState.waitForLogin()
        //await Task.sleep(20_000)
        
        // TODO: wait at a better place
        while store.loginState.isAuthenticating {
            // FIXME: !!!!!!!
            #warning("this is not good coding!!!!!")
            await Task.yield()
            //print("logging in")
            //sleep(1)
        }
        
        var resolutionResults = [INSendMessageRecipientResolutionResult]()
        
        print("group name: \(String(describing: intent.speakableGroupName))")
        
        for recipient in recipients {
            print("handle: \(String(describing: recipient.personHandle))")
            print("searching for room: \(recipient.displayName)")
            let rooms = store.rooms.filter { $0.displayName.lowercased() == recipient.displayName.lowercased() }.map({room in
                INPerson(
                    personHandle: INPersonHandle(value: room.id.id, type: .unknown),
                    nameComponents: nil,
                    displayName: room.displayName,
                    image: room.avatarUrl.flatMap({ INImage(url: $0)}),
                    contactIdentifier: nil,
                    customIdentifier: room.id.id,
                    isMe: false,
                    suggestionType: .none)
            })
            switch rooms.count {
            case 2 ... Int.max:
                resolutionResults += [INSendMessageRecipientResolutionResult.disambiguation(with: rooms)]
            case 1:
                //resolutionResults += [INSendMessageRecipientResolutionResult.confirmationRequired(with: rooms.first!)]
                resolutionResults += [INSendMessageRecipientResolutionResult.success(with: rooms.first!)]
            case 0:
                print("did not find a room")
                resolutionResults += [INSendMessageRecipientResolutionResult.unsupported(forReason: .noValidHandle)]
            default:
                fatalError("how can this be possible?")
            }
        }
        return resolutionResults
        
        
        /*
            var resolutionResults = [INSendMessageRecipientResolutionResult]()
            for recipient in recipients {
                let matchingContacts = [recipient] // Implement your contact matching logic here to create an array of matching contacts
                switch matchingContacts.count {
                case 2  ... Int.max:
                    // We need Siri's help to ask user to pick one from the matches.
                    resolutionResults += [INSendMessageRecipientResolutionResult.disambiguation(with: matchingContacts)]
                    
                case 1:
                    // We have exactly one matching contact
                    resolutionResults += [INSendMessageRecipientResolutionResult.success(with: recipient)]
                    
                case 0:
                    // We have no contacts matching the description provided
                    resolutionResults += [INSendMessageRecipientResolutionResult.unsupported()]
                    
                default:
                    break
                    
                }
            }
            //completion(resolutionResults)
            return resolutionResults
        } else {
            return [INSendMessageRecipientResolutionResult.needsValue()]
            //completion([INSendMessageRecipientResolutionResult.needsValue()])
        }*/
    }
    
    public func resolveContent(for intent: INSendMessageIntent) async -> INStringResolutionResult {
        if let text = intent.content, !text.isEmpty {
            print("writing text: \(text)")
            return INStringResolutionResult.success(with: text)
        }
        
        return INStringResolutionResult.needsValue()
    }
    // Once resolution is completed, perform validation on the intent and provide confirmation (optional).
    
    public func confirm(intent: INSendMessageIntent) async -> INSendMessageIntentResponse {
        print("confirm")
        // Verify user is authenticated and your app is ready to send a message.
        
        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))
        let response = INSendMessageIntentResponse(code: .ready, userActivity: userActivity)
        return response
    }
    
    // Handle the completed intent (required).
    
    public func handle(intent: INSendMessageIntent) async -> INSendMessageIntentResponse {
        print("handle INSendMessageIntent")
        // Implement your application logic to send a message here.
        let store = await AccountStore.shared
        
        guard let recipient = intent.recipients?.first?.customIdentifier else {
            return INSendMessageIntentResponse(code: .failure, userActivity: nil)
        }
        let userActivity = NSUserActivity(activityType: "org.matrix.room")
        userActivity.isEligibleForSearch = true
        userActivity.isEligibleForHandoff = true
        userActivity.isEligibleForPrediction = true
        userActivity.title = intent.recipients!.first!.displayName
        userActivity.userInfo = ["id": recipient as String]

        let attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
        
        attributes.contentDescription = "Open chat with \(intent.recipients!.first!.displayName)"
        attributes.instantMessageAddresses = [ recipient ]
        userActivity.contentAttributeSet = attributes
        userActivity.webpageURL = URL(string: "https://matrix.to/#/\(recipient)")
        
        // TODO: wait at a better place
        while await store.loginState.isAuthenticating {
            // FIXME: !!!!!!!
            #warning("this is not good coding!!!!!")
            await Task.yield()
        }
        
        print("intent: \(intent)")
        
        guard
            let room = await store.findRoom(id: MXRoom.MXRoomId(recipient)),
            let content = intent.content
        else {
            // TODO: is this the right error?
            let response = INSendMessageIntentResponse(code: .failureMessageServiceNotAvailable, userActivity: userActivity)
            return response
        }
        
        await room.send(text: content, publishIntent: false)
        
        
        let response = INSendMessageIntentResponse(code: .success, userActivity: userActivity)
        return response
    }
    
    // Implement handlers for each intent you wish to handle.  As an example for messages, you may wish to also handle searchForMessages and setMessageAttributes.
    
    // MARK: - INSearchForMessagesIntentHandling
    
    public func handle(intent: INSearchForMessagesIntent) async -> INSearchForMessagesIntentResponse {
        // Implement your application logic to find a message that matches the information in the intent.
        
        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSearchForMessagesIntent.self))
        let response = INSearchForMessagesIntentResponse(code: .success, userActivity: userActivity)
        // Initialize with found message's attributes
        response.messages = [INMessage(
            identifier: "identifier",
            content: "I am so excited about SiriKit!",
            dateSent: Date(),
            sender: INPerson(personHandle: INPersonHandle(value: "sarah@example.com", type: .emailAddress), nameComponents: nil, displayName: "Sarah", image: nil,  contactIdentifier: nil, customIdentifier: nil),
            recipients: [INPerson(personHandle: INPersonHandle(value: "+1-415-555-5555", type: .phoneNumber), nameComponents: nil, displayName: "John", image: nil,  contactIdentifier: nil, customIdentifier: nil)]
        )]
        return response
    }
    
    // MARK: - INSetMessageAttributeIntentHandling
    
    public func handle(intent: INSetMessageAttributeIntent) async -> INSetMessageAttributeIntentResponse {
        // Implement your application logic to set the message attribute here.
        
        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSetMessageAttributeIntent.self))
        let response = INSetMessageAttributeIntentResponse(code: .success, userActivity: userActivity)
        return response
    }
}
